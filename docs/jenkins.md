# Jenkins — CI/CD Pipeline

## What is Jenkins?

Jenkins is an open-source automation server. When code is pushed to Git, Jenkins automatically builds Docker images, pushes them to ECR, and rolls out the new version to EKS — all without manual steps.

**Why Jenkins (not GitHub Actions)?**
- Self-hosted: runs inside your own infrastructure, no per-minute billing
- Works with any Git server (GitHub, GitLab, Bitbucket, self-hosted)
- Mature plugin ecosystem — AWS credentials, Kubernetes, Docker all have first-class support
- Pipeline-as-code: the Jenkinsfile is version-controlled alongside the application

---

## Pipeline File Location

```
infra/ci-cd/Jenkinsfile
```

The Jenkinsfile is the single source of truth for the CI/CD process. Jenkins reads it from the repo on every run.

---

## Environment Variables

Defined once at the top, used throughout all stages:

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

**`IMAGE_TAG = "v${BUILD_NUMBER}"`** — Jenkins auto-increments `BUILD_NUMBER` on every run. This means every build produces a unique, traceable image tag. The image is also tagged `latest` for convenience.

---

## Pipeline Structure

```
Checkout  (+ DinD daemon readiness check)
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
Apply K8s Manifests  (if infra/** OR app/k8s/** changed)
    │
Cleanup
```

---

## Stage-by-Stage Breakdown

### Stage 1 — Checkout

```groovy
stage('Checkout') {
    steps {
        checkout scm
        // Wait for DinD daemon to be ready before any Docker commands
        retry(15) {
            sleep(time: 3, unit: 'SECONDS')
            sh 'docker info > /dev/null 2>&1'
        }
    }
}
```

Clones the repository at the commit that triggered the pipeline. `scm` refers to the source control configuration set in the Jenkins job.

After checkout, the pipeline waits for the Docker-in-Docker sidecar daemon to be ready before any stage tries to run `docker build`. The agent pod's DinD container can take a few seconds to initialise after the pod starts. Without this check, the first `docker build` call would fail with `"Cannot connect to the Docker daemon"`. The `retry(15)` block polls every 3 seconds for up to 45 seconds — enough time for DinD to come up on any reasonably-sized node.

---

### Stage 2 — App (Parallel)

The frontend and backend pipelines run simultaneously. This halves the total build time when both change.

#### Changeset Guards (`when { changeset '...' }`)

Every sub-stage is wrapped in a `when` condition:

```groovy
when { changeset 'app/frontend/**' }
```

**Why this matters:** If you push a change to only the backend (`app/backend/`), Jenkins skips all three frontend stages entirely — no unnecessary image rebuild, no unnecessary deployment.

| Push changes to... | Frontend stages | Backend stages | Terraform stages | Apply K8s Manifests |
|--------------------|----------------|----------------|-----------------|---------------------|
| `app/frontend/` | Run | Skip | Skip | Skip |
| `app/backend/` | Skip | Run | Skip | Skip |
| `infra/` | Skip | Skip | Run | Run |
| `app/k8s/` | Skip | Skip | Skip | Run |
| `app/frontend/` + `app/backend/` | Run | Run | Skip | Skip |
| `infra/` + `app/k8s/` | Skip | Skip | Run | Run |

#### Build Frontend

```groovy
sh """
    docker build \
        -f app/docker/Dockerfile.frontend \
        -t ${ECR_FRONTEND}:${IMAGE_TAG} \
        app/frontend/
"""
```

- `-f app/docker/Dockerfile.frontend` — Dockerfile is not in the build context directory; `-f` points to it explicitly
- `-t ...frontend:v42` — tags with the build number
- `app/frontend/` — build context (everything Docker can access during build)

#### Push Frontend

```groovy
withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                  credentialsId: 'aws-creds']]) {
    sh """
        aws ecr get-login-password --region ${AWS_REGION} | \
            docker login --username AWS --password-stdin ${ECR_REGISTRY}
        docker push ${ECR_FRONTEND}:${IMAGE_TAG}
        docker tag  ${ECR_FRONTEND}:${IMAGE_TAG} ${ECR_FRONTEND}:latest
        docker push ${ECR_FRONTEND}:latest
    """
}
```

ECR tokens expire after 12 hours, so the pipeline logs in fresh every run. The image is pushed twice: once with the versioned tag (`v42`) and once as `latest`. The entire block is wrapped in `withCredentials` so the `aws ecr get-login-password` call has valid IAM credentials — the same `aws-creds` credential used by the Terraform stages.

#### Deploy Frontend

```groovy
withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                  credentialsId: 'aws-creds']]) {
    sh """
        aws eks update-kubeconfig \
            --region ${AWS_REGION} --name ${EKS_CLUSTER}
        kubectl set image deployment/todo-frontend \
            todo-frontend=${ECR_FRONTEND}:${IMAGE_TAG} \
            -n ${KUBE_NS}
        kubectl rollout status deployment/todo-frontend \
            -n ${KUBE_NS} --timeout=180s \
        || (kubectl rollout undo deployment/todo-frontend -n ${KUBE_NS} && exit 1)
    """
}
```

**How the rollout works:**

1. `aws eks update-kubeconfig` — configures `kubectl` to talk to the EKS cluster using IAM credentials
2. `kubectl set image` — patches the deployment to use the new image tag; Kubernetes starts a rolling update
3. `kubectl rollout status --timeout=180s` — waits up to 3 minutes for the rollout to complete
4. `|| (kubectl rollout undo ... && exit 1)` — if the rollout fails or times out, Jenkins immediately rolls back to the previous working image and marks the build failed

This is an **automatic rollback** — no manual intervention needed if the new image crashes or fails health checks.

**Backend stages are identical** — same build, push, deploy pattern with `app/backend/**` changeset guard and `todo-backend` deployment name.

---

### Stages 3–6 — Terraform (Infrastructure Changes)

These stages only run when files under `infra/` change.

#### Terraform Init

```groovy
withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                  credentialsId: 'aws-creds']]) {
    sh "terraform -chdir=${TF_DIR} init -input=false"
}
```

Downloads providers and modules. `withCredentials` injects `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` from the Jenkins credential store — credentials are never hardcoded.

#### Terraform Validate

```groovy
sh "terraform -chdir=${TF_DIR} validate"
```

Validates HCL syntax and internal consistency without connecting to AWS. Fast — runs in seconds.

#### Terraform Plan

```groovy
sh """
    terraform -chdir=${TF_DIR} plan \
        -var-file=environments/dev/terraform.tfvars \
        -out=tfplan -input=false
"""
```

Computes the diff between current state and desired state. Saves the plan to `tfplan` so Apply executes exactly what was planned.

#### Terraform Apply

```groovy
sh "terraform -chdir=${TF_DIR} apply -input=false tfplan"
```

Executes the saved plan. Because the plan is pre-approved, this runs non-interactively.

**Note:** In production pipelines, you would add a manual approval gate between Plan and Apply:

```groovy
stage('Approve Terraform Apply') {
    steps {
        input message: 'Review the Terraform plan. Proceed with apply?'
    }
}
```

---

### Stage 7 — Apply K8s Manifests

```groovy
stage('Apply K8s Manifests') {
    when {
        anyOf {
            changeset 'infra/**'
            changeset 'app/k8s/**'
        }
    }
    steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                          credentialsId: 'aws-creds']]) {
            sh """
                aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}

                FRONTEND_TG_ARN=\$(terraform -chdir=${TF_DIR} output -raw frontend_tg_arn)
                BACKEND_TG_ARN=\$(terraform -chdir=${TF_DIR} output -raw backend_tg_arn)
                BACKEND_IRSA_ROLE_ARN=\$(terraform -chdir=${TF_DIR} output -raw todo_backend_irsa_role_arn)
                SECRET_NAME=\$(terraform -chdir=${TF_DIR} output -raw secrets_manager_secret_name)

                sed -e "s|__FRONTEND_TG_ARN__|\${FRONTEND_TG_ARN}|g" \
                    -e "s|__BACKEND_TG_ARN__|\${BACKEND_TG_ARN}|g" \
                    app/k8s/targetgroupbinding.yaml | kubectl apply -f -

                sed "s|__BACKEND_IRSA_ROLE_ARN__|\${BACKEND_IRSA_ROLE_ARN}|g" \
                    app/k8s/serviceaccount.yaml | kubectl apply -f -

                sed "s|__SECRET_NAME__|\${SECRET_NAME}|g" \
                    app/k8s/secretproviderclass.yaml | kubectl apply -f -
            """
        }
    }
}
```

This stage solves the problem of Kubernetes manifests that reference AWS resource ARNs which are only known after Terraform runs. Rather than manually editing manifest files after every `terraform apply`, the manifests store placeholder tokens and the pipeline injects the real values at deploy time using `sed`.

**When it runs:** any change under `infra/` (Terraform resources changed, so ARNs may have changed) or `app/k8s/` (manifest templates were edited).

**What it does — step by step:**

1. Configures `kubectl` to reach the EKS cluster
2. Reads four values from Terraform output at pipeline time:

| Terraform output | Used in manifest |
|---|---|
| `frontend_tg_arn` | `targetgroupbinding.yaml` — ALB target group for frontend pods |
| `backend_tg_arn` | `targetgroupbinding.yaml` — ALB target group for backend pods |
| `todo_backend_irsa_role_arn` | `serviceaccount.yaml` — IAM role the backend pod assumes |
| `secrets_manager_secret_name` | `secretproviderclass.yaml` — which Secrets Manager secret to mount |

3. Applies each manifest after substituting the placeholder tokens:

| Manifest | Placeholder(s) replaced |
|---|---|
| `targetgroupbinding.yaml` | `__FRONTEND_TG_ARN__`, `__BACKEND_TG_ARN__` |
| `serviceaccount.yaml` | `__BACKEND_IRSA_ROLE_ARN__` |
| `secretproviderclass.yaml` | `__SECRET_NAME__` |

**Why this approach matters:** These three manifests contain AWS ARNs that are account- and environment-specific. Hardcoding them means the repo can't be cloned and deployed to a fresh account without manual edits. Using `__PLACEHOLDER__` tokens keeps the manifests portable — Terraform always knows the correct values, and the pipeline bridges the two systems automatically. No one needs to copy-paste ARNs by hand after an infrastructure change.

---

### Stage 8 — Cleanup

```groovy
sh """
    docker rmi ${ECR_FRONTEND}:${IMAGE_TAG} ${ECR_FRONTEND}:latest || true
    docker rmi ${ECR_BACKEND}:${IMAGE_TAG}  ${ECR_BACKEND}:latest  || true
    rm -f ${TF_DIR}/tfplan || true
"""
```

Removes locally built images from the Jenkins agent and deletes the saved Terraform plan. The `|| true` prevents the stage from failing if an image was never built (e.g., frontend-only change means backend image doesn't exist).

---

## Post Section

```groovy
post {
    success { echo "Pipeline ${IMAGE_TAG} completed successfully." }
    failure { echo 'Pipeline failed — check stage logs above.' }
}
```

Runs after all stages complete regardless of outcome. In production, replace `echo` with Slack or email notifications:

```groovy
post {
    failure {
        slackSend channel: '#alerts', message: "Build ${IMAGE_TAG} FAILED: ${env.BUILD_URL}"
    }
}
```

---

## Jenkins Setup Requirements

### 1. Jenkins Credentials

The pipeline requires two credentials stored in Jenkins (Manage Jenkins → Credentials → Global):

| ID | Type | Used in | Contents |
|----|------|---------|---------|
| `aws-creds` | AWS Credentials | Push, Deploy, and all Terraform stages | IAM access key + secret key |
| `rds-password` | Secret text | `environment { TF_VAR_rds_password }` | RDS master password, passed to Terraform as a variable |

The `aws-creds` IAM user/role needs permissions for: ECR (push/pull), EKS (update-kubeconfig, kubectl), S3 (Terraform state), and the full set of Terraform-managed resources.

The `rds-password` credential is injected as `TF_VAR_rds_password` at the top of the pipeline so Terraform can pass it to the RDS module without the password ever appearing in `.tfvars` files or pipeline logs.

### 2. Required Plugins

| Plugin | Purpose |
|--------|---------|
| Pipeline | Jenkinsfile support |
| Git | Source checkout |
| AWS Credentials | `AmazonWebServicesCredentialsBinding` |
| Docker Pipeline | `docker build/push` in pipeline steps |

### 3. Jenkins Agent Requirements

The agent (the machine that runs build steps) must have these tools installed:
- `docker` (with daemon running)
- `aws` CLI (v2)
- `kubectl`
- `terraform` (>= 1.6.0)

---

## End-to-End Flow — Code Change to Production

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
Checkout stage pulls latest commit + waits for DinD daemon ready
    │
    ▼
changeset 'app/backend/**' matches? YES
    │
    ▼
Build Backend:  docker build → image tagged v43
Push Backend:   (withCredentials: aws-creds) ECR login → docker push v43 + latest
Deploy Backend: (withCredentials: aws-creds) kubectl set image → rolling update starts
                kubectl rollout status waits 180s
                    ├── SUCCESS → pipeline continues
                    └── FAIL   → kubectl rollout undo (v42 restored) + pipeline fails
    │
    ▼
changeset 'infra/**' matches? NO → Apply K8s Manifests skipped
    │
    ▼
Cleanup: docker rmi local images
    │
    ▼
post { success } or post { failure }
```

**Infrastructure + manifest change (e.g., after `terraform apply`):**

```
changeset 'infra/**' matches? YES
    │
    ▼
Terraform Init → Validate → Plan → Apply  (all withCredentials: aws-creds)
    │
    ▼
Apply K8s Manifests:
    Read terraform output → frontend_tg_arn, backend_tg_arn,
                            todo_backend_irsa_role_arn, secrets_manager_secret_name
    sed-inject ARNs into targetgroupbinding.yaml → kubectl apply
    sed-inject role ARN into serviceaccount.yaml  → kubectl apply
    sed-inject secret name into secretproviderclass.yaml → kubectl apply
    │
    ▼
Cleanup
```

![End-to-End CI/CD Flow](diagrams/End-to-End%20CICD%20Flow-2026-05-19-085645.png)

**Total time for a backend-only change:** ~3-5 minutes (build + push + rolling rollout)

---

## Image Tagging Strategy

```
v43 (build number)  ←  traceability: maps to a specific Jenkins build and Git commit
latest              ←  convenience: always points to the most recently deployed image
```

**Best practice improvement:** Also tag with the Git commit SHA for full traceability:

```groovy
environment {
    GIT_SHA  = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
    IMAGE_TAG = "v${BUILD_NUMBER}-${GIT_SHA}"  // e.g. v43-a3f2c1d
}
```

---

## Rolling Update Behaviour

When `kubectl set image` is called, Kubernetes performs a rolling update:

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

- Zero downtime: old pods serve traffic until new pods pass health checks
- If the new pod never becomes Ready, the rollout stalls and times out
- The `|| rollout undo` in the Jenkinsfile catches this and restores v42

This rollout behaviour is controlled by the deployment's `strategy.rollingUpdate` settings (default: `maxUnavailable: 25%`, `maxSurge: 25%`).
