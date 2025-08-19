#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/prepare-tools.log"
exec > >(tee -i "$LOG_FILE") 2>&1

STEP_NO=0
step(){ STEP_NO=$((STEP_NO+1)); echo -e "\n=== [STEP $STEP_NO] $* ==="; }
die(){ echo "[ERROR] $*" >&2; exit 1; }
trap 'echo "[FAIL] at line $LINENO"; exit 1' ERR

export AWS_REGION="us-east-1"
export AWS_DEFAULT_REGION="$AWS_REGION"
export CLUSTER_NAME="KubleOps"
export KUBECONFIG="/root/.kube/config"
export HOME="/root"

SUB_SUFFIX="devops.firasbennacib.com"
PARENT_ZONE="firasbennacib.com"
TXT_OWNER_ID="$CLUSTER_NAME"
TXT_PREFIX="external-dns"

INGRESS_GROUP="kubleops-public"
SSL_REDIRECT="true"
BACKEND_IRSA_ROLE_NAME="KubleOps-ecr-access-role"
FRONTEND_IRSA_ROLE_NAME="KubleOps-ecr-access-role"
ACM_SSM_PARAM="/KubleOps/acm_arn"
CERT_DOMAIN="*.devops.firasbennacib.com"

APP_NAME="kubleops"

KARPENTER_VERSION="1.6.2"
KARPENTER_CRD_VERSION="1.6.2"
KARPENTER_NS="kube-system"
KARPENTER_SA="karpenter"

curl_retry(){
  local u="$1" o="$2" n=1
  while :; do
    echo "[DL] $u (try $n)"
    if curl -fsSL --retry 5 --retry-connrefused --retry-delay 2 -o "$o" "$u"; then return 0; fi
    (( n>=5 )) && die "download failed: $u"
    sleep $((2**n)); ((n++))
  done
}
ns(){ kubectl get ns "$1" >/dev/null 2>&1 || kubectl create ns "$1"; }
pf(){
  local ns="$1" svc="$2" map="$3"
  pkill -f "kubectl -n $ns port-forward svc/$svc $map" >/dev/null 2>&1 || true
  nohup kubectl -n "$ns" port-forward "svc/$svc" $map >/var/log/${svc}-pf.log 2>&1 &
}

wait_for_noop(){
  local app="$1" timeout="${2:-1800}"
  echo "[ARGOCD] waiting for no running operation on app '${app}'..."

  argocd app wait "$app" --operation --timeout "$timeout" --grpc-web || true

  until argocd app wait "$app" --operation --timeout 15 --grpc-web >/dev/null 2>&1; do
    sleep 5
  done
}

safe_argocd_app_set(){ 
  local app="$1"; shift
  for i in {1..6}; do
    if argocd app set "$app" --grpc-web "$@"; then return 0; fi
    echo "[ARGOCD] app set collided with a running operation; waiting & retrying ($i/6)..."
    wait_for_noop "$app" 300
    sleep 5
  done
  die "argocd app set failed after retries"
}


step "Ensure SSM agent and base packages"
if ! systemctl is-active --quiet amazon-ssm-agent && ! systemctl is-active --quiet snap.amazon-ssm-agent.amazon-ssm-agent.service; then
  apt-get update -y && apt-get install -y snapd
  snap install amazon-ssm-agent --classic || true
  systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service || systemctl enable --now amazon-ssm-agent || true
fi

apt-get update -y
apt-get install -y ca-certificates unzip curl wget jq gnupg lsb-release apt-transport-https bash-completion git tar
mkdir -p /root/.{kube,argocd}

step "Install or verify AWS CLI"
if ! command -v aws >/dev/null; then
  curl_retry "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp && /tmp/aws/install
fi
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

step "Wait for EKS cluster to be ACTIVE"
until [[ "$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query "cluster.status" --output text)" == "ACTIVE" ]]; do
  echo "[WAIT] EKS cluster state ..."
  sleep 10
done

step "Install kubectl, Helm, ArgoCD CLI, eksctl"
K8S_MINOR="$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query "cluster.version" --output text 2>/dev/null || echo "1.28")"
KREL="$(curl -fsSL "https://dl.k8s.io/release/stable-${K8S_MINOR}.txt" 2>/dev/null || echo "v1.28.4")"
curl_retry "https://dl.k8s.io/release/${KREL}/bin/linux/amd64/kubectl" /usr/local/bin/kubectl || curl_retry "https://dl.k8s.io/release/v1.28.4/bin/linux/amd64/kubectl" /usr/local/bin/kubectl
chmod +x /usr/local/bin/kubectl
curl_retry "https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3" /tmp/get-helm-3 && bash /tmp/get-helm-3
ARGOCD_VERSION="v3.1.0"
curl_retry "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64" /usr/local/bin/argocd
chmod +x /usr/local/bin/argocd
if ! command -v eksctl >/dev/null; then
  curl_retry "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" /tmp/eksctl.tgz
  tar -xzf /tmp/eksctl.tgz -C /usr/local/bin
  chmod +x /usr/local/bin/eksctl
fi

step "Configure kubeconfig for root and ubuntu"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
install -d -o ubuntu -g ubuntu /home/ubuntu/.kube
cp -f /root/.kube/config /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

step "Discover VPC info"
VPC_ID="$(aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER_NAME" --query "cluster.resourcesVpcConfig.vpcId" --output text)"
VPC_CIDR="$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --query 'Vpcs[0].CidrBlock' --output text)"
CLUSTER_ENDPOINT="$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query "cluster.endpoint" --output text)"

step "Wait for core EKS components"
kubectl -n kube-system rollout status ds/aws-node --timeout=5m
kubectl -n kube-system rollout status deploy/coredns --timeout=5m
kubectl -n kube-system rollout status ds/kube-proxy --timeout=5m || true
kubectl -n kube-system rollout status deploy/ebs-csi-controller --timeout=5m || true
kubectl -n kube-system rollout status ds/ebs-csi-node --timeout=5m || true
kubectl -n kube-system rollout status ds/fluent-bit --timeout=5m || true
kubectl -n kube-system rollout status deploy/metrics-server --timeout=5m || true

step "Add Helm repos and update"
helm repo add eks https://aws.github.io/eks-charts || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/ || true
helm repo add argo https://argoproj.github.io/argo-helm || true
helm repo update

step "Install kube-prometheus-stack"
ns monitoring
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n monitoring \
  --set kubeStateMetrics.enabled=false \
  --set nodeExporter.enabled=false \
  --wait

step "Port-forward Grafana (3000) and Prometheus (9090)"
GF_SVC="$(kubectl -n monitoring get svc -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo monitoring-grafana)"
PM_SVC="$(kubectl -n monitoring get svc -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo monitoring-kube-prometheus-prometheus)"
pf monitoring "$GF_SVC" "3000:80"
pf monitoring "$PM_SVC" "9090:9090"
GRAFANA_PASS="$(kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' 2>/dev/null | base64 -d || true)"

step "Install AWS Load Balancer Controller CRDs (raw YAML)"
curl -fsSL https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml -o /tmp/alb-crds.yaml
kubectl apply -f /tmp/alb-crds.yaml
until kubectl get crd targetgroupbindings.elbv2.k8s.aws >/dev/null 2>&1; do sleep 2; done

step "Install AWS Load Balancer Controller via Helm"
ALB_ROLE_ARN="$(aws iam get-role --role-name AmazonEKSLoadBalancerControllerRole --query "Role.Arn" --output text 2>/dev/null || true)"
[[ -z "${ALB_ROLE_ARN:-}" || "${ALB_ROLE_ARN}" == "None" ]] && die "Missing IRSA role: AmazonEKSLoadBalancerControllerRole"
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

step "Discover Karpenter IRSA role, node role, and interruption queue"
KARPENTER_ROLE_ARN="$(aws iam get-role --role-name "${CLUSTER_NAME}-karpenter" --query "Role.Arn" --output text 2>/dev/null || true)"
[[ -z "${KARPENTER_ROLE_ARN:-}" || "${KARPENTER_ROLE_ARN}" == "None" ]] && die "Missing IRSA role for Karpenter (${CLUSTER_NAME}-karpenter)"
KARPENTER_NODE_ROLE_NAME="KarpenterNodeRole-${CLUSTER_NAME}"
KARPENTER_NODE_ROLE_ARN="$(aws iam get-role --role-name "${KARPENTER_NODE_ROLE_NAME}" --query "Role.Arn" --output text 2>/dev/null || true)"
[[ -z "${KARPENTER_NODE_ROLE_ARN:-}" || "${KARPENTER_NODE_ROLE_ARN}" == "None" ]] && die "Missing Karpenter node role: ${KARPENTER_NODE_ROLE_NAME}"
INTERRUPTION_QUEUE_NAME="${CLUSTER_NAME}"

step "Grant Karpenter node access via EKS Access Entries"
aws eks create-access-entry \
  --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$KARPENTER_NODE_ROLE_ARN" \
  --type EC2_LINUX >/dev/null 2>&1 || true
if ! aws eks describe-access-entry \
  --cluster-name "$CLUSTER_NAME" \
  --principal-arn "$KARPENTER_NODE_ROLE_ARN" \
  --query 'accessEntry.[principalArn,type,kubernetesGroups]' --output table >/dev/null 2>&1; then
  echo "[WARN] eks:DescribeAccessEntry not allowed yet for this instance role; ensure policy permits it on the access-entry ARN."
fi

helm registry logout public.ecr.aws || true

step "Install/upgrade Karpenter CRDs and controller"
helm upgrade --install karpenter-crd oci://public.ecr.aws/karpenter/karpenter-crd \
  --version "${KARPENTER_CRD_VERSION}" \
  --namespace "${KARPENTER_NS}" --create-namespace --wait

helm upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --version "${KARPENTER_VERSION}" \
  --namespace "${KARPENTER_NS}" \
  --set "settings.clusterName=${CLUSTER_NAME}" \
  --set "settings.clusterEndpoint=${CLUSTER_ENDPOINT}" \
  --set "settings.interruptionQueue=${INTERRUPTION_QUEUE_NAME}" \
  --set serviceAccount.create=true \
  --set "serviceAccount.name=${KARPENTER_SA}" \
  --set "serviceAccount.annotations.eks\.amazonaws\.com/role-arn=${KARPENTER_ROLE_ARN}" \
  --wait
kubectl -n "${KARPENTER_NS}" rollout status deploy/karpenter --timeout=10m


step "Install Argo CD (Helm, with ServiceMonitors)"
ns argocd
helm upgrade --install argocd argo/argo-cd -n argocd \
  --set server.metrics.enabled=true \
  --set server.serviceMonitor.enabled=true \
  --set repoServer.metrics.enabled=true \
  --set repoServer.serviceMonitor.enabled=true \
  --set controller.metrics.enabled=true \
  --set controller.serviceMonitor.enabled=true \
  --wait

ARGOCD_SVC="$(kubectl -n argocd get svc -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}')"
ARGOCD_DEPLOY="$(kubectl -n argocd get deploy -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].metadata.name}')"
kubectl -n argocd rollout status "deploy/${ARGOCD_DEPLOY}" --timeout=10m

step "Port-forward ArgoCD to https://localhost:8443"
pf argocd "${ARGOCD_SVC}" "8443:443"
sleep 5
ARGOCD_PASS="$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"

step "Resolve ACM cert ARN"
ACM_ARN="$(aws ssm get-parameter --name "${ACM_SSM_PARAM}" --query 'Parameter.Value' --output text 2>/dev/null || true)"
if [[ -z "${ACM_ARN:-}" || "${ACM_ARN}" == "None" ]]; then
  ACM_ARN="$(aws acm list-certificates --includes keyTypes=RSA_2048,RSA_4096,EC_prime256v1,EC_secp384r1 \
    --query "CertificateSummaryList[?DomainName=='${CERT_DOMAIN}' && Status=='ISSUED'].CertificateArn | [0]" --output text)"
fi
[[ -z "${ACM_ARN:-}" || "${ACM_ARN}" == "None" ]] && die "ACM not found for ${CERT_DOMAIN}"

step "Install ExternalDNS (Helm + IRSA)"
ns external-dns
EXTERNAL_DNS_ROLE_ARN="$(aws iam get-role --role-name "${CLUSTER_NAME}-external-dns-role" --query "Role.Arn" --output text 2>/dev/null || true)"
if [[ -z "${EXTERNAL_DNS_ROLE_ARN:-}" || "${EXTERNAL_DNS_ROLE_ARN}" == "None" ]]; then
  EXTERNAL_DNS_ROLE_ARN="$(aws iam get-role --role-name "KubleOps-external-dns-role" --query "Role.Arn" --output text 2>/dev/null || true)"
fi
[[ -z "${EXTERNAL_DNS_ROLE_ARN:-}" || "${EXTERNAL_DNS_ROLE_ARN}" == "None" ]] && die "Missing IRSA role for ExternalDNS"

ZONE_ID_ROOT="$(aws route53 list-hosted-zones-by-name --dns-name "${PARENT_ZONE}" \
  --query 'HostedZones[0].Id' --output text 2>/dev/null | sed 's|/hostedzone/||' || true)"
if [[ -n "${ZONE_ID_ROOT:-}" && "${ZONE_ID_ROOT}" != "None" ]]; then
  ZONE_FILTER_ARGS=( --set-string "zoneIdFilters[0]=${ZONE_ID_ROOT}" )
else
  ZONE_FILTER_ARGS=()
fi

helm upgrade --install external-dns external-dns/external-dns -n external-dns \
  --set "sources={service,ingress}" \
  --set-string "domainFilters[0]=${PARENT_ZONE}" ${ZONE_FILTER_ARGS[@]} \
  --set txtOwnerId="${TXT_OWNER_ID}" \
  --set txtPrefix="${TXT_PREFIX}" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=external-dns \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${EXTERNAL_DNS_ROLE_ARN}" \
  --set serviceMonitor.enabled=true \
  --set serviceMonitor.namespace=monitoring \
  --set env[0].name=AWS_DEFAULT_REGION \
  --set env[0].value="${AWS_REGION}" \
  --set interval=5m \
  --set policy=sync \
  --set provider.name=aws \
  --set-string 'extraArgs[0]=--regex-domain-exclusion=^_.*' \
  --set-string 'extraArgs[1]=--events' \
  --set-string 'extraArgs[2]=--min-event-sync-interval=5m' \
  --set-string 'extraArgs[3]=--aws-zones-cache-duration=1h' \
  --set-string 'extraArgs[4]=--aws-zone-type=public' \
  --wait

kubectl -n external-dns rollout status deploy/external-dns --timeout=3m || true


git clone https://github.com/firassBenNacib/KubleOps-manifest.git /tmp/KubleOps-manifest
kubectl apply -f /tmp/KubleOps-manifest/argocd-sync.yaml



step "Login to Argo CD"
argocd login localhost:8443 --username admin --password "$ARGOCD_PASS" --insecure --grpc-web

step "Wait for initial Argo CD operation(s) to finish for ${APP_NAME}"
wait_for_noop "$APP_NAME" 1800   

step "Disable auto-sync temporarily (if enabled)"
safe_argocd_app_set "$APP_NAME" --sync-policy none

wait_for_noop "$APP_NAME" 600

step "Set Helm values (IRSA, ACM, Ingress group, VPC CIDR)"
safe_argocd_app_set "$APP_NAME" \
  --helm-set backend.irsaRoleArn="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${BACKEND_IRSA_ROLE_NAME}" \
  --helm-set frontend.irsaRoleArn="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${FRONTEND_IRSA_ROLE_NAME}" \
  --helm-set ingress.certificateArn="$ACM_ARN" \
  --helm-set ingress.groupName="$INGRESS_GROUP" \
  --helm-set-string ingress.sslRedirect="$SSL_REDIRECT" \
  --helm-set-string 'networkPolicy.vpcCidrs[0]'"=$VPC_CIDR"

step "Sync once with overrides, then re-enable auto-sync"
argocd app sync "$APP_NAME" --grpc-web --prune
argocd app wait "$APP_NAME" --grpc-web --operation --timeout 1800
safe_argocd_app_set "$APP_NAME" --sync-policy automated || true

echo "[OK] KubleOps tools prepared successfully."
echo "Admin pw (ArgoCD): ${ARGOCD_PASS}"
echo "Admin pw (Grafana): ${GRAFANA_PASS}"
