# Dokploy Development Environment Setup Plan

## 🎯 Project Overview

**Owner:** (Redacted)
**System:** Fedora 43, GNOME 49, Wayland  
**Date:** January 28, 2026  
**Status:** In Progress

### Objective
Set up a hybrid development environment on Fedora 43 laptop:
- **Dokploy** for production-like deployments (self-hosted PaaS)
- **Separate dev environment** for active development with hot reload
- Deploy **NocoBase** and **Twenty CRM** as test applications

---

## 📊 Current State

### ✅ Completed
1. **Dokploy Installed & Running**
   - Docker CE 28.5.0 installed
   - Docker Swarm initialized
   - Dokploy v0.26.6 running on port 3000
   - Traefik v3.6.7 on ports 80/443
   - PostgreSQL 16 and Redis 7 as backend services
   - Dashboard accessible at `http://localhost:3000`
   - Admin account created

2. **Development Folder Structure Created**
   ```
   ~/dev/
   ├── projects/       # Active development projects (hot reload)
   ├── shared/         # Shared configs and data
   ├── scripts/        # Management scripts
   └── dokploy-apps/   # Dokploy compose file backups
   ```

3. **Dev Manager Script Installed**
   - Location: `~/dev/scripts/dev-manager.sh`
   - Alias: `dev` command available in zsh
   - Commands: status, list, ports, dokploy, help

### 🔄 In Progress
1. Deploy NocoBase via Dokploy
2. Deploy Twenty CRM via Dokploy

### ⏳ Pending
1. Configure Traefik domains (optional)
2. Set up development project templates
3. Configure backup strategy

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     FEDORA 43 LAPTOP                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                 DOKPLOY (Docker Swarm)                   │   │
│  │                                                         │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐   │   │
│  │  │Dokploy  │  │Traefik  │  │Postgres │  │ Redis   │   │   │
│  │  │ :3000   │  │ :80/443 │  │ :5432   │  │ :6379   │   │   │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘   │   │
│  │                                                         │   │
│  │  ┌──────────────────┐  ┌──────────────────┐           │   │
│  │  │    NocoBase      │  │   Twenty CRM     │           │   │
│  │  │     :13000       │  │     :13001       │           │   │
│  │  └──────────────────┘  └──────────────────┘           │   │
│  │                                                         │   │
│  │  Network: dokploy-network (isolated)                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              DEVELOPMENT (Docker Compose)                │   │
│  │                                                         │   │
│  │  ┌──────────────────┐  ┌──────────────────┐           │   │
│  │  │   Project A      │  │   Project B      │           │   │
│  │  │   :4000-4099     │  │   :4100-4199     │           │   │
│  │  │   (hot reload)   │  │   (hot reload)   │           │   │
│  │  └──────────────────┘  └──────────────────┘           │   │
│  │                                                         │   │
│  │  Network: bridge (host access)                          │   │
│  │  Volumes: :Z suffix for SELinux                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔌 Port Allocation

| Service | Port | URL | Status |
|---------|------|-----|--------|
| Dokploy Dashboard | 3000 | http://localhost:3000 | ✅ Running |
| Traefik HTTP | 80 | - | ✅ Running |
| Traefik HTTPS | 443 | - | ✅ Running |
| NocoBase | 13000 | http://localhost:13000 | 🔄 Deploying |
| Twenty CRM | 13001 | http://localhost:13001 | ⏳ Pending |
| Dev Projects | 4000-4999 | - | ⏳ Reserved |

---

## 📋 Deployment Tasks

### Task 1: Deploy NocoBase

**Application Info:**
- GitHub: https://github.com/nocobase/nocobase
- Type: No-code/Low-code platform
- Use case: Business applications, internal tools
- Stack: Node.js + PostgreSQL

**Dokploy Steps:**
1. Open Dokploy Dashboard: `http://localhost:3000`
2. Click "+ Create Project" → Name: `nocobase`
3. Inside project, click "+ Create Service" → Select "Compose"
4. Go to "Compose" tab
5. Paste contents from `compose-files/nocobase-compose.yml`
6. Click "Deploy"
7. Wait for deployment (check logs)
8. Access: `http://localhost:13000`

**First Run:**
- Create admin account on first visit
- Default setup wizard will guide through configuration

**Resource Requirements:**
- RAM: ~512MB-1GB
- Disk: ~2GB for images + data

---

### Task 2: Deploy Twenty CRM

**Application Info:**
- GitHub: https://github.com/twentyhq/twenty
- Type: Open-source CRM
- Use case: Customer relationship management
- Stack: Node.js + PostgreSQL + Redis

**Dokploy Steps:**
1. Open Dokploy Dashboard: `http://localhost:3000`
2. Click "+ Create Project" → Name: `twenty-crm`
3. Inside project, click "+ Create Service" → Select "Compose"
4. Go to "Compose" tab
5. Paste contents from `compose-files/twenty-compose.yml`
6. Click "Deploy"
7. Wait for deployment (check logs - takes longer due to migrations)
8. Access: `http://localhost:13001`

**First Run:**
- Create account on first visit
- Email verification disabled in self-hosted mode

**Resource Requirements:**
- RAM: ~2GB minimum (server + worker + db + redis)
- Disk: ~3GB for images + data

---

## 🤖 Browser Automation Guide

For Claude Code browser automation to deploy these apps:

### Prerequisites
```bash
# Install Playwright (if using browser automation)
npm init -y
npm install playwright
npx playwright install chromium
```

### Automation Flow for NocoBase

```javascript
// automation/deploy-nocobase.js
const { chromium } = require('playwright');

async function deployNocoBase() {
    const browser = await chromium.launch({ headless: false });
    const page = await browser.newPage();
    
    // 1. Go to Dokploy
    await page.goto('http://localhost:3000');
    
    // 2. Wait for dashboard to load
    await page.waitForSelector('text=Projects');
    
    // 3. Create Project
    await page.click('text=Create Project');
    await page.fill('input[name="name"]', 'nocobase');
    await page.click('text=Create');
    
    // 4. Create Compose Service
    await page.click('text=Create Service');
    await page.click('text=Compose');
    
    // 5. Paste compose content
    // ... (paste from file)
    
    // 6. Deploy
    await page.click('text=Deploy');
    
    // 7. Wait for deployment
    await page.waitForSelector('text=Running', { timeout: 300000 });
    
    await browser.close();
}

deployNocoBase();
```

### Key Selectors for Dokploy UI
- Create Project Button: `button:has-text("Create Project")`
- Project Name Input: `input[placeholder="Project name"]` or `input[name="name"]`
- Create Service: `button:has-text("Create Service")`
- Compose Option: `text=Compose` or `button:has-text("Compose")`
- Compose Editor: `textarea` or `.monaco-editor`
- Deploy Button: `button:has-text("Deploy")`
- Service Status: Check for "Running" text in service card

---

## 🛠️ Useful Commands

```bash
# Check all container status
dev status

# Check Dokploy services specifically
docker service ls

# Check container logs
docker logs -f <container-name>

# Check port usage
dev ports
ss -tulnp | grep LISTEN

# Restart Dokploy
docker service update --force dokploy

# Check resource usage
docker stats

# Open Dokploy dashboard
dev dokploy
# or
xdg-open http://localhost:3000
```

---

## ⚠️ Important Notes

1. **SELinux on Fedora**: Volume mounts require `:Z` suffix
2. **Docker Group**: User is in docker group (no sudo needed)
3. **Zsh Shell**: User uses zsh, not bash
4. **Swarm Mode**: Dokploy uses Docker Swarm, not standalone
5. **Port Conflicts**: Never use 3000, 80, 443 for dev projects

---

## 📁 File Structure

```
dokploy-setup/
├── PLAN.md                      # This file
├── README.md                    # Quick start guide
├── compose-files/
│   ├── nocobase-compose.yml     # NocoBase Docker Compose
│   └── twenty-compose.yml       # Twenty CRM Docker Compose
├── scripts/
│   └── dev-manager.sh           # Dev management script
└── automation/
    ├── deploy-nocobase.js       # Browser automation for NocoBase
    └── deploy-twenty.js         # Browser automation for Twenty
```

---

## 🔗 References

- Dokploy Docs: https://docs.dokploy.com
- NocoBase Docs: https://docs.nocobase.com
- Twenty Docs: https://twenty.com/developers
- Docker Compose: https://docs.docker.com/compose/

---

## 📝 Session Log

### 2026-01-28
- [x] Analyzed Docker vs Podman for enterprise use
- [x] Decided on hybrid approach (Dokploy + Dev environment)
- [x] Installed Dokploy successfully
- [x] Created folder structure ~/dev/
- [x] Created dev-manager.sh script
- [x] Configured zsh alias
- [ ] Deploy NocoBase
- [ ] Deploy Twenty CRM
- [ ] Test both applications
