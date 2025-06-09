#!/usr/bin/env bash
set -euo pipefail

IMAGE="ghcr.io/izzyisnt/dev:latest"
POD_NAME="${POD_NAME:-dev-test}"
GPU="${GPU_TYPE:-NVIDIA GeForce RTX 3090}"
WAIT_SEC=5

echo "🚀 Creating pod ${POD_NAME}…"
runpodctl create pod \
  --name "$POD_NAME" \
  --imageName "$IMAGE" \
  --gpuType "$GPU" \
  --ports 22/tcp

echo "⏳ Waiting for public IP…"
while true; do
  IP=$(runpodctl get pod -a -o json | jq -r '.[] | select(.status=="RUNNING") | .publicIp')
  if [[ -n "$IP" ]]; then
    echo "✅ Public IP: $IP"
    break
  fi
  echo "…retrying in $WAIT_SEC s"
  sleep $WAIT_SEC
done

echo "🔐 SSH into pod: ssh -i ~/.ssh/id_ed25519 root@$IP"
