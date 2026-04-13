#!/usr/bin/env bash
# verify-deploy.sh — Post-deploy verification + structured feedback
# Usage: verify-deploy.sh <composeId> <port> [expected_http_code] [app_name]
# Output: JSON to stdout, logs to stderr
# Exit: 0=SUCCESS, 1=FAILED, 2=TIMEOUT

set -euo pipefail

COMPOSE_ID="${1:?composeId required}"
PORT="${2:?port required}"
EXPECTED_CODE="${3:-200}"
APP_NAME="${4:-unknown}"

DOKPLOY_KEY=$(python3 -c "import json; d=json.load(open('~/.claude.json')); print(d['mcpServers']['DokployServer']['env']['DOKPLOY_API_KEY'])")
DOKPLOY_URL="http://localhost:3000"
MAX_WAIT=300   # 5 dakika
POLL_INTERVAL=10
EA_URL="http://localhost:8085"
EA_KEY="e396e5e3618c536878402fe7bc3640318479a09c364762c9d2c46d6054b7dae7"
WA_NUMBER="<YOUR_WA_NUMBER>@s.whatsapp.net"
EA_INSTANCE="t4f"

log() { echo "[$(date '+%H:%M:%S')] $*" >&2; }

# --- 1. Poll compose status until done/error ---
log "Polling compose $COMPOSE_ID (max ${MAX_WAIT}s)..."
elapsed=0
compose_status=""
while [ $elapsed -lt $MAX_WAIT ]; do
  resp=$(curl -s "${DOKPLOY_URL}/api/trpc/compose.one?input=%7B%22json%22%3A%7B%22composeId%22%3A%22${COMPOSE_ID}%22%7D%7D" \
    -H "x-api-key: $DOKPLOY_KEY" 2>/dev/null || echo '{}')
  compose_status=$(echo "$resp" | python3 -c "
import sys,json
try:
  d=json.load(sys.stdin)
  print(d.get('result',{}).get('data',{}).get('json',{}).get('composeStatus','unknown'))
except: print('parse_error')
" 2>/dev/null)
  log "  status=$compose_status (${elapsed}s elapsed)"
  if [ "$compose_status" = "done" ] || [ "$compose_status" = "error" ]; then break; fi
  sleep $POLL_INTERVAL
  elapsed=$((elapsed + POLL_INTERVAL))
done

# --- 2. Timeout check ---
if [ $elapsed -ge $MAX_WAIT ] && [ "$compose_status" != "done" ] && [ "$compose_status" != "error" ]; then
  result=$(python3 -c "import json; print(json.dumps({'status':'TIMEOUT','composeStatus':'$compose_status','composeId':'$COMPOSE_ID','port':$PORT,'app':'$APP_NAME','elapsed':$elapsed}))")
  echo "$result"
  exit 2
fi

# --- 3. On error: fetch last deployment log snippet ---
if [ "$compose_status" = "error" ]; then
  log "Deploy FAILED. Fetching last deployment log..."
  deployments=$(curl -s "${DOKPLOY_URL}/api/trpc/deployment.allByCompose?input=%7B%22json%22%3A%7B%22composeId%22%3A%22${COMPOSE_ID}%22%7D%7D" \
    -H "x-api-key: $DOKPLOY_KEY" 2>/dev/null || echo '{}')
  log_path=$(echo "$deployments" | python3 -c "
import sys,json
try:
  d=json.load(sys.stdin)
  deploys=d.get('result',{}).get('data',{}).get('json',[])
  last=[x for x in deploys if x.get('status')=='error']
  print(last[-1].get('logPath','') if last else '')
except: print('')
" 2>/dev/null)
  error_snippet=""
  if [ -n "$log_path" ] && [ -f "$log_path" ]; then
    error_snippet=$(tail -20 "$log_path" 2>/dev/null | tr '\n' '|' | head -c 500)
  fi

  # Known error patterns → auto-remediation hints
  remediation="check compose file and docker logs"
  if echo "$error_snippet" | grep -qi "not found\|no such image\|pull access"; then
    remediation="image not found — check image name/tag and registry access"
  elif echo "$error_snippet" | grep -qi "port is already allocated\|address already in use"; then
    remediation="port conflict — change host port in compose file"
  elif echo "$error_snippet" | grep -qi "network.*not found\|no such network"; then
    remediation="external network not found — verify network name with: docker network ls"
  elif echo "$error_snippet" | grep -qi "permission denied\|EACCES"; then
    remediation="permission denied — check volume paths and user permissions"
  fi

  result=$(python3 -c "
import json
print(json.dumps({
  'status': 'FAILED',
  'composeStatus': 'error',
  'composeId': '$COMPOSE_ID',
  'port': $PORT,
  'app': '$APP_NAME',
  'logPath': '$(echo $log_path | tr "'" "\"" )',
  'errorSnippet': '$(echo $error_snippet | head -c 300 | tr "'" "\"" | tr '\n' ' ')',
  'remediation': '$remediation'
}))
")
  echo "$result"

  # WA notification on failure
  wa_msg="Dokploy DEPLOY FAILED\nApp: $APP_NAME\nCompose: $COMPOSE_ID\nPort: $PORT\nFix: $remediation"
  curl -s -X POST "${EA_URL}/message/sendText/${EA_INSTANCE}" \
    -H "apikey: $EA_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"number\":\"$WA_NUMBER\",\"text\":\"$wa_msg\"}" >/dev/null 2>&1 || true

  exit 1
fi

# --- 4. HTTP health check ---
log "Compose done. HTTP health check on port $PORT (expecting $EXPECTED_CODE)..."
sleep 3
http_code=$(curl -s -o /dev/null -w "%{http_code}" -m 10 "http://localhost:$PORT" 2>/dev/null || echo "000")
log "  HTTP response: $http_code (expected: $EXPECTED_CODE)"

# Container running check
container_up=$(docker ps --format '{{.Names}}\t{{.Status}}' 2>/dev/null | grep -i "$(echo $APP_NAME | tr '-' '.')" | head -1 || echo "")

if [ "$http_code" = "$EXPECTED_CODE" ] || [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
  result=$(python3 -c "
import json
print(json.dumps({
  'status': 'SUCCESS',
  'composeStatus': 'done',
  'composeId': '$COMPOSE_ID',
  'port': $PORT,
  'httpCode': $http_code,
  'app': '$APP_NAME',
  'accessUrl': 'http://localhost:$PORT',
  'containerInfo': '$(echo $container_up | head -c 100)'
}))
")
  echo "$result"

  # WA notification on success
  wa_msg="Dokploy DEPLOY OK\nApp: $APP_NAME\nURL: http://localhost:$PORT\nHTTP: $http_code"
  curl -s -X POST "${EA_URL}/message/sendText/${EA_INSTANCE}" \
    -H "apikey: $EA_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"number\":\"$WA_NUMBER\",\"text\":\"$wa_msg\"}" >/dev/null 2>&1 || true

  exit 0
else
  result=$(python3 -c "
import json
print(json.dumps({
  'status': 'FAILED',
  'composeStatus': 'done',
  'composeId': '$COMPOSE_ID',
  'port': $PORT,
  'httpCode': $http_code,
  'expectedCode': $EXPECTED_CODE,
  'app': '$APP_NAME',
  'remediation': 'Container started but HTTP not responding — check app startup logs'
}))
")
  echo "$result"
  exit 1
fi
