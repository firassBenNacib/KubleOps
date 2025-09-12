#!/bin/bash
set -Eeuo pipefail
trap 'echo "[FAIL] at line $LINENO"; exit 1' ERR

LOG_FILE="/var/log/prepare-tools.log"
exec > >(tee -i "$LOG_FILE") 2>&1

export CLUSTER_NAME="${cluster_name}"
export PARENT_ZONE="${parent_zone}"
export CERT_DOMAIN="${cert_domain}"
export INGRESS_GROUP="${ingress_group}"
export SSL_REDIRECT="${ssl_redirect}"
SSM_PREFIX_RAW="${ssm_prefix}"

SSM_PREFIX="$SSM_PREFIX_RAW"
if [ -z "$SSM_PREFIX" ]; then SSM_PREFIX="/$CLUSTER_NAME"; fi
ACM_SSM_PARAM="$SSM_PREFIX/acm_arn"

KARPENTER_VERSION="1.6.2"
KARPENTER_CRD_VERSION="1.6.2"
KARPENTER_NS="karpenter"
KARPENTER_SA="karpenter"

EXTERNAL_DNS_NS="external-dns"
EXTERNAL_DNS_SA="external-dns"

ARGOCD_NS="argocd"

TXT_OWNER_ID="$CLUSTER_NAME"
TXT_PREFIX="external-dns"

step(){ echo -e "\n=== [STEP] $* ==="; }
warn(){ echo "[WARN] $*" >&2; }
die(){ echo "[ERROR] $*" >&2; exit 1; }
have(){ command -v "$1" >/dev/null 2>&1; }

curl_retry(){
  url="$1"; out="$2"; n=1
  while :; do
    echo "[DL] $url (try $n)"
    if curl -fsSL --retry 5 --retry-connrefused --retry-delay 2 -o "$out" "$url"; then return 0; fi
    [ $n -ge 5 ] && die "download failed: $url"
    sleep $((2**n)); n=$((n+1))
  done
}

ns(){ kubectl get ns "$1" >/dev/null 2>&1 || kubectl create ns "$1"; }

pf(){
  ns_="$1"; svc="$2"; map="$3"
  pkill -f "kubectl -n $ns_ port-forward svc/$svc $map" >/dev/null 2>&1 || true
  nohup kubectl -n "$ns_" port-forward "svc/$svc" $map >"/var/log/$${svc}-pf.log" 2>&1 &
}

ssm_get(){ aws ssm get-parameter --name "$1" --query 'Parameter.Value' --output text 2>/dev/null || true; }

region_from_imds(){
  tk="$(curl -sS -m 2 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)"
  if [ -n "$tk" ]; then
    doc="$(curl -sS -m 2 -H "X-aws-ec2-metadata-token: $tk" http://169.254.169.254/latest/dynamic/instance-identity/document || true)"
  else
    doc="$(curl -sS -m 2 http://169.254.169.254/latest/dynamic/instance-identity/document || true)"
  fi
  echo "$doc" | sed -n 's/.*"region"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
}

AWS_REGION="$(region_from_imds || true)"; [ -z "$AWS_REGION" ] && AWS_REGION="us-east-1"
export AWS_REGION
export AWS_DEFAULT_REGION="$AWS_REGION"
export KUBECONFIG="/root/.kube/config"
export HOME="/root"

step "Ensure SSM agent and base packages"
os_id(){ . /etc/os-release 2>/dev/null || true; echo "$${ID:-unknown}"; }

case "$(os_id)" in
  amzn|amazon)
    systemctl enable --now amazon-ssm-agent || true
    if have dnf; then
      dnf -y update || true
      if ! dnf -y install unzip curl-minimal wget jq tar git-core bash-completion ca-certificates; then
        dnf -y swap curl-minimal curl || true
        dnf -y install unzip curl wget jq tar git-core bash-completion ca-certificates || true
      fi
    else
      yum -y update || true
      yum -y install unzip curl wget jq tar git-core bash-completion ca-certificates || true
    fi
    ;;
  ubuntu|debian)
    if ! systemctl is-active --quiet amazon-ssm-agent && \
       ! systemctl is-active --quiet snap.amazon-ssm-agent.amazon-ssm-agent.service; then
      apt-get update -y
      apt-get install -y snapd
      snap install amazon-ssm-agent --classic || true
      systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service || \
      systemctl enable --now amazon-ssm-agent || true
    fi
    apt-get update -y
    apt-get install -y ca-certificates unzip curl wget jq gnupg lsb-release apt-transport-https bash-completion git tar || true
    ;;
  *)
    warn "Unknown OS; attempting generic package setup."
    have amazon-ssm-agent && systemctl enable --now amazon-ssm-agent || true
    ;;
esac

if ! have git; then
  have dnf && dnf -y install git-core || true
  have yum && yum -y install git || true
  have apt-get && apt-get update -y && apt-get install -y git || true
fi

step "Install AWS CLI if missing"
if ! have aws; then
  curl_retry "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp && /tmp/aws/install
fi
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

step "Wait for EKS cluster to be ACTIVE"
until [ "$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query "cluster.status" --output text)" = "ACTIVE" ]; do
  echo "[WAIT] EKS cluster state ..."
  sleep 10
done

step "Install kubectl, Helm, Argo CD CLI"
K8S_MINOR="$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query "cluster.version" --output text 2>/dev/null || echo "1.28")"
KREL="$(curl -fsSL "https://dl.k8s.io/release/stable-$K8S_MINOR.txt" 2>/dev/null || echo "v1.28.4")"
curl_retry "https://dl.k8s.io/release/$KREL/bin/linux/amd64/kubectl" /usr/local/bin/kubectl || curl_retry "https://dl.k8s.io/release/v1.28.4/bin/linux/amd64/kubectl" /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl
curl_retry "https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3" /tmp/get-helm-3 && bash /tmp/get-helm-3
ARGOCD_VERSION="v3.1.0"
curl_retry "https://github.com/argoproj/argo-cd/releases/download/$ARGOCD_VERSION/argocd-linux-amd64" /usr/local/bin/argocd
chmod +x /usr/local/bin/argocd
mkdir -p /root/.kube /root/.argocd

step "Configure kubeconfig for root and ubuntu"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
if id ubuntu >/dev/null 2>&1; then
  install -d -o ubuntu -g ubuntu /home/ubuntu/.kube
  cp -f /root/.kube/config /home/ubuntu/.kube/config
  chown -R ubuntu:ubuntu /home/ubuntu/.kube
fi

CLUSTER_ENDPOINT="$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query "cluster.endpoint" --output text)"
API_HOST="$(echo "$CLUSTER_ENDPOINT" | sed -E 's#https?://([^/]+)/?.*#\1#')"
if ! timeout 5 bash -c "echo > /dev/tcp/$API_HOST/443" 2>/dev/null; then
  die "Cannot reach EKS API endpoint $API_HOST:443 (likely missing SG rule to cluster SG)."
fi

step "Discover VPC and cluster info"
VPC_ID="$(aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER_NAME" --query "cluster.resourcesVpcConfig.vpcId" --output text)"
VPC_CIDR="$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --query 'Vpcs[0].CidrBlock' --output text)"
mapfile -t SUBNET_IDS < <(aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER_NAME" --query 'cluster.resourcesVpcConfig.subnetIds[]' --output text)

step "Check subnet available IPs (heads-up only)"
if [ "$${#SUBNET_IDS[@]}" -gt 0 ]; then
  for sid in "$${SUBNET_IDS[@]}"; do
    [ -z "$sid" ] && continue
    avail="$(aws ec2 describe-subnets --subnet-ids "$sid" --query 'Subnets[0].AvailableIpAddressCount' --output text 2>/dev/null || echo 0)"
    echo " - $sid has $avail available IPs"
    if [ "$avail" -lt 16 ]; then
      warn "Subnet $sid is low on free IPs (<16). Consider larger CIDRs or additional subnets to avoid CNI allocation failures."
    fi
  done
fi

step "Wait for core EKS components"
kubectl -n kube-system rollout status ds/aws-node --timeout=5m || true
kubectl -n kube-system rollout status deploy/coredns --timeout=5m || true
kubectl -n kube-system rollout status ds/kube-proxy --timeout=5m || true

step "Add Helm repos and update"
helm repo add eks https://aws.github.io/eks-charts || true
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/ || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo add argo https://argoproj.github.io/argo-helm || true
helm repo update

step "Install kube-prometheus-stack (Grafana/Prometheus)"
ns monitoring
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n monitoring \
  --set kubeStateMetrics.enabled=true \
  --set nodeExporter.enabled=true \
  --wait

GF_SVC="$(kubectl -n monitoring get svc -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo monitoring-grafana)"
PM_SVC="$(kubectl -n monitoring get svc -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo monitoring-kube-prometheus-prometheus)"
pf monitoring "$GF_SVC" "3000:80"
pf monitoring "$PM_SVC" "9090:9090"
GRAFANA_PASS="$(kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d || true)"

step "Install AWS Load Balancer Controller CRDs"
curl -fsSL https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml -o /tmp/alb-crds.yaml
kubectl apply -f /tmp/alb-crds.yaml
until kubectl get crd targetgroupbindings.elbv2.k8s.aws >/dev/null 2>&1; do sleep 2; done

step "Install AWS Load Balancer Controller (via Helm + IRSA)"
ALB_ROLE_ARN="$(aws iam get-role --role-name AmazonEKSLoadBalancerControllerRole --query "Role.Arn" --output text 2>/dev/null || true)"
[ -z "$ALB_ROLE_ARN" ] || [ "$ALB_ROLE_ARN" = "None" ] && die "Missing IRSA role: AmazonEKSLoadBalancerControllerRole"
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set region="$AWS_REGION" \
  --set vpcId="$VPC_ID" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$ALB_ROLE_ARN" \
  --set metrics.enabled=true \
  --set serviceMonitor.enabled=true \
  --set serviceMonitor.namespace=monitoring \
  --wait
kubectl -n kube-system rollout status deploy/aws-load-balancer-controller --timeout=5m

step "Install ExternalDNS (Helm + IRSA) to manage app/api records"
ns "$EXTERNAL_DNS_NS"

EXTERNAL_DNS_ROLE_ARN="$(ssm_get "$SSM_PREFIX/external-dns/role_arn")"
if [ -z "$EXTERNAL_DNS_ROLE_ARN" ] || [ "$EXTERNAL_DNS_ROLE_ARN" = "None" ]; then
  for name in "$${CLUSTER_NAME}-external-dns-role" "$${CLUSTER_NAME}-external-dns" "KubleOps-external-dns-role"; do
    EXTERNAL_DNS_ROLE_ARN="$(aws iam get-role --role-name "$name" --query "Role.Arn" --output text 2>/dev/null || true)"
    [ -n "$EXTERNAL_DNS_ROLE_ARN" ] && [ "$EXTERNAL_DNS_ROLE_ARN" != "None" ] && break
  done
fi
[ -z "$EXTERNAL_DNS_ROLE_ARN" ] || [ "$EXTERNAL_DNS_ROLE_ARN" = "None" ] && die "Missing IRSA role for ExternalDNS"

ZONE_ID_ROOT="$(aws route53 list-hosted-zones-by-name --dns-name "$${PARENT_ZONE}" \
  --query 'HostedZones[0].Id' --output text 2>/dev/null | sed 's|/hostedzone/||' || true)"
if [ -n "$ZONE_ID_ROOT" ] && [ "$ZONE_ID_ROOT" != "None" ]; then
  ZONE_FILTER_ARGS=( --set-string "zoneIdFilters[0]=$${ZONE_ID_ROOT}" )
else
  ZONE_FILTER_ARGS=()
fi

helm upgrade --install external-dns external-dns/external-dns -n "$EXTERNAL_DNS_NS" \
  --set "sources={service,ingress}" \
  --set-string "domainFilters[0]=$${PARENT_ZONE}" \
  "$${ZONE_FILTER_ARGS[@]}" \
  --set txtOwnerId="$${TXT_OWNER_ID}" \
  --set txtPrefix="$${TXT_PREFIX}" \
  --set serviceAccount.create=true \
  --set serviceAccount.name="$EXTERNAL_DNS_SA" \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$${EXTERNAL_DNS_ROLE_ARN}" \
  --set serviceMonitor.enabled=true \
  --set serviceMonitor.namespace=monitoring \
  --set env[0].name=AWS_DEFAULT_REGION \
  --set env[0].value="$${AWS_REGION}" \
  --set interval=5m \
  --set policy=sync \
  --set provider.name=aws \
  --set-string 'extraArgs[0]=--regex-domain-exclusion=^_.*' \
  --set-string 'extraArgs[1]=--events' \
  --set-string 'extraArgs[2]=--min-event-sync-interval=5m' \
  --set-string 'extraArgs[3]=--aws-zones-cache-duration=1h' \
  --set-string 'extraArgs[4]=--aws-zone-type=public' \
  --wait

kubectl -n "$EXTERNAL_DNS_NS" rollout status deploy/external-dns --timeout=3m || true

step "Install/upgrade Karpenter (IRSA from SSM or name fallback)"
KARPENTER_ROLE_ARN="$(ssm_get "$SSM_PREFIX/karpenter/controller_role_arn")"
if [ -z "$KARPENTER_ROLE_ARN" ] || [ "$KARPENTER_ROLE_ARN" = "None" ]; then
  for name in "KarpenterController-$CLUSTER_NAME" "$CLUSTER_NAME-karpenter" "karpenter-controller-$CLUSTER_NAME"; do
    KARPENTER_ROLE_ARN="$(aws iam get-role --role-name "$name" --query 'Role.Arn' --output text 2>/dev/null || true)"
    [ -n "$KARPENTER_ROLE_ARN" ] && [ "$KARPENTER_ROLE_ARN" != "None" ] && break
  done
fi
[ -z "$KARPENTER_ROLE_ARN" ] || [ "$KARPENTER_ROLE_ARN" = "None" ] && die "Missing IRSA role for Karpenter"

KARPENTER_NODE_ROLE_ARN="$(ssm_get "$SSM_PREFIX/karpenter/node_role_arn")"
if [ -z "$KARPENTER_NODE_ROLE_ARN" ] || [ "$KARPENTER_NODE_ROLE_ARN" = "None" ]; then
  KARPENTER_NODE_ROLE_ARN="$(aws iam get-role --role-name "KarpenterNodeRole-$CLUSTER_NAME" --query "Role.Arn" --output text 2>/dev/null || true)"
fi
[ -z "$KARPENTER_NODE_ROLE_ARN" ] || [ "$KARPENTER_NODE_ROLE_ARN" = "None" ] && die "Missing Karpenter node role"

aws eks create-access-entry \
  --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$KARPENTER_NODE_ROLE_ARN" \
  --type EC2_LINUX >/dev/null 2>&1 || true

helm registry logout public.ecr.aws || true
helm upgrade --install karpenter-crd oci://public.ecr.aws/karpenter/karpenter-crd \
  --version "$KARPENTER_CRD_VERSION" \
  --namespace "$KARPENTER_NS" --create-namespace --wait

helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version "$KARPENTER_VERSION" \
  --namespace "$KARPENTER_NS" \
  --set settings.clusterName="$CLUSTER_NAME" \
  --set settings.clusterEndpoint="$CLUSTER_ENDPOINT" \
  --set settings.interruptionQueue="$CLUSTER_NAME" \
  --set serviceAccount.create=true \
  --set serviceAccount.name="$KARPENTER_SA" \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$KARPENTER_ROLE_ARN" \
  --wait
kubectl -n "$KARPENTER_NS" rollout status deploy/karpenter --timeout=10m

step "Install Argo CD via Helm"
ns "$ARGOCD_NS"
helm upgrade --install argocd argo/argo-cd -n "$ARGOCD_NS" --wait
kubectl -n "$ARGOCD_NS" rollout status deploy/argocd-server --timeout=10m

ARGOCD_SVC="$(kubectl -n "$ARGOCD_NS" get svc -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}')"
pf "$ARGOCD_NS" "$ARGOCD_SVC" "8443:443"
sleep 5
if kubectl -n "$ARGOCD_NS" get secret argocd-initial-admin-secret >/dev/null 2>&1; then
  ARGOCD_PASS="$(kubectl -n "$ARGOCD_NS" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d || true)"
  if [ -n "$ARGOCD_PASS" ]; then
    argocd login localhost:8443 --username admin --password "$ARGOCD_PASS" --insecure --grpc-web || true
  fi
else
  echo "[INFO] Argo CD admin password secret not present (maybe SSO enabled)."
fi

step "Apply KubleOps Argo CD bootstrap"
if ! have git; then
  have dnf && dnf -y install git-core || true
  have yum && yum -y install git || true
  have apt-get && apt-get update -y && apt-get install -y git || true
fi

if git clone https://github.com/firassBenNacib/KubleOps-manifest.git /tmp/KubleOps-manifest 2>/dev/null; then
  kubectl apply -f /tmp/KubleOps-manifest/argocd-sync.yaml || true
else
  warn "Unable to clone KubleOps-manifest. Skipping bootstrap."
fi

APP_NAME="kubleops"
if argocd app get "$APP_NAME" --grpc-web >/dev/null 2>&1; then
  step "Resolve ACM certificate ARN (SSM first, then search)"
  ACM_ARN="$(ssm_get "$ACM_SSM_PARAM")"
  if [ -z "$ACM_ARN" ] || [ "$ACM_ARN" = "None" ]; then
    ACM_ARN="$(aws acm list-certificates --includes keyTypes=RSA_2048,RSA_4096,EC_prime256v1,EC_secp384r1 \
      --query "CertificateSummaryList[?DomainName=='$CERT_DOMAIN' && Status=='ISSUED'].CertificateArn | [0]" --output text || true)"
  fi
  [ -z "$ACM_ARN" ] || [ "$ACM_ARN" = "None" ] && warn "ACM not found for $CERT_DOMAIN; continuing without it."

  step "Sync KubleOps app with overrides"
  argocd app wait "$APP_NAME" --operation --timeout 600 --grpc-web || true
  argocd app set "$APP_NAME" --grpc-web --sync-policy none || true
  argocd app wait "$APP_NAME" --operation --timeout 600 --grpc-web || true

  if [ -n "$ACM_ARN" ] && [ "$ACM_ARN" != "None" ]; then
    argocd app set "$APP_NAME" --grpc-web --helm-set ingress.certificateArn="$ACM_ARN" || true
  fi

  argocd app set "$APP_NAME" --grpc-web \
    --helm-set ingress.groupName="$INGRESS_GROUP" \
    --helm-set-string ingress.sslRedirect="$SSL_REDIRECT" \
    --helm-set-string networkPolicy.vpcCidrs[0]="$VPC_CIDR" \
    --helm-set karpenter.nodeRoleArn="$KARPENTER_NODE_ROLE_ARN" || true

  argocd app sync "$APP_NAME" --grpc-web --prune || true
  argocd app wait "$APP_NAME" --grpc-web --operation --timeout 1800 || true
  argocd app set "$APP_NAME" --grpc-web --sync-policy automated || true
else
  echo "[INFO] Argo app '$APP_NAME' not present yet. It may sync shortly after bootstrap."
fi

echo
echo "[OK] KubleOps tools prepared successfully."
if [ -n "$${ARGOCD_PASS:-}" ]; then echo "Admin pw (ArgoCD): $ARGOCD_PASS"; fi
if [ -n "$${GRAFANA_PASS:-}" ]; then echo "Admin pw (Grafana): $GRAFANA_PASS"; fi
echo "Region: $AWS_REGION"
echo "Cluster: $CLUSTER_NAME"
