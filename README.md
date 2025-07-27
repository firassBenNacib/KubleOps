# KubleOps

KubleOps provisions a secure, scalable, and highly available AWS infrastructure for running a production-ready, multi-tier application on EKS. It uses Terraform modules to deploy a multi-AZ VPC with public and private subnets, dual NAT gateways, an EKS cluster, EC2 nodes, and a bastion host. Applications are deployed with Helm and ArgoCD. CircleCI handles CI/CD, pushing Docker images to ECR. Monitoring and security use Prometheus, Grafana, SonarQube, and Trivy. The AWS ALB Controller enables ingress routing via Application Load Balancers.

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Project Structure](#project-structure)
- [Installation](#installation)
- [Infrastructure Modules](#infrastructure-modules)
- [CI/CD Pipeline](#cicd-pipeline)
- [Security](#security)
- [Monitoring](#monitoring)
- [License](#license)
- [Author](#author)

## Features

- Highly available EKS cluster across multiple AZs
- VPC with public/private subnets and dual NAT gateways
- Bastion host for secure SSH access
- Autoscaling EC2 node groups
- IRSA for secure access to AWS ECR
- GitOps deployment with Helm and ArgoCD
- Ingress routing via AWS ALB Controller
- CI/CD pipeline with CircleCI
- Monitoring with Prometheus and Grafana
- Security checks via SonarQube and Trivy

## Architecture

 Architecture diagram placeholder 

## Project Structure

```plaintext
KubleOps/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── backend.tf
│   ├── terraform.tfvars
│   ├── resources.tf
│   └── modules/
│       ├── vpc/
│       ├── nat-gw/
│       ├── bastion/
│       ├── eks/
│       ├── eks_oidc/
│       ├── node-group/
│       ├── ec2/
│       └── iam/
├── k8s/             
│   ├── namespaces/
│   ├── secrets/
│   ├── frontend/
│   ├── backend/
│   ├── database/
│   └── ingress/
└── .circleci/
    └── config.yml
````

## Installation

1. Clone the repo:

   ```bash
   git clone https://github.com/firassBenNacib/KubleOps.git
   cd KubleOps/terraform
   ```

2. Copy and edit the Terraform variables:

   ```bash
   cp terraform.tfvars.exemple terraform.tfvars
   ```

   Set `allowed_ssh_cidr` to **your public IP** for bastion access.

3. Initialize and apply the infrastructure:

   ```bash
   terraform init
   terraform apply
   ```

4. Connect to the bastion host using the provided key:

   ```bash
   ssh -i KubleOps-project.pem ec2-user@<bastion-public-ip>
   ```

5. Apply local Kubernetes resources if needed:

   ```bash
   kubectl apply -f ../k8s
   ```

6. Configure ArgoCD to point to the [KubleOps-manifest](https://github.com/firassBenNacib/KubleOps-manifest) repo.

## Infrastructure Modules

* **vpc**: VPC, subnets (in 2 AZs), IGW, route tables, security groups
* **nat-gw**: Two NAT gateways for private subnet internet access
* **eks**: Cluster and control plane
* **node-group**: Worker nodes with autoscaling
* **bastion**: SSH-access EC2 host for secure admin
* **ec2**: EC2 instance that runs `prepare-tools.sh` to install SonarQube, Prometheus, Grafana, ArgoCD, and bootstrap GitOps
* **iam**: IAM roles for ECR access and IRSA
* **eks\_oidc**: OIDC provider setup for EKS
* **alb-controller** (in script): Installs AWS ALB Controller for ingress support

## CI/CD Pipeline

CircleCI automates:

* Cloning frontend/backend repos
* Building Angular/Spring apps
* Running SonarQube scans
* Scanning images with Trivy
* Pushing to AWS ECR
* Updating image tags in the Helm values of [KubleOps-manifest](https://github.com/firassBenNacib/KubleOps-manifest)

## Security

* SSH access controlled via `allowed_ssh_cidr`
* Private workloads use NAT and private subnets
* IRSA (`irsaRoleArn`) allows pod-level access to ECR
* Trivy scans Docker images in CI
* SonarQube checks for code quality issues

## Monitoring

* Prometheus collects metrics from pods and nodes
* Grafana visualizes system and app health
* Both are deployed via Helm in the EC2 bootstrapping script

## License

This project is licensed under the [Apache License 2.0](./LICENSE).

## Author

Created and maintained by [Firas Ben Nacib](https://github.com/firassBenNacib) - [bennacibfiras@gmail.com](mailto:bennacibfiras@gmail.com)
