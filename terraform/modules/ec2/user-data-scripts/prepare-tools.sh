#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/prepare-tools.log"
exec > >(tee -i "$LOG_FILE")
exec 2>&1

echo "[START] Provisioning started at $(date)"

export AWS_REGION="us-east-1"
export AWS_DEFAULT_REGION="$AWS_REGION"
export CLUSTER_NAME="KubleOps"
export KUBECONFIG="/root/.kube/config"

SONAR_PORT=9000

APEX_ZONE="firasbennacib.com"
TXT_OWNER_ID="$CLUSTER_NAME"
TXT_PREFIX="external-dns"

INGRESS_GROUP="kubleops-public"
SSL_REDIRECT="true"
BACKEND_IRSA_ROLE_NAME="KubleOps-ecr-access-role"
FRONTEND_IRSA_ROLE_NAME="KubleOps-ecr-access-role"
ACM_SSM_PARAM="/KubleOps/acm_arn"
CERT_DOMAIN="*.devops.firasbennacib.com"

echo "[INFO] Installing base packages..."
apt-get update -y
apt-get install -y docker.io unzip curl wget jq gnupg lsb-release apt-transport-https bash-completion git

echo "[INFO] Enabling Docker..."
usermod -aG docker ubuntu || true
systemctl enable docker
systemctl restart docker
chmod 666 /var/run/docker.sock || true

echo "[INFO] Starting SonarQube on :${SONAR_PORT} ..."
docker run -d --name sonar -p ${SONAR_PORT}:${SONAR_PORT} sonarqube:lts-community || echo "[WARN] SonarQube may already be running."
EC2_PUBLIC_IP="$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || true)"

if ! command -v aws &>/dev/null; then
  echo "[INFO] Installing AWS CLI..."
  curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install
fi
aws --version
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query "Account" --output text)"
export AWS_ACCOUNT_ID

echo "[INFO] Installing kubectl..."
curl -fsSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/v1.28.4/bin/linux/amd64/kubectl"
chmod +x /usr/local/bin/kubectl

echo "[INFO] Installing eksctl..."
curl -sSL "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" | tar xz -C /usr/local/bin

echo "[INFO] Installing Trivy..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | tee /etc/apt/keyrings/trivy.asc >/dev/null
echo "deb [signed-by=/etc/apt/keyrings/trivy.asc] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/trivy.list
apt-get update && apt-get install -y trivy

echo "[INFO] Installing Helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "[INFO] Installing ArgoCD CLI..."
curl -fsSL -o /usr/local/bin/argocd "https://github.com/argoproj/argo-cd/releases/download/v2.4.7/argocd-linux-amd64"
chmod +x /usr/local/bin/argocd

echo "[INFO] Waiting for EKS cluster '$CLUSTER_NAME' to become ACTIVE..."
until [[ "$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query "cluster.status" --output text)" == "ACTIVE" ]]; do
  echo "[WAIT] EKS is not ready yet..."
  sleep 15
done

echo "[INFO] Configuring kubeconfig..."
mkdir -p /root/.kube
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

mkdir -p /home/ubuntu/.kube
cp -f /root/.kube/config /home/ubuntu/.kube/config || true
chown -R ubuntu:ubuntu /home/ubuntu/.kube || true

kubectl get nodes || echo "[WARN] kubectl may not be fully ready yet."

echo "[INFO] Installing AWS Load Balancer Controller CRDs..."
curl -fsSL -o /tmp/alb-crds.yaml https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml
kubectl apply -f /tmp/alb-crds.yaml

ALB_ROLE_ARN="$(aws iam get-role --role-name AmazonEKSLoadBalancerControllerRole --query "Role.Arn" --output text)"

kubectl create serviceaccount aws-load-balancer-controller -n kube-system || true
kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system "eks.amazonaws.com/role-arn=${ALB_ROLE_ARN}" --overwrite

helm repo add eks https://aws.github.io/eks-charts
helm repo update

VPC_ID="$(aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER_NAME" --query "cluster.resourcesVpcConfig.vpcId" --output text)"

echo "[INFO] Deploying AWS Load Balancer Controller..."
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set region="$AWS_REGION" \
  --set vpcId="$VPC_ID" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

kubectl rollout status deployment/aws-load-balancer-controller -n kube-system

echo "[INFO] Installing ExternalDNS (cleanup pass: policy=sync)..."
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update

EXTERNAL_DNS_ROLE_ARN="$(aws iam get-role --role-name "KubleOps-external-dns-role" --query "Role.Arn" --output text || true)"
kubectl create namespace external-dns || true

helm upgrade --install external-dns external-dns/external-dns \
  -n external-dns \
  --set provider=aws \
  --set policy=sync \
  --set registry=txt \
  --set "sources={ingress}" \
  --set "domainFilters={${APEX_ZONE}}" \
  --set txtOwnerId="${TXT_OWNER_ID}" \
  --set txtPrefix="${TXT_PREFIX}" \
  --set interval=30s \
  --set serviceAccount.create=true \
  --set serviceAccount.name=external-dns \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${EXTERNAL_DNS_ROLE_ARN}"

sleep 60
kubectl -n external-dns logs deploy/external-dns | tail -n 200 || true

echo "[INFO] Switching ExternalDNS to steady-state (policy=upsert-only)..."
helm upgrade --install external-dns external-dns/external-dns \
  -n external-dns \
  --set provider=aws \
  --set policy=upsert-only \
  --set registry=txt \
  --set "sources={ingress}" \
  --set "domainFilters={${APEX_ZONE}}" \
  --set txtOwnerId="${TXT_OWNER_ID}" \
  --set txtPrefix="${TXT_PREFIX}" \
  --set interval=1m \
  --set serviceAccount.create=true \
  --set serviceAccount.name=external-dns \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="${EXTERNAL_DNS_ROLE_ARN}"

kubectl rollout status deployment/external-dns -n external-dns

echo "[INFO] Installing Prometheus & Grafana (ClusterIP)..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl delete ns monitoring --ignore-not-found
kubectl create namespace monitoring
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n monitoring --wait

echo "[INFO] Installing Argo CD (ClusterIP)..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.4.7/manifests/install.yaml || true
kubectl rollout status deploy/argocd-server -n argocd

echo "[INFO] Port-forwarding ArgoCD server to localhost:8443 ..."
nohup kubectl -n argocd port-forward svc/argocd-server 8443:443 >/var/log/argocd-portforward.log 2>&1 &
sleep 5

ARGOCD_PASS="$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)"

echo "[INFO] Applying Argo CD bootstrap..."
rm -rf /tmp/KubleOps-manifest
git clone https://github.com/firassBenNacib/KubleOps-manifest.git /tmp/KubleOps-manifest
kubectl apply -f /tmp/KubleOps-manifest/argocd-sync.yaml

echo "[INFO] Waiting for ArgoCD app 'kubleops' to exist..."
until kubectl get applications.argoproj.io -n argocd kubleops >/dev/null 2>&1; do
  sleep 5
done

echo "[INFO] Resolving ACM certificate ARN for ${CERT_DOMAIN} ..."
set +e
ACM_ARN="$(aws ssm get-parameter --name "${ACM_SSM_PARAM}" --query 'Parameter.Value' --output text 2>/dev/null)"
set -e
if [[ -z "${ACM_ARN:-}" || "${ACM_ARN}" == "None" ]]; then
  echo "[INFO] SSM param not found; listing ACM certificates..."
  ACM_ARN="$(aws acm list-certificates \
    --includes keyTypes=RSA_2048,RSA_4096,EC_prime256v1,EC_secp384r1 \
    --query "CertificateSummaryList[?DomainName=='${CERT_DOMAIN}' && Status=='ISSUED'].CertificateArn | [0]" \
    --output text)"
fi
if [[ -z "${ACM_ARN:-}" || "${ACM_ARN}" == "None" ]]; then
  echo "[ERROR] Could not resolve ACM ARN for ${CERT_DOMAIN}"
  exit 1
fi
echo "[INFO] Using ACM ARN: $ACM_ARN"

echo "[INFO] Logging into ArgoCD CLI over localhost:8443 ..."
argocd login localhost:8443 --username admin --password "$ARGOCD_PASS" --insecure --grpc-web

BACKEND_IRSA="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${BACKEND_IRSA_ROLE_NAME}"
FRONTEND_IRSA="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${FRONTEND_IRSA_ROLE_NAME}"

echo "[INFO] Injecting Helm values into Argo CD app..."
argocd app set kubleops \
  --helm-set backend.irsaRoleArn="$BACKEND_IRSA" \
  --helm-set frontend.irsaRoleArn="$FRONTEND_IRSA" \
  --helm-set ingress.certificateArn="$ACM_ARN" \
  --helm-set ingress.groupName="$INGRESS_GROUP" \
  --helm-set-string ingress.sslRedirect="$SSL_REDIRECT" \
  --grpc-web

echo "[INFO] Syncing application 'kubleops'..."
argocd app sync kubleops --grpc-web

echo
echo "========= FINAL SUMMARY ========="
echo "SonarQube (public for CI):  http://${EC2_PUBLIC_IP}:${SONAR_PORT}"
echo
echo "ArgoCD / Grafana / Prometheus are private (ClusterIP)."
echo "Access via bastion + tunnels or from this EC2 using kubectl port-forward."
echo
echo "ExternalDNS manages A/AAAA + TXT in ${APEX_ZONE} for app/api ingress hosts."
echo "================================="
echo "[SUCCESS] Provisioning finished at $(date)"
