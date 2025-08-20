
# KubleOps

KubleOps provisions a secure, scalable, and highly available AWS infrastructure for running a multi-tier application on EKS. It uses Terraform modules to deploy a multi-AZ VPC with public and private subnets, dual NAT gateways, an EKS cluster (private API), a managed node group, optional bastion, IRSA roles, and Karpenter. An admin EC2 instance bootstraps tooling (Helm, ArgoCD, monitoring) and wires GitOps. CircleCI builds and pushes images to ECR and bumps tags in the app manifests repo. The AWS Load Balancer Controller handles ingress with ALB. ExternalDNS manages Route53 records.

Manifests: [KubleOps-manifest](https://github.com/firassBenNacib/KubleOps-manifest)

## Table of Contents

* [Features](#features)
* [Architecture](#architecture)
* [Project Structure](#project-structure)
* [Installation](#installation)
* [Infrastructure Modules](#infrastructure-modules)
* [CI/CD Pipeline](#cicd-pipeline)
* [Security](#security)
* [Monitoring](#monitoring)
* [Next Steps and Improvements](#next-steps-and-improvements)
* [License](#license)
* [Author](#author)

## Features

* Private EKS API endpoint with control plane logs enabled.
* VPC with public/private subnets across two AZs; dual NAT gateways.
* VPC endpoints are **toggleable**: S3 gateway and selected interface endpoints.
* Managed node group plus Karpenter (node role, SQS interruption queue, EventBridge rules, access entry).
* IRSA roles for controllers: ALB Controller, EBS CSI, ExternalDNS, Fluent Bit, CloudWatch Agent, Karpenter.
* EKS add-ons: VPC CNI, CoreDNS, kube-proxy, EBS CSI.
* ACM certificate validated by Route53.
* Optional bastion host with strict SSH CIDR.
* Admin EC2 instance installs cluster tooling and wires GitOps.
* CircleCI builds, scans with Trivy, pushes to ECR, and updates Helm values.
* Database runs as a Kubernetes **StatefulSet** in this project. For production, prefer **RDS** or **Aurora**.

## Architecture

![KubleOps architecture](KubleOps-architecture.gif)

## Project Structure

```plaintext
KubleOps/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── resources.tf
│   ├── backend.tf.exemple
│   ├── terraform.tfvars.exemple
│   ├── ssh-bastion.sh
│   ├── ssm-tunnel.sh
│   └── modules/
│       ├── acm  bastion  ec2  eks  eks_oidc  iam_core  iam_irsa
│       ├── karpenter  nat-gw  node-group  route53-zone  vpc
└── .circleci/
    └── config.yml
````

## Installation

1. Clone:

   ```bash
   git clone https://github.com/firassBenNacib/KubleOps.git
   cd KubleOps/terraform
   ```

2. (Optional) Configure remote state:

   ```bash
   cp backend.tf.exemple backend.tf
   # edit S3 bucket, key, region, DynamoDB table
   ```

3. Set variables:

   ```bash
   cp terraform.tfvars.exemple terraform.tfvars
   ```

   Edit `terraform.tfvars`:

   ```hcl
   project_name             = "KubleOps"
   region                   = "us-east-1"
   # VPC
   vpc_cidr                 = "10.0.0.0/16"
   pub_subnet_1a_cidr       = "10.0.1.0/24"
   pub_subnet_2b_cidr       = "10.0.2.0/24"
   pri_subnet_3a_cidr       = "10.0.3.0/24"
   pri_subnet_4b_cidr       = "10.0.4.0/24"
   enable_s3_endpoint       = false
   # DNS/ACM
   zone_name                = "example.com"
   acm_domain_name          = "app.example.com"
   # SSH and keys
   allowed_ssh_cidr         = "YOUR.PUBLIC.IP.XXX/32"
   key_name                 = "KubleOps-project"
   enable_bastion           = true
   bastion_instance_type    = "t3.micro"
   # EKS/node group
   k8s_version              = "1.29"
   node_group_instance_type = "m5.xlarge"
   min_size                 = 2
   max_size                 = 4
   desired_size             = 2
   ```

4. Deploy:

   ```bash
   terraform init
   terraform apply
   ```

5. Access helpers (shell):

  Both helpers support `up` and `down` to open/close tunnels to cluster UIs and the terminal.  
They also support `shell` for an interactive session.

**Bastion path**
```bash
# starts SSH tunnels: ArgoCD :8443, Grafana :3000, Prometheus :9090
./ssh-bastion.sh up
./ssh-bastion.sh down

# open an interactive shell on the target via bastion
./ssh-bastion.sh shell
````

**SSM path (no bastion/public IP)**

```bash
# requires AWS SSO/keys and SSM permissions
./ssm-tunnel.sh up
./ssm-tunnel.sh down

# open an interactive SSM shell to the instance
./ssm-tunnel.sh shell
```


## Infrastructure Modules

* **vpc**: VPC, IGW, public/private subnets, route tables, security groups, S3 gateway endpoint, optional interface endpoints (toggle via variables).
* **nat-gw**: Two NAT gateways and private route tables.
* **route53-zone**: Looks up an existing hosted zone by name; exports the zone ID.
* **acm**: Public ACM certificate with DNS validation in Route53.
* **iam\_core**: IAM roles: EKS control plane, managed node group, EC2 admin; ECR access for app repos.
* **eks**: Private EKS cluster; control plane logging enabled.
* **eks\_oidc**: IAM OIDC provider for IRSA.
* **iam\_irsa**: IRSA roles for ALB Controller, EBS CSI, ExternalDNS, Fluent Bit, CloudWatch Agent, Karpenter.
* **node-group**: Managed node group in private subnets.
* **karpenter**: Node role and instance profile, SQS interruption queue, EventBridge rules, access entry, discovery tags.
* **ec2**: Admin Ubuntu instance that installs kubectl, Helm, ArgoCD CLI, monitoring stack, ALB Controller, ExternalDNS, and creates the ArgoCD Application for the manifests repo.
* **bastion** (optional): Amazon Linux host in a public subnet for SSH entry.

## CI/CD Pipeline

* Build frontend (Node) and backend (Java/Maven).
* Scan container images with Trivy.
* Push images to ECR.
* Update image tags in the application manifests (via `yq`), then ArgoCD syncs.
* SonarQube steps exist but are **disabled** right now.

## Security

* Private EKS API endpoint.
* Control plane logs enabled: `api`, `audit`, `authenticator`, `controllerManager`, `scheduler`.
* IRSA for add-ons and workloads; avoid node-wide credentials in pods.
* SSH access restricted by `allowed_ssh_cidr`.
* Private subnets behind NAT; ALB terminates at the edge.

## Monitoring

* Fluent Bit ships cluster and application logs to CloudWatch.
* kube-prometheus-stack (Prometheus, Alertmanager, Grafana) installed by the admin EC2 script.
* Quick access via the helper shells (`up` / `down`).

## Next Steps and Improvements

* Migrate the database to a managed service (RDS or Aurora).
* Encrypt EKS secrets with KMS; encrypt volumes and snapshots.

* database backups; EBS snapshots; Route53 health checks/failover.

## License

This project is licensed under the [Apache License 2.0](./LICENSE).

## Author

Created and maintained by Firas Ben Nacib - [bennacibfiras@gmail.com](mailto:bennacibfiras@gmail.com)
