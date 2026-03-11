#!/bin/bash
# Install Helm, Kyverno, and ArgoCD on EKS cluster

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
echo "Installing Kyverno (admission webhook engine)..."

# Add Kyverno Helm repo
helm repo add kyverno https://kyverno.github.io/kyverno/ || true
helm repo update

# Install Kyverno
helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --wait || true

echo "✓ Kyverno installed"
echo "Waiting for Kyverno webhook to be ready..."
kubectl wait --for=condition=Available --timeout=300s deployment/kyverno -n kyverno 2>/dev/null || true

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
  --wait || true

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

# Apply Kyverno policy to enforce webhook blocking
echo "Applying Kyverno admission webhook policy..."
echo "  (blocks all non-ArgoCD deployments)"
kubectl apply -f deploy/argocd/kyverno-policy.yaml

echo ""
echo "✓ ArgoCD + Kyverno setup complete"
echo ""
echo "Next steps:"
echo "1. Update deploy/argocd/application.yaml if your repo URL is different"
echo "2. Access ArgoCD at: kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "3. Login: admin / (password shown above)"
echo ""
echo "RBAC + Webhook Enforcement:"
echo "  - Direct 'kubectl apply' will be BLOCKED by Kyverno webhook"
echo "  - Only ArgoCD can deploy (via git push to main branch)"
echo ""
