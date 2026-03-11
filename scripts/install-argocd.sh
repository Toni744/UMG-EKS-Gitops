#!/bin/bash
# Install Helm and ArgoCD on EKS cluster

set -e

echo "Installing Helm..."

# Check if Helm is already installed
if ! command -v helm &> /dev/null; then
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  echo "✓ Helm installed"
else
  echo "✓ Helm already installed"
fi

echo ""
echo "Installing ArgoCD..."

# Create ArgoCD namespace
kubectl create namespace argocd || true

# Add Argo Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install ArgoCD
helm install argocd argo/argo-cd \
  --namespace argocd \
  --set 'configs.params."server\.insecure"=true' \
  --set server.service.type=LoadBalancer \
  --wait

echo "✓ ArgoCD installed"
echo ""

# Get ArgoCD admin password
echo "ArgoCD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""

# Get ArgoCD server URL
echo "ArgoCD server URL:"
kubectl -n argocd get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo ""
echo ""

# Apply RBAC to restrict deployments to ArgoCD only
echo "Applying ArgoCD RBAC (only argocd-application-controller can deploy)..."
kubectl apply -f deploy/argocd/rbac.yaml

# Create ArgoCD Application
echo "Creating ArgoCD Application..."
kubectl apply -f deploy/argocd/application.yaml

echo "✓ ArgoCD setup complete"
echo ""
echo "Next steps:"
echo "1. Update deploy/argocd/application.yaml if your repo URL is different"
echo "2. Access ArgoCD at: kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "3. Login: admin / (password shown above)"
