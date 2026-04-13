# SKILL: Dokploy Deployment & Diagnostics Agent
## Complete Installation, Configuration, Deployment, and Troubleshooting Guide

---

## METADATA

```yaml
skill_name: dokploy-deployment-agent
version: 1.0.0
created: 2026-01-28
author: Claude Code (Opus 4.5)
target_audience: AI Agents, Claude Code, Automation Systems
use_case: Self-hosted PaaS deployment on Fedora/RHEL/Debian systems
applications:
  - Dokploy (Self-hosted PaaS)
  - NocoBase (Low-code Platform)
  - Twenty CRM (Open-source CRM)
complexity: Medium-Advanced
estimated_time: 30-60 minutes (full deployment)
prerequisites:
  - Linux system (Fedora/Ubuntu/Debian)
  - Root or sudo access
  - Minimum 4GB RAM, 20GB disk
  - Ports 80, 443, 3000 available
```

---

## TABLE OF CONTENTS

1. [Quick Reference](#1-quick-reference)
2. [System Prerequisites](#2-system-prerequisites)
3. [Dokploy Installation](#3-dokploy-installation)
4. [Browser Automation Setup](#4-browser-automation-setup)
5. [NocoBase Deployment](#5-nocobase-deployment)
6. [Twenty CRM Deployment](#6-twenty-crm-deployment)
7. [Troubleshooting Guide](#7-troubleshooting-guide)
8. [Best Practices](#8-best-practices)
9. [Compose File Reference](#9-compose-file-reference)
10. [Diagnostic Commands](#10-diagnostic-commands)
11. [Known Issues & Solutions](#11-known-issues--solutions)
12. [Session Transcript Analysis](#12-session-transcript-analysis)

---

## 1. QUICK REFERENCE

### Port Allocation Table

| Service | Port | Protocol | Status Check |
|---------|------|----------|--------------|
| Dokploy Dashboard | 3000 | HTTP | `curl -s http://localhost:3000` |
| Traefik HTTP | 80 | HTTP | `curl -s http://localhost:80` |
| Traefik HTTPS | 443 | HTTPS | `curl -sk https://localhost:443` |
| NocoBase | 13000 | HTTP | `curl -s http://localhost:13000/api/health` |
| Twenty CRM | 13001 | HTTP | `curl -s http://localhost:13001/healthz` |

### Quick Health Check Script

```bash
#!/bin/bash
# Save as: health-check.sh
echo "=== Dokploy Environment Health Check ==="

check_service() {
    local name=$1
    local url=$2
    local expected=${3:-200}

    status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    if [[ "$status" == "$expected" ]] || [[ "$status" == "302" ]]; then
        echo "[OK] $name ($url) - HTTP $status"
        return 0
    else
        echo "[FAIL] $name ($url) - HTTP $status (expected $expected)"
        return 1
    fi
}

check_service "Dokploy" "http://localhost:3000"
check_service "NocoBase" "http://localhost:13000"
check_service "Twenty CRM" "http://localhost:13001"

echo ""
echo "=== Docker Status ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -20

echo ""
echo "=== Resource Usage ==="
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | head -15
```

---

## 2. SYSTEM PREREQUISITES

### 2.1 Hardware Requirements

```
MINIMUM:
├── CPU: 2 cores
├── RAM: 4GB (8GB recommended)
├── Disk: 20GB (50GB recommended)
└── Network: Stable internet connection

FOR PRODUCTION:
├── CPU: 4+ cores
├── RAM: 8GB+ (16GB for multiple apps)
├── Disk: 100GB+ SSD
└── Network: Static IP or domain
```

### 2.2 Operating System Compatibility

| OS | Version | Status | Notes |
|----|---------|--------|-------|
| Ubuntu | 20.04+ | Fully Supported | Recommended |
| Debian | 11+ | Fully Supported | |
| Fedora | 38+ | Supported | Requires SELinux config |
| RHEL/Rocky | 8+ | Supported | Requires subscription for Docker |
| AlmaLinux | 8+ | Supported | |

### 2.3 Pre-Installation Checklist

```bash
# Run these checks before installation:

# 1. Check if running as root or with sudo
whoami  # Should have root access

# 2. Check available memory
free -h
# Ensure: Available > 2GB

# 3. Check disk space
df -h /
# Ensure: Available > 10GB

# 4. Check if ports are free
ss -tulnp | grep -E ":80|:443|:3000"
# Should return empty (ports free)

# 5. Check if Docker is already installed
docker --version 2>/dev/null || echo "Docker not installed"

# 6. Check SELinux status (Fedora/RHEL)
getenforce 2>/dev/null || echo "SELinux not present"

# 7. Check firewall
systemctl status firewalld 2>/dev/null || systemctl status ufw 2>/dev/null
```

### 2.4 Fedora-Specific Prerequisites

```bash
# Fedora requires additional steps due to SELinux

# 1. Install required packages
sudo dnf install -y curl wget git

# 2. Configure firewall (if enabled)
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=13000/tcp
sudo firewall-cmd --permanent --add-port=13001/tcp
sudo firewall-cmd --reload

# 3. SELinux consideration
# NOTE: Docker Swarm has a known limitation where :Z and :z labels
# are IGNORED for bind mounts in services
# Reference: https://github.com/docker/docs/issues/2763
# For Dokploy, this is handled internally - no action needed
```

---

## 3. DOKPLOY INSTALLATION

### 3.1 One-Line Installation (Recommended)

```bash
# IMPORTANT: Run as root
curl -sSL https://dokploy.com/install.sh | sh
```

### 3.2 What the Installation Script Does

```
INSTALLATION PROCESS:
├── 1. Checks system requirements
├── 2. Installs Docker Engine (if not present)
├── 3. Initializes Docker Swarm mode
├── 4. Creates dokploy-network overlay network
├── 5. Deploys Dokploy stack:
│   ├── dokploy (main application)
│   ├── traefik (reverse proxy)
│   ├── dokploy-postgres (database)
│   └── dokploy-redis (cache)
└── 6. Displays access URL
```

### 3.3 Manual Installation Steps

If the one-liner fails, follow these manual steps:

```bash
# Step 1: Install Docker
curl -fsSL https://get.docker.com | sh

# Step 2: Add user to docker group (optional, for non-root)
sudo usermod -aG docker $USER
newgrp docker

# Step 3: Initialize Docker Swarm
docker swarm init

# Step 4: Create network
docker network create --driver overlay dokploy-network

# Step 5: Deploy Dokploy manually
docker service create \
  --name dokploy \
  --replicas 1 \
  --network dokploy-network \
  --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
  --mount type=bind,source=/etc/dokploy,target=/etc/dokploy \
  --publish 3000:3000 \
  dokploy/dokploy:latest
```

### 3.4 Post-Installation Verification

```bash
# 1. Check Docker Swarm services
docker service ls
# Expected output:
# ID            NAME               MODE        REPLICAS   IMAGE
# xxxxx         dokploy            replicated  1/1        dokploy/dokploy:latest
# xxxxx         dokploy-postgres   replicated  1/1        postgres:16
# xxxxx         dokploy-redis      replicated  1/1        redis:7
# xxxxx         dokploy-traefik    replicated  1/1        traefik:v3.x

# 2. Check if Dokploy is responding
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000
# Expected: 200 or 302 (redirect to login)

# 3. Check container logs
docker service logs dokploy --tail 50

# 4. Open browser
xdg-open http://localhost:3000  # Linux
# or
open http://localhost:3000       # macOS
```

### 3.5 Initial Setup (First-Time Access)

```
FIRST-TIME SETUP FLOW:
1. Navigate to http://localhost:3000
2. Create admin account:
   - Email: your-email@example.com
   - Password: (strong password, 8+ chars)
3. Dashboard loads automatically
4. Create your first project
```

---

## 4. BROWSER AUTOMATION SETUP

### 4.1 Why Browser Automation?

Dokploy's deployment is primarily UI-driven. For Claude Code or other AI agents to deploy applications autonomously, browser automation is required.

### 4.2 Playwright MCP Setup (Recommended for Claude Code)

```bash
# Method 1: Using Claude Code built-in command
claude mcp add playwright -- npx @playwright/mcp@latest

# Method 2: Manual configuration
# Add to ~/.config/claude-code/settings.json:
{
  "mcpServers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"]
    }
  }
}

# Method 3: Enable plugin in Claude Code
/plugins enable playwright
```

### 4.3 Browser Installation for Playwright

```bash
# CRITICAL: Playwright MCP requires a browser

# Option A: Use Playwright's bundled Chromium
npx playwright install chromium

# Option B: Use system Chromium (Fedora/RHEL)
# This is required when Playwright can't find the browser

# Create install script:
cat > /tmp/install-browser.sh << 'EOF'
#!/bin/bash
# Browser installation script for Playwright MCP

echo "Installing Chromium..."
# Fedora/RHEL
if command -v dnf &> /dev/null; then
    sudo dnf install -y chromium
# Debian/Ubuntu
elif command -v apt &> /dev/null; then
    sudo apt update && sudo apt install -y chromium-browser
fi

# Create symlink for Playwright
# Playwright looks for Chrome at: /opt/google/chrome/chrome
echo "Creating symlink..."
sudo mkdir -p /opt/google/chrome

# Try both possible binary names
if [ -f /usr/bin/chromium-browser ]; then
    sudo ln -sf /usr/bin/chromium-browser /opt/google/chrome/chrome
elif [ -f /usr/bin/chromium ]; then
    sudo ln -sf /usr/bin/chromium /opt/google/chrome/chrome
fi

echo "Verifying installation..."
/opt/google/chrome/chrome --version 2>/dev/null || chromium --version

echo "Done!"
EOF

chmod +x /tmp/install-browser.sh
sudo /tmp/install-browser.sh
```

### 4.4 Verifying Playwright MCP Connection

```bash
# In Claude Code, check MCP status:
/status

# Look for:
# MCP Servers:
#   plugin:playwright:playwright: npx @playwright/mcp@latest - Connected

# Test browser launch:
# Ask Claude Code to navigate to any URL using browser tools
```

### 4.5 Dokploy UI Selectors Reference

For automation tools interacting with Dokploy:

| Element | CSS Selector | XPath Alternative |
|---------|-------------|-------------------|
| Create Project Button | `button:has-text("Create Project")` | `//button[contains(text(),'Create Project')]` |
| Project Name Input | `input[placeholder*="name" i]` | `//input[@name='name']` |
| Create (Modal) | `button:has-text("Create"):visible` | `//button[text()='Create']` |
| Create Service | `button:has-text("Create Service")` | `//button[contains(text(),'Create Service')]` |
| Compose Option | `text=Compose` | `//span[text()='Compose']` |
| Compose Tab | `[role="tab"]:has-text("Compose")` | `//button[@role='tab'][contains(text(),'Compose')]` |
| Monaco Editor | `.monaco-editor textarea` | `//div[@class='monaco-editor']//textarea` |
| Deploy Button | `button:has-text("Deploy")` | `//button[contains(text(),'Deploy')]` |
| Confirm Button | `button:has-text("Confirm")` | `//button[text()='Confirm']` |
| Save Button | `button:has-text("Save")` | `//button[text()='Save']` |
| Running Status | `text=running, text=Running` | `//*[contains(text(),'running')]` |
| Deployments Tab | `tab:has-text("Deployments")` | `//button[@role='tab'][text()='Deployments']` |
| Logs Tab | `tab:has-text("Logs")` | `//button[@role='tab'][text()='Logs']` |

---

## 5. NOCOBASE DEPLOYMENT

### 5.1 Application Overview

```yaml
application:
  name: NocoBase
  type: Low-code/No-code Platform
  github: https://github.com/nocobase/nocobase
  documentation: https://docs.nocobase.com
  stack:
    - Node.js
    - PostgreSQL
  resources:
    ram_minimum: 512MB
    ram_recommended: 1GB
    disk: 2GB (images + data)
  ports:
    internal: 80
    external: 13000
  initial_credentials:
    email: admin@nocobase.com
    password: admin123
```

### 5.2 Complete Docker Compose Configuration

```yaml
# nocobase-compose.yml
# Port: 13000
# First run: Create admin account via web UI
# Docs: https://docs.nocobase.com

services:
  app:
    image: nocobase/nocobase:latest
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      # Security - CHANGE THESE IN PRODUCTION!
      - APP_KEY=your-unique-secret-key-minimum-32-characters-long
      - ENCRYPTION_FIELD_KEY=your-encryption-key-minimum-32-chars

      # Database Configuration
      - DB_DIALECT=postgres
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_DATABASE=nocobase
      - DB_USER=nocobase
      - DB_PASSWORD=CHANGE_ME_SECURE_PASSWORD

      # Application Settings
      - TZ=Europe/Amsterdam
      - APP_ENV=production

      # Optional: API Rate Limiting
      # - API_RATE_LIMIT_MAX=1000
      # - API_RATE_LIMIT_WINDOW=60
    volumes:
      - nocobase_storage:/app/nocobase/storage
    ports:
      - "13000:80"
    init: true
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  postgres:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: nocobase
      POSTGRES_DB: nocobase
      POSTGRES_PASSWORD: CHANGE_ME_SECURE_PASSWORD
    volumes:
      - nocobase_db:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U nocobase -d nocobase"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  nocobase_storage:
  nocobase_db:
```

### 5.3 Environment Variables Reference

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `APP_KEY` | Yes | Application secret key (32+ chars) | `openssl rand -hex 32` |
| `ENCRYPTION_FIELD_KEY` | Yes | Field encryption key (32+ chars) | `openssl rand -hex 32` |
| `DB_DIALECT` | Yes | Database type | `postgres`, `mysql`, `sqlite` |
| `DB_HOST` | Yes | Database hostname | `postgres` (service name) |
| `DB_PORT` | Yes | Database port | `5432` |
| `DB_DATABASE` | Yes | Database name | `nocobase` |
| `DB_USER` | Yes | Database user | `nocobase` |
| `DB_PASSWORD` | Yes | Database password | Strong password |
| `TZ` | No | Timezone | `Europe/Amsterdam` |
| `APP_ENV` | No | Environment mode | `production`, `development` |

### 5.4 Deployment Steps (Browser Automation)

```
STEP-BY-STEP BROWSER ACTIONS:

1. NAVIGATE
   - URL: http://localhost:3000
   - Wait for: "Projects" text visible

2. CREATE PROJECT
   - Click: "Create Project" button
   - Fill: Name = "nocobase"
   - Click: "Create" button in modal
   - Wait: 2 seconds

3. OPEN PROJECT
   - Click: Project card with name "nocobase"
   - Wait: 1.5 seconds

4. CREATE COMPOSE SERVICE
   - Click: "Create Service" button
   - Wait: 1 second
   - Click: "Compose" option
   - Wait: 2 seconds

5. CONFIGURE COMPOSE
   - Fill service name: "nocobase-stack"
   - Fill description: "NocoBase Low-code Platform"
   - Navigate to General tab (should be default)
   - Find text editor (Monaco editor)
   - Clear existing content (Ctrl+A)
   - Paste compose YAML content
   - Click: "Save" button
   - Wait: 2 seconds

6. DEPLOY
   - Click: "Deploy" button
   - Click: "Confirm" in dialog
   - Wait: Up to 3 minutes for deployment

7. VERIFY
   - Check Deployments tab for "done" status
   - Open new tab: http://localhost:13000
   - Should see NocoBase welcome page
```

### 5.5 Post-Deployment Verification

```bash
# Check container status
docker ps | grep nocobase

# Check application logs
docker logs $(docker ps -qf "name=nocobase-app") --tail 100

# Check database connectivity
docker exec $(docker ps -qf "name=nocobase-postgres") \
  pg_isready -U nocobase -d nocobase

# Test API endpoint
curl -s http://localhost:13000/api/health | jq .

# Expected response:
# {"status":"ok"}
```

---

## 6. TWENTY CRM DEPLOYMENT

### 6.1 Application Overview

```yaml
application:
  name: Twenty CRM
  type: Open-source CRM
  github: https://github.com/twentyhq/twenty
  documentation: https://twenty.com/developers
  stack:
    - Node.js (NestJS)
    - PostgreSQL (custom image)
    - Redis
  services:
    - server (main application)
    - worker (background jobs)
    - db (PostgreSQL)
    - redis (cache)
  resources:
    ram_minimum: 2GB
    ram_recommended: 4GB
    disk: 3GB (images + data)
  ports:
    internal: 3000
    external: 13001
```

### 6.2 CRITICAL: Required Environment Variables

```
!!! CRITICAL LEARNING FROM SESSION !!!

Twenty CRM v1.16+ REQUIRES the APP_SECRET environment variable.
Without it, the server will crash with:

  Error: APP_SECRET is not set
  at getSessionStorageOptions (/app/.../session-storage.module-factory.js:25:15)

REQUIRED SECRETS (all must be 64-character hex strings):
├── APP_SECRET          <- MOST CRITICAL, often missing in examples
├── ACCESS_TOKEN_SECRET
├── LOGIN_TOKEN_SECRET
├── REFRESH_TOKEN_SECRET
└── FILE_TOKEN_SECRET

Generate with:
  openssl rand -hex 32
```

### 6.3 Complete Docker Compose Configuration

```yaml
# twenty-compose.yml
# Port: 13001
# First run: Create account via web UI
# Minimum RAM: 2GB
# Docs: https://twenty.com/developers/section/self-hosting

services:
  server:
    image: twentycrm/twenty:latest
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      # Server URL - REQUIRED
      - SERVER_URL=http://localhost:13001

      # CRITICAL: ALL THESE SECRETS ARE REQUIRED
      # Generate each with: openssl rand -hex 32
      - APP_SECRET=a4b8e2f1c3d5e7f9a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4
      - ACCESS_TOKEN_SECRET=798f83865f6ba45249165d557010ed16a2581fdd5e207b2b00c3143eadd045e1
      - LOGIN_TOKEN_SECRET=631a29e2aed9a571828128e3f3f476b37b326f384da06dd21251eaffb64e2708
      - REFRESH_TOKEN_SECRET=2c1f3ffaf53606dfb273708e3077080f7e04b371deeadcf71c007414096521e6
      - FILE_TOKEN_SECRET=093b3ed09f4d7cc96f36ffc2cd2fc5ab77a85c9b230a09d1ff291ec6fca0986f

      # Database - Use service name as host
      - PG_DATABASE_URL=postgres://postgres:CHANGE_ME_SECURE_PASSWORD@db:5432/twenty

      # Redis - Use service name as host
      - REDIS_URL=redis://redis:6379

      # Storage Configuration
      - STORAGE_TYPE=local
      - STORAGE_LOCAL_PATH=.local-storage

      # Optional: Disable sign-up after first user
      # - IS_SIGN_UP_DISABLED=true

      # Optional: Email Configuration
      # - EMAIL_DRIVER=smtp
      # - EMAIL_SMTP_HOST=smtp.example.com
      # - EMAIL_SMTP_PORT=587
      # - EMAIL_SMTP_USER=user
      # - EMAIL_SMTP_PASSWORD=password
    ports:
      - "13001:3000"
    volumes:
      - twenty_server_data:/app/.local-storage
      - twenty_docker_data:/app/docker-data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 120s

  worker:
    image: twentycrm/twenty:latest
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    command: ["yarn", "worker:prod"]
    environment:
      # MUST MATCH SERVER ENVIRONMENT VARIABLES
      - SERVER_URL=http://localhost:13001
      - APP_SECRET=a4b8e2f1c3d5e7f9a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4
      - ACCESS_TOKEN_SECRET=798f83865f6ba45249165d557010ed16a2581fdd5e207b2b00c3143eadd045e1
      - LOGIN_TOKEN_SECRET=631a29e2aed9a571828128e3f3f476b37b326f384da06dd21251eaffb64e2708
      - REFRESH_TOKEN_SECRET=2c1f3ffaf53606dfb273708e3077080f7e04b371deeadcf71c007414096521e6
      - FILE_TOKEN_SECRET=093b3ed09f4d7cc96f36ffc2cd2fc5ab77a85c9b230a09d1ff291ec6fca0986f
      - PG_DATABASE_URL=postgres://postgres:CHANGE_ME_SECURE_PASSWORD@db:5432/twenty
      - REDIS_URL=redis://redis:6379
      - STORAGE_TYPE=local
      - STORAGE_LOCAL_PATH=.local-storage
    volumes:
      - twenty_server_data:/app/.local-storage
      - twenty_docker_data:/app/docker-data

  db:
    # IMPORTANT: Use Twenty's custom PostgreSQL image
    # It includes required extensions (pgcrypto, uuid-ossp, etc.)
    image: twentycrm/twenty-postgres:latest
    restart: unless-stopped
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=CHANGE_ME_SECURE_PASSWORD
      - POSTGRES_DB=twenty
    volumes:
      - twenty_db_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d twenty"]
      interval: 5s
      timeout: 5s
      retries: 10

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    volumes:
      - twenty_redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 10

volumes:
  twenty_db_data:
  twenty_server_data:
  twenty_docker_data:
  twenty_redis_data:
```

### 6.4 Environment Variables Reference

| Variable | Required | Description | Notes |
|----------|----------|-------------|-------|
| `SERVER_URL` | Yes | Public URL | `http://localhost:13001` |
| `APP_SECRET` | **CRITICAL** | Session encryption key | 64-char hex, MISSING = CRASH |
| `ACCESS_TOKEN_SECRET` | Yes | JWT access token signing | 64-char hex |
| `LOGIN_TOKEN_SECRET` | Yes | Login token signing | 64-char hex |
| `REFRESH_TOKEN_SECRET` | Yes | Refresh token signing | 64-char hex |
| `FILE_TOKEN_SECRET` | Yes | File access token | 64-char hex |
| `PG_DATABASE_URL` | Yes | PostgreSQL connection | `postgres://user:pass@host:port/db` |
| `REDIS_URL` | Yes | Redis connection | `redis://host:6379` |
| `STORAGE_TYPE` | Yes | Storage backend | `local` or `s3` |
| `IS_SIGN_UP_DISABLED` | No | Disable registration | `true` after first user |

### 6.5 Deployment Timeline

```
TWENTY CRM DEPLOYMENT TIMELINE:

0:00 - Deploy initiated
0:30 - Images pulled (if not cached)
1:00 - Database container healthy
1:15 - Redis container healthy
1:30 - Server starts, runs migrations
2:00 - Worker starts
2:30 - Application ready

TOTAL: ~2-3 minutes (first deploy)
       ~30 seconds (subsequent deploys)

NOTE: First startup takes longer due to:
- Database schema creation
- Migration execution
- Background job initialization
```

### 6.6 Post-Deployment Verification

```bash
# Check all containers
docker ps | grep -E "twenty|stack-"

# Expected: 4 containers running
# - server (main app)
# - worker (background jobs)
# - db (postgresql)
# - redis

# Check server logs for errors
docker logs $(docker ps -qf "name=server") --tail 100 2>&1 | grep -i error

# Check if migrations completed
docker logs $(docker ps -qf "name=server") 2>&1 | grep -i "migration"

# Test health endpoint
curl -s http://localhost:13001/healthz
# Expected: {"status":"ok"}

# Test GraphQL endpoint
curl -s http://localhost:13001/graphql -H "Content-Type: application/json" \
  -d '{"query":"{ __typename }"}' | jq .
```

---

## 7. TROUBLESHOOTING GUIDE

### 7.1 Dokploy Issues

#### Issue: Dokploy not accessible on port 3000

```bash
# Diagnosis
docker service ls | grep dokploy
docker service ps dokploy --no-trunc

# Check logs
docker service logs dokploy --tail 100

# Solution 1: Restart service
docker service update --force dokploy

# Solution 2: Check port conflict
ss -tulnp | grep :3000
# If occupied, stop conflicting service

# Solution 3: Reinitialize Swarm
docker swarm leave --force
docker swarm init
# Then reinstall Dokploy
```

#### Issue: "Error connecting to Docker socket"

```bash
# Check Docker daemon
systemctl status docker

# Check socket permissions
ls -la /var/run/docker.sock
# Should be: srw-rw---- root docker

# Solution: Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

### 7.2 Browser Automation Issues

#### Issue: "Chromium not found" / Browser executable not found

```bash
# Diagnosis
which chromium || which chromium-browser || which google-chrome

# Solution for Fedora/RHEL
sudo dnf install -y chromium

# Create Playwright symlink
sudo mkdir -p /opt/google/chrome
sudo ln -sf $(which chromium || which chromium-browser) /opt/google/chrome/chrome

# Verify
/opt/google/chrome/chrome --version
```

#### Issue: Playwright MCP not connecting

```bash
# Check MCP server status in Claude Code
/status

# Reinstall MCP
/plugins disable playwright
/plugins enable playwright

# Manual test
npx @playwright/mcp@latest --help
```

#### Issue: Browser crashes on Wayland (Fedora GNOME)

```bash
# Use X11 backend for Chromium
export DISPLAY=:0
chromium --no-sandbox --disable-gpu
```

### 7.3 NocoBase Issues

#### Issue: NocoBase container keeps restarting

```bash
# Check logs
docker logs $(docker ps -aqf "name=nocobase") --tail 200

# Common causes:
# 1. Database not ready - check postgres health
docker logs $(docker ps -aqf "name=postgres") --tail 50

# 2. Missing APP_KEY
# Solution: Ensure APP_KEY is set and 32+ characters

# 3. Port conflict
ss -tulnp | grep 13000
```

#### Issue: "relation does not exist" errors

```bash
# Database schema not created
# Solution: Restart the app container
docker restart $(docker ps -qf "name=nocobase-app")

# Or rebuild from scratch
# In Dokploy UI: Stop service, delete volumes, redeploy
```

### 7.4 Twenty CRM Issues

#### Issue: "Error: APP_SECRET is not set" (MOST COMMON)

```
THIS IS THE #1 ISSUE WITH TWENTY CRM DEPLOYMENTS

CAUSE: Missing APP_SECRET environment variable
       Many example compose files don't include it

SOLUTION:
1. Add APP_SECRET to BOTH server and worker services
2. Generate with: openssl rand -hex 32
3. Redeploy

Example:
  environment:
    - APP_SECRET=a4b8e2f1c3d5e7f9a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4
```

#### Issue: Container shows "running" but connection refused

```bash
# Check if container is crash-looping
docker ps -a | grep twenty

# Check logs for startup errors
docker logs $(docker ps -aqf "name=twenty-server") 2>&1 | tail -100

# Common causes:
# 1. Database not ready yet (wait 2-3 minutes)
# 2. Missing environment variables
# 3. Wrong database connection string

# Verify database connection from server container
docker exec $(docker ps -qf "name=twenty-server") \
  curl -s db:5432 2>&1 || echo "DB not reachable"
```

#### Issue: Twenty shows "Welcome" but no data

```bash
# This is NORMAL for fresh installation
# Twenty seeds demo data on first user creation

# Steps:
# 1. Click "Continue with Email"
# 2. Create your account
# 3. Demo data appears after login
```

### 7.5 General Docker/Swarm Issues

#### Issue: "No space left on device"

```bash
# Check disk usage
df -h /

# Clean Docker resources
docker system prune -af --volumes

# Clean unused images
docker image prune -af
```

#### Issue: Services stuck in "Pending" state

```bash
# Check service status
docker service ps <service-name> --no-trunc

# Common causes:
# 1. Image pull failure - check network/registry
# 2. Resource constraints - check RAM/CPU
# 3. Volume mount issues - check paths exist

# Force update
docker service update --force <service-name>
```

---

## 8. BEST PRACTICES

### 8.1 Security Best Practices

```
SECURITY CHECKLIST:

□ Change all default secrets before production
  - Generate with: openssl rand -hex 32

□ Use strong database passwords
  - No special characters in PostgreSQL passwords
  - Minimum 16 characters

□ Enable HTTPS in production
  - Configure domain in Dokploy settings
  - Let's Encrypt auto-renewal

□ Disable sign-up after first user (Twenty)
  - Set IS_SIGN_UP_DISABLED=true

□ Regular backups
  - Enable in Dokploy settings
  - Test restore procedures

□ Keep images updated
  - docker pull <image>:latest regularly

□ Firewall configuration
  - Only expose necessary ports
  - Restrict SSH access

□ Monitor logs for anomalies
  - Set up log aggregation
```

### 8.2 Performance Best Practices

```
PERFORMANCE OPTIMIZATION:

1. RESOURCE ALLOCATION
   ├── NocoBase: 512MB-1GB RAM
   ├── Twenty: 2GB minimum RAM
   └── Reserve 2GB for Dokploy itself

2. DATABASE OPTIMIZATION
   ├── Use PostgreSQL 16 for best performance
   ├── Configure shared_buffers (25% of RAM)
   └── Enable connection pooling for high load

3. VOLUME CONFIGURATION
   ├── Use named volumes (not bind mounts)
   ├── Place database volumes on SSD
   └── Avoid :Z label in Swarm (ignored anyway)

4. NETWORK OPTIMIZATION
   ├── Use overlay networks for Swarm
   ├── Keep services in same network
   └── Minimize external network calls

5. MONITORING
   ├── Enable Docker stats
   ├── Set up health checks
   └── Configure alerts for failures
```

### 8.3 Operational Best Practices

```
OPERATIONAL GUIDELINES:

DEPLOYMENT:
├── Always test in staging first
├── Keep compose files in version control
├── Document all environment variables
├── Use consistent naming conventions
└── Tag images for reproducibility

MAINTENANCE:
├── Schedule regular backups
├── Plan maintenance windows
├── Keep audit logs
├── Document runbooks
└── Test disaster recovery

UPDATES:
├── Read changelogs before updating
├── Backup data before updates
├── Test updates in staging
├── Have rollback plan ready
└── Update one service at a time
```

---

## 9. COMPOSE FILE REFERENCE

### 9.1 File Locations

```
dokploy-setup/
├── compose-files/
│   ├── nocobase-compose.yml    # NocoBase configuration
│   └── twenty-compose.yml      # Twenty CRM configuration
├── scripts/
│   ├── dev-manager.sh          # Development management script
│   └── install-browser.sh      # Browser installation for Playwright
└── automation/
    ├── deploy-nocobase.js      # Automated deployment script
    └── deploy-twenty.js        # Automated deployment script
```

### 9.2 Environment Variable Generation

```bash
# Generate all required secrets at once

echo "=== NocoBase Secrets ==="
echo "APP_KEY=$(openssl rand -hex 32)"
echo "ENCRYPTION_FIELD_KEY=$(openssl rand -hex 32)"

echo ""
echo "=== Twenty CRM Secrets ==="
echo "APP_SECRET=$(openssl rand -hex 32)"
echo "ACCESS_TOKEN_SECRET=$(openssl rand -hex 32)"
echo "LOGIN_TOKEN_SECRET=$(openssl rand -hex 32)"
echo "REFRESH_TOKEN_SECRET=$(openssl rand -hex 32)"
echo "FILE_TOKEN_SECRET=$(openssl rand -hex 32)"

echo ""
echo "=== Database Passwords ==="
echo "NOCOBASE_DB_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=')"
echo "TWENTY_DB_PASSWORD=$(openssl rand -base64 24 | tr -d '/+=')"
```

---

## 10. DIAGNOSTIC COMMANDS

### 10.1 Complete Diagnostic Script

```bash
#!/bin/bash
# Save as: diagnose.sh
# Usage: ./diagnose.sh > diagnostic-report.txt

echo "========================================"
echo "DOKPLOY ENVIRONMENT DIAGNOSTIC REPORT"
echo "Generated: $(date)"
echo "========================================"

echo ""
echo "=== SYSTEM INFORMATION ==="
echo "Hostname: $(hostname)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo "CPU: $(nproc) cores"
echo "RAM: $(free -h | awk '/^Mem:/{print $2}')"
echo "Disk: $(df -h / | awk 'NR==2{print $4 " available"}')"

echo ""
echo "=== DOCKER STATUS ==="
docker --version
docker info 2>/dev/null | grep -E "Server Version|Swarm|Operating System"

echo ""
echo "=== SWARM SERVICES ==="
docker service ls 2>/dev/null || echo "Swarm not active"

echo ""
echo "=== RUNNING CONTAINERS ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "=== CONTAINER RESOURCE USAGE ==="
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null | head -20

echo ""
echo "=== NETWORK STATUS ==="
docker network ls | grep -E "dokploy|overlay"

echo ""
echo "=== PORT BINDINGS ==="
ss -tulnp | grep -E ":80|:443|:3000|:13000|:13001" | head -10

echo ""
echo "=== SERVICE HEALTH CHECKS ==="
services=("http://localhost:3000|Dokploy" "http://localhost:13000|NocoBase" "http://localhost:13001|Twenty")
for svc in "${services[@]}"; do
    url=$(echo $svc | cut -d'|' -f1)
    name=$(echo $svc | cut -d'|' -f2)
    status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null)
    echo "$name: HTTP $status"
done

echo ""
echo "=== RECENT ERRORS (last 20 lines) ==="
for container in $(docker ps -q --filter "name=nocobase\|twenty\|dokploy" 2>/dev/null); do
    name=$(docker inspect --format '{{.Name}}' $container | tr -d '/')
    errors=$(docker logs $container 2>&1 | grep -i "error\|exception\|fatal" | tail -5)
    if [ -n "$errors" ]; then
        echo "--- $name ---"
        echo "$errors"
    fi
done

echo ""
echo "=== DISK USAGE BY CONTAINER ==="
docker system df -v 2>/dev/null | head -30

echo ""
echo "========================================"
echo "END OF DIAGNOSTIC REPORT"
echo "========================================"
```

### 10.2 Quick Commands Reference

```bash
# === CONTAINER MANAGEMENT ===
# List all containers
docker ps -a

# Follow logs
docker logs -f <container-id>

# Enter container shell
docker exec -it <container-id> /bin/sh

# Restart container
docker restart <container-id>

# === SWARM MANAGEMENT ===
# List services
docker service ls

# Inspect service
docker service inspect <service-name>

# View service logs
docker service logs <service-name> --tail 100

# Force service update (restart)
docker service update --force <service-name>

# Scale service
docker service scale <service-name>=3

# === NETWORK DIAGNOSTICS ===
# List networks
docker network ls

# Inspect network
docker network inspect <network-name>

# Test connectivity between containers
docker exec <container-a> ping <container-b>

# === VOLUME MANAGEMENT ===
# List volumes
docker volume ls

# Inspect volume
docker volume inspect <volume-name>

# Backup volume
docker run --rm -v <volume>:/data -v $(pwd):/backup alpine tar cvf /backup/backup.tar /data

# === CLEANUP ===
# Remove unused resources
docker system prune -af

# Remove unused volumes (CAUTION: data loss)
docker volume prune -f

# Remove unused images
docker image prune -af
```

---

## 11. KNOWN ISSUES & SOLUTIONS

### 11.1 Critical Issues Table

| Issue | Symptom | Root Cause | Solution |
|-------|---------|------------|----------|
| Twenty APP_SECRET | Server crashes immediately | Missing APP_SECRET env var | Add APP_SECRET to both server and worker |
| Playwright Chrome | "Browser not found" error | Missing system browser | Run install-browser.sh script |
| Docker Swarm SELinux | Volume permission denied | :Z label ignored in Swarm | Use named volumes instead of bind mounts |
| NocoBase .env | Config not loading | .env overwritten on start | Use environment: in compose, not env_file |
| Port conflict | Service won't start | Port already in use | Change port or stop conflicting service |

### 11.2 Version-Specific Issues

```
TWENTY CRM:
├── v1.16+ requires APP_SECRET (breaking change)
├── v1.15 and earlier: APP_SECRET optional
└── Always use twentycrm/twenty-postgres for DB

NOCOBASE:
├── v0.18+ changed environment variable names
├── Use official nocobase/nocobase image
└── Don't use data_only=True with openpyxl (wrong context but notable)

DOKPLOY:
├── v0.26+ improved compose support
├── Monaco editor for compose editing
└── Auto-cleanup only on main node (configure for workers)
```

---

## 12. SESSION TRANSCRIPT ANALYSIS

### 12.1 Timeline of Events

```
SESSION TIMELINE (2026-01-28):

1. INITIAL STATE
   - Dokploy v0.26.6 running
   - NocoBase and Twenty CRM pending deployment
   - Browser automation requested

2. PLAYWRIGHT MCP SETUP
   - Enabled plugin: /plugins enable playwright
   - Initial failure: Chromium not installed
   - Fixed: npx playwright install chromium
   - Still failed: /opt/google/chrome/chrome not found
   - Fixed: Created symlink script

3. NOCOBASE DEPLOYMENT
   - Created project via browser automation
   - Created Compose service
   - Pasted compose content
   - Deployed successfully (~41 seconds)
   - Verified at http://localhost:13000

4. TWENTY CRM DEPLOYMENT (First Attempt)
   - Created project
   - Created Compose service
   - Deployed
   - FAILED: "APP_SECRET is not set"

5. TWENTY CRM FIX
   - Identified missing APP_SECRET in logs
   - Updated compose file locally
   - Updated compose in Dokploy UI
   - Redeployed
   - SUCCESS: Running at http://localhost:13001

6. VERIFICATION
   - Both applications accessible
   - Health checks passing
   - Demo data loaded in Twenty
```

### 12.2 Key Learnings

```
CRITICAL LEARNINGS FROM THIS SESSION:

1. PLAYWRIGHT MCP BROWSER REQUIREMENT
   - Playwright MCP needs a real browser
   - On Fedora, use system Chromium
   - Create symlink to /opt/google/chrome/chrome
   - This is NOT documented clearly anywhere

2. TWENTY CRM APP_SECRET
   - v1.16+ REQUIRES APP_SECRET
   - Most example compose files are WRONG
   - Must be in BOTH server AND worker
   - 64-character hex string

3. DEPLOYMENT TIMING
   - NocoBase: ~1-2 minutes
   - Twenty: ~2-3 minutes
   - First deploy pulls images (longer)
   - Subsequent deploys faster

4. DOKPLOY UI NAVIGATION
   - Create Project → Open Project → Create Service
   - Compose tab for YAML editing
   - Save before Deploy
   - Confirm dialog before deployment

5. TROUBLESHOOTING APPROACH
   - Always check Logs tab first
   - Container selector in Logs tab
   - Look for "error" in logs
   - Check Deployments tab for build status
```

### 12.3 Files Created/Modified

```
FILES CREATED DURING SESSION:

1. /home/user/dokploy-setup/scripts/install-browser.sh
   - Browser installation script for Playwright
   - Creates symlink for Chrome path

2. /home/user/dokploy-setup/compose-files/twenty-compose.yml
   - MODIFIED: Added APP_SECRET environment variable
   - Added to both server and worker services

3. /home/user/dokploy-setup/.playwright-mcp/twenty-crm-deployed.png
   - Screenshot of successful Twenty CRM deployment
```

---

## APPENDIX A: QUICK START CHECKLIST

```
□ Step 1: System Prerequisites
  □ Linux system (Fedora/Ubuntu/Debian)
  □ 4GB+ RAM available
  □ 20GB+ disk space
  □ Ports 80, 443, 3000 free

□ Step 2: Install Dokploy
  □ curl -sSL https://dokploy.com/install.sh | sh
  □ Access http://localhost:3000
  □ Create admin account

□ Step 3: Setup Browser Automation (if needed)
  □ Enable Playwright MCP
  □ Install system browser (Fedora: dnf install chromium)
  □ Create Chrome symlink
  □ Verify browser works

□ Step 4: Deploy NocoBase
  □ Create project "nocobase"
  □ Create Compose service
  □ Paste compose YAML
  □ Deploy and verify at http://localhost:13000

□ Step 5: Deploy Twenty CRM
  □ Create project "twenty-crm"
  □ Create Compose service
  □ Paste compose YAML (WITH APP_SECRET!)
  □ Deploy and verify at http://localhost:13001

□ Step 6: Post-Deployment
  □ Create accounts in both apps
  □ Run health check script
  □ Configure backups
  □ Document credentials securely
```

---

## APPENDIX B: REFERENCES

### Official Documentation
- [Dokploy Documentation](https://docs.dokploy.com)
- [NocoBase Documentation](https://docs.nocobase.com)
- [Twenty CRM Self-Hosting](https://twenty.com/developers/section/self-hosting)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Playwright MCP](https://github.com/microsoft/playwright-mcp)

### Community Resources
- [Dokploy GitHub](https://github.com/Dokploy/dokploy)
- [Twenty CRM GitHub](https://github.com/twentyhq/twenty)
- [NocoBase GitHub](https://github.com/nocobase/nocobase)

### Troubleshooting Resources
- [Docker SELinux Labels](https://developers.redhat.com/articles/2025/04/11/my-advice-selinux-container-labeling)
- [Docker Swarm Volume Mounts](https://github.com/docker/docs/issues/2763)

---

## VERSION HISTORY

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-28 | Initial release based on deployment session |

---

**END OF SKILL DOCUMENT**
