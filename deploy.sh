#!/usr/bin/env bash
#
# Robust RunPod launcher with verbose polling            2025-06-09
#
set -euo pipefail

# ───── CONFIG ───────────────────────────────────────────────────────
: "${RUNPOD_API_KEY:?export RUNPOD_API_KEY=<your token>}"

IMAGE="ghcr.io/izzyisnt/surfdock-dev:latest"
POD_NAME="${POD_NAME:-dev-test}"
GPU="${GPU_TYPE:-NVIDIA GeForce RTX 3090}"

# ─── timing & back-off ──────────────────────────────────────────────
INITIAL_PAUSE=20    # give CP 20s to register the pod
POLL_DELAY=5
MAX_DELAY=60
TIMEOUT_MIN=${TIMEOUT_MIN:-10}
MAX_TRIES=$(( (TIMEOUT_MIN*60 - INITIAL_PAUSE) / POLL_DELAY ))

# ───── LOGGING (portable) ───────────────────────────────────────────
log()   { printf '%s %s\n' "$(date +%H:%M:%S)" "$*"; }
debug() { [[ "${DEBUG:-0}" == 0 ]] || log "$*"; }

# ───── CREATE POD ───────────────────────────────────────────────────
log "🚀 runpodctl create pod (image=$IMAGE gpu=\"$GPU\" ports=2222/tcp)"
CREATE_OUT=$(runpodctl create pod \
             --name "$POD_NAME" \
             --imageName "$IMAGE" \
             --gpuType "$GPU" \
             --ports "2222/tcp")

log "$CREATE_OUT"
POD_ID=$(awk -F'"' '/^pod "/{print $2}' <<<"$CREATE_OUT" | tr -d '[:space:]')
[[ -n "$POD_ID" ]] || { log "❌ Could not parse pod id"; exit 1; }

log "📦 Pod id: $POD_ID  –  sleeping ${INITIAL_PAUSE}s for propagation"
sleep "$INITIAL_PAUSE"

# ───── POLL LOOP ────────────────────────────────────────────────────
tries=0
sleep_time=$POLL_DELAY

while (( tries < MAX_TRIES )); do
  RAW=$(curl -s -w '\n%{http_code}' \
            -H "Authorization: Bearer ${RUNPOD_API_KEY}" \
            "https://rest.runpod.io/v1/pods/${POD_ID}")
  CODE=${RAW##*$'\n'}     # last line
  BODY=${RAW%$'\n'*}      # everything before last newline

  debug "curl → HTTP $CODE  data=$(jq -c '{desiredStatus,publicIp,portMappings}' <<<"$BODY" 2>/dev/null)"

  if [[ $CODE == 200 ]]; then
      state=$(jq -r '.desiredStatus' <<<"$BODY")
      ip=$(jq -r '.publicIp // empty' <<<"$BODY")
      ports=$(jq -c '.portMappings // {}' <<<"$BODY")

      log "🔍 state=$state  ip=${ip:-<none>}  ports=$ports"

      if [[ $state == "RUNNING" && -n $ip ]]; then
          ssh_port=$(jq -r '."2222" // empty' <<<"$ports")
          log "✅ Ready – SSH: ssh root@${ip}${ssh_port:+ -p $ssh_port}"
          exit 0
      fi

      [[ $state =~ ^(FAILED|EXITED|STOPPED)$ ]] && { log "❌ Pod state $state – aborting"; exit 2; }

  elif [[ $CODE == 404 ]]; then
      log "⚠️  API still says 404 (pod not found yet)"
  else
      log "❌ Unexpected HTTP $CODE – aborting"
      exit 3
  fi

  (( tries++ ))
  log "⏳ [$tries/$MAX_TRIES] sleeping ${sleep_time}s"
  sleep "$sleep_time"
  (( sleep_time = sleep_time < MAX_DELAY ? sleep_time*2 : MAX_DELAY ))
done

# ───── TIME-OUT HANDLING ────────────────────────────────────────────
log "🛑 Timed out after $TIMEOUT_MIN min – dumping last known server view:"
curl -s -H "Authorization: Bearer ${RUNPOD_API_KEY}" \
     https://rest.runpod.io/v1/pods \
  | jq -c --arg PID "$POD_ID" '.[]? | select(.id==$PID)'

exit 4
