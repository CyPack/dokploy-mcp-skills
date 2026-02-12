# Dokploy MCP Skills for Claude Code

Deploy and manage applications on [Dokploy](https://github.com/Dokploy/dokploy) directly from Claude Code using MCP (Model Context Protocol).

No browser automation. No Playwright. Pure API calls via MCP server.

```
Claude Code  →  MCP Protocol  →  dokploy-mcp  →  Dokploy REST API  →  Docker/Traefik
```

## What You Get

- **98 MCP tools** covering projects, applications, compose, deployments, Docker, backups, domains, registries, users, and servers
- **Claude Code skill** with risk-based approval, ID resolution, deployment tracking, and rollback workflows
- **Compose templates** for NocoBase and Twenty CRM, ready to deploy
- **Validation script** to verify your entire setup

---

## Prerequisites

| Requirement | Minimum | Check |
|-------------|---------|-------|
| Docker | 20.10+ | `docker --version` |
| Node.js | 18+ | `node --version` |
| Claude Code CLI | latest | `claude --version` |
| GitHub CLI | any | `gh --version` |

---

## Step 1: Install Dokploy

```bash
# Official one-liner install
curl -sSL https://dokploy.com/install.sh | sh
```

After installation:
1. Open `http://localhost:3000` in your browser
2. Create your admin account
3. Go to **Settings > API > Generate Token**
4. Save the token — you'll need it in Step 2

> Dokploy runs in Docker Swarm mode (single node). It manages Traefik (reverse proxy), PostgreSQL (state), and Redis (cache) automatically.

---

## Step 2: Configure MCP Server

### 2.1 Copy the example config

```bash
cp configs/dokploy-mcp-claude.json.example /tmp/dokploy-mcp-config.json
```

### 2.2 Edit the config with your values

Open `/tmp/dokploy-mcp-config.json` and replace:
- `<DOKPLOY_URL>` → your Dokploy URL (e.g., `http://localhost:3000`)
- `<DOKPLOY_API_KEY>` → the API token from Step 1

### 2.3 Merge into your Claude Code config

Add the `DokployServer` entry from your edited config into `~/.claude.json` under `mcpServers`:

```json
{
  "mcpServers": {
    "DokployServer": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "dokploy-mcp", "--enable-tools", "compose/"],
      "env": {
        "DOKPLOY_URL": "http://localhost:3000",
        "DOKPLOY_API_KEY": "your-api-key-here"
      }
    }
  }
}
```

> **About `--enable-tools compose/`**: The MCP server has 380 total tools, but only 55 are enabled by default. The `--enable-tools compose/` flag activates all 25 compose tools. Without it, you can't manage compose services via MCP.

### 2.4 Verify MCP connection

```bash
claude mcp list
# Should show: DokployServer - Connected
```

---

## Step 3: Install the Claude Code Skill

### 3.1 Copy skill files

```bash
cp -r skills/dokploy-manage/ ~/.claude/skills/dokploy-manage/
```

### 3.2 Add routing trigger to your CLAUDE.md

Add this line to your `~/.claude/CLAUDE.md` under domain routing:

```markdown
| dokploy, deploy, redeploy, rollback, compose deploy | `/dokploy-manage` skill yukle. Playwright KULLANMA! |
```

This tells Claude Code to automatically load the Dokploy skill when you mention deployment-related keywords.

---

## Step 4: Restart and Test

### 4.1 Restart Claude Code

**Important:** Claude Code caches the MCP tool list at session start. You must fully restart it after any MCP config change.

```bash
# Close all Claude Code sessions, then:
claude
```

### 4.2 Test the connection

```
You: "projeleri listele"
```

Claude should call `project-all` via MCP and list your Dokploy projects.

Other test commands:
- `"yeni proje olustur: test-project"` — creates a project
- `"template'leri goster"` — lists available compose templates
- `"container'lari goster"` — lists Docker containers

---

## Step 5: Run Validation

```bash
bash scripts/validate.sh
```

Expected output — all checks PASS:

```
[PASS] Docker is running
[PASS] Node.js >= 18
[PASS] Claude Code CLI found
[PASS] Dokploy API responding (200)
[PASS] MCP config exists in ~/.claude.json
[PASS] DokployServer entry found
[PASS] Skill files installed
[PASS] SKILL.md exists
[PASS] References directory exists
```

If any check fails, see [Troubleshooting](guides/troubleshooting.md).

---

## Compose Templates (Optional)

Ready-to-deploy compose files in `compose-files/`:

### NocoBase (Low-Code Platform)

```bash
# Deploy via Claude Code:
"bu compose'u deploy et: [paste compose-files/nocobase-compose.yml]"
```
- Port: 13000
- Includes: PostgreSQL 16, health checks, persistent storage
- First run: create admin account via web UI

### Twenty CRM

```bash
# Deploy via Claude Code:
"bu compose'u deploy et: [paste compose-files/twenty-compose.yml]"
```
- Port: 13001
- Includes: PostgreSQL, Redis, worker process
- Minimum RAM: 2GB
- First run: create account via web UI

> **Security note:** Both templates contain placeholder passwords (`CHANGE_ME_SECURE_PASSWORD`). Change them before deploying to production.

---

## Skill Capabilities

The installed skill gives Claude Code these capabilities:

| Category | Tools | Risk Level |
|----------|-------|------------|
| Projects | create, list, update | SAFE |
| Environments | create, get, update | SAFE |
| Applications | deploy, redeploy, start, stop, config | MEDIUM |
| Compose | create, import, deploy, delete | MEDIUM-CRITICAL |
| Deployments | list, history, kill | SAFE-MEDIUM |
| Docker | containers, restart, config | MEDIUM |
| Backups | schedule, manual trigger, list | SAFE |
| Domains | create, update (auto SSL) | MEDIUM |
| Registries | Docker Hub, GHCR, private | MEDIUM |
| Servers | multi-node management | MEDIUM |

Claude automatically asks for confirmation on MEDIUM+ risk operations and requires explicit approval for CRITICAL operations (like `compose-delete` with volume deletion).

---

## File Structure

```
dokploy-mcp-skills/
├── README.md                              # This file
├── configs/
│   └── dokploy-mcp-claude.json.example    # MCP config template
├── guides/
│   ├── troubleshooting.md                 # Known issues + fixes
│   └── lessons.md                         # Battle-tested patterns
├── scripts/
│   └── validate.sh                        # Setup validation
├── skills/dokploy-manage/                 # Claude Code skill
│   ├── SKILL.md                           # Skill definition (98 tools)
│   └── references/
│       ├── setup-guide.md                 # Dokploy + MCP setup details
│       ├── tool-reference.md              # All 98 tools with parameters
│       └── workflow-examples.md           # Step-by-step scenarios
└── compose-files/                         # Deploy templates
    ├── nocobase-compose.yml
    └── twenty-compose.yml
```

---

## Links

- [Dokploy](https://github.com/Dokploy/dokploy) — Self-hosted PaaS (30k+ stars)
- [dokploy-mcp](https://github.com/tacticlaunch/dokploy-mcp) — MCP server for Dokploy
- [Claude Code](https://claude.com/claude-code) — Anthropic's CLI for Claude
- [MCP Protocol](https://modelcontextprotocol.io/) — Model Context Protocol spec

## License

MIT
