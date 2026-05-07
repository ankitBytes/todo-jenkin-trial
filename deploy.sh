#!/bin/bash
# =============================================================================
# deploy.sh — Todo App Kubernetes Deployment Script
#
# Usage:
#   ./deploy.sh           # build, push, deploy everything
#   ./deploy.sh --skip-build   # deploy manifests only (no docker build/push)
#
# Requirements:
#   - docker, aws cli, kubectl installed and on PATH
#   - AWS credentials configured (env vars or ~/.aws/credentials)
#   - EKS cluster already exists
# =============================================================================

set -euo pipefail   # exit on error, unset var, or pipe failure

# ── Config ────────────────────────────────────────────────────────────────────
AWS_REGION="us-east-1"
ECR_REGISTRY="668076964228.dkr.ecr.us-east-1.amazonaws.com"
ECR_REPO="668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-trial"
IMAGE_TAG="v$(date +%Y%m%d-%H%M%S)"    # e.g. v20260506-143022
IMAGE_FULL="${ECR_REPO}:${IMAGE_TAG}"
EKS_CLUSTER="todo-eks"
KUBE_NS="default"
SKIP_BUILD=false

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # no colour

# ── Helpers ───────────────────────────────────────────────────────────────────
log()     { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Argument parsing ──────────────────────────────────────────────────────────
for arg in "$@"; do
  case $arg in
    --skip-build) SKIP_BUILD=true ;;
    *) error "Unknown argument: $arg. Usage: ./deploy.sh [--skip-build]" ;;
  esac
done

# ── Banner ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}=================================================${NC}"
echo -e "${CYAN}   Todo App — Kubernetes Deployment Script      ${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""
log "Image tag   : ${IMAGE_TAG}"
log "EKS cluster : ${EKS_CLUSTER}"
log "Namespace   : ${KUBE_NS}"
log "Skip build  : ${SKIP_BUILD}"
echo ""

# =============================================================================
# STEP 1 — Preflight checks
# =============================================================================
log "Step 1/6 — Preflight checks..."

command -v docker  &>/dev/null || error "docker is not installed or not on PATH"
command -v aws     &>/dev/null || error "aws cli is not installed or not on PATH"
command -v kubectl &>/dev/null || error "kubectl is not installed or not on PATH"

# Verify required manifest files exist
for f in deployment.yaml service.yaml ingress.yaml configmap.yaml secret.yaml; do
  [[ -f "$f" ]] || error "Missing required file: $f — run this script from the project root"
done

success "All preflight checks passed"
echo ""

# =============================================================================
# STEP 2 — Build Docker image
# =============================================================================
if [[ "$SKIP_BUILD" == "true" ]]; then
  warn "Step 2/6 — Skipping build (--skip-build flag set)"
else
  log "Step 2/6 — Building Docker image..."

  docker build \
    --tag "${IMAGE_FULL}" \
    --tag "${ECR_REPO}:latest" \
    --file Dockerfile \
    .

  success "Image built: ${IMAGE_FULL}"
fi
echo ""

# =============================================================================
# STEP 3 — Push to ECR
# =============================================================================
if [[ "$SKIP_BUILD" == "true" ]]; then
  warn "Step 3/6 — Skipping ECR push (--skip-build flag set)"
else
  log "Step 3/6 — Pushing image to ECR..."

  aws ecr get-login-password --region "${AWS_REGION}" \
    | docker login \
        --username AWS \
        --password-stdin "${ECR_REGISTRY}"

  docker push "${IMAGE_FULL}"
  docker push "${ECR_REPO}:latest"

  success "Image pushed: ${IMAGE_FULL}"
fi
echo ""

# =============================================================================
# STEP 4 — Patch image tag in deployment.yaml
# =============================================================================
log "Step 4/6 — Patching image tag in deployment.yaml..."

if [[ "$SKIP_BUILD" == "true" ]]; then
  warn "Skipping tag patch — using whatever image is already in deployment.yaml"
else
  # Replace any existing tag on both the frontend and backend image lines
  sed -i "s|image: ${ECR_REPO}:.*|image: ${IMAGE_FULL}|g" deployment.yaml

  log "Image lines after patch:"
  grep "image:" deployment.yaml | sed 's/^/         /'
fi
echo ""

# =============================================================================
# STEP 5 — Connect kubectl to EKS
# =============================================================================
log "Step 5/6 — Syncing kubeconfig for cluster: ${EKS_CLUSTER}..."

aws eks update-kubeconfig \
  --region "${AWS_REGION}" \
  --name "${EKS_CLUSTER}"

# Verify connectivity
kubectl cluster-info --request-timeout=10s &>/dev/null \
  || error "Cannot reach the Kubernetes API server. Check your AWS credentials and cluster name."

success "kubectl connected to ${EKS_CLUSTER}"
echo ""

# =============================================================================
# STEP 6 — Apply manifests
# =============================================================================
log "Step 6/6 — Applying Kubernetes manifests..."

# Apply in dependency order: config/secrets before workloads, workloads before ingress
kubectl apply -f configmap.yaml  -n "${KUBE_NS}"
kubectl apply -f secret.yaml     -n "${KUBE_NS}"
kubectl apply -f deployment.yaml -n "${KUBE_NS}"
kubectl apply -f service.yaml    -n "${KUBE_NS}"
kubectl apply -f ingress.yaml    -n "${KUBE_NS}"

success "All manifests applied"
echo ""

# =============================================================================
# STEP 7 — Wait for rollout
# =============================================================================
log "Waiting for frontend rollout..."
kubectl rollout status deployment/todo-frontend \
  -n "${KUBE_NS}" --timeout=120s \
  || error "Frontend deployment did not become ready in time. Run: kubectl describe deployment/todo-frontend"

log "Waiting for backend rollout..."
kubectl rollout status deployment/todo-backend \
  -n "${KUBE_NS}" --timeout=120s \
  || error "Backend deployment did not become ready in time. Run: kubectl describe deployment/todo-backend"

echo ""

# =============================================================================
# Summary
# =============================================================================
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}   Deployment complete!                         ${NC}"
echo -e "${GREEN}=================================================${NC}"
echo ""

log "Running pods:"
kubectl get pods -n "${KUBE_NS}" -l app=todo
echo ""

log "Services:"
kubectl get svc -n "${KUBE_NS}" todo-frontend-svc todo-backend-svc
echo ""

log "Ingress (ALB hostname — may take ~60s to provision):"
kubectl get ingress todo-ingress -n "${KUBE_NS}"
echo ""

# Extract and print the ALB address if already available
ALB_HOST=$(kubectl get ingress todo-ingress -n "${KUBE_NS}" \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)

if [[ -n "$ALB_HOST" ]]; then
  success "App is live at: http://${ALB_HOST}"
else
  warn "ALB not provisioned yet. Re-check in ~60s with:"
  echo "       kubectl get ingress todo-ingress"
fi

echo ""
