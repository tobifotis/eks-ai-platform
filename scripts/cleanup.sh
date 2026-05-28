#!/bin/bash
set -euo pipefail

# ============================================================
# eks-ai-platform cleanup script
# Tears down everything to stop AWS charges
# ============================================================

echo "============================================"
echo "  eks-ai-platform: Cleanup"
echo "============================================"
echo ""
echo "WARNING: This will delete the entire EKS cluster and all data."
read -p "Are you sure? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Cancelled."
  exit 0
fi

echo ""
echo "[1/4] Uninstalling Helm releases..."
helm uninstall open-webui --namespace open-webui 2>/dev/null || true
helm uninstall headlamp --namespace kube-system 2>/dev/null || true

echo ""
echo "[2/4] Deleting namespace..."
kubectl delete namespace open-webui 2>/dev/null || true

echo ""
echo "[3/4] Cleaning up RBAC resources..."
kubectl delete -f k8s/headlamp-rbac.yaml 2>/dev/null || true

echo ""
echo "[4/4] Deleting EKS cluster (this takes ~10 minutes)..."
eksctl delete cluster --name ai-platform-cluster --region us-east-1

echo ""
echo "============================================"
echo "  Cleanup complete. All AWS resources removed."
echo "============================================"