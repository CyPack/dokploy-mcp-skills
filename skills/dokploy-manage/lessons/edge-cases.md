# dokploy-manage - Edge Cases & Tuzaklar

---

## ⚡ KURAL 0 — PLAYWRIGHT OTO-TETİK

```
Kullanıcı hata bildirdi + Sen sunucu tarafında sorun görmüyorsun
→ HEMEN Playwright ile UI'a git
→ "Çalışıyor gibi görünüyor" DEME, GİT BAK
```

Neden? Sorun sunucuda değil tarayıcıda/localStorage'da olabilir.
Örnek: WAHA "Server connection failed" → container Up → sorun dashboard'ın localStorage'ındaki yanlış API key

---

## 🏗️ YAPI: Multi-Katmanlı Auth (Çok Yaygın Tuzak)

Birçok modern web uygulaması birden fazla auth katmanına sahiptir:

```
┌─────────────────────────────────────────────┐
│  Browser / Dashboard UI                     │
│  → Config localStorage'da (server'da değil)│
│  → "Connection failed" buradan gelir        │
├─────────────────────────────────────────────┤
│  Application API (REST)                     │
│  → Bearer token / API key                   │
│  → curl ile test edilebilir                 │
├─────────────────────────────────────────────┤
│  Docker Container                           │
│  → Env vars, port mapping, volumes          │
│  → docker ps / docker logs ile test         │
└─────────────────────────────────────────────┘
```

**Kural:** curl OK + UI hata = Browser katmanı sorunu → Playwright ile bak

---

## 🔐 WAHA'ya Özgü Tuzaklar

### Tuzak 1: Dashboard LocalStorage vs Server Env

WAHA Dashboard, worker konfigürasyonunu (URL + API key) **tarayıcı localStorage'ında** saklar:
- Server env: `WAHA_API_KEY=abc123` → curl -H "X-Api-Key: abc123" → çalışır
- Dashboard localStorage: worker config `api_key: "admin"` → 401 alır
- Bu **aynı sorun değil**, ayrı katmanlar

**Diagnosis:** Console'da `401 @ /api/version` → dashboard localStorage sorunu
**Fix:** Workers → Edit → API Key güncellemek (Playwright ile)

### Tuzak 2: Dashboard Erişimi Basic Auth

Dashboard URL'ine normal gidince Playwright `ERR_INVALID_AUTH_CREDENTIALS` atar:
```
# YANLIŞ:
browser_navigate("http://localhost:3002/dashboard")

# DOĞRU:
browser_navigate("http://admin:DASHBOARD_PASSWORD@localhost:3002/dashboard")
```

### Tuzak 3: Port 3000 Çakışması

Dokploy kendisi port 3000'de çalışır. WAHA da default 3000. **Her zaman 3002 kullan:**
```yaml
ports:
  - "3002:3000"  # HOST:CONTAINER
```

### Tuzak 4: SecurityError replaceState (Zararsız)

Dashboard'a basic auth ile gidince console'da:
```
SecurityError: Failed to execute 'replaceState'...
```
Bu zararsız bir Nuxt.js/history API sorunu. "Connection failed" ile ilgisi yok, ignore et.

### Tuzak 5: Worker Edit Butonu Sırası

Workers table'daki action butonları (soldan sağa):
1. Connect (her zaman aktif)
2. API Key göster (SADECE connected iken aktif)
3. Info (SADECE connected iken aktif)
4. Refresh (her zaman aktif)
5. **Edit** (her zaman aktif — bunu kullan)
6. Delete (her zaman aktif)

Snapshot'ta disabled butonların hangisi olduğuna dikkat et. Edit = son 3 butondan solda.

---

## 🐳 Docker Compose Tuzakları

| Durum | Çözüm | Tarih |
|-------|-------|-------|
| `version is obsolete` uyarısı | `version:` satırını kaldır, artık gerekmiyor | 2026-02-22 |
| Container Exited(1) ama log boş | `docker inspect CONTAINER` → Env bölümü → env var'lar var mı? | 2026-02-22 |
| Health check başarısız ama container çalışıyor | start_period yetersiz (en az 60s), interval çok kısa | 2026-02-22 |
| Named volume vs bind mount | Docker Swarm'da bind mount permission sorunlu → named volume kullan | 2026-02-22 |
| compose-update composeFile güncellenmiyor | MCP bug → REST API ile gönder | 2026-02-22 |
| application-saveEnvironment → container'da yok | MCP → Swarm iletim sorunu → compose YAML environment: bölümüne yaz | 2026-02-22 |
| Dokploy `--pull always` lokal image bulamıyor | Lokal registry kur (port 5000), image tag+push, compose'da localhost:5000/img kullan | 2026-02-22 |
| compose-import base64 hatası | MCP yanlış parse ediyor → REST API ile composeFile set et | 2026-02-22 |
| Dokploy proje var ama app/compose yok | Manuel container'lar Dokploy dışında deploy edilmiş | 2026-02-22 |
| Docker daemon restart sonrası TÜM Swarm service'ler kayboldu | docker_gwbridge firewalld ZONE_CONFLICT nedeniyle Swarm ingress oluşamadı → service'ler başlatılamadı. Volume'ler ve /etc/dokploy dosyaları SAĞLAM kaldı. Full restore prosedürü golden-paths.md'de. | 2026-03-03 |
| PG password bilinmiyor (secret kayıp) | Temp container + local trust auth ile password reset: `docker run --rm -d -v dokploy-postgres:/var/lib/postgresql/data postgres:16` → `docker exec psql -U dokploy -c "ALTER USER..."` → stop → new secret create | 2026-03-03 |
| Supabase container'lar Exited(255) Docker restart sonrası | restart:unless-stopped policy Docker daemon restart'ta container'ları kurtarmıyor. Manuel `docker compose up -d` gerekli. | 2026-03-03 |
| Evolution API "unhealthy" ama container Up | Healthcheck endpoint `/health` yerine `/` olmalı. Docker healthcheck config'inde değiştirilmeli. | 2026-03-03 |
| Traefik container Swarm restart sonrası kayıp | Traefik regular container olarak çalışıyor (Swarm service değil). Docker restart sonrası elle başlatılmalı. /etc/dokploy/traefik/traefik.yml mevcut. Restore komutu: `docker run -d --name traefik --restart unless-stopped -e DOCKER_API_VERSION=1.44 -p 80:80 -p 192.168.2.13:443:443 -v /var/run/docker.sock:/var/run/docker.sock:ro -v /etc/dokploy/traefik/traefik.yml:/etc/traefik/traefik.yml:ro -v /etc/dokploy/traefik/dynamic:/etc/dokploy/traefik/dynamic --network dokploy-network traefik:v3.3.0` | 2026-03-03 |
| Traefik Docker/Swarm provider "client version 1.24 is too old" (Docker 29.x+) | Docker 29.x minimum API 1.44, Traefik'in Go Docker SDK'sı v1.24 kullanıyor. DOCKER_API_VERSION=1.44 env var yeterli değil. Container çalışıyor ama label-tabanlı servis discovery bozuk. File provider çalışıyor. Fix: Tecnativa docker-socket-proxy (tcp://socket-proxy:2375) + traefik.yml'de endpoint güncelle. Port 443 için: Tailscale 100.75.115.68:443 kullandığı için 0.0.0.0:443 bind BAŞARISIZ → 192.168.2.13:443 (LAN IP) kullan. | 2026-03-03 |

---

## 🗄️ DB Client Tools Edge Cases (pgAdmin + DBgate) — 2026-03-14

### DBgate: CONN_CON1_* vs ENGINE_CON1 (KRİTİK TUZAK)

DBgate Community Edition env var formatı KARMAŞIKtır, kaynak kodundan okunmadan anlaşılmaz:

```
# YANLIŞ (çalışmaz — "missing ENGINE" hatası):
CONN_CON1_ENGINE=postgres@dbgate-plugin-postgres
CONN_CON1_SERVER=myhost

# DOĞRU (extractConnectionsFromEnv şu formatı okur):
ENGINE_CON1=postgres@dbgate-plugin-postgres
SERVER_CON1=myhost
USER_CON1=myuser
PASSWORD_CON1=mypass
PORT_CON1=5432
DATABASE_CON1=mydb    ← opsiyonel, defaultDatabase için
LABEL_CON1=Bağlantı Adı
```

`CONNECTIONS=CON1,CON2,CON3` ile birlikte kullanılır. ID herhangi bir string olabilir.

### DBgate: "Could not get driver from connection" vs "Engine driver undefined not found"

Bu iki farklı hata aynı kök nedenden gelir (yanlış env var formatı):
- `"Engine driver undefined not found"` → engine field null, plugin var ama engine tanımlanamamış
- `"Could not get driver from connection"` → engine boş/undefined ile bağlanmaya çalışıyor

Her ikisi de `ENGINE_{ID}=postgres@dbgate-plugin-postgres` ile düzelir.

### pgAdmin: servers.json Sadece Fresh Volume'de Çalışır

`PGADMIN_SERVER_JSON_FILE` env var sadece `pgadmin4.db` hiç yokken işlenir.
Volume'de pgadmin4.db mevcutsa (önceki deploy, UI login) → servers.json TAMAMEN YOKSAYILIR.

```
# Tuzak: Container yeniden oluşturuldu ama volume kaldı → servers.json etkisiz
# Çözüm: pgAdmin UI → Object > Register > Server → Save password ✅
# Saved password pgadmin4.db'de şifrelenerek kalır, redeploy'dan etkilenmez
```

### pgAdmin: fill() React Input Append Bug

pgAdmin form inputları React controlled component. Playwright `fill()` mevcut değeri temizlemez, üstüne yazar:
```
# Senaryo: Hostname alanında "postgres" var, "ownpilot-postgres" yazacaksın
# fill("ownpilot-postgres") → "postgresownpilot-postgres" (YANLIŞ!)

# Fix: JS ile React'ın nativeInputValueSetter'ını kullan:
evaluate("""
  const input = document.querySelector('input[name="host"]');
  const nativeSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
  nativeSetter.call(input, 'ownpilot-postgres');
  input.dispatchEvent(new Event('input', {bubbles: true}));
""")
```

### Dokploy compose-update MCP: composeFile Field Yok

`compose-update` MCP tool sadece `name`, `appName`, `description` field'larını günceller. `composeFile` YOKTUR.

**Tek yol: Doğrudan psql UPDATE** (dollar-quoting ile):
```bash
docker exec $(docker ps -q -f name=dokploy-postgres) psql -U dokploy -d dokploy -c \
  "UPDATE compose SET \"composeFile\"=\$yaml\$...\$yaml\$ WHERE \"composeId\"='ID';"
```

---

## 🔌 Dokploy tRPC API Edge Cases (2026-03-14)

| Durum | Çözüm | Tarih |
|-------|-------|-------|
| `compose-import` YAML base64 → "Unexpected token 's'" | compose-import JSON bekliyor, YAML gönderilemez | **compose-import KULLANMA** — `/api/trpc/compose.update` kullan | 2026-03-14 |
| `compose-import` JSON base64 → "Cannot read properties undefined" | Tam template schema gerekli (id, links, variable dahil) — çok karmaşık | **compose-import KULLANMA** — REST API ile composeFile set et | 2026-03-14 |
| `POST /api/compose.update` → 401 Unauthorized | tRPC prefix eksik. Doğru: `/api/trpc/` prefix | `curl -X POST http://localhost:3000/api/trpc/compose.update` | 2026-03-14 |
| `Authorization: Bearer KEY` → 401 Unauthorized | Dokploy `x-api-key` header bekliyor, Bearer kabul etmiyor | `-H "x-api-key: $DOKPLOY_KEY"` kullan | 2026-03-14 |
| `/api/auth.signIn` → Unauthorized | Session cookie auth MCP dışından çalışmıyor | API key: `python3 -c "import json; d=json.load(open('~/.claude.json')); print(d['mcpServers']['DokployServer']['env']['DOKPLOY_API_KEY'])"` | 2026-03-14 |
| tRPC body formatı | `{"composeId":"..."}` değil, `{"json": {"composeId":"..."}}` zorunlu | Her tRPC POST body'si `{"json": {...}}` ile sarılmalı | 2026-03-14 |
| compose-create appName Dokploy suffix ekler | appName'e Dokploy random suffix ekler: `pgadmin-tools` → `pgadmin-tools-bxuttx` | compose-create response'tan actual appName oku, hardcode etme | 2026-03-14 |
| Compose'u başka stack'in network'üne bağlama | `external: true + name: {appName}_default` ile mümkün. appName = Dokploy'un compose appName'i | `docker network ls` ile ağ adını doğrula. ownpilot: `ownpilot-znahub_default`, WA stack: `whatsapp-stack-fvpyro_default` | 2026-03-14 |
| GHCR/DockerHub pre-built image kullanimi (lokal build bypass) | Bazi uygulamalar (OwnPilot, SiYuan, vb.) GHCR/DockerHub'da hazir image sunar. `docker pull` + compose YAML'da `image:` referans → lokal build gereksiz, 10-15dk tasarruf | Once `docker pull <registry>/<image>:<tag>` ile erisilebilirlik test et. Auth gerekiyorsa `docker login <registry>`. Compose'da image tag'ini explicit yaz (`latest` yerine spesifik versiyon tercih et) | 2026-03-25 |
| Health endpoint "degraded" donebilir — HATA DEGIL | Bazi container'lar (OwnPilot vb.) opsiyonel dependency eksik olunca "degraded" doner (ornegin Docker socket yok → sandbox local mode). database.connected=true ise servis CALISIYOR | Health response'u parse et: `status` field'i "pass"/"degraded"/"fail" olabilir. "degraded" → opsiyonel feature eksik, core fonksiyon OK. "fail" → gercek sorun | 2026-03-25 |
| compose-create sonrasi sourceType kontrol etmeden deploy etme | compose-create default sourceType="github" doner. Hemen compose-deploy yaparsan "no repository" benzeri hata alirsin | compose-create SONRASI her zaman REST API ile sourceType="raw" set et (raw YAML compose icin). compose-one ile dogrula | 2026-03-25 |
| Dokploy volume naming convention: {appName}_{volumeName} | Compose YAML'daki volume ismi (ornekin `ownpilot-pgdata`) Dokploy tarafindan `{appName}_ownpilot-pgdata` olarak olusturulur. appName degisirse (yeni proje/compose) volume isimleri de degisir → eski volume'deki veri OTOMATIK GELMEZ | Volume migration gerekiyorsa: `docker run --rm -v old_vol:/from:ro -v new_vol:/to alpine cp -a /from/. /to/`. VEYA compose YAML'da `volumes: { ownpilot-pgdata: { external: true, name: eski_volume_adi } }` ile external volume kullan | 2026-03-25 |
| container'dan host servislerine erisim (Linux) | Linux'ta container icinden localhost/127.0.0.1 HOST'u degil CONTAINER'in kendisini gosterir. Host'taki MCP server, Bridge vb. servislere erisilemez | compose YAML'a `extra_hosts: ["host.docker.internal:host-gateway"]` ekle. Container icinden `host.docker.internal:PORT` ile host servislerine eris. macOS'ta bu otomatik var, Linux'ta ZORUNLU | 2026-03-25 |

---

## 🌐 API / Auth Edge Cases

| Durum | Çözüm | Tarih |
|-------|-------|-------|
| Evolution API DATABASE_PROVIDER boş/yanlış | Geçerli: postgresql, mysql, psql_bouncer. sqlite/false çalışmaz | 2026-02-22 |
| application-deploy sonrası "Unexpected end of JSON" | Deploy başlamış olabilir, application-one ile kontrol et | 2026-02-22 |
| MCP config değişikliği etkisiz | Deferred tools session başında cache'leniyor → kapat-aç | 2026-02-22 |
| compose-create "appName/projectId required" | name, appName, projectId, environmentId → hepsini ver | 2026-02-22 |
| domain-create tüm parametreler zorunlu | name, projectId, environmentId, serverId hepsi gerekli | 2026-02-22 |

---

## 🖥️ GPU / ML Edge Cases

| Durum | Çözüm | Tarih |
|-------|-------|-------|
| nvidia-ctk cdi list "Found 0 CDI devices" | `nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml` | 2026-02-22 |
| docker --gpus all başarısız ama nvidia-smi çalışıyor | `nvidia-ctk runtime configure --runtime=docker` + docker restart | 2026-02-22 |
| torch.cuda.is_available() False | CPU-only PyTorch kurulu → `pip install torch --index-url .../whl/cu121` | 2026-02-22 |
| ML deployment GPU yok | Health check gpu_available:false → inference çok yavaş → GPU zorunlu | 2026-02-22 |

---

## 🎯 Playwright ile Debug Kalıpları

### Kalıp 1: Form Doldurma (Config Güncelleme)
```
1. browser_snapshot → input ref'lerini bul
2. browser_click(input_ref) → odaklan
3. browser_press_key("Control+a") → tümünü seç
4. browser_type(ref, "yeni_değer") → yaz
5. browser_click(save_button_ref) → kaydet
6. browser_take_screenshot → doğrula
```

### Kalıp 2: Auth Gerektiren Sayfalara Gitme
```
# Basic Auth:
browser_navigate("http://user:password@host:port/path")

# Token gerektiren SPA:
browser_navigate(URL) → localStorage'ı kontrol et → token inject et
```

### Kalıp 3: "Neden 401 alıyorum?" Tespiti
```
1. browser_navigate (auth ile)
2. browser_console_messages → "401" olan URL'ler → hangi endpoint?
3. browser_snapshot → config form var mı? API key alanı?
4. Yanlış key'i düzelt → Save → console temiz mi?
```

### Kalıp 4: Network İzleme
```
browser_network_requests → şunlara bak:
- Status 4xx/5xx olanlar
- "localhost:YANLIS_PORT" gidenler (yanlış endpoint konfigürasyonu)
- Auth header eksik olanlar (credentials not included)
```

---

## 📋 Uygulama Spesifik Notlar

### WAHA
- Container: `devlikeapro/waha` (Core) veya `devlikeapro/waha-plus` (Plus)
- Port: 3002:3000 (Dokploy ile çakışma yok)
- Engine: NOWEB (ücretsiz, hafif), WEBJS (Plus gerekir)
- Dashboard: `/dashboard` (basic auth), Worker config localStorage'da
- API: `X-Api-Key` header, Swagger: `/` path

### Chatwoot
- Port: 3001 önerilen
- Redis zorunlu: `REDIS_URL=redis://:pass@redis:6379`
- Migrations: `docker compose exec rails bundle exec rails db:chatwoot_prepare`
- RAM: minimum 4GB

### Evolution API
- DATABASE_PROVIDER: sadece postgresql/mysql/psql_bouncer
- DATABASE_CONNECTION_URI zorunlu
- Port: 8080

### Dokploy
- Port 3000 kullanıyor → başka uygulamalar için farklı port seç
- Docker Swarm modunda çalışır
- REST API: `http://localhost:3000/api/` (x-api-key header)

### Atomic CRM (Vite + Supabase)
- Port 3015 → nginx:alpine SPA server
- Image: `localhost:5000/atomic-crm:latest` (local registry)
- Supabase paylaşımlı instance (aynı DB, ayrı tablolar)
- 22 migration, 31 tablo, 6 edge function (henüz deploy edilmedi)
- Detay: `deployments/atomic-crm/golden-path.md`

---

## 🏗️ Vite/React SPA Deploy Tuzakları (2026-04-13)

### Tuzak 1: VITE_* Env Var'ları Runtime'da Çalışmaz

Vite `import.meta.env.VITE_*` değerlerini **build time'da** JavaScript bundle'ına string olarak bake eder.
Container'a runtime `ENV` veya `docker run -e` ile verilen `VITE_*` değişkenleri **YOKSAYILIR**.

```
# YANLIŞ — container'da VITE_* env var çalışmaz:
services:
  frontend:
    image: my-vite-app
    environment:
      VITE_API_URL: "http://api.example.com"   # ← BU HİÇBİR ETKİ YAPMAZ

# DOĞRU — Build time'da ARG → ENV → RUN npm run build:
docker build --build-arg VITE_API_URL="http://api.example.com" ...
```

**Dockerfile pattern:**
```dockerfile
ARG VITE_API_URL
ENV VITE_API_URL=$VITE_API_URL
RUN npm run build   # Vite burada ENV'den okur ve bundle'a bake eder
```

### Tuzak 2: nginx SPA Routing Eksik → 404

Vite SPA'lar client-side routing kullanır (`/contacts`, `/deals` vb.). nginx default config sadece fiziksel dosyalara servis eder.
`/contacts` path'ine direkt gidilirse → nginx 404 döner (çünkü `/contacts` dosyası yok).

```nginx
# ZORUNLU — SPA catch-all routing:
location / {
    try_files $uri $uri/ /index.html;
}
```

**Dockerfile'da yazarken `$uri` tuzağı:**
- Shell `$uri`'yi expand etmeye çalışır → boş string olur
- Single quote kullan: `printf '... $uri ...'` → `$uri` literal olarak yazılır
- Double quote ile: `printf "... \$uri ..."` → escape gerekir, hata riski yüksek

### Tuzak 3: Supabase `sb_publishable_*` vs JWT ANON_KEY

| Format | Ortam | Örnek |
|--------|-------|-------|
| `sb_publishable_ACJWlzQ...` | Supabase CLI (`supabase start`) / Supabase Cloud | Dev .env dosyasında bulunur |
| `eyJhbGciOiJIUzI1NiIs...` (JWT) | Self-hosted Supabase (Docker) | Compose env `ANON_KEY` |

Atomic CRM `.env.development`'ta `sb_publishable_*` format kullanıyor. Self-hosted deploy'da **JWT ANON_KEY** kullanılmalı.
`createClient(url, key)` her iki formatı da kabul eder — format uyumsuzluğu sessiz hata verir (auth çalışmaz ama crash yok).

### Tuzak 4: Supabase Migration "already exists" Trigger Hatası

Supabase'in kendi auth setup'ı bazı function ve trigger'ları otomatik oluşturur:
- `public.handle_new_user()` — yeni kullanıcı kaydında çağrılır
- `on_auth_user_created` trigger — auth.users tablosuna INSERT sonrası

Atomic CRM bu fonksiyonları **farklı implementasyonla** override etmek istiyor (sales tablosu entegrasyonu).
`CREATE FUNCTION` hata verir → `CREATE OR REPLACE FUNCTION` kullanılmalı.

```sql
-- Güvenli migration pattern:
CREATE OR REPLACE FUNCTION public.handle_new_user() ...
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created ...
CREATE UNIQUE INDEX IF NOT EXISTS "uq__sales__user_id" ON public.sales (user_id);
CREATE OR REPLACE VIEW init_state ...
```

### Tuzak 5: Supabase DB Port 5432 Host'a Expose Değil

Çoklu PostgreSQL container'lar (OwnPilot, Dokploy, WhatsApp Stack, Supabase) aynı internal port 5432 kullanır.
Supabase supavisor port mapping `${POSTGRES_PORT}:5432` sessizce fail eder (host port zaten meşgul).

```bash
# YANLIŞ — host port erişilemez:
psql -h localhost -p 5432 -U postgres   # ← hangisine bağlanacak? → muhtemelen hiçbiri

# DOĞRU — docker exec ile doğrudan container'a bağlan:
docker exec -i supabase-supabase-0qdhd3-supabase-db psql -U postgres -d postgres

# ALTERNATİF — pooler port 6543 erişilebilir:
psql -h localhost -p 6543 -U postgres   # ← supavisor pooler
```

### Tuzak 6: `run_in_background: true` + Shell `&` = Process Kaybı

Bash tool'un `run_in_background: true` parametresi ile komut içinde `&` (background operator) birlikte kullanılamaz.
Shell `&` ile arka plana atılan subprocess, Bash tool background task bittiğinde **orphan olur ve kill edilir**.

```bash
# YANLIŞ — image build TAMAMLANMAZ:
docker build -t img:latest . &    # shell background — task bitince kill
echo "Build started"              # bu çalışır, build çalışmaz

# DOĞRU — run_in_background parametresini kullan:
# Bash tool: run_in_background=true
docker build -t img:latest .      # komut kendisi foreground, tool arka planda izler
```

### Tuzak 7: Dokploy REST API Path Değişkenliği

Önceki kayıtlar `/api/trpc/compose.update` zorunlu diyordu. 2026-04-13 (Dokploy v0.28.3) test:

| Path | Sonuç | Body Format |
|------|-------|-------------|
| `POST /api/compose.update` | ÇALIŞIYOR | Doğrudan JSON `{"composeId":"...", ...}` |
| `POST /api/trpc/compose.update` | ÇALIŞIYOR | tRPC wrapper `{"json": {"composeId":"...", ...}}` |

Her iki path de `x-api-key` header gerektirir. `/api/compose.update` (tRPC prefix'siz) daha basit — tercih et.

### Tuzak 8: traefik.me Domain `/etc/hosts` IP Uyumsuzluğu (2026-04-13)

`traefik.me` DNS servisi bazen yanlış sonuç döner veya lokal resolver override eder.
`supabase-supabase-7d9184-178-230-66-156.traefik.me` → beklenen IP `178.230.66.156` ama dönen: `127.0.0.1`.

Sorun zinciri:
```
1. /etc/hosts'da: 127.0.0.1 supabase-supabase-*.traefik.me
2. Traefik container: 192.168.2.13:80 → 80/tcp (0.0.0.0 DEĞİL!)
3. Browser → DNS → 127.0.0.1:80 → hiçbir şey dinlemiyor → ERR_CONNECTION_REFUSED
```

**Diagnosis:**
```bash
# 1. DNS çözümleme kontrol
dig +short supabase-supabase-*.traefik.me    # 127.0.0.1 ise → sorun
# 2. Traefik bind IP kontrol
docker ps | grep traefik                       # 192.168.2.13:80 → 0.0.0.0 DEĞİL
# 3. /etc/hosts kontrol
grep supabase /etc/hosts                       # 127.0.0.1 ise → DÜZELT
```

**Fix:** `/etc/hosts` IP'sini Traefik'in bind IP'sine değiştir:
```bash
sudo sed -i 's/127.0.0.1 supabase-supabase-7d9184.../192.168.2.13 supabase-supabase-7d9184.../' /etc/hosts
```

### Tuzak 9: Traefik → Compose Service Arası Network İzolasyonu (2026-04-13)

Traefik label'ları doğru olsa bile, Traefik container'ı ile hedef container FARKLI Docker network'lerde ise → **504 Gateway Timeout**.

```
Traefik networks: bridge, dokploy-network (overlay)
Supabase Kong network: supabase-supabase-0qdhd3 (bridge, local)
→ Traefik Kong'u GÖREMEZ → 504
```

**Diagnosis:**
```bash
# Traefik network'leri
docker inspect dokploy-traefik --format '{{json .NetworkSettings.Networks}}' | python3 -c "import json,sys; [print(k) for k in json.load(sys.stdin)]"
# → bridge, dokploy-network

# Hedef service network'ü
docker inspect supabase-...-kong --format '{{json .NetworkSettings.Networks}}' | python3 -c "import json,sys; [print(k) for k in json.load(sys.stdin)]"
# → supabase-supabase-0qdhd3
```

**Fix:**
```bash
docker network connect supabase-supabase-0qdhd3 dokploy-traefik
```

**DİKKAT:** Supabase `compose-deploy` veya `compose-redeploy` sonrası bu bağlantı **KOPABİLİR** (network yeniden oluşturulur). Her redeploy'dan sonra kontrol et:
```bash
docker network connect supabase-supabase-0qdhd3 dokploy-traefik 2>/dev/null
curl -s -o /dev/null -w "%{http_code}" http://supabase-supabase-*.traefik.me/rest/v1/  # 401 = OK
```

### Tuzak 10: Supabase Self-Hosted Mail Container Yok → Signup 500 (2026-04-13)

Supabase Docker template'i `SMTP_HOST=supabase-mail` (InBucket) ile gelir ama Dokploy template'inde mail container **deploy edilmemiş**.
`ENABLE_EMAIL_AUTOCONFIRM=false` (default) + mail yok = signup 500 "Error sending confirmation email".

**Diagnosis:**
```bash
docker ps | grep -i "mail\|inbucket"   # → boş = mail container YOK
docker exec supabase-...-auth env | grep AUTOCONFIRM
# GOTRUE_MAILER_AUTOCONFIRM=false → SORUN
```

**Fix (3 adım — compose env güncellemesi TEK BAŞINA yetmez):**
```bash
# 1. Dokploy compose env'de güncelle (REST API)
# ENABLE_EMAIL_AUTOCONFIRM=true

# 2. Auth container'ı yeniden oluştur (compose-deploy YETMEZ!)
docker stop supabase-...-auth
docker rm supabase-...-auth

# 3. Env override ile yeniden başlat
cd /etc/dokploy/compose/supabase-.../code
ENABLE_EMAIL_AUTOCONFIRM=true docker compose up -d --no-deps auth

# 4. Doğrula
docker exec supabase-...-auth env | grep AUTOCONFIRM
# GOTRUE_MAILER_AUTOCONFIRM=true → OK
```

**Neden compose-deploy yetmez?** Bilinen Dokploy env propagation bug'ı: REST API ile env güncellenip compose-deploy yapılsa bile container eski env ile oluşturulabiliyor. Elle `docker stop/rm` + `docker compose up` en güvenilir yol.

### Tuzak 11: Supabase Compose Redeploy Sonrası Checklist (2026-04-13)

Supabase compose her redeploy'dan sonra şu kontroller ZORUNLU:

```bash
# 1. Traefik network bağlantısı (kopmuş olabilir)
docker network connect supabase-supabase-0qdhd3 dokploy-traefik 2>/dev/null

# 2. Auth autoconfirm hâlâ aktif mi?
docker exec supabase-...-auth env | grep GOTRUE_MAILER_AUTOCONFIRM
# false ise → Tuzak 10'daki fix'i tekrarla

# 3. API erişilebilir mi?
curl -s -o /dev/null -w "%{http_code}" http://supabase-supabase-*.traefik.me/rest/v1/
# 401 = OK (auth gerekiyor), 504 = network kopuk, 000 = DNS/hosts sorunu
```
