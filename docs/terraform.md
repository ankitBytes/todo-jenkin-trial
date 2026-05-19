# Terraform — Infrastructure as Code

## What is Terraform?

Terraform is a tool that lets you define your entire cloud infrastructure in code (`.tf` files). Instead of clicking through the AWS console to create resources, you describe what you want, and Terraform creates, updates, or deletes resources to match that description.

**Why we use it:**
- Every infrastructure resource is version-controlled in Git
- Reproducible — run the same code, get the same infrastructure every time
- Changes are reviewed before they are applied (`terraform plan`)
- Supports multiple environments (dev, prod) from the same codebase

---

## How Terraform Works

```
Write .tf files  →  terraform plan  →  terraform apply  →  AWS Resources Created
     (code)          (preview)           (execute)
```

Terraform keeps track of what it has created in a **state file** (`terraform.tfstate`). On every apply, it compares the current state with the desired state and only changes what is different.

---

## Project Structure

```
infra/terraform/
├── main.tf          ← Root: calls all modules
├── variables.tf     ← Declares all input variables
├── outputs.tf       ← Values exported after apply (endpoint URLs, IDs)
├── providers.tf     ← AWS provider configuration
├── versions.tf      ← Locks provider versions
├── environments/
│   ├── dev/terraform.tfvars   ← Dev values (small instance sizes, no multi-AZ)
│   └── prod/terraform.tfvars  ← Prod values (larger instances, multi-AZ, deletion protection)
└── modules/         ← Reusable building blocks
```

Each module is a folder with three standard files:
- `variables.tf` — inputs the module accepts
- `main.tf` — resources the module creates
- `outputs.tf` — values the module exposes to other modules

---

## Modules

### 1. VPC (Virtual Private Cloud)
**File:** `modules/vpc/main.tf`

**What it creates:**
- 1 VPC (`10.0.0.0/16`) — an isolated network in AWS
- 2 public subnets — for the ALB (internet-facing)
- 2 private subnets — for EKS nodes, RDS, Redis (not reachable from internet)
- 1 Internet Gateway — allows public subnets to reach the internet
- 1 NAT Gateway — allows private subnet resources to reach the internet (for outbound, e.g., pulling Docker images)
- Route tables connecting subnets to the gateways

**Why private subnets for nodes?** Security. Application pods run on nodes that are not directly reachable from the internet. All traffic must go through the ALB.

```
Internet → Internet Gateway → Public Subnet (ALB)
                                    ↓
                            NAT Gateway
                                    ↓
                    Private Subnets (EKS nodes, RDS, Redis)
```

![VPC Network Layout](diagrams/VPC%20Network%20Layout-2026-05-19-085304.png)

---

### 2. Security Groups
**File:** `modules/security-groups/main.tf`

Security groups are AWS firewalls at the resource level. Each resource only allows the traffic it needs.

| Security Group | Inbound Allowed | Purpose |
|----------------|----------------|---------|
| `eks-node-sg` | Port 3000 from ALB SG, self (node-to-node), ports 10250/443/1025-65535 from control plane | EKS worker nodes |
| `rds-sg` | Port 3306 from EKS node SG | MySQL — only pods can connect |
| `redis-sg` | Port 6379 from EKS node SG | Redis — only pods can connect |
| `alb-sg` | Port 80 and 443 from internet (0.0.0.0/0) | ALB — accepts public traffic |

**Key rule — `alb_to_nodes`:** An `aws_security_group_rule` that allows the ALB to send traffic to port 3000 on worker nodes. Without this, the ALB health checks fail and pods are never marked healthy.

---

### 3. EKS (Elastic Kubernetes Service)
**File:** `modules/eks/main.tf`

**What it creates:**
- EKS cluster (the Kubernetes control plane — managed by AWS)
- OIDC provider (enables IRSA — pods assuming IAM roles)
- IAM role for the cluster
- IAM role for worker nodes
- Launch template (defines EC2 config for nodes: IMDSv2 only, encrypted gp3 storage, custom SG)
- Managed node group (the EC2 instances that run pods)
- Kubernetes addons: `vpc-cni`, `kube-proxy`, `coredns`, `aws-ebs-csi-driver`
- IRSA role for AWS Load Balancer Controller
- IRSA role for EBS CSI Driver
- Security group rules for control plane ↔ node communication

**Why managed node group?** AWS handles node provisioning, OS patching, and replacement on failure. We only define the instance type and scaling limits.

**What is IRSA?** IAM Roles for Service Accounts. Pods can assume IAM roles without storing credentials. The OIDC provider links a Kubernetes service account to an AWS IAM role using a JWT token.

```
Pod (with service account annotation)
    → Kubernetes issues OIDC token
    → Pod calls AWS STS with the token
    → STS validates token with OIDC provider
    → Returns temporary AWS credentials
    → Pod calls AWS APIs (e.g., ALB, S3)
```

![IRSA Flow](diagrams/IRSA%20Flow-2026-05-19-085411.png)

**Node group tags for Cluster Autoscaler:**
```hcl
"k8s.io/cluster-autoscaler/enabled"              = "true"
"k8s.io/cluster-autoscaler/todo-tf-cluster-dev"  = "owned"
```
These tags let the Cluster Autoscaler discover which ASG to scale.

---

### 4. ECR (Elastic Container Registry)
**File:** `modules/ecr/main.tf`

**What it creates:** One private Docker image repository per service.

| Repository | Images stored |
|-----------|--------------|
| `todo-frontend` | Frontend static file server images |
| `todo-backend` | Node.js API server images |

**Why two repos?** Separate repos allow independent pipelines. A backend change only triggers a backend image build. A shared repo would require tagging conventions (e.g., `frontend-v1`, `backend-v1`) which are error-prone.

**Lifecycle policy:** Automatically deletes old images, retaining only the latest N (configurable). Prevents storage costs from growing indefinitely.

---

### 5. RDS (Relational Database Service)
**File:** `modules/rds/main.tf`

**What it creates:** A managed MySQL 8.0 database instance.

| Setting | Dev | Prod |
|---------|-----|------|
| Instance class | `db.t3.micro` | `db.t3.small` |
| Storage | 20 GiB gp3 | 50 GiB gp3 |
| Multi-AZ | No | Yes |
| Deletion protection | No | Yes |
| Final snapshot | Skipped | Taken |

**Why managed RDS?** AWS handles: backups, point-in-time recovery, OS patches, minor version upgrades, and Multi-AZ failover. No DBA required.

**Note:** `performance_insights_enabled = false` — Performance Insights is not supported on `db.t3.micro`. It is supported on `db.t3.small` and above.

---

### 6. Redis (ElastiCache)
**File:** `modules/redis/main.tf`

**What it creates:** An ElastiCache replication group running Redis 7.1.

Used by the backend for session storage and caching. Reduces repeated database queries.

---

### 7. ALB (Application Load Balancer)
**File:** `modules/alb/main.tf`

**What it creates:**
- Internet-facing ALB in public subnets
- **Frontend target group** — `target_type = "ip"`, port 3000, health check path `/`
- **Backend target group** — `target_type = "ip"`, port 3000, health check path `/health`
- **HTTP listener (port 80)** — redirects all traffic to HTTPS (301)
- **HTTPS listener (port 443)** — forwards to frontend by default; path rule `/api/*` and `/health` forwards to backend

**Why `target_type = "ip"`?** The AWS Load Balancer Controller registers pod IPs directly into the target group (not EC2 instance IPs). This works because EKS uses the VPC CNI plugin which gives each pod a real VPC IP address.

```
ALB
├── Port 80  → redirect to 443
└── Port 443
    ├── /api/*   → Backend Target Group  → Backend pods (port 3000)
    ├── /health  → Backend Target Group  → Backend pods (port 3000)
    └── /        → Frontend Target Group → Frontend pods (port 3000)
```

![ALB Path Routing](diagrams/ALB%20Path%20Routing-2026-05-19-085341.png)

---

### 8. ASG (Auto Scaling Group Policy)
**File:** `modules/asg/main.tf`

EKS automatically creates an ASG for the managed node group. This module finds that ASG and adds a CPU target tracking scaling policy to it.

**What it does:** If average CPU across all nodes exceeds 60%, AWS automatically adds more nodes. When CPU drops, nodes are removed (respecting `min_size`).

```hcl
# Finds the EKS-created ASG by tags
data "aws_autoscaling_groups" "eks_nodes" {
  filter { name = "tag:eks:cluster-name" values = [var.cluster_name] }
  filter { name = "tag:eks:nodegroup-name" values = [var.node_group_name] }
}
```

---

### 9. Autoscalling (Cluster Autoscaler IRSA)
**File:** `modules/autoscalling/main.tf`

**What it creates:**
- IAM policy with permissions to describe and modify ASGs
- IRSA role that the Cluster Autoscaler pod assumes
- Policy attachment

**What is the Cluster Autoscaler?** A Kubernetes controller that watches for pods in `Pending` state (no nodes available) and increases the ASG desired count. It also removes underutilized nodes.

The Helm chart is installed separately after the cluster is up (Terraform cannot configure the Helm provider before the EKS cluster exists).

---

### 10. Route53
**File:** `modules/route53/main.tf`

**What it creates:** An A alias record pointing `www.ankit.services` to the ALB DNS name.

An alias record is an AWS-specific extension that works like a CNAME but can be used at the zone apex and resolves faster.

```
www.ankit.services  →  A alias  →  todo-alb-xxx.us-east-1.elb.amazonaws.com
```

---

### 11. S3
**File:** `modules/s3/main.tf`

A private S3 bucket for application assets. Configured with:
- Server-side encryption (AES-256)
- Versioning enabled
- All public access blocked
- Lifecycle rule to abort incomplete multipart uploads after 7 days

---

### 12. CloudWatch
**File:** `modules/cloudwatch/main.tf`

Pre-creates log groups so EKS starts shipping logs immediately:
- `/aws/eks/<cluster-name>/cluster` — control plane logs
- `/todo/dev/application` — application logs
- `/todo/dev/backend` — backend logs
- `/todo/dev/frontend` — frontend logs

---

## Apply Procedure

### Prerequisites
```bash
# Install tools
terraform --version   # >= 1.6.0
aws --version         # configured with appropriate IAM permissions

# Set sensitive variables
export TF_VAR_rds_password="YourStrongPassword123"
```

### Commands

```bash
cd infra/terraform

# First time only — downloads providers and initializes modules
terraform init

# Preview changes before applying
terraform plan -var-file=environments/dev/terraform.tfvars

# Apply changes
terraform apply -var-file=environments/dev/terraform.tfvars

# View outputs (endpoints, ARNs)
terraform output

# Destroy all resources (use with caution)
terraform destroy -var-file=environments/dev/terraform.tfvars
```

### State Management

Terraform stores state in `terraform.tfstate`. In production this must be stored remotely (S3 + DynamoDB lock) using `backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-tfstate-bucket"
    key            = "todo/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}
```

### Importing Existing Resources

If a resource already exists in AWS but is not in Terraform state (e.g., from a failed/interrupted apply):

```bash
# Import an IAM role
terraform import -var-file=environments/dev/terraform.tfvars \
  module.eks.aws_iam_role.eks_cluster todo-dev-eks-cluster-role

# Import a CloudWatch log group
terraform import -var-file=environments/dev/terraform.tfvars \
  module.cloudwatch.aws_cloudwatch_log_group.app /todo/dev/application
```

---

## Environment Differences

| Variable | Dev | Prod |
|----------|-----|------|
| EKS node type | `t3.medium` | `t3.large` |
| Node desired | 2 | 2 |
| Node max | 3 | 6 |
| RDS class | `db.t3.micro` | `db.t3.small` |
| RDS Multi-AZ | false | true |
| RDS deletion protection | false | true |
| Redis nodes | 1 | 1 |
| Log retention | 14 days | 30 days |
