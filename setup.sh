#!/usr/bin/env bash
set -euo pipefail

# Build & tag locally
docker build \
  --build-arg PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)" \
  -t izzyisnt/dev:local \
  .

# Tag for GHCR
docker tag izzyisnt/dev:local ghcr.io/izzyisnt/dev:latest

echo "▶ Smoke-testing local image…"
docker run --rm izzyisnt/dev:local python - <<'PY'
import torch, sys; from rdkit import Chem
assert torch.cuda.is_available(), "CUDA disabled"
assert Chem.MolFromSmiles("CCO")
print("✓ Torch & RDKit OK")
PY

echo "✅ Local image ready: izzyisnt/dev:local"
