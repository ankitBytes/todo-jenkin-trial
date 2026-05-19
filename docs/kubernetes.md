# Kubernetes — Container Orchestration

## What is Kubernetes?

Kubernetes (K8s) is a system that manages containers at scale. Instead of manually running `docker run` on servers, you declare what you want (e.g., "run 2 copies of the backend container") and Kubernetes continuously ensures that state is maintained — restarting crashed containers, rescheduling on healthy nodes, and scaling up/down.

**Why we use EKS (Elastic Kubernetes Service)?**
AWS manages the Kubernetes control plane (the master nodes). We only manage the worker nodes where our pods run. This eliminates the operational burden of running etcd, the API server, and scheduler ourselves.

---

## Cluster Overview

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

---

## Manifests Explained

### 1. Namespace — `namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: todo
```

**What it does:** Creates an isolated workspace called `todo`. All application resources live here.

**Why:** Namespaces prevent resource name collisions and allow per-namespace access control and resource quotas. The `kube-system` namespace is for cluster components — keeping our app in `todo` separates concerns clearly.

---

### 2. ConfigMap — `configmap.yaml`

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

**What it does:** Stores non-sensitive configuration as key-value pairs, injected into pods as environment variables.

**Why separate from the image?** Configuration changes (e.g., updating `ALLOWED_ORIGIN`) don't require rebuilding the Docker image — just update the ConfigMap and roll the deployment.

**Rule:** ConfigMap = safe to commit to Git. Secret = never commit plain text.

---

### 3. Secret — `secret.yaml`

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

**What it does:** Stores sensitive values. Kubernetes stores them separately from regular config and only mounts them in pods that need them.

**Important:** Base64 is encoding, not encryption. The values can be decoded with `base64 -d`. For production, use AWS Secrets Manager with the External Secrets Operator to inject secrets at runtime.

**How to generate values:**
```bash
# RDS endpoint (remove the :3306 port suffix)
terraform output -raw rds_endpoint | cut -d: -f1 | base64

# Redis endpoint
terraform output -raw redis_primary_endpoint | base64

# Password
echo -n "YourPassword" | base64
```

---

### 4. Deployment — `deployment.yaml`

The most important manifest. Defines how pods are created and managed.

**Frontend Deployment:**
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

**Backend Deployment:** Same structure but also mounts the Secret:
```yaml
        envFrom:
        - configMapRef:
            name: todo-config
        - secretRef:
            name: todo-secret
```

**Key settings:**

| Setting | Value | Reason |
|---------|-------|--------|
| `replicas: 2` | 2 pods each | High availability — if one pod crashes, the other handles traffic |
| `envFrom configMapRef` | Injects all ConfigMap keys as env vars | Decouples config from image |
| `envFrom secretRef` | Injects all Secret keys as env vars | Keeps credentials out of the image |

**Liveness vs Readiness Probes** (if configured):
- **Liveness:** If this fails, Kubernetes restarts the container
- **Readiness:** If this fails, Kubernetes stops sending traffic to this pod (but doesn't restart it)

---

### 5. Service — `service.yaml`

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

**What it does:** Creates a stable internal IP and DNS name for a group of pods. `todo-frontend-svc.todo.svc.cluster.local` always resolves to one of the running frontend pods.

**Why ClusterIP (not LoadBalancer)?** The ALB is our external entry point, managed by the Ingress. We don't need a separate AWS load balancer per service. ClusterIP is internal-only — cheaper and simpler.

**Port mapping:** The Service listens on port 80 internally but forwards to port 3000 on the pods (where the app runs).

---

### 6. Ingress — `ingress.yaml`

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

**What it does:** The AWS Load Balancer Controller reads this resource and configures the ALB's listener rules accordingly.

**Key annotations:**

| Annotation | Value | Purpose |
|-----------|-------|---------|
| `scheme: internet-facing` | — | ALB is reachable from the internet |
| `target-type: ip` | — | ALB registers pod IPs directly (not EC2 IPs) |
| `certificate-arn` | ACM ARN | TLS certificate for HTTPS |
| `ssl-redirect: 443` | — | HTTP requests are redirected to HTTPS |
| `load-balancer-arn` | existing ALB ARN | Tells controller to use this existing ALB instead of creating a new one |

**Path routing:**
```
https://www.ankit.services/api/todos  → todo-backend-svc → backend pods
https://www.ankit.services/health     → todo-backend-svc → backend pods
https://www.ankit.services/           → todo-frontend-svc → frontend pods
```

---

### 7. HPA (HorizontalPodAutoscaler) — `hpa.yaml`

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

**What it does:** Automatically increases/decreases the number of backend pods based on CPU usage.

**How it works:**
```
CPU > 70% for sustained period → HPA adds pods (up to maxReplicas: 6)
CPU < 70% and stable          → HPA removes pods (down to minReplicas: 2)
```

**Two levels of autoscaling:**
1. **HPA** (this) — scales pods within a node
2. **Cluster Autoscaler** — adds/removes nodes when pods can't be scheduled

---

### 8. PDB (PodDisruptionBudget) — `pdb.yaml`

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

**What it does:** Guarantees that at least 1 backend pod is always running during voluntary disruptions (node drains, upgrades).

**Why it matters:** Without a PDB, Kubernetes could drain a node and temporarily leave zero backend pods running. With `minAvailable: 1`, Kubernetes waits until a replacement pod is running before draining the next one.

---

## Traffic Flow — Complete Picture

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

## Useful Commands

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

---

## Updating the Application

### New image (code change):
```bash
# Build and push new image
docker build -t .../todo-backend:latest -f app/docker/Dockerfile.backend app/backend/
docker push .../todo-backend:latest

# Restart the deployment to pull the new image
kubectl rollout restart deployment/todo-backend -n todo
```

### Config change (no rebuild needed):
```bash
# Edit configmap.yaml, then:
kubectl apply -f app/k8s/configmap.yaml
kubectl rollout restart deployment/todo-backend -n todo
```

### Secret change:
```bash
# Edit secret.yaml with new base64 values, then:
kubectl apply -f app/k8s/secret.yaml
kubectl rollout restart deployment/todo-backend -n todo
```
