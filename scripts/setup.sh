#!/bin/bash
set -euo pipefail

# ============================================================
# eks-ai-platform setup script
# Creates EKS cluster, deploys Open WebUI + Headlamp
# ============================================================

echo "============================================"
echo "  eks-ai-platform: Setup"
echo "============================================"

# --- Check prerequisites ---
echo ""
echo "[1/8] Checking prerequisites..."
command -v aws >/dev/null 2>&1 || { echo "ERROR: aws CLI not found"; exit 1; }
command -v eksctl >/dev/null 2>&1 || { echo "ERROR: eksctl not found"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl not found"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "ERROR: helm not found"; exit 1; }
echo "All tools found."

# --- Create EKS cluster ---
echo ""
echo "[2/8] Creating EKS cluster (this takes ~15-20 minutes)..."
eksctl create cluster -f cluster.yaml

# --- Apply StorageClass ---
echo ""
echo "[3/8] Creating gp3 StorageClass..."
kubectl apply -f k8s/storage-class.yaml

# --- Create namespace + secret ---
echo ""
echo "[4/8] Creating open-webui namespace and API secret..."
kubectl create namespace open-webui
kubectl create secret generic anthropic-api-key \
  --namespace open-webui \
  --from-literal=api-key="placeholder"

echo ""
echo "NOTE: The Anthropic API key must be entered manually in the"
echo "Open WebUI admin panel after deployment."
echo "(Admin Settings > Connections > gear icon > paste key)"
echo ""

# --- Add Helm repos ---
echo ""
echo "[5/8] Adding Helm repositories..."
helm repo add open-webui https://open-webui.github.io/helm-charts
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
helm repo update

# --- Deploy Open WebUI ---
echo ""
echo "[6/8] Deploying Open WebUI..."
helm install open-webui open-webui/open-webui \
  --namespace open-webui \
  --values helm-values/open-webui-values.yaml

# --- Apply RBAC + Deploy Headlamp ---
echo ""
echo "[7/8] Deploying Headlamp..."
kubectl apply -f k8s/headlamp-rbac.yaml
helm install headlamp headlamp/headlamp \
  --namespace kube-system \
  --values helm-values/headlamp-values.yaml

# --- Wait for pods ---
echo ""
echo "[8/8] Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=open-webui \
  -n open-webui --timeout=120s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=headlamp \
  -n kube-system --timeout=120s

# --- Done ---
echo ""
echo "============================================"
echo "  Setup complete!"
echo "============================================"
echo ""
echo "Open WebUI:  kubectl port-forward svc/open-webui -n open-webui 3000:80"
echo "             Then open http://localhost:3000"
echo ""
echo "Headlamp:    kubectl port-forward svc/headlamp -n kube-system 8080:80"
echo "             Then open http://localhost:8080"
echo ""
echo "Headlamp token:"
kubectl get secret headlamp-admin-token \
  -n kube-system \
  -o jsonpath='{.data.token}' | base64 -d
echo ""
echo ""
echo "IMPORTANT: Enter your Anthropic API key in Open WebUI"
echo "Admin Settings > Connections > gear icon > paste key"
echo ""