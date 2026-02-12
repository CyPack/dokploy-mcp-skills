# Troubleshooting

Known issues and their fixes. If you hit a problem not listed here, open an issue.

---

## MCP Connection Issues

| Problem | Cause | Fix |
|---------|-------|-----|
| `claude mcp list` doesn't show DokployServer | Config not in `~/.claude.json` | Merge `configs/dokploy-mcp-claude.json.example` into `~/.claude.json` |
| MCP shows "Connected" but tools don't work | Session cache stale | Fully close and reopen Claude Code |
| `npx dokploy-mcp` fails | Node.js < 18 or npm issue | Run `node --version` (need 18+), try `npx -y dokploy-mcp` manually |
| Multiple MCP processes running | Opened Claude Code in multiple terminals | Close all sessions, kill stale `node` processes, reopen one session |

## API Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `401 Unauthorized` | API key invalid or expired | Generate new token: Dokploy UI > Settings > API |
| `404 Not Found` | Wrong resource ID | Use `project-all` to re-check IDs |
| `Connection refused` | Dokploy service not running | Run `docker service ls` to check, restart with `docker service update dokploy` |
| `ECONNREFUSED localhost:3000` | Dokploy container crashed | Check `docker service logs dokploy` for errors |

## Compose-Specific Issues

| Problem | Cause | Fix |
|---------|-------|-----|
| Compose tools not available in Claude Code | `--enable-tools compose/` missing from config | Add `"--enable-tools", "compose/"` to args in MCP config, restart Claude Code |
| `compose-import` fails with base64 error | YAML not properly encoded | Ensure UTF-8 encoding: `echo -n "YAML" \| base64` |
| `composeStatus` shows "error" but containers run | Dokploy didn't update status after recovery | Fix via REST API: `curl -X POST localhost:3000/api/compose.update -H "x-api-key: $KEY" -d '{"composeId":"...","composeStatus":"done"}'` |
| `compose-update` can't change `composeStatus` | MCP tool doesn't expose this field | Use REST API fallback (see above) |
| Port conflict on deploy | Another service using the port | Change port in compose YAML before importing |
| Volume permission denied | Docker Swarm + SELinux | Use named volumes instead of bind mounts |

## Skill Issues

| Problem | Cause | Fix |
|---------|-------|-----|
| Skill not auto-loading | Missing routing trigger in CLAUDE.md | Add dokploy trigger line (see README Step 3.2) |
| Skill loaded but tools fail | MCP server not connected | Check `claude mcp list`, verify API key |
| "Tool not found" errors | Deferred tools not loaded | Claude Code loads tools on-demand; try the operation again |

## Docker/Swarm Issues

| Problem | Cause | Fix |
|---------|-------|-----|
| `docker service ls` shows 0/1 replicas | Container crash loop | Check logs: `docker service logs dokploy --tail 50` |
| Dokploy update fails | Image pull error | `docker pull dokploy/dokploy:latest` then retry |
| Container restart via CLI doesn't work | Swarm manages containers | Use `docker-restartContainer` MCP tool or `docker service update` |

---

## Quick Diagnostic Commands

```bash
# Is Docker running?
docker info > /dev/null 2>&1 && echo "OK" || echo "Docker not running"

# Is Dokploy responding?
curl -sf http://localhost:3000/api > /dev/null && echo "OK" || echo "Dokploy not responding"

# Is the API key valid?
curl -sf http://localhost:3000/api/project.all \
  -H "x-api-key: $DOKPLOY_API_KEY" > /dev/null && echo "OK" || echo "Invalid API key"

# Is MCP config present?
grep -q "DokployServer" ~/.claude.json && echo "OK" || echo "MCP config missing"

# Are skill files installed?
test -f ~/.claude/skills/dokploy-manage/SKILL.md && echo "OK" || echo "Skill not installed"
```

Or just run: `bash scripts/validate.sh`
