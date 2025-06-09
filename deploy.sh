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

echo "⏳ Waiting for pod to get a public IP…"
while true; do
  IP=$(runpodctl get pod -a | jq -r \
    ".[] | select(.name==\"$POD_NAME\" and .status==\"RUNNING\") | .publicIp")
  if [[ -n "$IP" && "$IP" != "null" ]]; then
    echo "✅ Public IP: $IP"
    break
  fi
  echo "…retrying in ${WAIT_SEC}s"
  sleep "$WAIT_SEC"
done

POD_ID=$(runpodctl get pod -o json | jq -r \
  ".[] | select(.name==\"$POD_NAME\" and .status==\"RUNNING\") | .id")

SSH_ADDR=$(runpodctl get pod "$POD_ID" -o json | jq -r '
  .portMappings[] | select(.containerPort==22 and .type=="Public") | "\(.ip):\(.hostPort)"')

echo "📡 SSH endpoint: $SSH_ADDR"

echo "⏳ Waiting for SSH port to open…"
while ! nc -z "${SSH_ADDR%%:*}" "${SSH_ADDR##*:}" 2>/dev/null; do
  echo "…waiting on $SSH_ADDR"
  sleep "$WAIT_SEC"
done

SSH_CMD="ssh -i ~/.ssh/id_ed25519 root@${SSH_ADDR%%:*} -p ${SSH_ADDR##*:}"
echo "🔐 SSH into pod: $SSH_CMD"

# macOS: copy to clipboard
if command -v pbcopy &>/dev/null; then
  echo "$SSH_CMD" | pbcopy
 echo "📋 SSH command copied to clipboard."
fi

