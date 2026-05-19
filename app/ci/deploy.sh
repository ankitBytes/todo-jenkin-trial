#!/bin/bash
# =============================================================================
# deploy.sh — Todo App Kubernetes Deployment Script
#
# Usage (run from the app/ directory):
#   ./ci/deploy.sh                          # build, push, deploy everything
#   ./ci/deploy.sh --skip-build             # deploy manifests only (no docker build/push)
#   ./ci/deploy.sh --latest-tag             # also push :latest tag alongside the versioned tag
#
# Requirements:
#   - docker, aws cli, kubectl installed and on PATH
#   - AWS credentials configured (env vars or ~/.aws/credentials)
#   - EKS cluster already exists
# =============================================================================

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

AWS_REGION="us-east-1"
ECR_REGISTRY="668076964228.dkr.ecr.us-east-1.amazonaws.com"
ECR_REPO="668076964228.dkr.ecr.us-east-1.amazonaws.com/todo-trial"
IMAGE_TAG="v$(date +%Y%m%d-%H%M%S)"
IMAGE_FULL="${ECR_REPO}:${IMAGE_TAG}"
EKS_CLUSTER="todo-tf-cluster"
KUBE_NS="todo"
K8S_DIR="${APP_DIR}/k8s"
SKIP_BUILD=false
PUSH_LATEST=false

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

log()     { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── Argument parsing ──────────────────────────────────────────────────────────
for arg in "$@"; do
  case $arg in
    --skip-build)  SKIP_BUILD=true ;;
    --latest-tag)  PUSH_LATEST=true ;;
    *) error "Unknown argument: $arg. Usage: ./ci/deploy.sh [--skip-build] [--latest-tag]" ;;
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
log "Push latest : ${PUSH_LATEST}"
echo ""

# =============================================================================
# STEP 1 — Preflight checks
# =============================================================================
log "Step 1/7 — Preflight checks..."

command -v docker  &>/dev/null || error "docker not found"
command -v aws     &>/dev/null || error "aws cli not found"
command -v kubectl &>/dev/null || error "kubectl not found"

for f in namespace.yaml deployment.yaml service.yaml ingress.yaml configmap.yaml secret.yaml; do
  [[ -f "${K8S_DIR}/${f}" ]] || error "Missing ${K8S_DIR}/${f}"
done

success "All preflight checks passed"
echo ""

# =============================================================================
# STEP 2 — Build Docker image
# =============================================================================
if [[ "$SKIP_BUILD" == "true" ]]; then
  warn "Step 2/7 — Skipping build (--skip-build)"
else
  log "Step 2/7 — Building Docker image..."

  docker build \
    --tag  "${IMAGE_FULL}" \
    --file "${APP_DIR}/docker/Dockerfile" \
    "${APP_DIR}"

  success "Image built: ${IMAGE_FULL}"
fi
echo ""

# =============================================================================
# STEP 3 — Push to ECR
# =============================================================================
if [[ "$SKIP_BUILD" == "true" ]]; then
  warn "Step 3/7 — Skipping ECR push (--skip-build)"
else
  log "Step 3/7 — Pushing image to ECR..."

  aws ecr get-login-password --region "${AWS_REGION}" \
    | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

  docker push "${IMAGE_FULL}"

  if [[ "$PUSH_LATEST" == "true" ]]; then
    docker tag "${IMAGE_FULL}" "${ECR_REPO}:latest"
    docker push "${ECR_REPO}:latest"
    success "Also pushed: ${ECR_REPO}:latest"
  fi

  success "Image pushed: ${IMAGE_FULL}"
fi
echo ""

# =============================================================================
# STEP 4 — Patch image tag in deployment.yaml
# =============================================================================
log "Step 4/7 — Patching image tag in ${K8S_DIR}/deployment.yaml..."

if [[ "$SKIP_BUILD" == "false" ]]; then
  sed -i "s|image: ${ECR_REPO}:.*|image: ${IMAGE_FULL}|g" "${K8S_DIR}/deployment.yaml"
  log "Image lines after patch:"
  grep "image:" "${K8S_DIR}/deployment.yaml" | sed 's/^/         /'
else
  warn "Skipping tag patch — using image already in deployment.yaml"
fi
echo ""

# =============================================================================
# STEP 5 — Connect kubectl to EKS
# =============================================================================
log "Step 5/7 — Syncing kubeconfig for cluster: ${EKS_CLUSTER}..."

aws eks update-kubeconfig --region "${AWS_REGION}" --name "${EKS_CLUSTER}"

kubectl cluster-info --request-timeout=10s &>/dev/null \
  || error "Cannot reach Kubernetes API. Check AWS credentials and cluster name."

success "kubectl connected to ${EKS_CLUSTER}"
echo ""

# =============================================================================
# STEP 6 — Apply manifests (dependency order)
# =============================================================================
log "Step 6/7 — Applying Kubernetes manifests..."

kubectl apply -f "${K8S_DIR}/namespace.yaml"
kubectl apply -f "${K8S_DIR}/configmap.yaml"      -n "${KUBE_NS}"
kubectl apply -f "${K8S_DIR}/secret.yaml"          -n "${KUBE_NS}"
kubectl apply -f "${K8S_DIR}/deployment.yaml"      -n "${KUBE_NS}"
kubectl apply -f "${K8S_DIR}/service.yaml"         -n "${KUBE_NS}"
kubectl apply -f "${K8S_DIR}/ingress.yaml"         -n "${KUBE_NS}"
kubectl apply -f "${K8S_DIR}/hpa.yaml"             -n "${KUBE_NS}"
kubectl apply -f "${K8S_DIR}/pdb.yaml"             -n "${KUBE_NS}"
kubectl apply -f "${K8S_DIR}/networkpolicy.yaml"   -n "${KUBE_NS}"

success "All manifests applied"
echo ""

# =============================================================================
# STEP 7 — Wait for rollout (with auto-rollback on failure)
# =============================================================================
log "Step 7/7 — Waiting for rollout completion..."

kubectl rollout status deployment/todo-frontend -n "${KUBE_NS}" --timeout=180s \
  || { kubectl rollout undo deployment/todo-frontend -n "${KUBE_NS}"; \
       error "Frontend rollout failed — rolled back. Run: kubectl describe deployment/todo-frontend -n ${KUBE_NS}"; }

kubectl rollout status deployment/todo-backend -n "${KUBE_NS}" --timeout=180s \
  || { kubectl rollout undo deployment/todo-backend -n "${KUBE_NS}"; \
       error "Backend rollout failed — rolled back. Run: kubectl describe deployment/todo-backend -n ${KUBE_NS}"; }

echo ""

# =============================================================================
# Summary
# =============================================================================
echo -e "${GREEN}=================================================${NC}"
echo -e "${GREEN}   Deployment complete!                         ${NC}"
echo -e "${GREEN}=================================================${NC}"
echo ""

log "Running pods:"
kubectl get pods -n "${KUBE_NS}" -l 'app in (todo-app-frontend,todo-app-backend)'
echo ""

log "Services:"
kubectl get svc -n "${KUBE_NS}" todo-frontend-svc todo-backend-svc
echo ""

log "Ingress:"
kubectl get ingress todo-ingress -n "${KUBE_NS}"
echo ""

ALB_HOST=$(kubectl get ingress todo-ingress -n "${KUBE_NS}" \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)

if [[ -n "$ALB_HOST" ]]; then
  success "App is live at: https://www.ankit.services"
else
  warn "ALB not provisioned yet. Re-check in ~60s: kubectl get ingress todo-ingress"
fi

echo ""
