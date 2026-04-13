# OwnPilot Dokploy Deployment Golden Path

> Bu dosya OwnPilot'a spesifik deploy bilgisi icerir.
> Generic Dokploy pattern'leri icin: `~/.claude/skills/dokploy-manage/lessons/golden-paths.md`
> Generic Dokploy hatalari icin: `~/.claude/skills/dokploy-manage/lessons/errors.md`

---

## 1. Temiz Kurulum (Sifirdan, GHCR Image)

### On Kosullar
- Dokploy calisiyoir (http://localhost:3000)
- DokployServer MCP aktif
- Port 8080 bos (baska container kullanmiyorsa)
- GHCR erisilebilir: `docker pull ghcr.io/ownpilot/ownpilot:latest` (test et)

### Adim Adim Kurulum

```
ADIM 1: GHCR image test
        docker pull ghcr.io/ownpilot/ownpilot:latest
        Beklenen: ~1.58 GB, node:22-alpine base, Chromium dahil
        BASARISIZ → internet baglantisi veya GHCR auth kontrol

ADIM 2: Dokploy proje olustur
        MCP: project-create(name="OwnPilot", description="OwnPilot vX.Y — Privacy-first AI assistant")
        Beklenen: projectId + environmentId (auto-olusur)
        NOT: Proje adi bosluk/ozel karakter ICERMEMELI

ADIM 3: Compose olustur
        MCP: compose-create(name="ownpilot", appName="ownpilot-app", projectId=<ADIM2>, environmentId=<ADIM2>)
        Beklenen: composeId + appName (Dokploy random suffix ekler: "ownpilot-app-XXXXXX")
        KRITIK: Donen appName'i KAYDET — volume isimleri bu prefix'i kullanir

ADIM 4: REST API ile composeFile + sourceType set et
        ⚠️ compose-create DEFAULT sourceType="github" doner — bu CALISMAZ
        ⚠️ compose-update MCP'de composeFile/sourceType FIELD'I YOK
        ⚠️ ZORUNLU: REST API ile sourceType="raw" + composeFile set et

        DOKPLOY_KEY=$(python3 -c "import json; d=json.load(open('/home/ayaz/.claude.json')); print(d['mcpServers']['DokployServer']['env']['DOKPLOY_API_KEY'])")

        COMPOSE_YAML='<ASAGIDAKI YAML REFERANSI>'

        COMPOSE_JSON=$(python3 -c "import json,sys; print(json.dumps(sys.stdin.read()))" <<< "$COMPOSE_YAML")

        curl -s -X POST "http://localhost:3000/api/trpc/compose.update" \
          -H "x-api-key: ${DOKPLOY_KEY}" \
          -H "Content-Type: application/json" \
          -d "{\"json\":{\"composeId\":\"<COMPOSE_ID>\",\"name\":\"ownpilot\",\"appName\":\"<APPNAME>\",\"sourceType\":\"raw\",\"composeFile\":${COMPOSE_JSON}}}"

        DOGRULAMA: Response JSON'da composeFile DOLU ve sourceType="raw" olmali
        BASARISIZ → PATH, AUTH, BODY formatini kontrol et (Golden Path #1 Adim 3 bak)

ADIM 5: Deploy
        MCP: compose-deploy(composeId=<COMPOSE_ID>)
        Beklenen: {"success": true, "message": "Deployment queued"}
        Sure: GHCR image cached ise ~7sn, ilk cekimde ~60sn

ADIM 6: Dogrulama (UCLU KONTROL — hepsi PASS olmali)
        a) MCP: compose-one(composeId) → composeStatus: "done"
           BASARISIZ (error) → deployment log oku: /etc/dokploy/logs/{appName}/
        b) docker ps --filter "label=com.docker.compose.project=<APPNAME>"
           → 2 container: ownpilot + ownpilot-db, STATUS: Up + (healthy)
           BASARISIZ → docker logs <container> --tail=50
        c) curl -s http://localhost:8080/health | python3 -m json.tool
           → {"success":true,"data":{"status":"degraded","version":"0.3.1","database":{"connected":true}}}
           "degraded" = NORMAL (Docker socket yok, sandbox=local mode)
           BASARISIZ → container log kontrol, POSTGRES env var'lar dogru mu?

ADIM 7: UI password ayarla (ILK KURULUMDA ZORUNLU)
        curl -s -X POST http://localhost:8080/api/v1/auth/password \
          -H "Content-Type: application/json" \
          -d '{"password":"<MIN_8_KARAKTER_SIFRE>"}'
        Beklenen: {"success":true,"data":{"message":"Password set","token":"...","expiresAt":"..."}}
        BASARISIZ → "No password configured" = zaten dogru, ilk kez set ediliyor
                  → "Password already configured" = zaten set edilmis, login kullan

ADIM 8: Browser'dan eris
        http://localhost:8080 → Login sayfasi → ADIM 7'deki sifre ile giris
        → "You're Ready!" dashboard gorunmeli
        → Sol menu: Chat, Dashboard, Analytics, Channels, Settings...
```

### Hata Durumlarinda Ne Yapilir

| Hata | Neden | Cozum |
|------|-------|-------|
| Deploy error: "no repository configured" | sourceType hala "github" | ADIM 4'u tekrarla, sourceType="raw" ZORUNLU |
| Deploy error: "container name already in use" | compose YAML'da container_name var | container_name satirlarini SIL, Dokploy kendi naming yapar |
| Port 8080 already in use | Baska container/process kullaniyoir | `docker ps \| grep 8080` ile bul, durdur veya port degistir |
| DB connection refused | ownpilot container, DB'den once baslamis | depends_on + condition: service_healthy ZORUNLU |
| Health "degraded" | Docker socket yok | NORMAL — database.connected=true ise sorun yok |
| UI "No password configured" | Ilk kurulum, sifre set edilmemis | ADIM 7'yi uygula |
| 401 Unauthorized (API) | API key yanlış veya AUTH_TYPE=none | API_KEYS env var kontrol, x-api-key header kullan |

---

## 2. Compose YAML Referans (2026-03-25 kanitlanmis, production-grade)

Her satirin neden oldugunu acikliyorum:

```yaml
services:
  ownpilot-db:
    image: pgvector/pgvector:pg16       # pgvector extension dahil, OwnPilot embedding icin kullanir
    # container_name YOK — Dokploy best practice, redeploy'da name conflict onler
    restart: unless-stopped              # Crash'te kalk, ama manual stop'ta kalma
    environment:
      - POSTGRES_USER=ownpilot
      - POSTGRES_PASSWORD=<GUCLU_SIFRE>  # Degistir! openssl rand -hex 16
      - POSTGRES_DB=ownpilot
      - TZ=Europe/Amsterdam              # Log timestamp'ler dogru olsun
    volumes:
      - ownpilot-pgdata:/var/lib/postgresql/data  # Named volume — Dokploy backup destekler
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ownpilot -d ownpilot"]
      interval: 10s                      # DB hizli baslar, sik kontrol OK
      timeout: 5s
      retries: 5
      start_period: 10s                  # Ilk boot'ta 10sn tolerans
    logging:
      driver: json-file
      options:
        max-size: "10m"                  # Disk dolmasini onle
        max-file: "3"                    # Max 30MB log

  ownpilot:
    image: ghcr.io/ownpilot/ownpilot:latest  # Pre-built, lokal build gereksiz
    # container_name YOK
    restart: unless-stopped
    ports:
      - "8080:8080"                      # UI + API tek portta
    extra_hosts:
      - "host.docker.internal:host-gateway"  # Container → host erisimi (MCP server'lar icin)
    environment:
      - NODE_ENV=production              # Production mode (DB credentials zorunlu olur)
      - PORT=8080
      - HOST=0.0.0.0                     # Tum interface'lerden erisilir
      - OWNPILOT_DATA_DIR=/app/data      # Container icindeki data dizini
      - POSTGRES_HOST=ownpilot-db        # Docker Compose service name ile DNS
      - POSTGRES_PORT=5432               # Container-internal port (host'a acik degil)
      - POSTGRES_USER=ownpilot
      - POSTGRES_PASSWORD=<GUCLU_SIFRE>  # DB ile AYNI sifre
      - POSTGRES_DB=ownpilot
      - AUTH_TYPE=api-key                # KRITIK: "none" = wide open API, ASLA production'da
      - API_KEYS=<API_KEY>               # Virgul-separated birden fazla key destekler
      - LOG_LEVEL=info                   # debug = cok verbose, warn = az bilgi
      - CORS_ORIGINS=http://localhost:8080  # KRITIK: "*" = herhangi site API'ye erisir
      - TZ=Europe/Amsterdam
    volumes:
      - ownpilot-data:/app/data          # App data: config, credentials, workspace, SOR files
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://127.0.0.1:8080/health"]
      interval: 30s                      # App daha yavas baslar, 30s yeterli
      timeout: 10s
      retries: 3
      start_period: 30s                  # Ilk boot'ta DB migration + schema init suresi
    depends_on:
      ownpilot-db:
        condition: service_healthy       # DB healthy olana kadar BEKLEME
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  ownpilot-pgdata:    # Dokploy prefix ekler: {appName}_ownpilot-pgdata
  ownpilot-data:      # Dokploy prefix ekler: {appName}_ownpilot-data
```

---

## 3. Guvenlik Kontrol Listesi

| # | Kontrol | Dogru Deger | Yanlis Deger | Risk |
|---|---------|-------------|-------------|------|
| 1 | AUTH_TYPE | api-key veya jwt | none | CRITICAL — API tamamen acik |
| 2 | CORS_ORIGINS | http://localhost:8080 | * | HIGH — herhangi site API'ye erisir |
| 3 | API_KEYS | guclu, rastgele, min 32 char | basit, tahmin edilebilir | HIGH |
| 4 | POSTGRES_PASSWORD | openssl rand -hex 16 | ownpilot, 123456 | HIGH — DB acik |
| 5 | HOST | 0.0.0.0 (firewall ile koruma) | 0.0.0.0 (firewall YOK) | MEDIUM |
| 6 | DB port | host'a ACIK DEGIL | ports: "5432:5432" | MEDIUM |
| 7 | container_name | YOK (Dokploy yonetir) | container_name: ownpilot | LOW ama deploy kirar |
| 8 | TZ | Europe/Amsterdam | UTC (default) | LOW — log okuma zorluğu |

---

## 4. Volume Yonetimi

Dokploy volume naming: `{appName}_{volumeName}`
Ornek: appName=ownpilot-app-zfst6b → volumes:
- `ownpilot-app-zfst6b_ownpilot-pgdata` (DB)
- `ownpilot-app-zfst6b_ownpilot-data` (App data)

**Backup:**
```bash
# DB logical dump (onerilen — portable)
docker exec <db-container> pg_dump -U ownpilot -d ownpilot --format=custom --compress=9 > backup.custom

# Volume raw backup
docker run --rm -v <volume-name>:/data -v /path/to/backup:/backup alpine tar czf /backup/vol.tar.gz -C /data .
```

**Restore:**
```bash
# DB restore
docker exec -i <db-container> pg_restore -U ownpilot -d ownpilot --clean < backup.custom

# Volume restore
docker run --rm -v <volume-name>:/data -v /path/to/backup:/backup alpine tar xzf /backup/vol.tar.gz -C /data
```

---

## 5. Upgrade Stratejisi

OwnPilot GHCR image guncellendiginde:
```
1. Backup al (ADIM 4 — Volume Yonetimi)
2. compose-one ile mevcut composeFile oku
3. image tag'ini guncelle (latest veya spesifik versiyon)
4. REST API ile composeFile guncelle
5. compose-deploy
6. Uclu dogrulama (ADIM 6)
7. DB migration otomatik (initializeSchema — idempotent)
```

Downgrade/Rollback:
```
1. Image tag'ini eski versiyona dondur
2. compose-deploy
3. DB rollback MANUAL gerekebilir (migration geri alinamaz)
   → Backup'tan restore et
```

---

## 6. Claude Code Entegrasyonu (API KEY OLMADAN)

### Kural: ANTHROPIC_API_KEY ASLA KULLANILMAYACAK

OwnPilot Claude Code'u 3 modda destekliyor:

| Mod | API Key Gerekli | OAuth ile Calisir | Docker Uyumu | Onerilen |
|-----|----------------|-------------------|-------------|----------|
| SDK (in-process) | EVET (ZORUNLU) | HAYIR | Kolay | KULLANILAMAZ |
| PTY (CLI spawn) | HAYIR | EVET | ZOR (CLI + creds mount) | ALTERNATIF |
| ACP bridge | EVET (SDK'ya bagli) | HAYIR | ZOR | KULLANILAMAZ |

### En Pratik Yol: Bridge Entegrasyonu

OpenClaw Bridge (host port 9090) zaten OAuth ile Claude Code spawn ediyor.

```
OwnPilot Container → HTTP POST host.docker.internal:9090/v1/chat/completions
  → Bridge → Claude Code (OAuth session, API key YOK)
  → Yanit → OwnPilot
```

Gereksinimler:
- Bridge calisiyoir (systemd: openclaw-bridge.service)
- extra_hosts compose'da tanimli (host.docker.internal)

### CALISAN KONFIGÜRASYON (2026-03-26, E2E 8/10 PASS):

```sql
-- 1. local_providers (TEK KAYIT — tum provider config burda)
INSERT INTO local_providers (id, provider_type, base_url, is_enabled, is_default)
VALUES ('bridge-claude', 'custom', 'http://host.docker.internal:9090/v1', true, true);

-- 2. settings (JSON-encoded ZORUNLU — raw string CALISMAZ!)
INSERT INTO settings (key, value) VALUES ('default_ai_provider', '"bridge-claude"');
INSERT INTO settings (key, value) VALUES ('default_ai_model', '"bridge-model"');
-- NOT: Value'lar DIS tirnak dahil: '"bridge-claude"' — JSON.stringify sonucu
-- RAW 'bridge-claude' yazarsan cache JSON.parse fail → null → chat BOZULUR!
```

KRITIK KURALLAR:
- `default_ai_provider = openai` KULLANMA → OwnPilot preset baseUrl='https://api.openai.com/v1' HARDCODED
- `default_ai_provider = bridge-claude` KULLAN → local_providers'a duser → dogru Bridge URL
- Settings degerlerini ASLA raw SQL INSERT ile yazma → JSON-encode et veya API kullan
- custom_providers GEREKSIZ → local_providers yeterli (temiz config)

Bridge baglanti testi:
```bash
docker exec ownpilot-app-zfst6b-ownpilot-1 wget -qO- http://host.docker.internal:9090/ping
# Beklenen: {"pong":true}
```

Session resume KNOWN LIMITATION:
- OwnPilot full messages[] array gonderiyor (100k token)
- Bridge sadece SON user mesajini aliyor, onceki mesajlari YOKSAYIYOR
- CC her istekte SIFIRDAN basliyor (onceki context YOK)
- Fix: Bridge tarafinda messages[] forwarding veya X-Conversation-Id desteği gerekli

### Alternatif: Container'a Claude CLI + OAuth Mount

```yaml
# Compose'a eklenecek volume mount'lar:
volumes:
  - ownpilot-data:/app/data
  - /home/ayaz/.claude/.credentials.json:/home/ownpilot/.claude/.credentials.json:ro
```

Container icinde claude CLI kurulumu:
```bash
docker exec <container> npm install -g @anthropic-ai/claude-code
```

Sonra OwnPilot Coding Agents sayfasindan interactive PTY session aciilabilir.
Dezavantaj: OAuth token expire olabilir, container'da refresh mekanizmasi yok.

---

## 7. Host Filesystem + MCP Entegrasyon (Opsiyonel)

Container'dan host MCP server'larina erisim:

| MCP Server | Erisim Adresi | Not |
|------------|--------------|-----|
| Voorinfra | http://voorinfra-mcp:8766/mcp | Ayni Docker network'te ise |
| Evolution API | http://host.docker.internal:8765/mcp | Host'ta calisiyor |
| Bridge | http://host.docker.internal:9090 | Host'ta systemd |
| SiYuan | http://host.docker.internal:6806 | Host'ta container |

Host dosya sistemine erisim (bind mount):
```yaml
volumes:
  - /home/ayaz/projects:/host/projects:ro        # Projeler (read-only)
  - /home/ayaz/.claude/skills:/host/skills:ro     # Skills (read-only)
  - /home/ayaz/.claude/rules:/host/rules:ro       # Rules (read-only)
```

ASLA mount ETME:
- `~/.ssh/`, `~/.gnupg/` (private key'ler)
- `~/.claude.json` (API key'ler, bearer token'lar)
- `/var/run/docker.sock` (host ROOT erisimi)
- `.env` dosyalari (secret'lar)

OwnPilot filesystem tool'lari varsayilan olarak sadece WORKSPACE_DIR + /tmp'ye erisir.
Bind mount'lanan dizinlere erisim icin: EXTRA_ALLOWED_PATHS env var veya kod degisikligi gerekir.

---

## 8. Mevcut Deploy Referans (2026-03-25)

| Bilgi | Deger |
|-------|-------|
| Dokploy Project | OwnPilot (WAsjX1dMKdK3cVRPPK0sx) |
| Compose | ownpilot (5D5V14E1ESPb0pdSbrSN6) |
| appName | ownpilot-app-zfst6b |
| Environment | production (97Vll5hed7aKJjEfrvSHo) |
| Image | ghcr.io/ownpilot/ownpilot:latest (v0.3.1) |
| UI | http://localhost:8080 |
| UI Password | OwnPilot2026! |
| API Key | op-2026-secure-key-ayaz (x-api-key header) |
| DB | pgvector/pg16, user=ownpilot, db=ownpilot |
| Containers | ownpilot-app-zfst6b-ownpilot-1, ownpilot-app-zfst6b-ownpilot-db-1 |
| Volumes | ownpilot-app-zfst6b_ownpilot-pgdata, ownpilot-app-zfst6b_ownpilot-data |
| Eski compose (error) | bs4fm7QMkxuoyA4DxqO-0 (MCP Tools projesi, deleteVolumes=false ile silinebilir) |
| Eski volumes | ownpilot-znahub_* (backup verisi, migration icin sakli) |
| Full backup | ~/backups/2026-03-24-ownpilot-full/ (MANIFEST.md ile, 1.1 GB) |
