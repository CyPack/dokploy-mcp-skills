# Atomic CRM — Dokploy Deployment Golden Path

> **Upstream:** https://github.com/marmelab/atomic-crm
> **Stack:** React Admin + Vite + Supabase (PostgreSQL + Auth + Storage + Edge Functions)
> **Deployment date:** 2026-04-13
> **Dokploy project:** `atomic-crm` (projectId: `-1gg-Tjc7fzckuTJ_kg46`)
> **Compose:** `atomic-crm-frontend` (composeId: `Qiz60IjeLAKgyrQRMmBnD`, appName: `atomic-crm-frontend-hlbafu`)
> **Port:** 3015 (HTTP)
> **Image:** `localhost:5000/atomic-crm:latest` (local registry)
> **Supabase:** Mevcut self-hosted instance (`supabase-supabase-0qdhd3`) paylaşılıyor

---

## Mimari Genel Bakış

```
┌─────────────────────────────────────────────────────────────────┐
│                       Browser (User)                            │
│                    http://localhost:3015                         │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTP
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              Dokploy Compose: atomic-crm-frontend               │
│  ┌──────────────────────────────────────────┐                   │
│  │  nginx:alpine                            │                   │
│  │  /usr/share/nginx/html ← Vite dist       │                   │
│  │  SPA routing: try_files $uri /index.html │                   │
│  │  Port: 80 → Host: 3015                   │                   │
│  └──────────────────────────────────────────┘                   │
└─────────────────────────────────────────────────────────────────┘
                             │ Supabase JS Client (from browser)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│           Existing Supabase Stack (Dokploy project)             │
│  ┌─────────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │ Kong (API GW)   │  │ GoTrue Auth  │  │ PostgREST         │  │
│  │ :8000 (Traefik) │  │ :9999        │  │ :3000             │  │
│  └────────┬────────┘  └──────┬───────┘  └─────────┬─────────┘  │
│           │                  │                     │            │
│           ▼                  ▼                     ▼            │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  PostgreSQL 15 (supabase-db)                               │ │
│  │  31 atomic-crm tablosu (public schema)                     │ │
│  │  + Supabase system tabloları (auth, storage, vb.)          │ │
│  └────────────────────────────────────────────────────────────┘ │
│  Network: supabase-supabase-0qdhd3                              │
│  Domain: supabase-supabase-7d9184-178-230-66-156.traefik.me     │
└─────────────────────────────────────────────────────────────────┘
```

**Kritik tasarım kararı:** Atomic CRM'in kendi Supabase instance'ı yok — mevcut self-hosted Supabase ile DB paylaşıyor. Bu kaynak tasarrufu sağlıyor ama migration'lar ayrı yönetilmeli.

---

## Ön Koşullar

| Gerekli | Nerede | Doğrulama |
|---------|--------|-----------|
| Supabase self-hosted çalışıyor | Dokploy project "Supabase" | `docker ps \| grep supabase-kong` → Up |
| Local Docker registry | localhost:5000 | `curl -s http://localhost:5000/v2/_catalog` |
| Node 22 image | Docker cache | `docker image ls node:22-alpine` |
| Port 3015 boş | Host | `ss -tlnp \| grep 3015` → boş |

---

## Deployment Adımları (Sıfırdan)

### Adım 1: Repo'yu Clone Et

```bash
cd /tmp && git clone --depth=1 https://github.com/marmelab/atomic-crm.git atomic-crm
```

**Ne var:** 22 SQL migration, 6 edge function, Vite/React frontend, Supabase config

### Adım 2: Dockerfile Yaz

```bash
cat > /tmp/atomic-crm/Dockerfile << 'DOCKERFILE'
FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
ARG VITE_SUPABASE_URL
ARG VITE_SB_PUBLISHABLE_KEY
ARG VITE_IS_DEMO=false
ARG VITE_ATTACHMENTS_BUCKET=attachments
ARG VITE_INBOUND_EMAIL
ENV VITE_SUPABASE_URL=$VITE_SUPABASE_URL
ENV VITE_SB_PUBLISHABLE_KEY=$VITE_SB_PUBLISHABLE_KEY
ENV VITE_IS_DEMO=$VITE_IS_DEMO
ENV VITE_ATTACHMENTS_BUCKET=$VITE_ATTACHMENTS_BUCKET
ENV VITE_INBOUND_EMAIL=$VITE_INBOUND_EMAIL
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
RUN printf 'server {\n    listen 80;\n    root /usr/share/nginx/html;\n    index index.html;\n    location / {\n        try_files $uri $uri/ /index.html;\n    }\n}\n' > /etc/nginx/conf.d/default.conf
EXPOSE 80
DOCKERFILE
```

**Neden bu yapı:**
- Multi-stage build: node:22-alpine (builder, ~1GB) → nginx:alpine (final, ~50MB)
- `npm ci` layer'ı ayrı → package.json değişmedikçe cache'li kalır
- ARG → ENV dönüşümü: Vite, `VITE_*` env var'larını BUILD TIME'da okur
- `printf` ile nginx SPA config: `try_files $uri $uri/ /index.html` client-side routing için zorunlu
- `$uri` single quote içinde: shell expansion'dan korunur, nginx kendi değişkeni olarak kullanır

### Adım 3: Docker Image Build

```bash
docker build \
  --build-arg VITE_SUPABASE_URL="http://supabase-supabase-7d9184-178-230-66-156.traefik.me" \
  --build-arg VITE_SB_PUBLISHABLE_KEY="<YOUR_SUPABASE_ANON_KEY>" \
  --build-arg VITE_IS_DEMO="false" \
  --build-arg VITE_ATTACHMENTS_BUCKET="attachments" \
  --build-arg VITE_INBOUND_EMAIL="" \
  -t localhost:5000/atomic-crm:latest \
  /tmp/atomic-crm
```

**Build-arg açıklamaları:**

| Arg | Değer | Kaynak |
|-----|-------|--------|
| `VITE_SUPABASE_URL` | Supabase Kong external URL (Traefik) | Supabase compose env: `SUPABASE_HOST` |
| `VITE_SB_PUBLISHABLE_KEY` | Supabase ANON_KEY (JWT) | Supabase compose env: `ANON_KEY` |
| `VITE_IS_DEMO` | `false` | Production mode |
| `VITE_ATTACHMENTS_BUCKET` | `attachments` | Supabase Storage bucket adı |
| `VITE_INBOUND_EMAIL` | boş | Postmark entegrasyonu (opsiyonel) |

**UYARI:** `VITE_SB_PUBLISHABLE_KEY` upstream dev env'de `sb_publishable_*` formatında. Bu, Supabase CLI local format. Self-hosted Supabase'de standart JWT ANON_KEY kullanılır.

**Build süresi:** ~90-120 saniye (npm ci ~60s + Vite build ~30s)

### Adım 4: Push to Local Registry

```bash
docker push localhost:5000/atomic-crm:latest
```

**Neden local registry?** Dokploy `--pull always` kullanır. Docker Hub'da image yoksa pull fail eder. Local registry (`localhost:5000`) bu sorunu çözer.

### Adım 5: Dokploy Project + Compose Oluştur

```bash
# MCP ile:
project-create(name="atomic-crm", description="Atomic CRM — React Admin + Supabase (marmelab/atomic-crm)")
# → projectId ve environmentId döner

compose-create(name="atomic-crm-frontend", appName="atomic-crm-frontend", projectId=PROJECT_ID, environmentId=ENV_ID)
# → composeId döner
# ⚠️ sourceType default "github" — DÜZELTMEK ZORUNLU
```

### Adım 6: Compose YAML + sourceType Set Et (REST API)

```bash
DOKPLOY_KEY=$(python3 -c "import json; d=json.load(open('/home/ayaz/.claude.json')); print(d['mcpServers']['DokployServer']['env']['DOKPLOY_API_KEY'])")

# composeFile + sourceType TEK CALL'da set et
curl -s -X POST "http://localhost:3000/api/compose.update" \
  -H "x-api-key: $DOKPLOY_KEY" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "
import json
payload = {
    'composeId': 'COMPOSE_ID_BURAYA',
    'sourceType': 'raw',
    'composeFile': '''name: atomic-crm

services:
  frontend:
    image: localhost:5000/atomic-crm:latest
    ports:
      - \"3015:80\"
'''
}
print(json.dumps(payload))
")"
```

**ÇOK ÖNEMLİ — sourceType hataları:**
- `compose-create` MCP default `sourceType: "github"` ile oluşturur
- `sourceType: "github"` + raw YAML = deploy FAIL ("Github Provider not found")
- `sourceType: "raw"` REST API ile set edilmeli — compose-update MCP'de sourceType field'ı YOK

**REST API path notu (2026-04-13):**
- `/api/compose.update` ÇALIŞIYOR (tRPC prefix GEREKMEZ bu endpoint için)
- `x-api-key` header ZORUNLU
- Body doğrudan JSON (tRPC `{"json":{...}}` wrapper GEREKMEZ)

### Adım 7: Database Migration'ları Uygula

```bash
# Tüm 22 migration'ı sırayla uygula
for f in $(ls -1 /tmp/atomic-crm/supabase/migrations/*.sql | sort); do
  fname=$(basename "$f")
  echo -n "Applying $fname ... "
  result=$(docker exec -i supabase-supabase-0qdhd3-supabase-db psql -U postgres -d postgres < "$f" 2>&1)
  if echo "$result" | grep -qi "error\|fatal"; then
    echo "FAILED"
    echo "$result" | grep -i "error\|fatal" | head -3
  else
    echo "OK"
  fi
done
```

**Beklenen çıktı:** 21/22 OK, 1 migration (init_triggers) "already exists" hatası verir.

**init_triggers Fix (ZORUNLU):**

```bash
docker exec -i supabase-supabase-0qdhd3-supabase-db psql -U postgres -d postgres << 'EOF'
-- handle_new_user: Yeni kullanıcı signup'ında sales kaydı oluşturur
-- İlk kullanıcı otomatik admin olur (sales_count=0 → administrator=TRUE)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  sales_count int;
BEGIN
  SELECT count(id) INTO sales_count FROM public.sales;
  INSERT INTO public.sales (first_name, last_name, email, user_id, administrator)
  VALUES (
    new.raw_user_meta_data ->> 'first_name', 
    new.raw_user_meta_data ->> 'last_name', 
    new.email, 
    new.id, 
    CASE WHEN sales_count > 0 THEN FALSE ELSE TRUE END
  );
  RETURN new;
END;
$$;

-- handle_update_user: Auth user güncellenince sales kaydını senkronize eder
CREATE OR REPLACE FUNCTION public.handle_update_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  UPDATE public.sales
  SET 
    first_name = new.raw_user_meta_data ->> 'first_name', 
    last_name = new.raw_user_meta_data ->> 'last_name', 
    email = new.email
  WHERE user_id = new.id;
  RETURN new;
END;
$$;

-- Trigger'ları yeniden oluştur (DROP IF EXISTS → CREATE)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

DROP TRIGGER IF EXISTS on_auth_user_updated ON auth.users;
CREATE TRIGGER on_auth_user_updated
  AFTER UPDATE ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_update_user();

-- Unique index ve view
CREATE UNIQUE INDEX IF NOT EXISTS "uq__sales__user_id" ON public.sales (user_id);

CREATE OR REPLACE VIEW init_state
  WITH (security_invoker=off)
  AS
SELECT count(id) AS is_initialized FROM public.sales LIMIT 1;
EOF
```

**Neden bu hata olur?** Supabase'in kendi auth setup'ı `handle_new_user` fonksiyonunu zaten oluşturmuş olabilir. Atomic CRM versiyonu farklı (sales tablosu entegrasyonu eklemiş). `CREATE OR REPLACE` kullanarak CRM versiyonuyla override ediyoruz.

### Adım 8: Deploy

```bash
# MCP ile:
compose-deploy(composeId="Qiz60IjeLAKgyrQRMmBnD")
# → {"success": true, "message": "Deployment queued"}

# Doğrulama (20 saniye bekle):
docker ps --format "{{.Names}}\t{{.Ports}}" | grep atomic
# → atomic-crm-frontend-hlbafu-frontend-1    0.0.0.0:3015->80/tcp

curl -s -o /dev/null -w "HTTP %{http_code}" http://localhost:3015/
# → HTTP 200
```

### Adım 9: İlk Kullanıcı Kaydı

1. http://localhost:3015 aç
2. "Sign Up" sekmesine tıkla
3. First name, Last name, Email, Password gir
4. İlk kullanıcı otomatik **Administrator** olur (`handle_new_user` trigger'ı)
5. Sonraki kullanıcılar normal `sales` rolü alır

---

## Oluşturulan Tablolar (31 adet)

| Tablo | Açıklama |
|-------|----------|
| `sales` | Satış ekibi üyeleri (auth.users ile trigger bağlantılı) |
| `contacts` | CRM kişileri |
| `contacts_summary` | İletişim özeti view'ı |
| `companies` | Şirketler |
| `companies_summary` | Şirket özeti |
| `deals` | Satış fırsatları |
| `deal_notes` | Fırsat notları |
| `tasks` | Görevler |
| `tags` | Etiketler |
| `contact_notes` | Kişi notları |
| `activity_log` | Aktivite geçmişi |
| `configuration` | Uygulama yapılandırması |
| `email_queue` | E-posta kuyruğu |
| `email_tracking` | E-posta takibi |
| `invoices` | Faturalar |
| `invoice_line_items` | Fatura kalemleri |
| `invoice_templates` | Fatura şablonları |
| `invoice_attachments` | Fatura ekleri |
| `invoice_counters` | Fatura numaralandırma |
| `invoice_notes` | Fatura notları |
| `payments` | Ödemeler |
| `recurring_invoices` | Tekrarlayan faturalar |
| `organizations` | Organizasyonlar |
| `organization_branding` | Marka ayarları |
| `org_members` | Organizasyon üyeleri |
| `team_invitations` | Takım davetleri |
| `customers` | Müşteriler |
| `customer_notes` | Müşteri notları |
| `custom_field_definitions` | Özel alan tanımları |
| `favicons_excluded_domains` | Favicon hariç domainler |
| `init_state` | İlk kurulum durumu (view) |

---

## Edge Functions (Henüz Deploy Edilmedi)

| Function | Açıklama | Kritiklik |
|----------|----------|-----------|
| `users` | Kullanıcı yönetimi (listeleme, güncelleme) | YÜKSEK |
| `update_password` | Şifre değiştirme | ORTA |
| `merge_contacts` | Kişi birleştirme | DÜŞÜK |
| `delete_note_attachments` | Not eki silme cleanup'ı | DÜŞÜK |
| `postmark` | E-posta gönderimi (Postmark entegrasyonu) | ORTA |
| `mcp` | MCP entegrasyonu | DÜŞÜK |

**Deploy etmek için:** Edge function'lar Supabase'in `functions` container'ına mount edilmeli. Mevcut Supabase compose'undaki `supabase-edge-functions` container'ının volume'üne kopyalanmalı:

```bash
# 1. Function dosyalarını kopyala
for fn in users update_password merge_contacts delete_note_attachments postmark mcp _shared; do
  docker cp /tmp/atomic-crm/supabase/functions/$fn \
    supabase-supabase-0qdhd3-supabase-edge-functions:/home/deno/functions/
done

# 2. Edge functions container'ını restart et
docker restart supabase-supabase-0qdhd3-supabase-edge-functions

# 3. Test
curl -H "Authorization: Bearer ANON_KEY" \
  http://supabase-supabase-7d9184-178-230-66-156.traefik.me/functions/v1/users
```

---

## Ortam Değişkenleri Referansı

### Vite Build-Time (Dockerfile ARG → ENV)

| Değişken | Değer | Açıklama |
|----------|-------|----------|
| `VITE_SUPABASE_URL` | `http://supabase-supabase-7d9184-178-230-66-156.traefik.me` | Supabase API gateway (Kong) — browser'dan erişilebilir olmalı |
| `VITE_SB_PUBLISHABLE_KEY` | Supabase ANON_KEY (JWT) | `createClient(url, key)` için kullanılır — self-hosted'da JWT format |
| `VITE_IS_DEMO` | `false` | Demo mod kapalı |
| `VITE_ATTACHMENTS_BUCKET` | `attachments` | Supabase Storage bucket adı |
| `VITE_INBOUND_EMAIL` | `` | Postmark inbound email (opsiyonel) |

### Supabase Credentials (Mevcut Instance)

| Key | Değer | Kullanım |
|-----|-------|----------|
| SUPABASE_HOST | `supabase-supabase-7d9184-178-230-66-156.traefik.me` | External access (Traefik) |
| ANON_KEY | `<YOUR_SUPABASE_ANON_KEY>` | Frontend publishable key |
| SERVICE_ROLE_KEY | `<YOUR_SUPABASE_SERVICE_ROLE_KEY>` | Backend admin key (ASLA frontend'e koyma) |
| POSTGRES_PASSWORD | `<YOUR_POSTGRES_PASSWORD>` | DB direct access |
| DB Container | `supabase-supabase-0qdhd3-supabase-db` | docker exec ile erişim |
| DB Internal IP | `172.22.0.100` | Docker network |
| Kong Internal IP | `172.22.0.200` | Docker network |
| Network | `supabase-supabase-0qdhd3` | External network adı |

---

## Güncelleme / Redeploy Prosedürü

### Frontend Güncelleme (Upstream repo değişti)

```bash
# 1. Güncel kodu çek
cd /tmp/atomic-crm && git pull

# 2. Yeniden build et
docker build \
  --build-arg VITE_SUPABASE_URL="http://supabase-supabase-7d9184-178-230-66-156.traefik.me" \
  --build-arg VITE_SB_PUBLISHABLE_KEY="<YOUR_SUPABASE_ANON_KEY>" \
  --build-arg VITE_IS_DEMO="false" \
  --build-arg VITE_ATTACHMENTS_BUCKET="attachments" \
  -t localhost:5000/atomic-crm:latest \
  /tmp/atomic-crm

# 3. Push
docker push localhost:5000/atomic-crm:latest

# 4. Redeploy (MCP)
compose-redeploy(composeId="Qiz60IjeLAKgyrQRMmBnD")
```

### Migration Güncelleme (Yeni migration'lar geldi)

```bash
cd /tmp/atomic-crm && git pull
# Sadece yeni migration'ları uygula (tarih kontrolü ile)
for f in $(ls -1 supabase/migrations/*.sql | sort); do
  fname=$(basename "$f")
  ts=$(echo "$fname" | cut -d'_' -f1)  # timestamp prefix
  # Belirli bir tarihten sonrakileri uygula
  if [ "$ts" -gt "20260320120000" ]; then
    echo "Applying NEW: $fname"
    docker exec -i supabase-supabase-0qdhd3-supabase-db psql -U postgres -d postgres < "$f"
  fi
done
```

---

## Troubleshooting

### Frontend 404/blank sayfa

**Neden:** nginx SPA routing eksik — `try_files $uri $uri/ /index.html;` gerekiyor
**Fix:** Dockerfile'daki `printf` komutuyla nginx default.conf override edilmeli

### Supabase "Invalid API key"

**Neden:** `VITE_SB_PUBLISHABLE_KEY` yanlış format
**Fix:** Self-hosted Supabase'de JWT ANON_KEY kullan (`eyJ...` format), `sb_publishable_*` DEĞİL

### Migration "already exists" hataları

**Neden:** Supabase kendi auth trigger'larını oluşturmuş
**Fix:** `CREATE OR REPLACE FUNCTION` + `DROP TRIGGER IF EXISTS` + `CREATE TRIGGER` pattern'i kullan

### Container başlamıyor

**Kontrol sırası:**
1. `docker ps -a | grep atomic` → Exited?
2. `docker logs atomic-crm-frontend-hlbafu-frontend-1` → nginx hata?
3. Image var mı? `docker images localhost:5000/atomic-crm`
4. Port çakışması? `ss -tlnp | grep 3015`

### Browser'da ERR_CONNECTION_REFUSED (Supabase API)

**Belirtiler:** Frontend yükleniyor ama Supabase API'ye bağlanamıyor. Network tab'da `ERR_CONNECTION_REFUSED` hatası.

**Neden:** `/etc/hosts`'da Supabase traefik.me domain'i `127.0.0.1`'e yönlendirilmiş ama Traefik `192.168.2.13:80`'de dinliyor.

**Diagnosis:**
```bash
grep supabase /etc/hosts          # 127.0.0.1 ise → SORUN
docker ps | grep traefik           # 192.168.2.13:80 → Traefik IP'si farklı
```

**Fix:**
```bash
sudo sed -i 's/127.0.0.1 supabase-supabase-7d9184-178-230-66-156.traefik.me/192.168.2.13 supabase-supabase-7d9184-178-230-66-156.traefik.me/' /etc/hosts
```

### Browser'da HTTP 504 Gateway Timeout (Supabase API)

**Belirtiler:** `/etc/hosts` düzeltildi ama Supabase API hâlâ çalışmıyor — 504 hatası.

**Neden:** Traefik ve Supabase Kong container'ları farklı Docker network'lerde. Traefik (`dokploy-network`) Kong'u (`supabase-supabase-0qdhd3`) göremez.

**Diagnosis:**
```bash
# Traefik network'leri
docker inspect dokploy-traefik --format '{{json .NetworkSettings.Networks}}' | python3 -c "import json,sys; [print(k) for k in json.load(sys.stdin)]"
# supabase-supabase-0qdhd3 YOKSA → SORUN
```

**Fix:**
```bash
docker network connect supabase-supabase-0qdhd3 dokploy-traefik
# Test: curl → 401 = OK
curl -s -o /dev/null -w "%{http_code}" http://supabase-supabase-7d9184-178-230-66-156.traefik.me/rest/v1/
```

**DİKKAT:** Supabase compose redeploy sonrası bu bağlantı KOPABİLİR — her seferinde kontrol et.

### Signup 500 "Error sending confirmation email"

**Belirtiler:** Signup formu doldurulur, "Creating..." görünür, sonra 500 hatası — kullanıcı oluşamaz.

**Neden:** Supabase `GOTRUE_MAILER_AUTOCONFIRM=false` (default) ama mail container (InBucket) deploy edilmemiş. GoTrue email doğrulama göndermeye çalışıyor → mail yok → 500.

**Diagnosis:**
```bash
docker ps | grep -i "mail\|inbucket"    # → boş = mail container YOK
docker exec supabase-...-auth env | grep GOTRUE_MAILER_AUTOCONFIRM  # → false = SORUN
```

**Fix (compose-deploy YETMEZ — elle container restart):**
```bash
# 1. Compose env güncelle (REST API)
# ENABLE_EMAIL_AUTOCONFIRM=true yapıldığından emin ol

# 2. Auth container'ı elle yeniden oluştur
docker stop supabase-supabase-0qdhd3-supabase-auth
docker rm supabase-supabase-0qdhd3-supabase-auth
cd /etc/dokploy/compose/supabase-supabase-0qdhd3/code
ENABLE_EMAIL_AUTOCONFIRM=true docker compose up -d --no-deps auth

# 3. Doğrula
docker exec supabase-supabase-0qdhd3-supabase-auth env | grep GOTRUE_MAILER_AUTOCONFIRM
# → true
```

---

## Deploy Sonrası Zorunlu Checklist (3 Kontrol)

```bash
# Her deploy/redeploy sonrası bu 3 kontrol ZORUNLU:

# 1. Traefik ↔ Supabase network bağlantısı
docker network connect supabase-supabase-0qdhd3 dokploy-traefik 2>/dev/null

# 2. /etc/hosts → Supabase domain doğru IP'ye mi yönleniyor?
grep supabase /etc/hosts  # → 192.168.2.13 olmalı

# 3. Supabase API erişilebilir mi?
curl -s -o /dev/null -w "%{http_code}" http://supabase-supabase-7d9184-178-230-66-156.traefik.me/rest/v1/
# 401 = OK | 504 = network kopuk | 000 = DNS/hosts sorunu

# 4. Auth autoconfirm aktif mi?
docker exec supabase-supabase-0qdhd3-supabase-auth env | grep GOTRUE_MAILER_AUTOCONFIRM
# true = OK | false = Tuzak 10 fix'i gerekli
```

---

## Browser Test Sonuçları (2026-04-13)

| Test | Durum |
|------|-------|
| Frontend yükleniyor (localhost:3015) | PASS |
| Supabase API bağlantısı (init_state → 200) | PASS |
| İlk kullanıcı signup (admin) | PASS |
| Dashboard onboarding checklist | PASS |
| Contact oluşturma (Test Contact, Software Engineer) | PASS |
| Deals sayfası (Search, Filter, Export, New Deal) | PASS |
| Navigasyon (Dashboard/Contacts/Companies/Deals) | PASS |
| Dark mode UI | PASS |

**Hesap bilgileri:**
- Email: `your-email@example.com`
- Password: `<YOUR_SECURE_PASSWORD>`
- Rol: Administrator (ilk kullanıcı)

---

## Bilinen Limitasyonlar

1. **Edge Functions henüz deploy edilmedi** — Email gönderimi, MCP entegrasyonu, kişi birleştirme çalışmaz
2. **Supabase DB paylaşılıyor** — Başka projeler aynı DB'yi kullanırsa tablo adı çakışması riski (düşük — atomic-crm benzersiz isimler kullanıyor)
3. **CORS yapılandırması** — Supabase Auth redirect URL'lerine atomic-crm frontend domain'i eklenmeli (şu an localhost:3015 kullanıldığı için sorun yok)
4. **Supabase Storage bucket** — `attachments` bucket'ı Supabase'de oluşturulmalı (invoice ekleri için)
5. **SMTP** — Email bildirimleri için Supabase SMTP ayarları yapılmalı (şu an InBucket fake mail yok, `ENABLE_EMAIL_AUTOCONFIRM=true` ile bypass edildi)
6. **Traefik network bağlantısı** — Supabase compose redeploy sonrası `docker network connect` tekrar gerekebilir
7. **traefik.me DNS** — `/etc/hosts` override gerekiyor (traefik.me servisi `127.0.0.1` döndürüyor)

---

*Created: 2026-04-13 | Updated: 2026-04-13 (browser test sonuçları eklendi)*
*Author: Ayaz + Claude Opus 4.6*
*Session: atomic-crm Dokploy deployment + browser testing*
