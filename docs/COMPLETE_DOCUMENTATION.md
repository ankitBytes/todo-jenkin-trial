# Todo Fullstack — DevOps Documentation

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Terraform — Infrastructure as Code](#2-terraform--infrastructure-as-code)
3. [Docker — Containerisation](#3-docker--containerisation)
4. [Kubernetes — Container Orchestration](#4-kubernetes--container-orchestration)
5. [Jenkins — CI/CD Pipeline](#5-jenkins--cicd-pipeline)
6. [Troubleshooting — What Went Wrong and How We Fixed It](#6-troubleshooting--what-went-wrong-and-how-we-fixed-it)

---

# 1. Project Overview

We built a full-stack Todo application and deployed it on AWS with a setup that's meant to survive real production traffic — automated infrastructure, containerised workloads, a proper CI/CD pipeline, and autoscaling at both the pod and node level.

The app itself is a JavaScript frontend talking to a Node.js backend, backed by MySQL for storage and Redis for caching. It's live at `https://www.ankit.services`.

---

## Architecture

```
                         ┌─────────────────────────────────────┐
                         │              AWS Cloud               │
                         │                                      │
  User Browser           │  ┌──────────┐    ┌───────────────┐  │
      │                  │  │ Route 53 │    │  ACM (TLS)    │  │
      │ HTTPS            │  │ DNS A    │    │  Certificate  │  │
      │                  │  └────┬─────┘    └───────────────┘  │
      │                  │       │                              │
      ▼                  │  ┌────▼──────────────────────┐      │
  www.ankit.services ────►  │  Application Load Balancer │      │
                         │  │  (internet-facing, HTTPS) │      │
                         │  └────┬──────────────────────┘      │
                         │       │                              │
                         │  ┌────▼────────────────────────┐    │
                         │  │        EKS Cluster           │    │
                         │  │  ┌─────────┐  ┌──────────┐  │    │
                         │  │  │Frontend │  │ Backend  │  │    │
                         │  │  │  Pods   │  │  Pods    │  │    │
                         │  │  │(serve)  │  │(Node.js) │  │    │
                         │  │  └─────────┘  └────┬─────┘  │    │
                         │  └──────────────────── │────────┘    │
                         │                        │             │
                         │         ┌──────────────┴──────────┐  │
                         │         │                         │  │
                         │  ┌──────▼──────┐  ┌─────────────┐│  │
                         │  │  RDS MySQL  │  │  ElastiCache ││  │
                         │  │  (private)  │  │    Redis     ││  │
                         │  └─────────────┘  └─────────────┘│  │
                         │                                    │  │
                         └────────────────────────────────────┘  │
```

![Overall Architecture](diagrams/Overall%20Architecture-2026-05-19-085235.png)

When a user hits the URL, Route53 resolves the domain to the ALB's IP. The ALB terminates TLS using an ACM certificate, then routes the request based on the path — anything under `/api/` goes to the backend pods, everything else goes to the frontend. The backend handles database reads/writes against RDS and uses Redis to avoid hitting the database for every repeated request.

---

## Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Infrastructure as Code | Terraform | Provision all AWS resources |
| Container Runtime | Docker | Package apps into images |
| Container Orchestration | Kubernetes (EKS) | Run and scale containers |
| CI/CD | Jenkins | Automate build, push, deploy |
| DNS | Route53 | Domain management |
| Load Balancer | AWS ALB | HTTPS termination, path routing |
| Container Registry | ECR | Store Docker images |
| Database | RDS MySQL 8.0 | Persistent data storage |
| Cache | ElastiCache Redis | Session cache |
| Object Storage | S3 | Static assets |
| Monitoring | CloudWatch | Logs and metrics |

---

## Repository Structure

```
todo-fullstack/
├── app/
│   ├── backend/              # Node.js API source code
│   │   └── src/
│   │       ├── app.js        # Express server entry point
│   │       ├── db.js         # MySQL connection pool
│   │       ├── redis.js      # Redis client
│   │       ├── routes/       # API route definitions
│   │       └── controllers/  # Business logic
│   ├── frontend/             # Static HTML/JS/CSS
│   ├── docker/               # Dockerfiles and docker-compose
│   │   ├── Dockerfile.backend
│   │   ├── Dockerfile.frontend
│   │   └── docker-compose.yaml
│   └── k8s/                  # Kubernetes manifests
│       ├── namespace.yaml
│       ├── configmap.yaml
│       ├── secret.yaml
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       ├── hpa.yaml
│       └── pdb.yaml
├── infra/
│   ├── ci-cd/
│   │   └── Jenkinsfile       # Pipeline definition
│   └── terraform/
│       ├── main.tf           # Root module — wires everything together
│       ├── variables.tf      # Input variables
│       ├── outputs.tf        # Exported values
│       ├── providers.tf      # AWS + TLS provider config
│       ├── versions.tf       # Provider version constraints
│       ├── environments/
│       │   ├── dev/          # Dev-specific variable values
│       │   └── prod/         # Prod-specific variable values
│       └── modules/
│           ├── vpc/          # Networking
│           ├── security-groups/
│           ├── eks/          # Kubernetes cluster
│           ├── ecr/          # Container registry
│           ├── rds/          # MySQL database
│           ├── redis/        # Cache
│           ├── alb/          # Load balancer
│           ├── asg/          # Auto Scaling Group policy
│           ├── autoscalling/ # Cluster Autoscaler IAM
│           ├── route53/      # DNS
│           ├── s3/           # Object storage
│           └── cloudwatch/   # Logging
└── docs/                     # This documentation
```

---

## Quick Reference Commands

```bash
# Deploy infrastructure
cd infra/terraform
terraform apply -var-file=environments/dev/terraform.tfvars

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name todo-tf-cluster-dev

# Deploy application
kubectl apply -f app/k8s/

# Check status
kubectl get pods -n todo
kubectl get ingress -n todo

# View logs
kubectl logs -n todo deployment/todo-backend
kubectl logs -n todo deployment/todo-frontend
```

---

# 2. Terraform — Infrastructure as Code

Rather than clicking through the AWS console and hoping we remember every step next time, we wrote the entire infrastructure as `.tf` files. Terraform compares what the code describes to what's actually running in AWS, and only changes what's different. Every resource is version-controlled, every change goes through a `plan` before it's applied, and spinning up a fresh environment is just one command.

The workflow is straightforward:

```
Write .tf files  →  terraform plan  →  terraform apply  →  AWS Resources Created
     (code)          (preview)           (execute)
```

Terraform tracks everything it creates in a state file (`terraform.tfstate`). Lose the state file and you're in trouble — in production, store it remotely in S3 with a DynamoDB lock so multiple people can't apply simultaneously.

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

Each module is a self-contained folder — `variables.tf` declares what it needs, `main.tf` creates the resources, and `outputs.tf` exposes values that other modules can reference. The root `main.tf` just wires them all together.

---

## Modules

### 1. VPC — `modules/vpc/main.tf`

Everything lives inside a single VPC (`10.0.0.0/16`), but not everything gets the same level of exposure. We split the network into public and private subnets across two availability zones.

The ALB sits in the public subnets — it needs to be reachable from the internet. Everything else (EKS nodes, RDS, Redis) is in private subnets. Pods can still reach the internet for outbound calls (pulling Docker images, calling AWS APIs) through a NAT Gateway, but nothing from the internet can reach them directly. All inbound traffic has to go through the ALB.

```
Internet → Internet Gateway → Public Subnet (ALB)
                                    ↓
                            NAT Gateway
                                    ↓
                    Private Subnets (EKS nodes, RDS, Redis)
```

![VPC Network Layout](diagrams/VPC%20Network%20Layout-2026-05-19-085304.png)

---

### 2. Security Groups — `modules/security-groups/main.tf`

Security groups are the firewall rules that control what can talk to what. We follow a least-privilege approach — each resource only allows the traffic it genuinely needs.

| Security Group | Inbound Allowed | Purpose |
|----------------|----------------|---------|
| `eks-node-sg` | Port 3000 from ALB SG, self (node-to-node), ports 10250/443/1025-65535 from control plane | EKS worker nodes |
| `rds-sg` | Port 3306 from EKS node SG | MySQL — only pods can connect |
| `redis-sg` | Port 6379 from EKS node SG | Redis — only pods can connect |
| `alb-sg` | Port 80 and 443 from internet (0.0.0.0/0) | ALB — accepts public traffic |

One rule that often gets missed is `alb_to_nodes` — an `aws_security_group_rule` that allows the ALB to reach port 3000 on the worker nodes. Without it, ALB health checks fail and no pods ever show as healthy, which took us a while to track down the first time.

---

### 3. EKS — `modules/eks/main.tf`

This is the most complex module. We use EKS rather than self-managed Kubernetes because AWS manages the control plane for us — no etcd to babysit, no API server to upgrade manually.

The module provisions the EKS cluster itself, an OIDC provider (needed for IRSA), IAM roles for the cluster and worker nodes, a launch template that locks down the node config (IMDSv2 only, encrypted gp3 storage), a managed node group, and a few essential Kubernetes addons: `vpc-cni`, `kube-proxy`, `coredns`, and `aws-ebs-csi-driver`.

We also create IRSA roles for the AWS Load Balancer Controller and the EBS CSI Driver. IRSA (IAM Roles for Service Accounts) is worth understanding — it lets pods assume IAM roles without any credentials being stored in the cluster. The flow looks like this:

```
Pod (with service account annotation)
    → Kubernetes issues OIDC token
    → Pod calls AWS STS with the token
    → STS validates token with OIDC provider
    → Returns temporary AWS credentials
    → Pod calls AWS APIs (e.g., ALB, S3)
```

![IRSA Flow](diagrams/IRSA%20Flow-2026-05-19-085411.png)

The node group also gets two specific tags that the Cluster Autoscaler needs to discover which ASG to scale:

```hcl
"k8s.io/cluster-autoscaler/enabled"              = "true"
"k8s.io/cluster-autoscaler/todo-tf-cluster-dev"  = "owned"
```

---

### 4. ECR — `modules/ecr/main.tf`

We have two separate ECR repositories — one for the frontend, one for the backend. Keeping them separate means a backend code change only triggers a backend image build. If they shared a repo, you'd need tagging conventions like `frontend-v1`/`backend-v1` which are annoying to maintain.

| Repository | Images stored |
|-----------|--------------|
| `todo-frontend` | Frontend static file server images |
| `todo-backend` | Node.js API server images |

Each repo has a lifecycle policy that automatically expires old images, keeping only the most recent ones. Without this, registries quietly accumulate hundreds of stale images and storage costs creep up.

---

### 5. RDS — `modules/rds/main.tf`

A managed MySQL 8.0 instance. The dev and prod configs differ significantly to keep dev costs low while prod stays resilient:

| Setting | Dev | Prod |
|---------|-----|------|
| Instance class | `db.t3.micro` | `db.t3.small` |
| Storage | 20 GiB gp3 | 50 GiB gp3 |
| Multi-AZ | No | Yes |
| Deletion protection | No | Yes |
| Final snapshot | Skipped | Taken |

One gotcha we hit: Performance Insights isn't available on `db.t3.micro`. We had it enabled in the config and Terraform failed on apply. Had to set `performance_insights_enabled = false` for dev — it's fine on `db.t3.small` and above in prod.

---

### 6. Redis — `modules/redis/main.tf`

An ElastiCache replication group running Redis 7.1. The backend uses it for session storage and to cache database query results. Anything that would hit MySQL on every request and return the same data is a good Redis candidate.

---

### 7. ALB — `modules/alb/main.tf`

The load balancer handles all incoming traffic. It sits in the public subnets, terminates TLS using the ACM certificate, and routes requests based on path:

```
ALB
├── Port 80  → redirect to 443
└── Port 443
    ├── /api/*   → Backend Target Group  → Backend pods (port 3000)
    ├── /health  → Backend Target Group  → Backend pods (port 3000)
    └── /        → Frontend Target Group → Frontend pods (port 3000)
```

![ALB Path Routing](diagrams/ALB%20Path%20Routing-2026-05-19-085341.png)

We use `target_type = "ip"` on both target groups, which means the ALB registers pod IPs directly rather than EC2 instance IPs. This works because the VPC CNI plugin gives each pod its own real VPC IP — the ALB can hit pods without going through the node's IP at all.

---

### 8. ASG — `modules/asg/main.tf`

EKS creates an Auto Scaling Group automatically when you create a managed node group. This module finds that ASG by its EKS tags and attaches a CPU-based scaling policy to it.

```hcl
# Finds the EKS-created ASG by tags
data "aws_autoscaling_groups" "eks_nodes" {
  filter { name = "tag:eks:cluster-name" values = [var.cluster_name] }
  filter { name = "tag:eks:nodegroup-name" values = [var.node_group_name] }
}
```

If average CPU across all nodes climbs above 60%, AWS adds another node. When things calm down, nodes are removed (but never below `min_size`). This is node-level scaling — separate from the pod-level HPA scaling we set up in Kubernetes.

---

### 9. Autoscaling (Cluster Autoscaler IRSA) — `modules/autoscalling/main.tf`

While the ASG module adds a CPU policy to the node ASG, the Cluster Autoscaler is a Kubernetes controller that watches for pods stuck in `Pending` state because there's no node with enough capacity. When it sees that, it signals the ASG to add a node.

This module just creates the IAM plumbing the Cluster Autoscaler pod needs — an IAM policy with permissions to describe and modify ASGs, and an IRSA role that the pod assumes. The Helm chart itself is installed separately after the cluster is running, because Terraform can't configure the Helm provider until the cluster exists (a circular dependency we ran into — more on that in the troubleshooting section).

---

### 10. Route53 — `modules/route53/main.tf`

An A alias record pointing `www.ankit.services` at the ALB. We use an alias record rather than a CNAME because alias records work at the zone apex and AWS resolves them faster internally.

```
www.ankit.services  →  A alias  →  todo-alb-xxx.us-east-1.elb.amazonaws.com
```

---

### 11. S3 — `modules/s3/main.tf`

A private S3 bucket for application assets — AES-256 encryption, versioning on, all public access blocked, and a lifecycle rule to clean up incomplete multipart uploads after 7 days. Nothing fancy, but it's all configured properly from the start rather than retrofitted later.

---

### 12. CloudWatch — `modules/cloudwatch/main.tf`

We pre-create log groups so EKS starts shipping logs the moment the cluster comes up, without waiting for CloudWatch to auto-create them:

- `/aws/eks/<cluster-name>/cluster` — control plane logs
- `/todo/dev/application` — application logs
- `/todo/dev/backend` — backend logs
- `/todo/dev/frontend` — frontend logs

One thing to watch: if you enable EKS control plane logging, AWS creates the cluster log group automatically. If Terraform then tries to create it too, you'll get a `ResourceAlreadyExistsException`. The fix is `terraform import` — covered in the troubleshooting section.

---

## Running Terraform

```bash
# Set the DB password as an environment variable (never hardcode it)
export TF_VAR_rds_password="YourStrongPassword123"

cd infra/terraform

# First run only — downloads providers and modules
terraform init

# Always plan first and review the diff
terraform plan -var-file=environments/dev/terraform.tfvars

# Apply when you're happy with the plan
terraform apply -var-file=environments/dev/terraform.tfvars

# See the output values (endpoint URLs, ARNs, etc.)
terraform output
```

In production, remote state is essential. Add a `backend.tf`:

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

If a resource already exists in AWS but isn't in Terraform state (usually from an interrupted apply), use `terraform import` to adopt it rather than deleting and recreating it:

```bash
# Import an IAM role
terraform import -var-file=environments/dev/terraform.tfvars \
  module.eks.aws_iam_role.eks_cluster todo-dev-eks-cluster-role

# Import a CloudWatch log group
terraform import -var-file=environments/dev/terraform.tfvars \
  module.cloudwatch.aws_cloudwatch_log_group.app /todo/dev/application
```

---

## Dev vs Prod

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

---

# 3. Docker — Containerisation

Docker solves the "works on my machine" problem by packaging the application and everything it depends on into a single image that runs identically everywhere — a developer's laptop, a CI agent, or an EKS node. The image is built once, pushed to ECR, and that exact image is what runs in production.

---

## Two Separate Repositories

We have one ECR repo per service:

| Image | Repository |
|-------|----------|
| Frontend | `668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-frontend` |
| Backend | `668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-backend` |

Keeping them separate means a backend fix only triggers a backend build. With a shared repo you'd need tag prefixes like `frontend-v1`, `backend-v1` — which works until someone forgets the prefix and overwrites the wrong image.

---

## Dockerfiles

### Backend — `app/docker/Dockerfile.backend`

```dockerfile
FROM node:20-alpine

# Run as non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy package files first (layer cache — only re-runs npm ci when deps change)
COPY package*.json ./
RUN npm ci --omit=dev

# Copy source code
COPY src/ ./src/

# Fix file ownership
RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 3000
CMD ["node", "src/app.js"]
```

A few intentional choices here worth explaining:

`node:20-alpine` keeps the base image small (~5MB vs ~150MB for full Debian). Smaller images mean faster ECR pulls and less attack surface.

The non-root user matters more than it sounds — if someone exploits a vulnerability in the app, they're dropped into a container with no root access rather than having the keys to the kingdom.

The order of `COPY` instructions is deliberate. `package*.json` is copied and `npm ci` runs before the source code is copied. Docker caches each layer, so if you change a source file but not `package.json`, the install layer is reused from cache. Builds that used to take 2 minutes drop to 20 seconds.

`npm ci --omit=dev` installs exactly what's in `package-lock.json` (no version surprises) and skips dev dependencies like test frameworks and linters that have no business being in a production image.

**Build context:** `app/backend/` — the Dockerfile expects to find `package.json` and `src/` at the root of whatever directory you pass as the build context.

---

### Frontend — `app/docker/Dockerfile.frontend`

```dockerfile
FROM node:20-alpine

# Run as non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Install 'serve' — a lightweight static file server
RUN npm install -g serve@14

WORKDIR /app

# Copy all frontend files (index.html, app.js, style.css)
COPY . .

# Fix file ownership
RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 3000
CMD ["serve", "-s", ".", "-l", "3000"]
```

The frontend is plain HTML/JS/CSS — no React, no build step. We use the `serve` package to host the static files on port 3000. Both services use port 3000; the ALB routes to them separately by path, not by port.

---

## Building and Pushing Images

ECR tokens expire after 12 hours, so you need to log in at the start of each session:

```bash
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
    668076964228.dkr.ecr.us-east-1.amazonaws.com
```

Then build and push. Note the `-f` flag — the Dockerfiles live in `app/docker/` but the build context is the service directory:

```bash
# Backend
docker build \
  -t 668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-backend:latest \
  -f app/docker/Dockerfile.backend \
  app/backend/

docker push 668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-backend:latest

# Frontend
docker build \
  -t 668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-frontend:latest \
  -f app/docker/Dockerfile.frontend \
  app/frontend/

docker push 668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-frontend:latest
```

For local development without Kubernetes, `docker-compose` spins up the full stack locally:

```bash
docker compose -f app/docker/docker-compose.yaml up
```

---

## Image Lifecycle

ECR keeps the last 10 tagged images per repo and deletes the rest automatically. Terraform creates this lifecycle policy:

```json
{
  "rules": [{
    "rulePriority": 1,
    "description": "Keep last 10 tagged images",
    "selection": {
      "tagStatus": "tagged",
      "countType": "imageCountMoreThan",
      "countNumber": 10
    },
    "action": { "type": "expire" }
  }]
}
```

We're currently tagging images as `latest`. For proper traceability in production you'd tag with the Git commit SHA so you can always trace a running image back to the exact commit that produced it:

```bash
IMAGE_TAG=$(git rev-parse --short HEAD)
docker build -t .../todo-backend:$IMAGE_TAG ...
docker push .../todo-backend:$IMAGE_TAG

# Keep latest pointing at the newest build too
docker tag .../todo-backend:$IMAGE_TAG .../todo-backend:latest
docker push .../todo-backend:latest
```

---

# 4. Kubernetes — Container Orchestration

Kubernetes removes the burden of manually deciding which server runs which container. You tell it what you want — "keep two copies of the backend running" — and it figures out placement, restarts failures, and redistributes load when nodes go down. We run it on EKS so AWS manages the control plane (etcd, API server, scheduler) and we just deal with the worker nodes.

---

## What's Running in the Cluster

```
EKS Cluster (todo-tf-cluster-dev)
│
├── kube-system namespace
│   ├── aws-load-balancer-controller  ← watches Ingress, manages ALB target groups
│   ├── coredns                       ← DNS resolution inside the cluster
│   ├── kube-proxy                    ← network rules on each node
│   └── vpc-cni                       ← gives each pod a real VPC IP
│
└── todo namespace
    ├── todo-frontend (Deployment, 2 replicas)
    ├── todo-backend  (Deployment, 2 replicas)
    ├── todo-frontend-svc (Service, ClusterIP)
    ├── todo-backend-svc  (Service, ClusterIP)
    ├── todo-ingress (Ingress, ALB class)
    ├── todo-config  (ConfigMap)
    ├── todo-secret  (Secret)
    ├── HPA (HorizontalPodAutoscaler × 2)
    └── PDB (PodDisruptionBudget × 2)
```

![EKS Namespace Structure](diagrams/EKS%20Namespace%20Structure-2026-05-19-085451.png)

The application resources all live in the `todo` namespace to keep them separate from the cluster system components in `kube-system`. Namespaces also let you apply resource quotas and access controls per team or per environment.

---

## Manifest Walkthrough

### Namespace — `namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: todo
```

Simple — just creates the `todo` workspace. Everything the application needs lives in here.

---

### ConfigMap — `configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: todo-config
  namespace: todo
data:
  PORT: "3000"
  DB_NAME: "todo_db"
  ALLOWED_ORIGIN: "https://www.ankit.services"
```

Non-sensitive config is stored here and injected into pods as environment variables. The benefit is that if you need to change `ALLOWED_ORIGIN` — say you're adding a new domain — you update the ConfigMap and restart the deployment. No image rebuild, no CI pipeline run.

ConfigMaps are safe to commit to Git. Secrets (next section) are not.

---

### Secret — `secret.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: todo-secret
  namespace: todo
type: Opaque
data:
  DB_HOST:     <base64 encoded>
  DB_PORT:     <base64 encoded>
  DB_USER:     <base64 encoded>
  DB_PASSWORD: <base64 encoded>
  REDIS_HOST:  <base64 encoded>
  REDIS_PORT:  <base64 encoded>
```

Database credentials and Redis endpoints go here. Worth calling out: base64 is just encoding, not encryption. Anyone who can run `kubectl get secret` and has the right RBAC permissions can decode the values. For a hardened production setup, you'd use AWS Secrets Manager with the External Secrets Operator to inject secrets at pod startup instead of storing them in Kubernetes at all.

To get the right values for this file after Terraform runs:

```bash
# RDS endpoint (strip the :3306 port suffix first)
terraform output -raw rds_endpoint | cut -d: -f1 | base64

# Redis endpoint
terraform output -raw redis_primary_endpoint | base64

# Password
echo -n "YourPassword" | base64
```

---

### Deployment — `deployment.yaml`

This is the most important manifest. It tells Kubernetes what image to run, how many replicas to keep alive, and where to pull config from.

**Frontend:**
```yaml
spec:
  replicas: 2
  selector:
    matchLabels:
      app: todo-app-frontend
  template:
    spec:
      containers:
      - name: frontend
        image: 668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-frontend:latest
        ports:
        - containerPort: 3000
        envFrom:
        - configMapRef:
            name: todo-config
```

**Backend** — same structure, but also mounts the Secret for database credentials:
```yaml
        envFrom:
        - configMapRef:
            name: todo-config
        - secretRef:
            name: todo-secret
```

Two replicas means if one pod crashes or a node goes down, the other keeps serving traffic while Kubernetes reschedules the missing pod. `envFrom` injects all keys from the ConfigMap (and Secret, for the backend) as environment variables — the app code just reads them with `process.env.DB_HOST` and doesn't need to know anything about Kubernetes.

A note on probes: if you add liveness and readiness probes (we'd recommend it for production), the distinction matters — a failing liveness probe causes a container restart, while a failing readiness probe just pulls the pod from the load balancer rotation without restarting it.

---

### Service — `service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: todo-frontend-svc
  namespace: todo
spec:
  type: ClusterIP
  selector:
    app: todo-app-frontend
  ports:
  - port: 80
    targetPort: 3000
```

A Service gives a stable internal hostname to a group of pods. `todo-frontend-svc.todo.svc.cluster.local` always resolves to one of the running frontend pods, even as pods restart and get new IPs. Without it, you'd have to track pod IPs manually, which change every time a pod restarts.

We use `ClusterIP` (internal only) rather than `LoadBalancer` because the ALB is our external entry point. Creating a `LoadBalancer` service would spin up an additional AWS load balancer per service — expensive and unnecessary when the Ingress already handles external routing. The Service maps port 80 internally to port 3000 on the pods.

---

### Ingress — `ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: todo-ingress
  namespace: todo
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/load-balancer-arn: arn:aws:elasticloadbalancing:...
spec:
  ingressClassName: alb
  rules:
  - host: www.ankit.services
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: todo-backend-svc
            port:
              number: 80
      - path: /health
        pathType: Prefix
        backend:
          service:
            name: todo-backend-svc
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: todo-frontend-svc
            port:
              number: 80
```

The AWS Load Balancer Controller watches for Ingress resources and translates them into ALB listener rules. The annotations tell it how to configure the ALB — internet-facing, direct pod IP targeting, HTTPS with the ACM cert, HTTP-to-HTTPS redirect, and which existing ALB to attach to (so it doesn't create a second one).

```
https://www.ankit.services/api/todos  → todo-backend-svc → backend pods
https://www.ankit.services/health     → todo-backend-svc → backend pods
https://www.ankit.services/           → todo-frontend-svc → frontend pods
```

---

### HPA — `hpa.yaml`

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: todo-backend-hpa
  namespace: todo
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: todo-backend
  minReplicas: 2
  maxReplicas: 6
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

When backend CPU stays above 70%, the HPA adds pods (up to 6). When it drops back down, pods are removed until we're back at the minimum of 2. This handles traffic spikes without over-provisioning all the time.

There are two levels of autoscaling working together:
- **HPA** scales pods within the existing nodes
- **Cluster Autoscaler** adds nodes when there are no nodes with enough capacity to schedule new pods

---

### PDB — `pdb.yaml`

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: todo-backend-pdb
  namespace: todo
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: todo-app-backend
```

Without a PDB, Kubernetes could drain two nodes at once during an upgrade and briefly leave zero backend pods running. With `minAvailable: 1`, it has to keep at least one pod running at all times during voluntary disruptions. It's a small thing that prevents embarrassing outages during routine maintenance.

---

## Traffic Flow — Request to Response

```
User request: GET https://www.ankit.services/api/todos

1. DNS:     Route53 → ALB IP address
2. TLS:     ALB terminates HTTPS using ACM certificate
3. Routing: ALB rule matches /api/* → Backend Target Group
4. Target:  ALB selects a healthy backend pod IP (e.g., 10.0.11.76:3000)
5. Network: Traffic flows directly to pod via VPC CNI
6. App:     backend/src/app.js handles the request
7. DB:      Queries RDS MySQL at todo-db-dev.xxx.rds.amazonaws.com:3306
8. Cache:   Reads/writes Redis at todo-redis-dev.xxx.cache.amazonaws.com:6379
9. Response: JSON returned → ALB → User
```

![Full Request Traffic Flow](diagrams/Full%20Request%20Traffic%20Flow-2026-05-19-085523.png)

---

## Day-to-Day Commands

```bash
# Set namespace shortcut
alias k="kubectl -n todo"

# Check everything
kubectl get all -n todo

# Pod logs
kubectl logs -n todo deployment/todo-backend --tail=50 -f
kubectl logs -n todo deployment/todo-frontend --tail=50

# Describe a failing pod
kubectl describe pod -n todo <pod-name>

# Shell into a pod (debugging)
kubectl exec -it -n todo deployment/todo-backend -- sh

# Check HPA status
kubectl get hpa -n todo

# Check ingress address
kubectl get ingress -n todo

# Force restart a deployment (picks up new image or config)
kubectl rollout restart deployment/todo-backend -n todo
kubectl rollout status deployment/todo-backend -n todo

# Check events (useful for diagnosing issues)
kubectl get events -n todo --sort-by='.lastTimestamp'
```

## Updating the Application

**New code (requires image rebuild):**
```bash
docker build -t .../todo-backend:latest -f app/docker/Dockerfile.backend app/backend/
docker push .../todo-backend:latest
kubectl rollout restart deployment/todo-backend -n todo
```

**Config change (no rebuild needed):**
```bash
kubectl apply -f app/k8s/configmap.yaml
kubectl rollout restart deployment/todo-backend -n todo
```

**Secret change (updated base64 values):**
```bash
kubectl apply -f app/k8s/secret.yaml
kubectl rollout restart deployment/todo-backend -n todo
```

---

# 5. Jenkins — CI/CD Pipeline

Jenkins is our automation server. When code hits the main branch, Jenkins picks it up, builds the Docker image, pushes it to ECR, deploys it to EKS, and watches the rollout. If anything goes wrong, it rolls back automatically and marks the build failed.

We chose Jenkins over GitHub Actions mainly because it's self-hosted — no per-minute billing, and it works with whatever Git server you're running. The pipeline is defined in a `Jenkinsfile` that lives in the repo alongside the code, so pipeline changes go through the same review process as everything else.

The Jenkinsfile lives at `infra/ci-cd/Jenkinsfile`.

---

## Environment Variables

```groovy
environment {
    AWS_REGION   = 'us-east-1'
    ECR_REGISTRY = '668076964228.dkr.ecr.us-east-1.amazonaws.com'
    ECR_FRONTEND = "${ECR_REGISTRY}/todo-frontend"
    ECR_BACKEND  = "${ECR_REGISTRY}/todo-backend"
    EKS_CLUSTER  = 'todo-tf-cluster'
    IMAGE_TAG    = "v${BUILD_NUMBER}"    // e.g. v42, v43, v44
    KUBE_NS      = 'todo'
    TF_DIR       = 'infra/terraform'
}
```

`BUILD_NUMBER` is automatically incremented by Jenkins on every run, so every build gets a unique `IMAGE_TAG`. The image is also tagged `latest` for convenience, but the versioned tag (`v43`) is what gets deployed so it's traceable.

---

## Pipeline Structure

```
Checkout
    │
    ├─────────────────────────────────────────────┐
    │                                             │
  Frontend (parallel)                        Backend (parallel)
    ├── Build Frontend  (if app/frontend/** changed)   ├── Build Backend  (if app/backend/** changed)
    ├── Push Frontend   (if app/frontend/** changed)   ├── Push Backend   (if app/backend/** changed)
    └── Deploy Frontend (if app/frontend/** changed)   └── Deploy Backend (if app/backend/** changed)
    │                                             │
    └─────────────────────────────────────────────┘
    │
Terraform Init     (if infra/** changed)
Terraform Validate (if infra/** changed)
Terraform Plan     (if infra/** changed)
Terraform Apply    (if infra/** changed)
    │
Cleanup
```

---

## How Each Stage Works

**Checkout** just clones the repo at the triggering commit. Simple.

**App stages** run the frontend and backend pipelines in parallel — if both changed, they build simultaneously rather than waiting for each other.

Every sub-stage is wrapped in a changeset guard:

```groovy
when { changeset 'app/frontend/**' }
```

This is what makes the pipeline smart. If you push a backend fix, Jenkins skips all three frontend stages without even looking at them — no unnecessary rebuild, no unnecessary push, no unnecessary deployment.

| Push changes to... | Frontend stages | Backend stages | Terraform stages |
|--------------------|----------------|----------------|-----------------|
| `app/frontend/` | Run | Skip | Skip |
| `app/backend/` | Skip | Run | Skip |
| `infra/` | Skip | Skip | Run |
| `app/frontend/` + `app/backend/` | Run | Run | Skip |

**Build** runs `docker build` with the `-f` flag to point at the Dockerfile (which is in `app/docker/`, not in the build context directory):

```groovy
sh """
    docker build \
        -f app/docker/Dockerfile.backend \
        -t ${ECR_BACKEND}:${IMAGE_TAG} \
        app/backend/
"""
```

**Push** logs into ECR fresh (tokens expire after 12 hours) and pushes both the versioned tag and `latest`:

```groovy
sh """
    aws ecr get-login-password --region ${AWS_REGION} | \
        docker login --username AWS --password-stdin ${ECR_REGISTRY}
    docker push ${ECR_BACKEND}:${IMAGE_TAG}
    docker tag  ${ECR_BACKEND}:${IMAGE_TAG} ${ECR_BACKEND}:latest
    docker push ${ECR_BACKEND}:latest
"""
```

**Deploy** updates the running deployment and watches the rollout:

```groovy
sh """
    aws eks update-kubeconfig \
        --region ${AWS_REGION} --name ${EKS_CLUSTER}
    kubectl set image deployment/todo-backend \
        todo-backend=${ECR_BACKEND}:${IMAGE_TAG} \
        -n ${KUBE_NS}
    kubectl rollout status deployment/todo-backend \
        -n ${KUBE_NS} --timeout=180s \
    || (kubectl rollout undo deployment/todo-backend -n ${KUBE_NS} && exit 1)
"""
```

`kubectl set image` patches the deployment to use the new tag. Kubernetes starts a rolling update. `kubectl rollout status` waits up to 3 minutes. If the rollout doesn't complete — maybe the new image crashes, maybe health checks fail — the `||` clause fires: it rolls back to the previous version and exits with a failure code, which marks the Jenkins build red.

No one needs to manually intervene to get the old version back. It just happens.

**Terraform stages** (only when `infra/` changes) run init → validate → plan → apply. Credentials come from a Jenkins credential store entry called `aws-creds`, injected via `withCredentials` so they're never visible in logs:

```groovy
withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                  credentialsId: 'aws-creds']]) {
    sh "terraform -chdir=${TF_DIR} init -input=false"
}
```

For production, you'd put a manual approval between plan and apply:

```groovy
stage('Approve Terraform Apply') {
    steps {
        input message: 'Review the Terraform plan. Proceed with apply?'
    }
}
```

**Cleanup** removes the locally built images from the Jenkins agent and deletes the saved plan file. The `|| true` stops the stage from failing if an image was never built (e.g., a frontend-only change means no backend image exists to clean up):

```groovy
sh """
    docker rmi ${ECR_FRONTEND}:${IMAGE_TAG} ${ECR_FRONTEND}:latest || true
    docker rmi ${ECR_BACKEND}:${IMAGE_TAG}  ${ECR_BACKEND}:latest  || true
    rm -f ${TF_DIR}/tfplan || true
"""
```

---

## End-to-End: What Happens When You Push

```
Developer pushes to main branch
    │
    ▼
GitHub/GitLab notifies Jenkins (webhook)
    │
    ▼
Jenkins reads Jenkinsfile
    │
    ▼
Checkout stage pulls latest commit
    │
    ▼
changeset 'app/backend/**' matches? YES
    │
    ▼
Build Backend:  docker build → image tagged v43
Push Backend:   ECR login → docker push v43 + latest
Deploy Backend: kubectl set image → rolling update starts
                kubectl rollout status waits 180s
                    ├── SUCCESS → pipeline continues to Cleanup
                    └── FAIL   → kubectl rollout undo (v42 restored) + pipeline fails
    │
    ▼
Cleanup: docker rmi local images
    │
    ▼
post { success } or post { failure }
```

![End-to-End CI/CD Flow](diagrams/End-to-End%20CICD%20Flow-2026-05-19-085645.png)

A backend-only change takes roughly 3-5 minutes from push to running in production.

---

## Jenkins Agent Requirements

The machine running the pipeline needs:
- Docker (with the daemon running)
- AWS CLI v2
- `kubectl`
- Terraform >= 1.6.0

And one credential in Jenkins (Manage Jenkins → Credentials):

| ID | Type | Contents |
|----|------|---------|
| `aws-creds` | AWS Credentials | IAM access key + secret key |

Required plugins: Pipeline, Git, AWS Credentials, Docker Pipeline.

---

## Rolling Updates

When `kubectl set image` fires, Kubernetes doesn't stop the old pods immediately — it spins up new ones first:

```
Before: [Pod v42] [Pod v42]
         ↓
Step 1: [Pod v42] [Pod v42] [Pod v43 starting...]
Step 2: [Pod v42] [Pod v43 running] ← old pod removed
Step 3: [Pod v43] [Pod v43 running]
         ↓
After:  [Pod v43] [Pod v43]
```

![Kubernetes Rolling Update](diagrams/Kubernetes%20Rolling%20Update-2026-05-19-085612.png)

Old pods keep serving traffic until the new pod passes its readiness check. If the new pod never becomes ready, the rollout stalls, Jenkins times out, and `rollout undo` restores v42. Zero-downtime deployments by default.

The rollout behaviour is controlled by `strategy.rollingUpdate` in the deployment (default: `maxUnavailable: 25%`, `maxSurge: 25%`).

---

# 6. Troubleshooting — What Went Wrong and How We Fixed It

This is the honest account of every non-trivial problem we hit during the initial deployment. None of these are hypothetical edge cases — each one is something that actually blocked us, sometimes for hours. Hopefully this saves someone else the same debugging time.

---

## Problem 1: `localss` typo in the ALB module

**Error:**
```
Error: Unsupported block type
  on modules/alb/main.tf line 1:
  localss {
```

`locals` was misspelled as `localss`. On top of that, references throughout the file used `${locals.name}` instead of `${local.name}` — the block is declared as `locals {}` but referenced as `local.`.

```hcl
# Wrong
localss {
  name = "${var.project}-${var.environment}"
}
resource "..." {
  name = "${locals.name}-alb"
}

# Correct
locals {
  name = "${var.project}-${var.environment}"
}
resource "..." {
  name = "${local.name}-alb"
}
```

---

## Problem 2: Wrong attribute names on `aws_lb`

**Error:**
```
Error: Unsupported argument
  on modules/alb/main.tf:
  "security_group_id": argument not supported here
  "subnet": argument not supported here
```

`aws_lb` takes `security_groups` (a list) and `subnets` (a list), not the singular versions.

```hcl
# Wrong
resource "aws_lb" "main" {
  security_group_id = var.alb_sg_id
  subnet            = var.public_subnet_ids
}

# Correct
resource "aws_lb" "main" {
  security_groups = [var.alb_sg_id]
  subnets         = var.public_subnet_ids
}
```

---

## Problem 3: `redirects {}` instead of `redirect {}`

**Error:**
```
Error: Unsupported block type
  on modules/alb/main.tf:
  redirects {
```

The HTTP→HTTPS redirect action block is `redirect {}`, not `redirects {}`.

```hcl
# Wrong
action {
  type = "redirect"
  redirects {
    port        = "443"
    protocol    = "HTTPS"
    status_code = "HTTP_301"
  }
}

# Correct
action {
  type = "redirect"
  redirect {
    port        = "443"
    protocol    = "HTTPS"
    status_code = "HTTP_301"
  }
}
```

---

## Problem 4: `autoscalling` typos throughout the ASG module

**Error:**
```
Error: Invalid resource type
  on modules/asg/main.tf:
  resource "aws_autoscalling_policy" "cpu"
```

The module had `autoscalling` (double-l) everywhere it should be `autoscaling`. The full list of things to fix:
- `aws_autoscalling_groups` → `aws_autoscaling_groups`
- `aws_autoscalling_policy` → `aws_autoscaling_policy`
- `"ASGAverageCPUAutoscallization"` → `"ASGAverageCPUUtilization"`
- `predefied_metric_specification` → `predefined_metric_specification`
- `locals.name` → `local.name`

Global find-and-replace of `autoscalling` → `autoscaling` gets most of it.

---

## Problem 5: `filters = [...]` syntax not valid for data sources

**Error:**
```
Error: Unsupported argument
  on modules/asg/main.tf:
  filters = [
```

The `aws_autoscaling_groups` data source doesn't take a `filters` list argument. It uses separate `filter {}` blocks.

```hcl
# Wrong
data "aws_autoscaling_groups" "eks_nodes" {
  filters = [
    { name = "tag:eks:cluster-name" values = [var.cluster_name] },
    { name = "tag:eks:nodegroup-name" values = [var.node_group_name] }
  ]
}

# Correct
data "aws_autoscaling_groups" "eks_nodes" {
  filter {
    name   = "tag:eks:cluster-name"
    values = [var.cluster_name]
  }
  filter {
    name   = "tag:eks:nodegroup-name"
    values = [var.node_group_name]
  }
}
```

---

## Problem 6: Wrong protocol attribute and non-list `cidr_blocks` in security groups

**Error:**
```
Error: Unsupported argument "ip_protocol"
Error: Incorrect attribute value type — "0.0.0.0/0" (string) cannot be used as cidr_blocks
```

Inside `aws_security_group` inline `ingress`/`egress` blocks, the attribute is `protocol` not `ip_protocol`. (`ip_protocol` is used in `aws_vpc_security_group_ingress_rule`, which is a completely different resource type.) Also, `cidr_blocks` must be a list.

```hcl
# Wrong
ingress {
  ip_protocol = "-1"
  cidr_blocks = "0.0.0.0/0"
}

# Correct
ingress {
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
```

---

## Problem 7: `aws_security_group` used where `aws_security_group_rule` was needed

**Error:**
```
Error: Unsupported argument
  on modules/security-groups/main.tf:
  source_security_group_id is not a valid argument for aws_security_group
```

The `alb_to_nodes` rule — which lets the ALB reach port 3000 on worker nodes — was accidentally declared as an `aws_security_group` resource instead of an `aws_security_group_rule`. You can't reference another security group as a source inside an `aws_security_group` inline block; that requires a standalone rule resource.

```hcl
# Wrong
resource "aws_security_group" "alb_to_nodes" {
  source_security_group_id = aws_security_group.alb.id
  ...
}

# Correct
resource "aws_security_group_rule" "alb_to_nodes" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_nodes.id
  source_security_group_id = aws_security_group.alb.id
  description              = "ALB to EKS node port"
}
```

---

## Problem 8: Stray `tags {}` block outside any resource in the EKS module

**Error:**
```
Error: Unsupported block type
  on modules/eks/main.tf line 315:
  tags {
```

A `tags {}` block ended up outside the closing `}` of the last resource — Terraform sees it as a top-level block, which isn't valid. Deleted lines 314–318.

---

## Problem 9: S3 lifecycle rule missing the required `filter {}` block

**Error:**
```
Error: Missing required argument
  The argument "filter" is required for aws_s3_bucket_lifecycle_configuration rule
```

Every S3 lifecycle rule needs a `filter {}` block specifying which objects it applies to. An empty `filter {}` means "all objects."

```hcl
rule {
  id     = "abort-incomplete-multipart"
  status = "Enabled"

  filter {}   # apply to all objects

  abort_incomplete_multipart_upload {
    days_after_initiation = 7
  }
}
```

---

## Problem 10: Em-dashes in security group descriptions

**Error:**
```
Error: creating Security Group: InvalidParameterValue: Invalid description
  description = "EKS nodes — allow self"
```

The `—` character is Unicode U+2014 (em-dash), not an ASCII hyphen. AWS security group descriptions only accept printable ASCII. This happened because descriptions were typed in an editor that auto-converted `--` to `—`. Replaced all em-dashes with regular hyphens.

---

## Problem 11: Performance Insights rejected on db.t3.micro

**Error:**
```
Error: modifying RDS DB Instance: InvalidParameterCombination:
  Performance Insights is not supported for DB instance class db.t3.micro
```

AWS Performance Insights requires `db.t3.small` or larger. Simple fix:

```hcl
performance_insights_enabled = false
```

It's enabled in prod where we use `db.t3.small`.

---

## Problem 12: Route53 `count` depends on an unknown value

**Error:**
```
Error: Invalid count argument
  The "count" value depends on resource attributes that cannot be determined
  until apply, so Terraform cannot predict how many instances will be created.
```

The Route53 record had `count = var.alb_dns_name != "" ? 1 : 0`. The ALB DNS name comes from another resource's output — its value isn't known until apply time, so Terraform can't evaluate the conditional during plan. Removed the conditional count entirely; the record is always created.

```hcl
resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.subdomain}.${var.domain}"
  type    = "A"
  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
```

---

## Problem 13: Helm provider chicken-and-egg with EKS

**Error:**
```
Error: Kubernetes cluster unreachable: the server doesn't have a resource type "helmrelease"
```

We originally tried to install the Cluster Autoscaler via a `helm_release` resource in Terraform. The problem: the Helm provider needs the EKS cluster endpoint to connect, but that endpoint doesn't exist until the cluster is created — which is in the same `terraform apply`. Terraform evaluates all providers before running any resources, so it deadlocks.

The solution was to remove the `provider "helm"` block and all `helm_release` resources from Terraform entirely and install the Cluster Autoscaler manually via Helm CLI after the cluster is up:

```bash
helm repo add autoscaler https://kubernetes.github.io/autoscaler
helm install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set autoDiscovery.clusterName=todo-tf-cluster-dev \
  --set awsRegion=us-east-1 \
  --set rbac.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=<autoscaler-role-arn>
```

---

## Problem 14: CloudWatch log groups already existed

**Error:**
```
Error: creating CloudWatch Logs Log Group: ResourceAlreadyExistsException:
  The specified log group already exists: /aws/eks/todo-tf-cluster-dev/cluster
```

EKS automatically creates its own log group when control plane logging is enabled. When Terraform tries to create the same one, AWS rejects it. Rather than deleting the log group (which would lose logs), we imported it into state so Terraform manages it going forward:

```bash
terraform import -var-file=environments/dev/terraform.tfvars \
  module.cloudwatch.aws_cloudwatch_log_group.eks_cluster \
  /aws/eks/todo-tf-cluster-dev/cluster

terraform import -var-file=environments/dev/terraform.tfvars \
  module.cloudwatch.aws_cloudwatch_log_group.app \
  /todo/dev/application
```

---

## Problem 15: IAM roles and policies already existed

**Error:**
```
Error: creating IAM Role: EntityAlreadyExists: Role with name todo-dev-eks-cluster-role already exists.
Error: creating IAM Policy: EntityAlreadyExists: A policy called todo-dev-alb-controller-policy already exists.
```

An earlier interrupted apply had already created these. Terraform's state didn't know about them, so it tried to create them again. Import was the right call:

```bash
terraform import -var-file=environments/dev/terraform.tfvars \
  module.eks.aws_iam_role.eks_cluster todo-dev-eks-cluster-role

terraform import -var-file=environments/dev/terraform.tfvars \
  module.eks.aws_iam_role.eks_nodes todo-dev-eks-node-role

terraform import -var-file=environments/dev/terraform.tfvars \
  module.eks.aws_iam_role.ebs_csi todo-dev-ebs-csi-role

terraform import -var-file=environments/dev/terraform.tfvars \
  module.eks.aws_iam_role.alb_controller todo-dev-alb-controller-role

terraform import -var-file=environments/dev/terraform.tfvars \
  module.eks.aws_iam_policy.alb_controller \
  arn:aws:iam::668076964228:policy/todo-dev-alb-controller-policy
```

---

## Problem 16: Route53 CNAME conflicted with the new A alias record

**Error:**
```
Error: [ERR]: Error building changeset: InvalidChangeBatch:
  RRSet of type CNAME with DNS name www.ankit.services. is not permitted at apex
```

During an earlier attempt the ALB controller had auto-created a CNAME record pointing `www.ankit.services` at the controller-managed ALB. Terraform was trying to create an A alias record at the same name. Two record types at the same name conflict. Deleted the CNAME manually:

```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id Z07812883CC72HQVS0WSK \
  --change-batch '{
    "Changes": [{
      "Action": "DELETE",
      "ResourceRecordSet": {
        "Name": "www.ankit.services.",
        "Type": "CNAME",
        "TTL": 300,
        "ResourceRecords": [{"Value": "k8s-default-todoingr-096e8f96c2-1251263405.us-east-1.elb.amazonaws.com"}]
      }
    }]
  }'
```

Then `terraform apply` created the correct A alias record.

---

## Problem 17: ALB controller in CrashLoopBackOff — VPC ID and region missing

**Symptom:**
```
$ kubectl get pods -n kube-system
aws-load-balancer-controller-xxx    0/1    CrashLoopBackOff    5

$ kubectl logs -n kube-system deployment/aws-load-balancer-controller
level=error msg="VPC ID must be specified"
```

The initial Helm install was missing `--set vpcId` and `--set region`. The controller needs both to function and crashes immediately without them. Reinstalled with the missing values:

```bash
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=todo-tf-cluster-dev \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set vpcId=vpc-045b7a536d94660d0 \
  --set region=us-east-1
```

---

## Problem 18: Webhook `context deadline exceeded` — nodes had the wrong security group

**Symptom:**
```
$ kubectl apply -f app/k8s/
Error from server (InternalError): failed calling webhook "mpod.elbv2.k8s.aws":
  Post "https://aws-load-balancer-webhook-service.kube-system.svc:443/mutate-v1-pod":
  context deadline exceeded
```

This one took the longest to understand. The nodes had security group `sg-04f784e2a0b0c0f10`, which was assigned during the first (interrupted) Terraform apply. The second apply created a new SG `sg-0910a9a61b664d82d` and applied all the rules to that one. The control plane SG (`sg-0d1c831b59c30df03`) had no rules allowing it to reach port 443 or 10250 on the actual node SG.

In plain terms: the nodes and Terraform's security group rules were out of sync. The control plane couldn't reach the nodes for webhook calls or kubelet communication.

Fix: manually added the required rules to the actual node SG:

```bash
# Allow kubelet API (port 10250)
aws ec2 authorize-security-group-ingress \
  --group-id sg-04f784e2a0b0c0f10 \
  --protocol tcp --port 10250 \
  --source-group sg-0d1c831b59c30df03

# Allow webhook HTTPS (port 443)
aws ec2 authorize-security-group-ingress \
  --group-id sg-04f784e2a0b0c0f10 \
  --protocol tcp --port 443 \
  --source-group sg-0d1c831b59c30df03

# Allow high ports for NodePort and ephemeral traffic
aws ec2 authorize-security-group-ingress \
  --group-id sg-04f784e2a0b0c0f10 \
  --protocol tcp --port 1025-65535 \
  --source-group sg-0d1c831b59c30df03
```

The long-term fix is to ensure Terraform doesn't end up managing a different SG than what the nodes were actually assigned — either by importing the existing SG into state or by doing a clean teardown and redeploy.

---

## Problem 19: ALB controller `AccessDenied: DescribeListenerAttributes`

**Symptom:**
```
$ kubectl logs -n kube-system deployment/aws-load-balancer-controller
AccessDenied: not authorized to perform: elasticloadbalancing:DescribeListenerAttributes
```

The IAM policy file we used was copied from documentation for an older controller version. Version 3.3.0+ added `elasticloadbalancing:DescribeListenerAttributes` as a required permission. The policy didn't have it.

Immediate fix — add the permission to the existing policy without waiting for a full Terraform run:

```bash
POLICY_ARN=$(aws iam list-policies --query \
  "Policies[?PolicyName=='todo-dev-alb-controller-policy'].Arn" \
  --output text)

aws iam create-policy-version \
  --policy-arn $POLICY_ARN \
  --policy-document file://updated-policy.json \
  --set-as-default
```

Permanent fix: added `"elasticloadbalancing:DescribeListenerAttributes"` to the action list in `infra/terraform/modules/eks/alb-controller-policy.json`. The controller picked up the new permissions automatically without needing a restart.

---

## Problem 20: Backend pods crashing — wrong DB_HOST and wrong password

**Symptom 1:**
```
$ kubectl logs -n todo deployment/todo-backend
Error: getaddrinfo ENOTFOUND todo-db
```

The `DB_HOST` in the Secret was base64-encoded `todo-db` — a placeholder that was never updated. The actual RDS endpoint from Terraform is `todo-db-dev.c23qc6e80bp5.us-east-1.rds.amazonaws.com`. Got the correct value and updated the Secret:

```bash
terraform -chdir=infra/terraform output -raw rds_endpoint | cut -d: -f1 | base64
# → dG9kby1kYi1kZXYuYzIzcWM2ZTgwYnA1LnVzLWVhc3QtMS5yZHMuYW1hem9uYXdzLmNvbQ==
```

**Symptom 2:**
```
$ kubectl logs -n todo deployment/todo-backend
Error: Access denied for user 'todo_user'@'...' (using password: YES)
```

Two issues here. First, the password in the Secret was still the placeholder `rootpass`. Second, when we tried to fix it, we used `tododev` (7 characters) — AWS RDS requires a minimum 8-character password and silently rejected it. Reset the master password with a valid value:

```bash
aws rds modify-db-instance \
  --db-instance-identifier todo-db-dev \
  --master-user-password tododev1 \
  --apply-immediately
```

Waited ~60 seconds for the change to propagate, then updated the Secret:

```bash
echo -n "tododev1" | base64
# → dG9kb2RldjE=

kubectl apply -f app/k8s/secret.yaml
kubectl rollout restart deployment/todo-backend -n todo
```

---

## Lessons from All of This

| # | What we learned |
|---|--------|
| 1–4 | Run `terraform validate` before every apply — it catches typos and wrong attribute names in seconds |
| 5–7 | When Terraform rejects an attribute name, look it up in the Terraform registry docs rather than guessing. `ip_protocol` vs `protocol` is a good example of two resources with similar-but-different schemas |
| 8 | Every block in a `.tf` file has to live inside a resource, data source, or module. A stray block at the top level breaks the whole file |
| 10 | Copy-pasting from word processors or certain editors can silently introduce Unicode characters that AWS APIs reject |
| 11 | Check AWS feature compatibility for your instance class before enabling monitoring features |
| 12–13 | Terraform `count` and provider configuration can't depend on values that are unknown at plan time — this is a fundamental constraint, not a bug |
| 14–16 | When resources already exist in AWS but not in Terraform state, `terraform import` is almost always the right answer. Deleting and recreating loses data and can cause downtime |
| 17 | Always check the pod logs first — the error message is usually specific enough to point straight at the problem |
| 18 | Security group state drifts badly when applies are interrupted. After an interrupted apply, verify that the SG IDs assigned to your nodes match what Terraform thinks it configured |
| 19 | IAM policies need to stay in sync with the component version that uses them — always check the changelog when upgrading controllers |
| 20 | Never deploy with placeholder values in Secrets. Base64-decoding a secret is trivial, so it's easy to verify you have the right value before applying |
