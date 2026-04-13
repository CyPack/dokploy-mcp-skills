#!/usr/bin/env bash
# monitor-all.sh — Periodic Dokploy service health monitor
# Cron: */5 * * * * /Users/ayazmutlu/.claude/skills/dokploy-manage/scripts/monitor-all.sh >> /tmp/dokploy-monitor.log 2>&1
# State file: /tmp/dokploy-monitor-state.json
# Detects status TRANSITIONS and sends WA notification on degradation

DOKPLOY_KEY=$(python3 -c "import json; d=json.load(open('~/.claude.json')); print(d['mcpServers']['DokployServer']['env']['DOKPLOY_API_KEY'])")
DOKPLOY_URL="http://localhost:3000"
STATE_FILE="/tmp/dokploy-monitor-state.json"
EA_URL="http://localhost:8085"
EA_KEY="e396e5e3618c536878402fe7bc3640318479a09c364762c9d2c46d6054b7dae7"
WA_NUMBER="<YOUR_WA_NUMBER>@s.whatsapp.net"
EA_INSTANCE="t4f"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# --- Load previous state ---
prev_state="{}"
[ -f "$STATE_FILE" ] && prev_state=$(cat "$STATE_FILE" 2>/dev/null || echo "{}")

# --- Fetch all projects + compose status ---
projects=$(curl -s "${DOKPLOY_URL}/api/trpc/project.all" \
  -H "x-api-key: $DOKPLOY_KEY" 2>/dev/null || echo '{}')

current_state=$(echo "$projects" | python3 -c "
import sys, json
try:
  d = json.load(sys.stdin)
  projects = d.get('result', {}).get('data', {}).get('json', [])
  state = {}
  for proj in projects:
    for env in proj.get('environments', []):
      for comp in env.get('compose', []):
        key = comp['composeId']
        state[key] = {
          'name': comp['name'],
          'project': proj['name'],
          'status': comp['composeStatus']
        }
  print(json.dumps(state))
except Exception as e:
  print('{}')
" 2>/dev/null)

log "Checked $(echo "$current_state" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null) compose services"

# --- Detect transitions ---
transitions=$(python3 -c "
import json

prev = json.loads('''$prev_state''')
curr = json.loads('''$current_state''')

alerts = []
for cid, info in curr.items():
  prev_status = prev.get(cid, {}).get('status', 'unknown')
  curr_status = info['status']
  name = info['name']
  project = info['project']

  # Degradation: done/running → error
  if curr_status == 'error' and prev_status in ('done', 'running', 'unknown'):
    alerts.append(f'ERROR: {project}/{name} ({cid}) {prev_status}→error')
  # Recovery: error → done
  elif curr_status == 'done' and prev_status == 'error':
    alerts.append(f'RECOVERED: {project}/{name} ({cid}) error→done')

for a in alerts:
  print(a)
" 2>/dev/null)

# --- Send WA notifications for transitions ---
if [ -n "$transitions" ]; then
  log "Transitions detected: $transitions"
  while IFS= read -r transition; do
    if [ -n "$transition" ]; then
      log "WA notify: $transition"
      curl -s -X POST "${EA_URL}/message/sendText/${EA_INSTANCE}" \
        -H "apikey: $EA_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"number\":\"$WA_NUMBER\",\"text\":\"Dokploy Monitor\n$transition\"}" >/dev/null 2>&1 || true
    fi
  done <<< "$transitions"
else
  log "No transitions. All stable."
fi

# --- Save current state ---
echo "$current_state" > "$STATE_FILE"

# --- Container health spot check (down containers) ---
down_containers=$(docker ps -a --filter "status=exited" --format "{{.Names}}\t{{.Status}}" 2>/dev/null | grep -v "^$" | head -5 || echo "")
if [ -n "$down_containers" ]; then
  log "WARNING — Exited containers: $down_containers"
fi
