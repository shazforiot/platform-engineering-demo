#!/usr/bin/env bash
# =============================================================
# Full IDP Demo Setup Script
# Platform Engineering with K8s — YouTube Demo
# =============================================================
# Usage: GITHUB_TOKEN=ghp_xxx ./demo/setup.sh
# =============================================================
set -euo pipefail

# Colors
GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[INFO]${NC}  $1"; }
log_success() { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  Platform Engineering IDP — Full Demo Setup          ║"
echo "║  Backstage + ArgoCD + Kind + K8s                     ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# ─── CHECK PREREQUISITES ──────────────────────────────────────
log_info "Checking prerequisites..."

command -v docker >/dev/null 2>&1 || log_error "Docker not found. Install Docker Desktop."
command -v kubectl >/dev/null 2>&1 || log_error "kubectl not found. See README for install instructions."
command -v kind >/dev/null 2>&1 || log_error "kind not found. Run: go install sigs.k8s.io/kind@latest"
command -v node >/dev/null 2>&1 || log_error "Node.js not found. Install Node.js 20+."
command -v yarn >/dev/null 2>&1 || log_warn "yarn not found. Install with: npm install -g yarn"
command -v argocd >/dev/null 2>&1 || log_warn "argocd CLI not found (optional for setup)"

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  log_error "GITHUB_TOKEN environment variable not set.\nExport it first: export GITHUB_TOKEN=ghp_your_token"
fi

log_success "All prerequisites found!"

# ─── STEP 1: CREATE KIND CLUSTER ──────────────────────────────
log_info "Step 1/4: Creating Kind cluster 'idp-cluster'..."

if kind get clusters | grep -q "idp-cluster"; then
  log_warn "Cluster 'idp-cluster' already exists. Skipping creation."
else
  kind create cluster --config "${SCRIPT_DIR}/kind-cluster/cluster-config.yaml"
  log_success "Kind cluster created!"
fi

kubectl config use-context kind-idp-cluster
log_success "Kubernetes context set to kind-idp-cluster"

# ─── STEP 2: INSTALL ARGOCD ───────────────────────────────────
log_info "Step 2/4: Installing ArgoCD..."

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

log_info "Waiting for ArgoCD server (this takes 2-3 minutes)..."
kubectl wait --for=condition=Available deployment/argocd-server \
  -n argocd --timeout=300s

kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "NodePort", "ports": [{"name":"https","port":443,"targetPort":8080,"nodePort":30081}]}}' \
  2>/dev/null || true

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

log_success "ArgoCD installed! UI: http://localhost:8080 | admin / ${ARGOCD_PASSWORD}"

# ─── STEP 3: CREATE IDP ARGOCD PROJECT ────────────────────────
log_info "Step 3/4: Setting up ArgoCD IDP project..."
kubectl apply -f "${SCRIPT_DIR}/argocd/idp-project.yaml" || true
log_success "ArgoCD IDP project configured!"

# ─── STEP 4: SCAFFOLD BACKSTAGE ───────────────────────────────
log_info "Step 4/4: Scaffolding Backstage..."

BACKSTAGE_DIR="${HOME}/my-idp"
if [[ -d "${BACKSTAGE_DIR}" ]]; then
  log_warn "Backstage directory already exists at ${BACKSTAGE_DIR}. Skipping scaffolding."
else
  npx @backstage/create-app@latest --name my-idp --path "${BACKSTAGE_DIR}"
fi

# Copy custom app-config
cp "${SCRIPT_DIR}/backstage/app-config.yaml" "${BACKSTAGE_DIR}/app-config.yaml"
log_success "Backstage scaffolded at ${BACKSTAGE_DIR}"

# ─── SUMMARY ──────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  ✅ Setup Complete!                                   ║"
echo "╠══════════════════════════════════════════════════════╣"
echo -e "║  ArgoCD UI:   ${BLUE}http://localhost:8080${NC}              ║"
echo -e "║  Username:    ${GREEN}admin${NC}                              ║"
echo -e "║  Password:    ${GREEN}${ARGOCD_PASSWORD}${NC}                       ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  Next: Start Backstage with:                         ║"
echo -e "║  ${YELLOW}cd ~/my-idp && yarn dev${NC}                          ║"
echo "╠══════════════════════════════════════════════════════╣"
echo -e "║  Backstage:   ${BLUE}http://localhost:3000${NC}              ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
