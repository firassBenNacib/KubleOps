# KubleOps

KubleOps provisions a secure, scalable, and highly available AWS infrastructure for running a multi-tier application on EKS. It uses **official terraform-aws-modules** to deploy a multi-AZ VPC with public and private subnets, configurable NAT (single or dual), an EKS cluster (private API), a managed node group, optional bastion, IRSA roles, and Karpenter. An admin EC2 instance bootstraps tooling (Helm, ArgoCD, monitoring) and wires GitOps. CircleCI builds and pushes images to ECR and bumps tags in the app manifests repo. The AWS Load Balancer Controller handles ingress with ALB. ExternalDNS manages Route53 records.

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
* VPC with public/private subnets across two AZs; **single or dual NAT gateways (configurable)**.
* VPC endpoints are **toggleable**: S3 gateway and selected interface endpoints (SSM, ECR, CloudWatch, etc.).
* Managed node group plus Karpenter (node role/profile, discovery tags, access entry).
* IRSA roles for controllers: ALB Controller, EBS CSI, ExternalDNS, Fluent Bit, CloudWatch Agent, Karpenter.
* **Managed EKS add-ons** as code: VPC CNI, CoreDNS, kube-proxy, **metrics-server**, **Fluent Bit**, (EBS CSI if desired).
* ACM certificate validated by Route53.
* Optional bastion host with strict SSH CIDR.
* Admin EC2 instance installs cluster tooling and wires GitOps.
* CircleCI builds, scans with Trivy, pushes to ECR, and updates Helm values.
* Database runs as a Kubernetes **StatefulSet** in this project (by design). For production, prefer **RDS** or **Aurora**.

## Architecture

![KubleOps architecture](KubleOps-architecture.gif)

## Project Structure

```plaintext
KubleOps/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   ├── backend.tf           
│   ├── terraform.tfvars     
│   ├── ssh-bastion.sh
│   ├── ssm-tunnel.sh
│   └── modules/
│       ├── acm  bastion  ec2  eks  eks-managed-addons  iam_core  iam_irsa
│       ├── karpenter  node-group  route53-zone  vpc
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

   # NAT & endpoints
   enable_nat_gateway       = true
   single_nat_gateway       = true          # set false for one NAT per AZ
   enable_ssm_endpoints     = true
   enable_ecr_cw_endpoints  = true
   enable_s3_gateway        = false

   # DNS/ACM
   zone_name                = "example.com"
   acm_domain_name          = "app.example.com"

   # SSH and keys
   allowed_ssh_cidr         = "YOUR.PUBLIC.IP.XXX/32"
   key_name                 = "KubleOps-project"
   enable_bastion           = true
   bastion_instance_type    = "t3.micro"

   # EKS/node group
   k8s_version              = "1.33"
   node_group_instance_type = "m5.xlarge"
   min_size                 = 2
   max_size                 = 5
   desired_size             = 3
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
```

**SSM path (no bastion/public IP)**

```bash
# requires AWS SSO/keys and SSM permissions
./ssm-tunnel.sh up
./ssm-tunnel.sh down

# open an interactive SSM shell to the instance
./ssm-tunnel.sh shell
```

## Infrastructure Modules

* **vpc**: Terraform AWS VPC module; VPC, subnets, routes, security groups, **gateway + interface endpoints** (toggle via variables).
* **route53-zone**: Looks up an existing hosted zone by name; exports the zone ID.
* **acm**: Public ACM certificate with DNS validation in Route53.
* **iam\_core**: IAM roles (EKS control plane, node groups, admin EC2), ECR access.
* **eks**: Private EKS cluster; control plane logging enabled; **CMK created** (optionally used via `encryption_config`).
* **eks-managed-addons**: VPC CNI, CoreDNS, kube-proxy, metrics-server, Fluent Bit.
* **iam\_irsa**: IRSA roles for ALB Controller, EBS CSI, ExternalDNS, Fluent Bit, CloudWatch Agent, Karpenter.
* **node-group**: Managed node group in private subnets.
* **karpenter**: Node role and instance profile, interruption handling, discovery tags/access entry.
* **ec2**: Admin instance via module; installs kubectl, Helm, ArgoCD CLI, monitoring stack, ALB Controller, ExternalDNS, and creates the ArgoCD Application for the manifests repo.
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
* KMS CMK is created; use `encryption_config` to encrypt Kubernetes Secrets with your CMK.
* SSH access restricted by `allowed_ssh_cidr`.
* Private subnets behind NAT; ALB terminates at the edge.

## Monitoring

* Fluent Bit ships cluster and application logs to CloudWatch.
* kube-prometheus-stack (Prometheus, Alertmanager, Grafana) installed by the admin EC2 script.
* Quick access via the helper shells (`up` / `down`).

## Next Steps and Improvements

* Attach AWS WAFv2 to ALB and add HSTS headers.
* Tighten the S3 Gateway Endpoint policy to project buckets/principals only.
* Policy guardrails (Kyverno/Gatekeeper); image signing (cosign) + admission checks.
* Integrate HashiCorp Vault provider for centralized secret management.

## License

This project is licensed under the [Apache License 2.0](./LICENSE).

## Author

Created and maintained by Firas Ben Nacib - [bennacibfiras@gmail.com](mailto:bennacibfiras@gmail.com)
