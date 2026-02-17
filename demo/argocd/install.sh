#!/usr/bin/env bash
# =============================================================
# ArgoCD Installation Script for IDP Demo
# =============================================================
set -euo pipefail

ARGOCD_NAMESPACE="argocd"
ARGOCD_VERSION="v2.10.0"

echo "🔄 Installing ArgoCD ${ARGOCD_VERSION}..."

# Create namespace
kubectl create namespace "${ARGOCD_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
kubectl apply -n "${ARGOCD_NAMESPACE}" \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo "⏳ Waiting for ArgoCD server to be ready (up to 5 minutes)..."
kubectl wait --for=condition=Available \
  deployment/argocd-server \
  -n "${ARGOCD_NAMESPACE}" \
  --timeout=300s

# Expose ArgoCD via NodePort
echo "🌐 Exposing ArgoCD UI on port 8080..."
kubectl patch svc argocd-server -n "${ARGOCD_NAMESPACE}" \
  -p '{"spec": {"type": "NodePort", "ports": [{"name":"https","port":443,"targetPort":8080,"nodePort":30081}]}}'

# Get initial admin password
echo ""
echo "✅ ArgoCD is ready!"
echo ""
echo "📋 Admin credentials:"
echo "   URL:      http://localhost:8080"
echo "   Username: admin"
echo -n "   Password: "
kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo "💡 Login with: argocd login localhost:8080 --insecure --username admin"
