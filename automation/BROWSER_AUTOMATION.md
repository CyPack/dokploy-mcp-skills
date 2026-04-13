# Claude Code Browser Automation Instructions

## For Use with Claude Code + Browser MCP

This document provides step-by-step instructions for Claude Code to automate Dokploy deployments via browser.

---

## Prerequisites

Before running browser automation:

```bash
# Verify Dokploy is running
curl -s http://localhost:3000 > /dev/null && echo "Dokploy OK" || echo "Dokploy not running"

# Verify ports are free
ss -tulnp | grep -E "13000|13001" || echo "Ports 13000 and 13001 are free"
```

---

## Task 1: Deploy NocoBase

### Browser Steps (for Claude Code with browser MCP)

1. **Navigate to Dokploy**
   - URL: `http://localhost:3000`
   - Wait for: Text "Projects" visible on page

2. **Create Project**
   - Click: Button with text "Create Project"
   - Fill input: Name = `nocobase`
   - Click: Button with text "Create" (in modal)
   - Wait: 2 seconds

3. **Open Project**
   - Click: Text `nocobase` (the project card)
   - Wait: 1.5 seconds

4. **Create Compose Service**
   - Click: Button with text "Create Service"
   - Wait: 1 second
   - Click: Text "Compose"
   - Wait: 2 seconds

5. **Configure Compose**
   - Click: Tab/Button with text "Compose"
   - Find: Text editor (Monaco editor or textarea)
   - Clear existing content (Ctrl+A)
   - Paste the following compose content:

```yaml
services:
  app:
    image: nocobase/nocobase:latest
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - APP_KEY=CHANGE_THIS_SECRET_KEY
      - ENCRYPTION_FIELD_KEY=CHANGE_THIS_ENCRYPTION_KEY
      - DB_DIALECT=postgres
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_DATABASE=nocobase
      - DB_USER=nocobase
      - DB_PASSWORD=CHANGE_ME_SECURE_PASSWORD
      - TZ=Europe/Amsterdam
      - APP_ENV=production
    volumes:
      - nocobase_storage:/app/nocobase/storage
    ports:
      - "13000:80"
    init: true

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

6. **Deploy**
   - Click: Button with text "Deploy"
   - Wait: Up to 5 minutes for deployment
   - Success indicator: Text "Running" appears

7. **Verify**
   - Open new tab: `http://localhost:13000`
   - Should see NocoBase setup page

---

## Task 2: Deploy Twenty CRM

### Browser Steps

1. **Navigate to Dokploy**
   - URL: `http://localhost:3000`
   - Wait for: Text "Projects" visible

2. **Create Project**
   - Click: Button "Create Project"
   - Fill input: Name = `twenty-crm`
   - Click: Button "Create"
   - Wait: 2 seconds

3. **Open Project**
   - Click: Text `twenty-crm`
   - Wait: 1.5 seconds

4. **Create Compose Service**
   - Click: Button "Create Service"
   - Click: Text "Compose"
   - Wait: 2 seconds

5. **Configure Compose**
   - Click: Tab "Compose"
   - Clear editor
   - Paste the following:

```yaml
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
      - SERVER_URL=http://localhost:13001
      - ACCESS_TOKEN_SECRET=798f83865f6ba45249165d557010ed16a2581fdd5e207b2b00c3143eadd045e1
      - LOGIN_TOKEN_SECRET=631a29e2aed9a571828128e3f3f476b37b326f384da06dd21251eaffb64e2708
      - REFRESH_TOKEN_SECRET=2c1f3ffaf53606dfb273708e3077080f7e04b371deeadcf71c007414096521e6
      - FILE_TOKEN_SECRET=093b3ed09f4d7cc96f36ffc2cd2fc5ab77a85c9b230a09d1ff291ec6fca0986f
      - PG_DATABASE_URL=postgres://postgres:CHANGE_ME_SECURE_PASSWORD@db:5432/twenty
      - REDIS_URL=redis://redis:6379
      - STORAGE_TYPE=local
      - STORAGE_LOCAL_PATH=.local-storage
    ports:
      - "13001:3000"
    volumes:
      - twenty_server_data:/app/.local-storage
      - twenty_docker_data:/app/docker-data

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
      - SERVER_URL=http://localhost:13001
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

6. **Deploy**
   - Click: Button "Deploy"
   - Wait: Up to 10 minutes (Twenty is larger)
   - Success: Text "Running" appears

7. **Verify**
   - Open: `http://localhost:13001`
   - Should see Twenty login/signup page

---

## Dokploy UI Selectors Reference

For automation tools:

| Element | Selector |
|---------|----------|
| Create Project Button | `button:has-text("Create Project")` |
| Project Name Input | `input[placeholder*="name" i]` or `input[name="name"]` |
| Create (modal) | `button:has-text("Create"):visible` |
| Create Service | `button:has-text("Create Service")` |
| Compose Option | `text=Compose` |
| Compose Tab | `[role="tab"]:has-text("Compose")` |
| Editor | `.monaco-editor` or `textarea` |
| Deploy Button | `button:has-text("Deploy")` |
| Running Status | `text=Running` |

---

## Verification Commands

After deployment, verify from terminal:

```bash
# Check containers
docker ps | grep -E "nocobase|twenty"

# Check NocoBase
curl -s http://localhost:13000 | head -20

# Check Twenty
curl -s http://localhost:13001 | head -20

# Check logs
docker logs $(docker ps -qf "name=nocobase") --tail 50
docker logs $(docker ps -qf "name=twenty-server") --tail 50
```

---

## Troubleshooting

### If deployment fails:

1. Check Dokploy logs:
   ```bash
   docker logs dokploy.1.$(docker service ps dokploy -q --no-trunc | head -1) --tail 100
   ```

2. Check available disk space:
   ```bash
   df -h /
   ```

3. Check memory:
   ```bash
   free -h
   ```

4. Restart and retry:
   ```bash
   docker service update --force dokploy
   ```
