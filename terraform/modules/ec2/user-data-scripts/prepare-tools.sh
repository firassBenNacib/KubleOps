#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/prepare-tools.log"
exec > >(tee -i "$LOG_FILE")
exec 2>&1

echo "[START] Provisioning started at $(date)"

export AWS_REGION="us-east-1"
export CLUSTER_NAME="KubleOps"
export KUBECONFIG="/root/.kube/config"

echo "[INFO] Installing base packages..."
sudo apt update -y
sudo apt install -y docker.io unzip curl wget jq gnupg lsb-release apt-transport-https bash-completion git

echo "[INFO] Enabling Docker for ubuntu user..."
sudo usermod -aG docker ubuntu
sudo systemctl enable docker
sudo systemctl restart docker
sudo chmod 666 /var/run/docker.sock

echo "[INFO] Running SonarQube on port 9000..."
docker run -d --name sonar -p 9000:9000 sonarqube:lts-community || echo "[WARN] SonarQube may already be running."
EC2_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "UNKNOWN")

if ! command -v aws &>/dev/null; then
  echo "[INFO] Installing AWS CLI..."
  curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
  unzip -q awscliv2.zip
  sudo ./aws/install
fi

aws --version
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)

echo "[INFO] Installing kubectl..."
curl -LO "https://dl.k8s.io/release/v1.28.4/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

echo "[INFO] Installing eksctl..."
curl -sSL "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

echo "[INFO] Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "[INFO] Installing ArgoCD CLI..."
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/download/v2.4.7/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

echo "[INFO] Waiting for EKS cluster '$CLUSTER_NAME' to become ACTIVE..."
until [[ "$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query "cluster.status" --output text)" == "ACTIVE" ]]; do
  echo "[WAIT] EKS is not ready yet..."
  sleep 15
done

echo "[INFO] Configuring kubeconfig..."
mkdir -p /root/.kube
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

sleep 30
kubectl get nodes || echo "[WARN] kubectl cluster access may not be ready yet."

mkdir -p /home/ubuntu/.kube
cp -i /root/.kube/config /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube

echo "[INFO] Installing AWS Load Balancer Controller..."
wget -q https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml
kubectl apply -f crds.yaml

export ALB_ROLE_ARN=$(aws iam get-role --role-name AmazonEKSLoadBalancerControllerRole --query "Role.Arn" --output text)

kubectl create serviceaccount aws-load-balancer-controller -n kube-system || true
kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system eks.amazonaws.com/role-arn="$ALB_ROLE_ARN" --overwrite

helm repo add eks https://aws.github.io/eks-charts
helm repo update

export VPC_ID=$(aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER_NAME" --query "cluster.resourcesVpcConfig.vpcId" --output text)

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName="$CLUSTER_NAME" \
  --set region="$AWS_REGION" \
  --set vpcId="$VPC_ID" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

kubectl delete pod -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller || true
kubectl rollout status deployment/aws-load-balancer-controller -n kube-system

echo "[INFO] Installing Prometheus and Grafana..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl delete ns monitoring --ignore-not-found
kubectl create namespace monitoring
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack -n monitoring --wait

kubectl patch svc monitoring-grafana -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'
kubectl patch svc monitoring-kube-prometheus-prometheus -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'

echo "[INFO] Waiting for Grafana and Prometheus IPs..."
until kubectl get svc monitoring-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' | grep -q "."; do sleep 10; done
GRAFANA_HOST=$(kubectl get svc monitoring-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

until kubectl get svc monitoring-kube-prometheus-prometheus -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' | grep -q "."; do sleep 10; done
PROMETHEUS_HOST=$(kubectl get svc monitoring-kube-prometheus-prometheus -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "[INFO] Installing ArgoCD..."
kubectl create namespace argocd || true
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.4.7/manifests/install.yaml || true

echo "[INFO] Exposing ArgoCD with LoadBalancer..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

echo "[INFO] Waiting for ArgoCD LoadBalancer hostname..."
until kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' | grep -q "."; do
  echo "[WAIT] ArgoCD LoadBalancer not ready yet..."
  sleep 10
done

export ARGOCD_HOST=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
export ARGOCD_PASS=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)

echo "[INFO] Waiting for ArgoCD server deployment rollout..."
kubectl rollout status deployment/argocd-server -n argocd

echo "[INFO] Bootstrapping ArgoCD from GitHub repo..."
git clone https://github.com/firassBenNacib/KubleOps-manifest.git /tmp/KubleOps-manifest
kubectl apply -f /tmp/KubleOps-manifest/argocd-sync.yaml

echo "[INFO] Waiting for DNS of ArgoCD server..."
until nslookup "$ARGOCD_HOST" >/dev/null 2>&1; do
  echo "[WAIT] DNS not yet resolved for $ARGOCD_HOST"
  sleep 10
done

echo "[INFO] Logging into ArgoCD CLI..."
argocd login "$ARGOCD_HOST" --username admin --password "$ARGOCD_PASS" --insecure --grpc-web

echo "[INFO] Waiting for ArgoCD app 'kubleops' to exist..."
until kubectl get applications.argoproj.io -n argocd kubleops >/dev/null 2>&1; do
  sleep 5
done

BACKEND_IRSA="arn:aws:iam::${AWS_ACCOUNT_ID}:role/KubleOps-ecr-access-role"
FRONTEND_IRSA="arn:aws:iam::${AWS_ACCOUNT_ID}:role/KubleOps-ecr-access-role"

echo "[INFO] Injecting IRSA role ARNs into the app via Helm set..."
argocd app set kubleops \
  --helm-set backend.irsaRoleArn="$BACKEND_IRSA" \
  --helm-set frontend.irsaRoleArn="$FRONTEND_IRSA" \
  --grpc-web

echo "[INFO] Syncing application 'kubleops'..."
argocd app sync kubleops --grpc-web

echo
echo "=========FINAL SUMMARY========="
echo "Grafana → http://$GRAFANA_HOST"
echo "Prometheus → http://$PROMETHEUS_HOST:9090/targets"
echo "ArgoCD → http://$ARGOCD_HOST"
echo "ArgoCD Login → user: admin | pass: $ARGOCD_PASS"
echo "======================================="
echo "[SUCCESS] All tools and components installed successfully"
