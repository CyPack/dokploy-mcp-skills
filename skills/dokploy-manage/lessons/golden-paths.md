# dokploy-manage - Kanıtlanmış Yollar

> Bu dosyadaki her yol gerçek deployment'lardan öğrenildi.
> Yeni bir şey denerken ÖNCE buraya bak — tekerleği yeniden icat etme.

---

## 🔍 TABLO: Hangi Senaryoda Ne Yaparsın?

| Senaryo | Golden Path | Kritik Not |
|---------|-------------|-----------|
| Yeni proje + compose deploy | Compose Workflow (aşağı bak) | `/api/trpc/compose.update` + `x-api-key` header, compose-import KULLANMA |
| GitHub repo deploy | GitHub Workflow | nixpacks en güvenli build tipi |
| Docker image + env var | Compose YAML kullan | saveEnvironment MCP ÇALIŞMIYOR |
| "Connection failed" UI hatası | Playwright Investigation | Server OK olabilir, browser localStorage bak |
| WAHA deploy | WAHA-Specific Path | Port 3002, NOWEB engine, 3 farklı auth katmanı var |
| WAHA dashboard "not connected" | WAHA Dashboard Fix | Worker edit → API key güncelle |
| Compose deploy sonrası status=error | composeStatus Fix | Container'lar çalışıyorsa REST ile status=done set et |
| Proje sil | REST API (MCP'de yok) | `POST /api/trpc/project.remove` + `{"json":{"projectId":"..."}}` |
| Debug: UI hata var ama server OK | Playwright Investigation | Browser katmanına bak |
| Compose'u başka stack'in DB'sine bağla | External network | `ownpilot-znahub_default` veya `whatsapp-stack-fvpyro_default` external network olarak tanımla |
| pgAdmin/DBgate DB bağlantısı kur | DB Client Setup Path (aşağı bak) | UI + saved password → kalıcı; env var CONNECTIONS → DBgate için |
| Dokploy DB composeFile güncelle | psql UPDATE doğrudan | `docker exec dokploy-postgres psql -U dokploy -d dokploy` + UPDATE compose |
| Deploy sonrası servis çalışıyor mu? | Post-Deploy Verification (aşağı bak) | compose-one status + docker ps + curl health — üçü birden |

---

## DB Client Setup Path (pgAdmin + DBgate)

**Senaryo:** pgAdmin/DBgate'i mevcut DB container'larına bağla

**Ön koşul:** Her iki client container'ı external network'lere bağlı olmalı (`ownpilot-znahub_default`, `whatsapp-stack-fvpyro_default`)

| Adım | pgAdmin | DBgate |
|------|---------|--------|
| Network | compose'a `external: true, name: ownpilot-znahub_default` ekle | aynı |
| Bağlantı config | UI'dan Object > Register > Server; Name+Connection tab; Save password ✅ | compose env: `CONNECTIONS: CON1,CON2` + `ENGINE_CON1: postgres@dbgate-plugin-postgres` + `SERVER_CON1`, `USER_CON1`, `PASSWORD_CON1`, `DATABASE_CON1` (kısa format — `CONN_CON1_*` YANLIŞ!) |
| Kalıcılık | pgAdmin4.db volume'da (UI ile eklenen bağlantılar survive redeploy) | compose env var'lar Dokploy DB'de kalıcı |
| fill() tuzağı | fill() mevcut değere APPEND yapar! — önce JS ile `nativeInputValueSetter` set et | N/A |
| Dokploy DB güncelle | `docker exec $(docker ps -q -f name=dokploy-postgres) psql -U dokploy -d dokploy -c "UPDATE compose SET \"composeFile\"=\$yaml\$...\$yaml\$ WHERE \"composeId\"='ID';"` — dollar-quoting zorunlu, tırnak escape gerekmez | aynı |
| Dokploy MCP deploy | `compose-deploy(composeId)` → `{"success":true,"message":"Deployment queued"}` | aynı |
| S3/MinIO | pgAdmin desteklemiyor | DBgate Community'de `dbgate-plugin-s3` YOK — Enterprise only. MinIO Console port 9001 kullan |

**Referans bağlantılar:** OwnPilot=`ownpilot-postgres:5432`, WA Stack=`whatsapp_stack_db:5432`, MinIO=`whatsapp_stack_minio:9000`

**Tamamlanan deploy (2026-03-14):**
- pgAdmin `c6qCHi12QOpxI6b5uL3NV` → done, port 5050, UI'dan 2 sunucu kayıtlı (saved password, volume'da kalıcı)
- DBgate `evqJnGNWWT-Z4s0MQ-lM8` → done, port 3001, 3 CONNECTIONS env var aktif (CON1=OwnPilot, CON2=evolution, CON3=chatwoot)
- Credentials: `~/.claude/skills/dokploy-manage/references/disaster-recovery.md`

---

## 1. Compose Workflow (ANA GOLDEN PATH)

**Kullan:** Multi-service, env var gereken, docker-compose.yml ile çalışan her şey

```
Adım 1: project-create(name, description)
        → projectId ve environmentId döner (auto-oluşur)

Adım 2: compose-create(name, appName, projectId, environmentId)
        → composeId döner
        ⚠️ appName ve projectId ZORUNLU (dökümantasyonda yok ama gerekli)

Adım 3: REST API ile composeFile set et
        ⚠️  compose-update MCP ÇALIŞMIYOR, compose-import ASLA KULLANMA
        ⚠️  PATH: /api/trpc/compose.update  (NOT /api/compose.update)
        ⚠️  AUTH: x-api-key header          (NOT Authorization: Bearer)
        ⚠️  BODY: {"json": {...}} tRPC wrapper zorunlu

        DOKPLOY_KEY=$(python3 -c "import json; d=json.load(open('/home/ayaz/.claude.json')); print(d['mcpServers']['DokployServer']['env']['DOKPLOY_API_KEY'])")
        python3 -c "
        import json
        yaml_str = '''services:
          myapp:
            image: myimage:latest
            ...'''
        print(json.dumps({'json': {
          'composeId': 'COMPOSE_ID',
          'name': 'NAME',
          'appName': 'APPNAME',
          'composeFile': yaml_str,
          'sourceType': 'raw'
        }}))
        " | curl -s -X POST "http://localhost:3000/api/trpc/compose.update" \
          -H "x-api-key: $DOKPLOY_KEY" \
          -H "Content-Type: application/json" -d @-
        → Dönen JSON'da composeFile alanının dolu olduğunu doğrula: result.data.json.composeFile != ""

Adım 4: compose-deploy(composeId)
        → {"success": true, "message": "Deployment queued"} beklenir

Adım 5: 10 saniye bekle, status kontrol et:
        compose-one(composeId) → composeStatus: "running" → "done" beklenir
        VEYA: curl -s "http://localhost:3000/api/compose.one?composeId=X" -H "x-api-key: $KEY" | python3 -c "import json,sys; print(json.load(sys.stdin).get('composeStatus'))"

Adım 6: Container doğrula:
        docker ps --filter "name=CONTAINER_NAME"
        → "Up X seconds" + port mapping görünmeli

Adım 7: API/health test:
        curl http://localhost:PORT/health (veya /api/version vb.)
```

**Başarı kriteri:** `docker ps` → "Up" ve API → 200

---

## 2. WAHA Deploy (Spesifik)

**Image:** `devlikeapro/waha:latest` (Core, ücretsiz)
**Port:** 3002:3000 (Dokploy port 3000'i kullanıyor, çakışma)
**Engine:** NOWEB (browser gerektirmez, hafif)

```yaml
# docker-compose.yml içeriği
services:
  waha:
    image: devlikeapro/waha:latest
    container_name: waha
    ports:
      - "3002:3000"
    volumes:
      - waha_sessions:/app/.sessions
      - waha_media:/app/.media
    environment:
      - WAHA_API_KEY=OPENSSL_RAND_HEX_16        # API key (32 karakter hex)
      - WAHA_DASHBOARD_ENABLED=true
      - WAHA_DASHBOARD_USERNAME=admin
      - WAHA_DASHBOARD_PASSWORD=OPENSSL_RAND_HEX_12
      - WHATSAPP_SWAGGER_ENABLED=true
      - WHATSAPP_SWAGGER_USERNAME=admin
      - WHATSAPP_SWAGGER_PASSWORD=OPENSSL_RAND_HEX_12
      - WHATSAPP_DEFAULT_ENGINE=NOWEB
      - WAHA_LOG_FORMAT=PRETTY
      - TZ=Europe/Amsterdam
    restart: unless-stopped
    dns:
      - 1.1.1.1
      - 8.8.8.8
    logging:
      driver: json-file
      options:
        max-size: "100m"
        max-file: "10"
volumes:
  waha_sessions:
  waha_media:
```

**Credential oluştur:**
```bash
WAHA_API_KEY=$(openssl rand -hex 16)
DASHBOARD_PASS=$(openssl rand -hex 12)
SWAGGER_PASS=$(openssl rand -hex 12)
```

**Test:**
```bash
curl -H "X-Api-Key: WAHA_API_KEY" http://localhost:3002/api/version
# → {"version":"2026.2.2","engine":"NOWEB","tier":"CORE",...}
```

**Auth katmanları (KARIŞTIRma):**
- Layer 1: HTTP Basic Auth → Dashboard'a girmek için → `admin:DASHBOARD_PASS`
- Layer 2: Worker API Key → Dashboard'ın server'a konuşmak için → `WAHA_API_KEY`
- Layer 3: API Key header → Dış dünyadan API'ye erişim → `X-Api-Key: WAHA_API_KEY`
- Layer 2 = Layer 3 (aynı key), Layer 1 ayrı

**Playwright ile dashboard'a gir:**
```
browser_navigate("http://admin:DASHBOARD_PASS@localhost:3002/dashboard")
```

---

## 3. WAHA Dashboard "Server connection failed" Fix

**Senaryo:** Kullanıcı dashboard'da "not connected" / "Server connection failed" görüyor
**Server tarafı:** curl ile API çalışıyor, container Up

```
Adım 1: Playwright ile dashboard'a git
        browser_navigate("http://admin:DASHBOARD_PASS@localhost:3002/dashboard")

Adım 2: Screenshot al — Workers bölümündeki WAHA row'unda kırmızı ikon var mı?

Adım 3: Console'a bak (browser_console_messages):
        "Failed to load resource: 401 Unauthorized @ /api/version" → LocalStorage'da yanlış key

Adım 4: Browser snapshot → Workers table → WAHA row → Edit butonu (kalem ikonu, ref bul)
        ⚠️ Butonlar soldan sağa: Connect, API Key (disabled), Info (disabled), Refresh, Edit, Delete
        Edit = son iki butondan solda olanı (disabled olmayanlar arasında)

Adım 5: Edit butonuna tıkla → Dialog açılır:
        - Name: WAHA (değiştirme)
        - API URL: http://localhost:PORT (değiştirme)
        - API Key: "admin" veya yanlış değer var → SİL ve doğru WAHA_API_KEY yaz

Adım 6: API Key input'u temizle:
        browser_click(input_ref) → browser_press_key("Control+a") → browser_type(doğru_key)

Adım 7: Save butonuna tıkla

Adım 8: Screenshot → Workers: "1 connected" görünmeli
        Row: "NOWEB (2026.2.x CORE) HH:MM:SS up"
```

**Neden olur?** Dashboard browser localStorage'a worker config kaydeder. Server WAHA_API_KEY ile deploy edildi ama dashboard'da eski/yanlış key kayıtlıydı.

---

## 4. "UI Hata Var Ama Server OK" Investigation (Playwright)

**Senaryo:** Kullanıcı UI'da hata görüyor, curl ile API OK, container çalışıyor

```
Adım 1: Server-side test et (hızlı doğrula):
        docker ps → Up ✓
        curl -H "API-Key: KEY" http://localhost:PORT/health → 200 ✓

Adım 2: Sonuç → Katman 3 OK → Sorun Katman 4 (Browser/UI)
        HEMEN Playwright aç, "çalışıyor gibi görünüyor" DEME

Adım 3: browser_navigate → URL'e git
        ⚠️ Basic auth gerekliyse: http://user:pass@host/path

Adım 4: Screenshot → İlk görüntü nedir?

Adım 5: browser_console_messages → Hangi JS hataları var?
        "401" → localStorage'da yanlış API key
        "ERR_CONNECTION_REFUSED" → Yanlış endpoint/port
        "CORS" → Cross-origin sorun, proxy gerekebilir
        "SecurityError: replaceState" → URL auth sonrası redirect sorunu (önemli değil)

Adım 6: browser_network_requests → Hangi URL'lere istek gidiyor?
        Yanlış port? Yanlış base URL? Auth header eksik?

Adım 7: browser_snapshot → Hangi form/input alanları var? Config düzeltilebilir mi?

Adım 8: UI üzerinden fix uygula (form doldur, button tıkla, save)

Adım 9: Son screenshot → "connected" / çalışıyor mu?
```

---

## 5. composeStatus Düzeltme

**Senaryo:** Container çalışıyor ama Dokploy status=error gösteriyor

```bash
DOKPLOY_KEY=$(python3 -c "import json; d=json.load(open('/home/ayaz/.claude.json')); print(d['mcpServers']['DokployServer']['env']['DOKPLOY_API_KEY'])")
curl -s -X POST "http://localhost:3000/api/compose.update" \
  -H "x-api-key: $DOKPLOY_KEY" \
  -H "Content-Type: application/json" \
  -d '{"composeId":"COMPOSE_ID","composeStatus":"done"}'
```

Redeploy GEREKMEZ. Container'lar çalışıyorsa sadece status'ü düzelt.

---

## 6. Proje Silme (REST API — MCP'de yok)

```bash
DOKPLOY_KEY=$(python3 -c "import json; d=json.load(open('/home/ayaz/.claude.json')); print(d['mcpServers']['DokployServer']['env']['DOKPLOY_API_KEY'])")

# 1. Önce AskUserQuestion ile confirm al
# 2. İçindeki compose'ları sil (opsiyonel, deleteVolumes sorup)
# 3. Sonra projeyi sil
curl -s -X POST "http://localhost:3000/api/project.remove" \
  -H "x-api-key: $DOKPLOY_KEY" \
  -H "Content-Type: application/json" \
  -d '{"projectId":"PROJECT_ID"}'
```

---

## 7. GitHub Repo Deploy

```
project-create(name, description)
→ projectId + environmentId al

application-create(name, environmentId)
→ applicationId al

application-saveGithubProvider(applicationId, owner="user", repository="repo", branch="main")

application-saveBuildType(applicationId, buildType="nixpacks")

application-deploy(applicationId)

# Takip:
deployment-allByType(applicationId, "application")
→ status: "done" beklenir
```

---

## 8. Container Temizle / Yeniden Deploy

```
# Hızlı redeploy:
compose-redeploy(composeId)

# Durum kontrol:
docker ps --filter "name=APP"
docker logs APP --tail=50

# Tam sıfırlama (dikkatli):
compose-stop(composeId) → REST API composeFile güncelle → compose-deploy(composeId)
```

---

## 9. Deployment Sonrası Doğrulama Checklist

```
□ docker ps → container "Up" durumda mı?
□ Port mapping doğru mu? (HOST_PORT:CONTAINER_PORT)
□ curl health/version endpoint → 200 döndü mü?
□ Auth gerekliyse API key ile test et
□ Playwright ile UI'ı görsel kontrol et (hata bildirimi var mı?)
□ browser_console_messages → 0 critical error
□ Dokploy dashboard → composeStatus "done" mu?
```

---

## 10. Post-Deploy Verification — Feedback Loop (ZORUNLU)

**Her deploy sonrası otomatik çalıştır. Kanıtsız "tamamlandı" DEME.**

```bash
# verify-deploy.sh wrapper — Claude her deploy sonrası bunu çalıştırır
bash ~/.claude/skills/dokploy-manage/scripts/verify-deploy.sh <composeId> <port> [expected_http_code]

# Örnek: pgAdmin deploy sonrası
bash ~/.claude/skills/dokploy-manage/scripts/verify-deploy.sh c6qCHi12QOpxI6b5uL3NV 5050 302

# Çıktı (JSON):
# {"status":"SUCCESS","composeStatus":"done","httpCode":302,"containerUp":true,"accessUrl":"http://localhost:5050"}
# {"status":"FAILED","composeStatus":"error","error":"Deploy log: image pull failed","remediation":"check image name"}
```

**Akış:**
```
deploy() → compose-deploy(composeId)
         → verify-deploy.sh poll loop (max 5dk, 10s aralik)
         → composeStatus "done"? → HTTP health check
         → SUCCESS JSON → raporla
         → composeStatus "error"? → log çek → FAILED JSON → otomatik retry veya kullanıcıya sor
```

**Feedback → Recursive Fix:**
```
FAILED → son deployment log'u oku → hata nedenini parse et
       → Bilinen hata? (image not found, port conflict, network not found)
         → EVET: otomatik fix uygula + redeploy
         → HAYIR: kullanıcıya yapılandırılmış hata raporu sun
```

---

## 11. Compose Monitoring — Sürekli Sağlık Takibi

**Cron tabanlı, tüm Dokploy compose servislerini izler:**

```bash
# Manuel çalıştır
bash ~/.claude/skills/dokploy-manage/scripts/monitor-all.sh

# Cron (her 5 dakika, /var/spool/cron/crontabs/ayaz):
# */5 * * * * /home/ayaz/.claude/skills/dokploy-manage/scripts/monitor-all.sh >> /tmp/dokploy-monitor.log 2>&1
```

**State tracking:** `/tmp/dokploy-monitor-state.json` — önceki durum saklanır
**Geçiş algılama:** `running→error` veya `done→error` → WA bildirimi gönder
**WA channel:** Evolution API (localhost:8085), instance: `t4f`, numara: `31633196146`

---

## 12. Eski Kayıtlar (Küçük Senaryolar)

| Senaryo | Adımlar | Ön-koşul | Tarih |
|---------|---------|----------|-------|
| Template deploy | compose-templates → AskUser seçim → compose-deployTemplate(environmentId, templateId) | Proje/environment mevcut | 2026-02-12 |
| Backup zamanlama | compose-loadServices → backup-create(schedule="0 2 * * *", prefix, keepLatestCount=5) | composeId + serviceName | 2026-02-12 |
| Domain + SSL | domain-create(host, https=true, certificateType=letsencrypt) | DNS A record ayarlanmalı | 2026-02-12 |
| Rollback | deployment-allByType → önceki versiyonu bul → saveDockerProvider → redeploy | Deployment geçmişi var | 2026-02-12 |
| Container log debug | docker logs CONTAINER --tail=100 → "Error:" satırları → nedeni anla | Container name biliniyor | 2026-02-22 |
| compose tool enable | `~/.claude.json` args'a `"--enable-tools", "compose/"` ekle → restart | Config değişikliği | 2026-02-12 |
| Hafif compose kontrol | REST API + jq: `curl .../compose.one?composeId=X \| jq '{name,composeStatus}'` | API key | 2026-02-12 |
| Supabase migration (docker exec) | `docker exec -i supabase-...-db psql -U postgres -d postgres < migration.sql` | DB container Up, port 5432 host'a expose DEĞİL (docker exec zorunlu) | 2026-04-13 |
| Manuel docker-compose deploy | docker-compose.yml yaz → docker compose up -d → docker ps → curl test | Docker kurulu | 2026-02-22 |
| Chatwoot deploy | image=chatwoot/chatwoot:latest, REDIS_URL, SECRET_KEY_BASE, db:chatwoot_prepare | Docker, 4GB RAM | 2026-02-22 |
| Dokploy Swarm Full Restore | 1) firewalld stale binding fix → docker_gwbridge create 2) Temp PG container → ALTER USER password → docker secret create 3) docker network create overlay dokploy-network 4) docker service create dokploy-postgres (secret mount, volume) 5) docker service create dokploy-redis (volume) 6) docker service create dokploy (bind mounts: docker.sock + /etc/dokploy, secret, port 3000, env ADVERTISE_ADDR + POSTGRES_PASSWORD_FILE) 7) curl localhost:3000 → hasAdmin:true 8) MCP project-all verify | Docker Swarm active, volumes intact, /etc/dokploy intact | 2026-03-03 |
| docker_gwbridge Recreate | `firewall-cmd --zone=trusted --remove-interface=docker_gwbridge --permanent` + runtime → `docker network create --driver bridge --subnet 172.18.0.0/16 --gateway 172.18.0.1 --opt com.docker.network.bridge.name=docker_gwbridge --opt com.docker.network.bridge.enable_icc=false --opt com.docker.network.bridge.enable_ip_masquerade=true docker_gwbridge` → verify: `firewall-cmd --get-zone-of-interface=docker_gwbridge` = docker | Swarm active, firewalld running | 2026-03-03 |
| Docker GPU aktifleştirme | dnf install nvidia-container-toolkit → nvidia-ctk cdi generate → systemctl restart docker | NVIDIA driver | 2026-02-22 |
| Lokal registry | docker run -d -p 5000:5000 registry:2 → tag+push → compose'da localhost:5000/img kullan | Dokploy --pull always için | 2026-02-22 |
| GHCR image deploy (pre-built) | GHCR Image Compose Path (aşağı bak) | container_name KULLANMA, sourceType=raw ZORUNLU, extra_hosts | 2026-03-25 |
| App + DB compose (production) | Production Compose Checklist (aşağı bak) | Auth, TZ, log rotation, healthcheck, depends_on | 2026-03-25 |
| Vite/React SPA + Supabase backend | Vite + Supabase Path (aşağı bak) | Build-time ARG, local registry, migration docker exec, SPA nginx config | 2026-04-13 |
| Upstream GitHub repo (Dockerfile yok) | Custom Dockerfile + Local Registry | Repo clone → Dockerfile yaz → build → localhost:5000 push → compose image ref | 2026-04-13 |

---

## 13. GHCR / Docker Hub Pre-Built Image Deploy (Compose Workflow)

**Senaryo:** Pre-built GHCR/DockerHub image'ı Dokploy'a deploy et (SiYuan, OwnPilot, Gitea vb.)

**Bu path'i kullan:** Image zaten registry'de var, lokal build GEREKMEZ.

```
Adım 1: Image erişilebilir mi test et
        docker pull <registry>/<image>:<tag>
        Ör: docker pull ghcr.io/ownpilot/ownpilot:latest
            docker pull b3log/siyuan

Adım 2: project-create + compose-create (Golden Path #1 Adım 1-2)

Adım 3: REST API ile composeFile + sourceType set et
        ⚠️ sourceType: "raw" ZORUNLU — compose-create default "github" döner
        ⚠️ sourceType "github" kalırsa deploy FAIL eder (repo yok çünkü)
        ⚠️ compose-update MCP'de composeFile/sourceType parametresi YOK → REST API kullan

        curl payload'ında şu ikisi ZORUNLU:
        "sourceType": "raw"
        "composeFile": "<YAML string>"

Adım 4: compose-deploy → doğrula (Golden Path #1 Adım 4-7)
```

**Kritik öğrenim:** `compose-create` default `sourceType: "github"` ile oluşturur.
REST API ile `sourceType: "raw"` set etmezsen, deploy "no repository configured" benzeri hata verir.

---

## 14. Production Compose Best Practices Checklist (2026-03-25)

**Her yeni compose için bu checklist'i uygula:**

| # | Kural | Neden | Referans |
|---|-------|-------|----------|
| 1 | `container_name` KULLANMA | Dokploy resmi uyarı — redeploy'da name conflict error verir | Dokploy docs + OwnPilot deploy hatası (2026-03-25) |
| 2 | `restart: unless-stopped` | Dokploy stop komutu çalışabilsin, ama crash'te otomatik kalksin | Tüm mevcut compose'lar |
| 3 | `healthcheck` her servise | Dokploy monitoring + depends_on condition: service_healthy | DB: pg_isready, App: wget/curl |
| 4 | `start_period` yeterli ver | Migration/init süresi. DB: 10s, App: 15-30s | OwnPilot 30s (migration var) |
| 5 | `logging` driver + limits | Disk dolmasını önle | `json-file`, `max-size: 10m`, `max-file: 3` |
| 6 | `TZ=Europe/Amsterdam` | Log timestamp'ler doğru olsun | Her container'a ekle |
| 7 | `extra_hosts: host.docker.internal:host-gateway` | Container'dan host servislerine (MCP, Bridge vb.) erişim | Linux'ta zorunlu (macOS'ta otomatik) |
| 8 | Auth AÇIK (production) | `AUTH_TYPE=none` + `CORS_ORIGINS=*` = wide open API (CRITICAL risk) | Güvenlik audit (2026-03-25) |
| 9 | DB port'u host'a AÇMA | Sadece internal erişim yeterli, güvenlik için ports: bölümü olmasın | pgvector/postgres servisleri |
| 10 | `depends_on: condition: service_healthy` | App, DB hazır olmadan başlamasın | Multi-service compose'larda |

---

## 15. İlk Kurulum Sonrası Doğrulama Pattern'i

Bazı uygulamalar deploy sonrası ek kurulum/doğrulama gerektirir. Generic pattern:

```
1. Health endpoint kontrol: curl http://localhost:PORT/health
   → "degraded" dönerse: genellikle opsiyonel bir bağımlılık eksik (Docker socket, GPU vb.)
      database.connected: true = servis çalışıyor, degraded NORMAL olabilir

2. İlk kullanıcı/şifre ayarı: Bazı app'ler ilk deploy'da auth boş gelir
   → App'in docs'una bak: /setup, /auth/password, /api/v1/auth/register gibi endpoint'ler

3. DB migration: Bazı app'ler ilk deploy'da migration gerektir
   → docker exec <container> <migration_command>

4. Browser localStorage: Dashboard'lu app'lerde config browser'da saklanır
   → Server OK ama UI hata veriyorsa → Playwright ile browser katmanını kontrol et
```

---

## 16. Vite/React SPA + Supabase Backend Deploy (2026-04-13)

**Senaryo:** GitHub'daki bir Vite/React projesini Dokploy'a deploy et, mevcut Supabase instance'ını backend olarak kullan.
**Referans uygulama:** [marmelab/atomic-crm](https://github.com/marmelab/atomic-crm) — React Admin CRM, port 3015
**Detaylı rehber:** `deployments/atomic-crm/golden-path.md`

### Neden Bu Path?

- Repo'da Dockerfile YOK → kendin yazmalısın
- Vite `VITE_*` env var'larını BUILD TIME'da bake eder → runtime ENV çalışmaz
- Dokploy `--pull always` → Docker Hub'da image yoksa fail → local registry zorunlu
- Supabase zaten çalışıyor → yeni instance gereksiz, mevcut DB'ye migration uygula

### Akış (9 Adım)

```
1. git clone --depth=1 <repo> /tmp/<repo>

2. Dockerfile yaz (multi-stage: node:22-alpine builder → nginx:alpine)
   ⚠️ ARG VITE_X → ENV VITE_X=$VITE_X → RUN npm run build
   ⚠️ nginx SPA config: try_files $uri $uri/ /index.html

3. docker build --build-arg VITE_SUPABASE_URL="..." --build-arg VITE_SB_PUBLISHABLE_KEY="..." \
     -t localhost:5000/<app>:latest /tmp/<repo>

4. docker push localhost:5000/<app>:latest

5. MCP: project-create(name, description) → projectId + environmentId

6. MCP: compose-create(name, appName, projectId, environmentId) → composeId
   ⚠️ sourceType default "github" → DÜZELTMEK ZORUNLU

7. REST API: POST /api/compose.update
   Body: {"composeId":"...", "sourceType":"raw", "composeFile":"name: ...\nservices:\n  frontend:\n    image: localhost:5000/<app>:latest\n    ports:\n      - \"PORT:80\"\n"}
   Header: x-api-key: $DOKPLOY_KEY

8. Migration: docker exec -i supabase-...-db psql -U postgres -d postgres < migration.sql
   ⚠️ "already exists" hatası → CREATE OR REPLACE FUNCTION + DROP TRIGGER IF EXISTS

9. MCP: compose-deploy(composeId) → 20s bekle → docker ps + curl → HTTP 200
```

### Vite Build-Time Env Var Pattern (Dockerfile)

```dockerfile
FROM node:22-alpine AS builder
WORKDIR /app
# Dependencies (cached layer — package.json değişmedikçe tekrar çalışmaz)
COPY package*.json ./
RUN npm ci

# Build args — npm ci'den SONRA (cache optimization)
ARG VITE_SUPABASE_URL
ARG VITE_SB_PUBLISHABLE_KEY
ARG VITE_IS_DEMO=false
ARG VITE_ATTACHMENTS_BUCKET=attachments
ARG VITE_INBOUND_EMAIL

# ARG → ENV dönüşümü — Vite build time'da ENV okur
ENV VITE_SUPABASE_URL=$VITE_SUPABASE_URL
ENV VITE_SB_PUBLISHABLE_KEY=$VITE_SB_PUBLISHABLE_KEY
ENV VITE_IS_DEMO=$VITE_IS_DEMO
ENV VITE_ATTACHMENTS_BUCKET=$VITE_ATTACHMENTS_BUCKET
ENV VITE_INBOUND_EMAIL=$VITE_INBOUND_EMAIL

COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
# SPA routing — tüm path'leri index.html'e yönlendir
RUN printf 'server {\n    listen 80;\n    root /usr/share/nginx/html;\n    index index.html;\n    location / {\n        try_files $uri $uri/ /index.html;\n    }\n}\n' > /etc/nginx/conf.d/default.conf
EXPOSE 80
```

**Neden ARG → ENV → RUN?**
- `ARG` tek başına `RUN` komutlarında environment olarak kullanılabilir ama bazı build tool'ları (Vite/Webpack/esbuild) `process.env` üzerinden okur
- `ENV` ile explicit dönüşüm en güvenli yol — tüm senaryolarda çalışır
- ARG'ları `npm ci`'den SONRA declare et → dependency install layer'ı cache'lenmeye devam eder

### Supabase Self-Hosted Key Mapping

| Upstream .env (dev) | Self-Hosted Karşılığı | Format Farkı |
|---------------------|----------------------|--------------|
| `VITE_SUPABASE_URL=http://127.0.0.1:54321` | Supabase Kong external URL (Traefik domain) | Port değişir, domain olur |
| `VITE_SB_PUBLISHABLE_KEY=sb_publishable_*` | ANON_KEY (JWT `eyJ...` format) | `sb_publishable_*` = CLI local format, self-hosted = JWT |

### Migration Docker Exec Pattern

```bash
# Supabase DB host port'a expose DEĞİL (çoklu PG container çakışması)
# → docker exec ile container'a doğrudan bağlan
docker exec -i supabase-supabase-0qdhd3-supabase-db psql -U postgres -d postgres < migration.sql

# "already exists" hatası alan migration'lar için:
# CREATE FUNCTION → CREATE OR REPLACE FUNCTION
# CREATE TRIGGER → DROP TRIGGER IF EXISTS + CREATE TRIGGER
# CREATE INDEX → CREATE INDEX IF NOT EXISTS
```

### Başarı Kriteri

```bash
docker ps | grep atomic    # → Up, 0.0.0.0:3015->80/tcp
curl -s -o /dev/null -w "%{http_code}" http://localhost:3015/  # → 200
# İlk kullanıcı signup → otomatik admin olur
```

### Browser Erişim Ön Koşulları (Deploy Sonrası ZORUNLU)

Frontend deploy olduktan sonra browser'dan erişim için 3 koşul sağlanmalı:

```
1. /etc/hosts → Supabase traefik.me domain'i Traefik IP'sine yönlendirilmeli
   grep supabase /etc/hosts → "192.168.2.13 supabase-..." olmalı (127.0.0.1 DEĞİL!)
   Fix: sudo sed -i 's/127.0.0.1 supabase-.../192.168.2.13 supabase-.../' /etc/hosts

2. Traefik → Supabase network bağlı olmalı
   docker network connect supabase-supabase-0qdhd3 dokploy-traefik 2>/dev/null
   Test: curl -s -w "%{http_code}" http://supabase-...-traefik.me/rest/v1/ → 401 = OK

3. Supabase email autoconfirm AÇIK olmalı (mail container yoksa)
   docker exec supabase-...-auth env | grep GOTRUE_MAILER_AUTOCONFIRM → true
   Fix: docker stop/rm auth → ENABLE_EMAIL_AUTOCONFIRM=true docker compose up -d --no-deps auth
```

**Hızlı doğrulama scripti:**
```bash
# Deploy sonrası tek komutta 3 kontrol
docker network connect supabase-supabase-0qdhd3 dokploy-traefik 2>/dev/null
SB_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://supabase-supabase-7d9184-178-230-66-156.traefik.me/rest/v1/)
AUTH_CONF=$(docker exec supabase-supabase-0qdhd3-supabase-auth env 2>/dev/null | grep GOTRUE_MAILER_AUTOCONFIRM | cut -d= -f2)
echo "Supabase API: $SB_STATUS (401=OK) | AutoConfirm: $AUTH_CONF (true=OK)"
```
