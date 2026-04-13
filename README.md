# Dokploy MCP Skills for Claude Code

Deploy and manage applications on [Dokploy](https://github.com/Dokploy/dokploy) directly from Claude Code using MCP (Model Context Protocol).

No browser automation needed. Pure API calls via MCP server. Browser testing via Chrome DevTools MCP for post-deploy verification.

```
Claude Code  →  MCP Protocol  →  dokploy-mcp  →  Dokploy REST API  →  Docker/Traefik
                                                                     ↓
Chrome DevTools MCP  →  Browser Testing  →  End-to-End Verification
```

## What You Get

- **98 MCP tools** covering projects, applications, compose, deployments, Docker, backups, domains, registries, users, and servers
- **Claude Code skill** with risk-based approval, ID resolution, deployment tracking, and rollback workflows
- **Real deployment golden paths** — battle-tested guides for Atomic CRM, OwnPilot, NocoBase, Twenty CRM
- **Playwright/Chrome DevTools test guides** — browser-based E2E verification after deployment
- **200+ documented errors, edge cases, and proven fixes** — learned from real production deployments
- **Compose templates** ready to deploy
- **Validation & monitoring scripts**

---

## Repository Structure

```
dokploy-mcp-skills/
│
├── skills/dokploy-manage/              # Claude Code Skill (SSOT)
│   ├── SKILL.md                        #   Skill definition — 98 tools, 11 categories
│   ├── lessons/                        #   Battle-tested knowledge base
│   │   ├── errors.md                   #     170+ known errors with fixes
│   │   ├── golden-paths.md             #     16 proven deployment workflows
│   │   └── edge-cases.md              #     50+ traps and gotchas
│   ├── references/                     #   Technical reference docs
│   │   ├── tool-reference.md           #     All 98 tools with parameters
│   │   ├── workflow-examples.md        #     Step-by-step API call sequences
│   │   └── setup-guide.md             #     Dokploy + MCP installation guide
│   └── scripts/                        #   Monitoring & validation
│       ├── monitor-all.sh              #     Compose health monitoring (cron)
│       └── verify-deploy.sh            #     Post-deploy verification
│
├── deployments/                        # Per-Application Deployment Guides
│   ├── atomic-crm/                     #   marmelab/atomic-crm (React Admin + Supabase)
│   │   ├── golden-path.md              #     Full 9-step deployment guide
│   │   └── playwright-test.md          #     5 browser test scenarios + smoke test
│   └── ownpilot/                       #   OwnPilot AI Assistant
│       ├── golden-path.md              #     Deployment + health check guide
│       └── BRIDGE-INTEGRATION-PLAN.md  #     OpenClaw Bridge integration
│
├── compose-files/                      # Ready-to-Deploy Compose Templates
│   ├── nocobase-compose.yml            #   NocoBase low-code platform (port 13000)
│   └── twenty-compose.yml              #   Twenty CRM (port 13001)
│
├── automation/                         # Browser Automation (Legacy)
│   ├── BROWSER_AUTOMATION.md           #   Playwright deployment automation guide
│   ├── deploy-nocobase.js              #   NocoBase auto-deploy script
│   ├── deploy-twenty.js                #   Twenty CRM auto-deploy script
│   └── package.json                    #   Node.js dependencies
│
├── scripts/                            # Standalone Scripts
│   ├── dev-manager.sh                  #   Development environment manager
│   └── install-browser.sh              #   Chromium/Playwright installer
│
├── guides/                             # General Guides
│   ├── lessons.md                      #   Deployment lessons learned
│   ├── troubleshooting.md              #   Common issues + solutions
│   └── terminal-setups-comparison.md   #   Terminal emulator comparison
│
├── configs/                            # Configuration Templates
│   └── dokploy-mcp-claude.json.example #   MCP server config for Claude Code
│
├── archive/                            # Historical Reference
│   ├── SKILL-dokploy-deployment-agent.md  # Original skill (v1, Feb 2026)
│   └── PLAN.md                         #   Original project plan
│
├── LICENSE                             # MIT
└── README.md                           # This file
```

---

## Quick Start

### 1. Install Dokploy

```bash
curl -sSL https://dokploy.com/install.sh | sh
```

Open `http://localhost:3000` → create admin → **Settings > API > Generate Token**.

### 2. Configure MCP Server

Add to `~/.claude.json`:

```json
{
  "mcpServers": {
    "DokployServer": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "dokploy-mcp", "--enable-tools", "compose/"],
      "env": {
        "DOKPLOY_URL": "http://localhost:3000",
        "DOKPLOY_API_KEY": "<your-api-key>"
      }
    }
  }
}
```

> `--enable-tools compose/` activates 25 compose tools (disabled by default in dokploy-mcp v1.0.7).

### 3. Install Skill

```bash
cp -r skills/dokploy-manage/ ~/.claude/skills/dokploy-manage/
```

### 4. Restart Claude Code & Test

```bash
claude
# Then: "projeleri listele" → should list your Dokploy projects
```

---

## Deployment Guides

### Atomic CRM (React Admin + Supabase)

**Source:** [marmelab/atomic-crm](https://github.com/marmelab/atomic-crm)
**Guide:** [`deployments/atomic-crm/golden-path.md`](deployments/atomic-crm/golden-path.md)
**Browser Tests:** [`deployments/atomic-crm/playwright-test.md`](deployments/atomic-crm/playwright-test.md)

Highlights:
- Vite/React SPA → multi-stage Docker build (node:22 → nginx:alpine)
- Supabase self-hosted as shared backend (22 migrations, 31 tables)
- Build-time env vars via `ARG → ENV` pattern (Vite bakes at build time)
- 5 Chrome DevTools browser test scenarios
- Traefik network isolation fix, DNS hosts workaround, SMTP autoconfirm

### OwnPilot (AI Assistant)

**Guide:** [`deployments/ownpilot/golden-path.md`](deployments/ownpilot/golden-path.md)

Highlights:
- Custom Docker image via local registry (localhost:5000)
- PostgreSQL + pgvector backend
- Bridge integration for Claude Code orchestration

### NocoBase & Twenty CRM

**Templates:** `compose-files/nocobase-compose.yml`, `compose-files/twenty-compose.yml`

Deploy via Claude Code:
```
"bu compose'u deploy et: [paste YAML]"
```

---

## Lessons & Knowledge Base

The `skills/dokploy-manage/lessons/` directory contains battle-tested knowledge from real deployments:

| File | Content | Entries |
|------|---------|---------|
| `errors.md` | Known errors with root cause + fix | 170+ |
| `golden-paths.md` | Proven deployment workflows | 16 |
| `edge-cases.md` | Traps, gotchas, and workarounds | 50+ |

### Key Findings

- **MCP env propagation bug**: `compose-update` env changes don't always reach containers → use `docker stop/rm` + `docker compose up -d --no-deps`
- **compose-import is broken**: Always use REST API `/api/compose.update` instead
- **sourceType default "github"**: New compose services default to `sourceType: "github"` → must set to `"raw"` via REST API for YAML-based deployments
- **Traefik network isolation**: Traefik must be connected to each compose's network → `docker network connect <network> dokploy-traefik`

---

## Browser Testing (Chrome DevTools MCP)

Post-deploy verification using Chrome DevTools MCP:

```
navigate_page → take_screenshot → take_snapshot → fill → click → verify
```

See [`deployments/atomic-crm/playwright-test.md`](deployments/atomic-crm/playwright-test.md) for a complete 5-test example including:
- Page load verification
- User signup flow
- CRUD operations
- Navigation testing
- Pre-flight smoke test script

---

## Links

- [Dokploy](https://github.com/Dokploy/dokploy) — Self-hosted PaaS (30k+ stars)
- [dokploy-mcp](https://github.com/tacticlaunch/dokploy-mcp) — MCP server for Dokploy
- [Claude Code](https://claude.com/claude-code) — Anthropic's CLI for Claude
- [MCP Protocol](https://modelcontextprotocol.io/) — Model Context Protocol spec

## License

MIT
