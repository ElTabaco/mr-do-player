#!/bin/bash
# Idempotent apply via Kustomize. Run from this directory.
# The ArgoCD Application at application.yaml keeps the cluster in sync automatically;
# this script is for one-off / out-of-band recovery.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Pre-create the namespace (kustomization does not manage namespaces anymore)
kubectl create namespace mr-do-player --dry-run=client -o yaml | kubectl apply -f -

# Apply every resource in this directory via Kustomize
kubectl apply -k .

# --- Status checks (informational, non-fatal) ---
kubectl describe pod -n mr-do-player -l app.kubernetes.io/name=mr-do-player || true

kubectl get pods -n mr-do-player -o wide || true
kubectl get services -n mr-do-player -o wide || true
kubectl get pv,pvc -A | grep mr-do-player || true
kubectl get configmap -n mr-do-player -o wide || true
