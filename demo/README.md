# Platform Engineering with K8s — Demo Project
## Build an Internal Developer Platform from Scratch

> **Video:** [Platform Engineering with K8s — Build an Internal Developer Platform (2026)](https://youtube.com)

---

## What This Demo Builds

```
Developer opens Backstage
       ↓
Creates service from template
       ↓
GitHub repo auto-created (with app code + K8s manifests)
       ↓
ArgoCD auto-syncs repo → deploys to Kubernetes
       ↓
Service live in <5 minutes — zero YAML written by developer
```

**Stack:**
| Component | Tool | Purpose |
|-----------|------|---------|
| Cluster | Kind | Local Kubernetes |
| Dev Portal | Backstage | Service catalog + templates |
| GitOps | ArgoCD | Continuous deployment |
| App | Node.js | Demo microservice |

---

## Prerequisites

Install these tools before starting:

```bash
# Docker Desktop
# https://www.docker.com/products/docker-desktop/

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Kind
go install sigs.k8s.io/kind@v0.22.0
# or: brew install kind  (macOS)
#Linx Installation
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Node.js 20+
# https://nodejs.org  (use nvm recommended)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
nvm install 20 && nvm use 20

# ArgoCD CLI
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd-linux-amd64 && sudo mv argocd-linux-amd64 /usr/local/bin/argocd
```

**Minimum Resources:** 8GB RAM, 4 CPU cores, 20GB disk

---

## Quick Start (Automated)

```bash
# Clone the demo repo
git clone https://github.com/YOUR_ORG/platform-engineering-demo
cd platform-engineering-demo/demo

# Set your GitHub token
export GITHUB_TOKEN=ghp_your_token_here


# Run the full setup (takes ~5-8 minutes)
chmod +x setup.sh
./setup.sh
```

---

## Manual Step-by-Step

### Step 1 — Create Kind Cluster

```bash
kind create cluster --config kind-cluster/cluster-config.yaml
kubectl cluster-info --context kind-idp-cluster
kubectl get nodes
```

Expected output:
```
NAME                         STATUS   ROLES           AGE
idp-cluster-control-plane    Ready    control-plane   45s
```

---

### Step 2 — Install ArgoCD

```bash
# Run the install script
bash argocd/install.sh

# Or manually:
kubectl create namespace argocd
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side
# Wait for deployment
kubectl wait --for=condition=Available deployment/argocd-server \
  -n argocd --timeout=300s

# Expose UI
kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "NodePort", "ports": [{"port":443,"nodePort":30081}]}}'

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo


# Login
argocd login localhost:8080 --insecure --username admin --password <PASSWORD>

```

Open ArgoCD UI: **http://localhost:8080**

---

### Step 3 — Scaffold & Start Backstage

```bash
# Create a new Backstage app

rm -rf ~/.npm/_npx  #Clear Cache
# Install dependencies
  npm install -g yarn@1.22.22
  yarn --version
npx @backstage/create-app@latest --name my-idp
npx @backstage/create-app
cd my-idp
rm -rf my-idp # remove the app


# Copy our custom app-config
cp ../backstage/app-config.yaml ./app-config.yaml

# Start Backstage
export GITHUB_TOKEN=ghp_your_token_here
yarn dev
```

Open Backstage: **http://localhost:3000**

---

### Step 4 — Register the Service Template

1. Open Backstage at http://localhost:3000
2. Click **"Catalog"** in the left nav
3. Click **"Register Existing Component"**
4. Enter the template URL or file path to `backstage/template.yaml`
5. Click **"Analyze"** → **"Import"**

You should now see the **"Node.js Microservice"** template in Create → Software Templates.

---

### Step 5 — Create a Service via the IDP

1. In Backstage, click **"Create"** (top nav)
2. Select **"Node.js Microservice"**
3. Fill in the form:
   - **Service Name:** `payment-service`
   - **Description:** `Handles payment processing`
   - **Owner:** `platform-team`
   - **Repository:** `github.com?owner=YOUR_ORG&repo=payment-service`
4. Click **"Review"** → **"Create"**

Watch the scaffolder logs. In ~60 seconds:
- ✅ GitHub repo created with full skeleton
- ✅ Service registered in Backstage catalog
- ✅ ArgoCD Application created and syncing

---

### Step 6 — Verify the Deployment

```bash
# Check pods are running
kubectl get pods -n payment-service

# Check service
kubectl get svc -n payment-service

# Hit the endpoint
curl http://localhost:8888
```

Expected response:
```json
{
  "service": "payment-service",
  "version": "1.0.0",
  "environment": "dev",
  "message": "Hello from payment-service! Deployed via IDP 🚀"
}
```

---

## Deploy the Demo App Manually (without template)

If you want to test the Kubernetes manifests directly:

```bash
# Build the image
cd app
docker build -t demo-microservice:latest .

# Load image into Kind cluster
kind load docker-image demo-microservice:latest --name idp-cluster

# Create namespace and deploy
kubectl create namespace demo-microservice
kubectl apply -f app/k8s/

# Check deployment
kubectl rollout status deployment/demo-microservice -n demo-microservice

# Test the service
curl http://localhost:8888
```

---

## Cleanup

```bash
# Delete the Kind cluster (removes everything)
kind delete cluster --name idp-cluster

# Or delete just the demo app
kubectl delete namespace demo-microservice
kubectl delete namespace payment-service
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `kind create cluster` fails | Ensure Docker Desktop is running |
| ArgoCD pod stuck in Pending | Check `kubectl describe pod -n argocd` for resource limits |
| Backstage fails to start | Verify `GITHUB_TOKEN` is set and valid |
| Template not showing | Check app-config.yaml `catalog.locations` path |
| Service not reachable on port 8888 | Confirm NodePort mapping in service.yaml matches cluster config |

---

## Project Structure

```
demo/
├── kind-cluster/
│   └── cluster-config.yaml    # Kind cluster with port mappings
├── argocd/
│   ├── install.sh             # ArgoCD installation script
│   └── idp-project.yaml       # ArgoCD project for IDP apps
├── backstage/
│   ├── app-config.yaml        # Backstage configuration
│   └── template.yaml          # Node.js microservice template
└── app/
    ├── index.js               # Demo Node.js application
    ├── Dockerfile             # Multi-stage production Dockerfile
    ├── package.json
    └── k8s/
        ├── deployment.yaml    # Kubernetes Deployment
        ├── service.yaml       # Kubernetes Service (NodePort)
        └── catalog-info.yaml  # Backstage catalog registration
```

---

## Next Steps

- Add **Crossplane** for self-service database provisioning
- Add **Vault + External Secrets Operator** for secret management
- Add **Prometheus + Grafana** stack for observability
- Set up **ArgoCD ApplicationSets** for multi-environment GitOps
- Add **OPA Gatekeeper** for policy enforcement

---

*Created for the YouTube video: "Build an Internal Developer Platform with K8s (2026)"*
