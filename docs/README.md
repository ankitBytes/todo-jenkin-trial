# Todo Fullstack — DevOps Documentation

## Overview

This project deploys a full-stack Todo application on AWS using a production-grade DevOps setup. The infrastructure is fully automated — from networking to container orchestration — using industry-standard tools.

**Application:** A Todo web app with a JavaScript frontend, Node.js backend, MySQL database, and Redis cache.

**Deployed at:** `https://www.ankit.services`

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
                                                                  │
```

![Overall Architecture](diagrams/Overall%20Architecture-2026-05-19-085235.png)

**Traffic Flow:**
1. User visits `https://www.ankit.services`
2. Route53 resolves DNS → ALB IP
3. ALB terminates TLS, routes `/api/*` → Backend pods, `/` → Frontend pods
4. Backend reads/writes to RDS (MySQL) and Redis (cache/sessions)
5. Frontend is served as static files by the `serve` package

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

## Documentation Index

| Document | Contents |
|----------|---------|
| [Terraform](terraform.md) | Infrastructure modules, variables, apply procedure |
| [Docker](docker.md) | Dockerfiles, build strategy, ECR push |
| [Kubernetes](kubernetes.md) | Manifests, traffic flow, scaling, secrets |
| [Jenkins](jenkins.md) | CI/CD pipeline, path-based triggers |
| [Troubleshooting](troubleshooting.md) | Problems encountered and their solutions |

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
