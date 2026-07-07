#!/bin/bash
# Delete in reverse order. Run from this directory.
# Requires typed confirmation to prevent accidental removal.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

read -r -p "Delete the entire mr-do-player deployment (namespace + PV)? Type 'yes' to confirm: " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted."
    exit 1
fi

# Delete every resource in this directory via Kustomize
kubectl delete -k .

# Force the namespace cleanup if anything remained
kubectl delete namespace mr-do-player --ignore-not-found
