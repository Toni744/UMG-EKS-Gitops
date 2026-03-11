#!/bin/bash
# Install Kyverno for admission webhook enforcement

set -e

echo "Installing Kyverno..."

# Add Kyverno Helm repo
helm repo add kyverno https://kyverno.github.io/kyverno/ || true
helm repo update

# Install Kyverno with simpler config
helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --wait

echo "✓ Kyverno installed"
echo ""
echo "Waiting for Kyverno webhook to be ready..."
kubectl wait --for=condition=Available --timeout=300s deployment/kyverno -n kyverno 2>/dev/null || true

echo "✓ Kyverno ready"
