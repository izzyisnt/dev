#!/usr/bin/env bash
set -euo pipefail

IMAGE="ghcr.io/izzyisnt/surfdock-dev:latest"
POD_NAME="${POD_NAME:-dev-test}"
GPU="${GPU_TYPE:-NVIDIA GeForce RTX 3090}"
WAIT_SEC=5

echo "🚀 Creating pod ${POD_NAME}…"
runpodctl create pod \
  --name "$POD_NAME" \
  --imageName "$IMAGE" \
  --gpuType "$GPU" \
  --ports 22/tcp \
  --cost 0.30  # or whatever max $/hr you're okay with


echo "⏳ Waiting for pod to be assigned a public IP…"
while true; do
  POD_JSON=$(runpodctl get pod -a | grep -o '{.*}' || true)
  IP=$(echo "$POD_JSON" | jq -r \
    "select(.name==\"$POD_NAME\" and .status==\"RUNNING\") | .publicIp")
  if [[ -n "$IP" && "$IP" != "null" ]]; then
    echo "✅ Public IP: $IP"
    break
  fi
  echo "…retrying in ${WAIT_SEC}s"
  sleep "$WAIT_SEC"
done

POD_ID=$(echo "$POD_JSON" | jq -r \
  "select(.name==\"$POD_NAME\" and .status==\"RUNNING\") | .id")

POD_DETAIL=$(runpodctl get pod "$POD_ID" | grep -o '{.*}')
SSH_ADDR=$(echo "$POD_DETAIL" | jq -r '
  .portMappings[] | select(.containerPort==22 and .type=="Public") | "\(.ip):\(.hostPort)"')

echo "📡 SSH endpoint: $SSH_ADDR"

echo "⏳ Waiting for SSH port to open…"
while ! nc -z "${SSH_ADDR%%:*}" "${SSH_ADDR##*:}" 2>/dev/null; do
  echo "…waiting on $SSH_ADDR"
  sleep "$WAIT_SEC"
done

SSH_CMD="ssh -i ~/.ssh/id_ed25519 root@${SSH_ADDR%%:*} -p ${SSH_ADDR##*:}"
echo "🔐 SSH into pod: $SSH_CMD"

if command -v pbcopy &>/dev/null; then
  echo "$SSH_CMD" | pbcopy
  echo "📋 SSH command copied to clipboard."
fi
