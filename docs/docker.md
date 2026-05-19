# Docker — Containerisation

## What is Docker?

Docker packages an application and all its dependencies (runtime, libraries, config) into a single portable unit called a **container image**. The image runs identically on any machine — a developer's laptop, a CI server, or a Kubernetes node in AWS.

**Why we use it:**
- "Works on my machine" is eliminated — the container is the machine
- Images are versioned and stored in ECR; any version can be rolled back to instantly
- EKS pulls images directly from ECR to run pods

---

## Project Image Strategy

| Image | Registry | Repository |
|-------|---------|----------|
| Frontend | ECR | `668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-frontend` |
| Backend | ECR | `668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-backend` |

**Why two separate repositories?**
- A backend code change should only trigger a backend image build — not rebuild the frontend
- Independent versioning: frontend can be on `v2.1`, backend on `v3.0`
- Avoids tag collision that occurs in a shared repo

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

**Key decisions:**

| Decision | Reason |
|----------|--------|
| `node:20-alpine` | Alpine Linux is ~5MB vs ~150MB for full Debian — smaller image, faster pulls |
| Non-root user | If a container is compromised, the attacker has no root privileges |
| `COPY package*.json` before `COPY src/` | Docker caches each layer. If source changes but `package.json` doesn't, npm install is not re-run — faster builds |
| `npm ci --omit=dev` | `ci` installs exactly what's in `package-lock.json` (reproducible). `--omit=dev` skips test frameworks, linters — smaller image |

**Build context:** `app/backend/` — the Dockerfile expects `package.json` and `src/` at the root of the build context.

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

**Key decisions:**

| Decision | Reason |
|----------|--------|
| `serve` package | The frontend is pure HTML/JS/CSS — no build step needed. `serve` hosts the files on port 3000 |
| `COPY . .` | All frontend files are copied. Build context is `app/frontend/` |
| Port 3000 | Both frontend and backend use port 3000. The ALB routes to separate target groups by URL path — not port |

---

## Build and Push Commands

### Step 1 — Authenticate with ECR

ECR uses short-lived tokens (12 hours). Run this once per session:

```bash
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
    668076964228.dkr.ecr.us-east-1.amazonaws.com
```

### Step 2 — Build Backend Image

```bash
docker build \
  -t 668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-backend:latest \
  -f app/docker/Dockerfile.backend \
  app/backend/
```

- `-f` specifies the Dockerfile location (it is not in the build context directory)
- Last argument `app/backend/` is the **build context** — the directory Docker sends to the daemon

### Step 3 — Push Backend Image

```bash
docker push 668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-backend:latest
```

### Step 4 — Build and Push Frontend Image

```bash
docker build \
  -t 668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-frontend:latest \
  -f app/docker/Dockerfile.frontend \
  app/frontend/

docker push 668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-frontend:latest
```

---

## Local Development

For local testing without Kubernetes, use `docker-compose`:

```bash
docker compose -f app/docker/docker-compose.yaml up
```

This starts frontend, backend, MySQL, and Redis containers locally, wired together on a private Docker network. Useful for development before pushing to EKS.

---

## Image Lifecycle in ECR

ECR retains the last **10 images** (dev: 5) per repository, controlled by the lifecycle policy Terraform creates:

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

Older images are automatically deleted. This keeps storage costs low and prevents the registry from accumulating hundreds of stale images.

---

## Tagging Strategy

Currently using `latest` tag for simplicity. In production, best practice is to tag with the Git commit SHA:

```bash
IMAGE_TAG=$(git rev-parse --short HEAD)
docker build -t .../todo-backend:$IMAGE_TAG ...
docker push .../todo-backend:$IMAGE_TAG

# Also push as latest for convenience
docker tag .../todo-backend:$IMAGE_TAG .../todo-backend:latest
docker push .../todo-backend:latest
```

This makes every build traceable back to an exact commit.
