# OwnPilot ↔ Bridge (Claude Code) Entegrasyon Plani

> Tarih: 2026-03-26
> Durum: PLAN (henuz uygulanmadi)
> Onkosul: OwnPilot v0.3.1 Dokploy'da calisiyor (port 8080)
> Onkosul: Bridge v5.0 host'ta calisiyor (port 9090, systemd)
> KURAL: ANTHROPIC_API_KEY ASLA KULLANILMAYACAK — sadece OAuth/subscription

---

## Mimari Ozet

```
OwnPilot UI (browser :8080)
    |
    v
OwnPilot Gateway (Hono, container)
    |  middleware pipeline: audit → persistence → context-injection → agent-execution
    |
    v
Bridge Provider Adapter (HTTP client, container icinde)
    |  POST http://host.docker.internal:9090/v1/chat/completions
    |  X-Conversation-Id: {OwnPilot conversation ID}
    |  X-Project-Dir: /home/ayaz
    |
    v
OpenClaw Bridge (Fastify, host :9090)
    |  ClaudeManager: session create/resume
    |
    v
Claude Code CLI (host, OAuth login)
    |  --resume {session-id} (devam eden conversation)
    |  --session-id {uuid} (yeni conversation)
    |
    v
Anthropic API (Claude Max subscription, API key YOK)
```

**Session Mapping:** OwnPilot `conversation.id` = Bridge `X-Conversation-Id` (1:1, dogal)
**Resume:** Ayni conversation ID → Bridge otomatik `--resume` → CC context korunur
**Auth:** Bridge bearer token (sabit), CC OAuth (host keyring)

---

## Phase 0: Pre-Flight Checks (5 dk)

### Amac
Tum onkosullarin saglandigini dogrula. Bir sey eksikse DURUR.

### Adimlar

```bash
# 0.1 OwnPilot container calisiyoir mu?
docker ps --filter "name=ownpilot-app-zfst6b" --format "{{.Names}} {{.Status}}"
# BEKLENEN: 2 container, Up, (healthy)

# 0.2 OwnPilot health endpoint
curl -s http://localhost:8080/health | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['version'], d['data']['database']['connected'])"
# BEKLENEN: 0.3.1 True

# 0.3 Bridge calisiyoir mu?
curl -s http://localhost:9090/ping -H "Authorization: Bearer <YOUR_BRIDGE_AUTH_TOKEN>"
# BEKLENEN: {"pong":true}

# 0.4 Container'dan Bridge'e erisim
docker exec ownpilot-app-zfst6b-ownpilot-1 wget -qO- http://host.docker.internal:9090/ping 2>/dev/null
# BEKLENEN: {"pong":true}

# 0.5 OwnPilot DB erisimi
docker exec ownpilot-app-zfst6b-ownpilot-db-1 psql -U ownpilot -d ownpilot -c "SELECT count(*) FROM custom_providers;"
# BEKLENEN: 0 (henuz kayit yok)

# 0.6 Claude Code OAuth aktif mi? (host'ta)
claude --version 2>/dev/null
# BEKLENEN: 2.1.x
```

### Basari Kriteri
6/6 kontrol PASS. Herhangi biri FAIL → durumu fix et, Phase 0'i tekrarla.

### Rollback
Yok — sadece okuma islemleri.

---

## Phase 1: Bridge'i Custom Provider Olarak Kaydet (10 dk)

### Amac
OwnPilot'un `custom_providers` tablosuna Bridge'i OpenAI-compatible provider olarak ekle. SIFIR kod degisikligi.

### Onkosul
Phase 0 PASS.

### Adimlar

```bash
# 1.1 custom_providers tablosunun schema'sini dogrula
docker exec ownpilot-app-zfst6b-ownpilot-db-1 psql -U ownpilot -d ownpilot -c "\d custom_providers"
# BEKLENEN: id, user_id, provider_id, display_name, api_base_url, api_key_setting,
#           provider_type, is_enabled, config, created_at, updated_at

# 1.2 Bridge'i custom provider olarak INSERT et
docker exec ownpilot-app-zfst6b-ownpilot-db-1 psql -U ownpilot -d ownpilot -c "
INSERT INTO custom_providers (id, user_id, provider_id, display_name, api_base_url, api_key_setting, provider_type, is_enabled, config)
VALUES (
  'bridge-claude-code',
  'default',
  'bridge',
  'Claude Code (Bridge)',
  'http://host.docker.internal:9090/v1',
  '<YOUR_BRIDGE_AUTH_TOKEN>',
  'openai_compatible',
  true,
  '{\"models\":[\"bridge-model\"],\"description\":\"Claude Code via OpenClaw Bridge (OAuth, no API key)\"}'::jsonb
);"
# BEKLENEN: INSERT 0 1

# 1.3 Kaydin dogru eklendigini dogrula
docker exec ownpilot-app-zfst6b-ownpilot-db-1 psql -U ownpilot -d ownpilot -c "
SELECT provider_id, display_name, api_base_url, provider_type, is_enabled FROM custom_providers WHERE id='bridge-claude-code';"
# BEKLENEN: bridge | Claude Code (Bridge) | http://host.docker.internal:9090/v1 | openai_compatible | t
```

### Test

```bash
# 1.4 OwnPilot settings API'den provider gorunuyor mu?
curl -s -H "x-api-key: op-2026-secure-key-ayaz" http://localhost:8080/api/v1/settings | python3 -c "
import sys,json
d = json.load(sys.stdin)
providers = d.get('data',{}).get('configuredProviders',[])
for p in providers:
  if 'bridge' in str(p).lower():
    print('FOUND:', p)
" 2>/dev/null
# BEKLENEN: bridge provider listede gorunmeli
```

### Basari Kriteri
- DB'de kayit var
- OwnPilot settings API'de provider gorunuyor

### Rollback
```sql
DELETE FROM custom_providers WHERE id='bridge-claude-code';
```

---

## Phase 2: Bridge Provider ile Ilk Chat Testi (15 dk)

### Amac
OwnPilot UI veya API uzerinden Bridge provider'i ile mesaj gonder, Claude Code yanit aldigini dogrula.

### Onkosul
Phase 1 PASS.

### Adimlar

```bash
# 2.1 API uzerinden bridge provider ile chat gonder
curl -s -X POST http://localhost:8080/api/v1/chat \
  -H "x-api-key: op-2026-secure-key-ayaz" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Merhaba, kim olduğunu ve ne yapabildiğini kısaca açıkla.",
    "provider": "bridge",
    "model": "bridge-model",
    "stream": false
  }' | python3 -c "
import sys,json
d = json.load(sys.stdin)
if d.get('success'):
  msg = d.get('data',{}).get('message','')[:200]
  conv = d.get('data',{}).get('conversationId','')
  print(f'SUCCESS: convId={conv}')
  print(f'MESSAGE: {msg}...')
else:
  print(f'ERROR: {d}')
"
# BEKLENEN: Claude'un bir yaniti ve conversation ID
```

### Olasi Hatalar ve Cozumleri

| Hata | Neden | Cozum |
|------|-------|-------|
| "Provider not found" | custom_providers kaydi OwnPilot tarafindan okunmadi | OwnPilot container restart: `docker restart ownpilot-app-zfst6b-ownpilot-1` |
| "ECONNREFUSED" | Container'dan Bridge'e erisim yok | Phase 0.4 tekrarla, extra_hosts compose'da var mi kontrol |
| "401 Unauthorized" | Bridge API key yanlis | api_key_setting degerini kontrol et |
| "model not found" | Bridge "bridge-model" tanimiyor | Bridge `/v1/models` endpoint'ini kontrol et, model adini duzelt |
| Timeout | Bridge CC spawn suresi > OwnPilot timeout | OwnPilot timeout config'ini artir |
| "No active session" | Bridge conversation ID formati uyumsuz | Bridge log'larini kontrol et |

### Test — Browser'dan

```
1. http://localhost:8080 ac
2. Settings → Providers → "Claude Code (Bridge)" gorunuyor mu?
3. Settings → Model Routing → Default provider: "bridge" sec
4. Chat → New Chat → "Merhaba" yaz → yanit geldi mi?
```

### Basari Kriteri
- API veya UI uzerinden mesaj gonderildi
- Claude Code yanit dondu
- conversation_id olusturuldu

### Rollback
Phase 1 rollback (provider sil) veya default provider'i degistir.

---

## Phase 3: Session Resume Testi (15 dk)

### Amac
Ayni chat'e tekrar mesaj gonderince CC'nin onceki context'i hatirlayip hatirlamadigini dogrula.

### Onkosul
Phase 2 PASS, conversation ID elde edildi.

### Adimlar

```bash
# 3.1 Ayni conversation'a ikinci mesaj gonder
CONV_ID="<Phase 2'den alinan conversation ID>"

curl -s -X POST http://localhost:8080/api/v1/chat \
  -H "x-api-key: op-2026-secure-key-ayaz" \
  -H "Content-Type: application/json" \
  -d "{
    \"message\": \"Az önce sana ne sormuştum? Özetler misin?\",
    \"conversationId\": \"${CONV_ID}\",
    \"provider\": \"bridge\",
    \"model\": \"bridge-model\",
    \"stream\": false
  }" | python3 -c "
import sys,json
d = json.load(sys.stdin)
msg = d.get('data',{}).get('message','')[:300]
print(f'RESUME TEST: {msg}')
"
# BEKLENEN: CC onceki mesaji hatirlayarak yanit vermeli
```

### Kontrol Noktalari

```bash
# 3.2 Bridge'de session var mi?
ENCODED=$(python3 -c "import urllib.parse; print(urllib.parse.quote('/home/ayaz',safe=''))")
curl -s "http://localhost:9090/v1/projects/${ENCODED}/sessions" \
  -H "Authorization: Bearer <YOUR_BRIDGE_AUTH_TOKEN>" | python3 -c "
import sys,json
sessions = json.load(sys.stdin)
for s in sessions:
  print(f'  convId={s.get(\"conversationId\",\"?\")} status={s.get(\"status\",\"?\")} msgs={s.get(\"messagesSent\",0)}')
"
# BEKLENEN: conversation ID ile eslesen session, messagesSent >= 2

# 3.3 OwnPilot messages tablosunda mesajlar var mi?
docker exec ownpilot-app-zfst6b-ownpilot-db-1 psql -U ownpilot -d ownpilot -c "
SELECT role, length(content) as chars, created_at FROM messages
WHERE conversation_id='${CONV_ID}' ORDER BY created_at;"
# BEKLENEN: user + assistant + user + assistant (4 mesaj)
```

### Muhtemel Sorun: Session Resume Calismiyorsa

OpenAI-compatible flow'da `X-Conversation-Id` header'i gonderilmiyor. Bu durumda Bridge her istegi YENI conversation olarak gorur.

**Teshis:**
```bash
# Bridge log'larinda conversation ID var mi?
journalctl -u openclaw-bridge --since "5 min ago" | grep -i "conversation\|session\|spawn"
```

**Cozum secenekleri:**
a) Bridge'in body'den conversation_id almasini saglama (Bridge tarafinda degisiklik)
b) OwnPilot'a bridge-specific middleware ekleme (OwnPilot tarafinda degisiklik)
c) OwnPilot chat history'sini her mesajda Bridge'e gonderme (OpenAI compat — messages array)

**Secenek C en kolay:** OwnPilot zaten conversation history'sini messages array olarak gonderiyorsa, Bridge (ve CC) onceki mesajlari body'den okur. Bu OpenAI-compat standart davranisi. Test et!

### Basari Kriteri
- Ikinci mesajda CC onceki context'i hatirladi → session resume CALISIYOR
- VEYA: CC history'yi messages array'den aldi → OpenAI compat flow CALISIYOR

### Rollback
Yok — okuma + chat testi.

---

## Phase 4: Streaming Test (15 dk)

### Amac
Bridge provider ile SSE streaming calistigini dogrula. Chat UI'da real-time token akisi gormek.

### Onkosul
Phase 2 PASS.

### Adimlar

```bash
# 4.1 Streaming API testi
curl -s -N -X POST http://localhost:8080/api/v1/chat \
  -H "x-api-key: op-2026-secure-key-ayaz" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "1den 10a kadar say, her sayiyi ayri satirda yaz.",
    "provider": "bridge",
    "model": "bridge-model",
    "stream": true
  }' 2>&1 | head -20
# BEKLENEN: SSE event'leri: event: chunk, data: {...}
# Her chunk'ta delta field'i gorunmeli
```

### Browser Testi

```
1. OwnPilot UI → Chat → mesaj yaz
2. Yanit gelirken token-by-token akiyor mu? (typing animation)
3. Yoksa tum yanit bir anda mi geliyor? (non-streaming)
```

### Basari Kriteri
- SSE event'leri gorunuyor (event: chunk + data)
- UI'da real-time token akisi var

### Basarisiz ise
Bridge `stream:true` degi mi destekliyor kontrol et. Bridge log'lari incele.
Fallback: `stream:false` ile devam et (yanit bir seferde gelir, UX daha kotu ama calisir).

---

## Phase 5: OwnPilot Context Injection Testi (10 dk)

### Amac
OwnPilot'un memory/goals/tools context'inin Bridge uzerinden CC'ye ulasip ulasmadigini dogrula.

### Onkosul
Phase 2 PASS.

### Adimlar

```bash
# 5.1 OwnPilot'a bir memory ekle
curl -s -X POST http://localhost:8080/api/v1/memories \
  -H "x-api-key: op-2026-secure-key-ayaz" \
  -H "Content-Type: application/json" \
  -d '{"content": "Kullanıcının adı Ayaz, Hollanda'\''da yaşıyor, fiber teknisyen olarak çalışıyor.", "type": "fact"}'

# 5.2 Bridge provider ile chat — memory'yi biliyor mu?
curl -s -X POST http://localhost:8080/api/v1/chat \
  -H "x-api-key: op-2026-secure-key-ayaz" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Benim hakkimda ne biliyorsun?",
    "provider": "bridge",
    "model": "bridge-model",
    "stream": false
  }' | python3 -c "
import sys,json
d = json.load(sys.stdin)
msg = d.get('data',{}).get('message','')[:300]
print(f'CONTEXT TEST: {msg}')
# Ayaz, Hollanda, fiber gibi kelimeleri icermeli
"
```

### Basari Kriteri
- CC yaniti kullanicinin adini, lokasyonunu veya meslegini icerir
- → OwnPilot context injection CALISIYOR (middleware pipeline'dan geciyor)

### Basarisiz ise
OwnPilot'un middleware pipeline'i bridge provider icin calismiyordur.
Debug: OwnPilot container log'larinda `context-injection` middleware trace'i ara.

---

## Phase 6: Default Provider Olarak Ayarla (5 dk)

### Amac
Her chat'te manual provider secimi gerekmeden, default olarak Bridge kullanilsin.

### Onkosul
Phase 2-5 PASS.

### Adimlar

```bash
# 6.1 Default provider'i bridge olarak ayarla
curl -s -X POST http://localhost:8080/api/v1/settings/provider \
  -H "x-api-key: op-2026-secure-key-ayaz" \
  -H "Content-Type: application/json" \
  -d '{"provider": "bridge", "model": "bridge-model"}'

# VEYA DB uzerinden:
docker exec ownpilot-app-zfst6b-ownpilot-db-1 psql -U ownpilot -d ownpilot -c "
INSERT INTO settings (key, value) VALUES ('default_ai_provider', 'bridge')
ON CONFLICT (key) DO UPDATE SET value = 'bridge';
INSERT INTO settings (key, value) VALUES ('default_ai_model', 'bridge-model')
ON CONFLICT (key) DO UPDATE SET value = 'bridge-model';
"
```

### Test

```
1. OwnPilot UI → New Chat → mesaj yaz (provider secmeden)
2. Yanit Claude Code'dan mi geliyor?
3. Settings → provider "bridge" gorunuyor mu?
```

### Rollback
```sql
DELETE FROM settings WHERE key IN ('default_ai_provider', 'default_ai_model');
```

---

## Phase 7: E2E Dogrulama + Stress Test (20 dk)

### Amac
Tum flow'un uretim ortaminda guvenilir calistigini dogrula.

### Test Senaryolari

| # | Senaryo | Beklenen Sonuc |
|---|---------|----------------|
| 1 | New Chat + mesaj | Claude Code yanit verir |
| 2 | Ayni chat'e 2. mesaj | Context korunur (resume veya history) |
| 3 | Baska chat'e gec, geri don | Her chat kendi context'inde |
| 4 | Uzun mesaj (500+ kelime) | Timeout olmadan yanit gelir |
| 5 | "Bu dizindeki dosyalari listele" | CC host filesystem'e erisir |
| 6 | Bridge restart, sonra mesaj | Yeni session baslar, hata yok |
| 7 | 3 paralel chat | Hepsi calisir (concurrent limit icinde) |
| 8 | OwnPilot container restart | Chat history korunur (DB), yeni mesaj calisir |
| 9 | 20dk bos bekleme, sonra mesaj | Session timeout sonrasi yeni session baslar |
| 10 | Chat sil | OwnPilot'tan silinir, Bridge session da temizlenir |

### Monitoring

```bash
# Container durumu
docker stats --no-stream ownpilot-app-zfst6b-ownpilot-1 ownpilot-app-zfst6b-ownpilot-db-1

# Bridge durumu
curl -s http://localhost:9090/v1/metrics -H "Authorization: Bearer <YOUR_BRIDGE_AUTH_TOKEN>" | python3 -m json.tool | head -20

# OwnPilot conversation sayisi
docker exec ownpilot-app-zfst6b-ownpilot-db-1 psql -U ownpilot -d ownpilot -t -c "SELECT count(*) FROM conversations;"
```

### Basari Kriteri
10/10 senaryo PASS → production-ready.
8/10 PASS → bilinen kisitlamalarla kabul edilebilir.
<8 PASS → Phase 2-5'e geri don, sorunlu senaryolari fix et.

---

## Phase 8: Lesson Documentation (10 dk)

### Amac
Tum ogrenilenleri dokploy-manage lesson dosyalarina kaydet.

### Dosyalar
- `~/.claude/skills/dokploy-manage/deployments/ownpilot/golden-path.md` — Bridge entegrasyon bölümü guncelle
- `~/.claude/skills/dokploy-manage/lessons/errors.md` — yeni hatalar ekle
- `~/.claude/skills/dokploy-manage/lessons/edge-cases.md` — yeni edge case'ler ekle
- `~/.claude/projects/-home-ayaz/memory/ownpilot-details.md` — memory guncelle

---

## Zaman Tahmini

| Phase | Sure | Bagimlilk |
|-------|------|-----------|
| Phase 0: Pre-flight | 5 dk | Yok |
| Phase 1: DB kayit | 10 dk | Phase 0 |
| Phase 2: Ilk chat testi | 15 dk | Phase 1 |
| Phase 3: Session resume | 15 dk | Phase 2 |
| Phase 4: Streaming | 15 dk | Phase 2 |
| Phase 5: Context injection | 10 dk | Phase 2 |
| Phase 6: Default provider | 5 dk | Phase 2-5 |
| Phase 7: E2E dogrulama | 20 dk | Phase 1-6 |
| Phase 8: Documentation | 10 dk | Phase 7 |
| **TOPLAM** | **~105 dk** | |

---

## Risk Matrisi

| Risk | Olasilik | Etki | Mitigation |
|------|---------|------|------------|
| OpenAI-compat flow X-Conversation-Id gondermiyor | HIGH | MEDIUM | Messages array ile history gonderilebilir (OpenAI standart) |
| Bridge streaming format OwnPilot ile uyumsuz | MEDIUM | LOW | stream:false fallback |
| Bridge idle timeout (20dk) session kaybeder | HIGH | LOW | Sonraki mesajda otomatik yeni session |
| Bridge down | LOW | HIGH | Health check + UI'da "offline" badge |
| OAuth token expire | LOW | LOW | CC CLI kendi refresh yapar |
| OwnPilot context injection bridge'e gecmiyor | MEDIUM | MEDIUM | Middleware pipeline debug, system prompt kontrol |

---

## Karar Noktalari (Phase sonlarinda)

- **Phase 2 sonrasi:** Chat calisiyor mu? EVET → devam. HAYIR → Bridge API format'ini debug et.
- **Phase 3 sonrasi:** Resume calisiyor mu? EVET → harika. HAYIR → messages array yaklasimiyla devam (OpenAI compat standart davranis).
- **Phase 4 sonrasi:** Streaming calisiyor mu? EVET → harika. HAYIR → stream:false ile devam, UX kabul edilebilir.
- **Phase 7 sonrasi:** 8+ senaryo PASS mi? EVET → production-ready. HAYIR → sorunlu senaryolari fix et.
