# Dokploy & MCP Kurulum Rehberi

Dokploy platform kurulumu, MCP entegrasyonu, troubleshooting ve mimari notlar.

---

## 1. Dokploy Platform Kurulumu

### Ortam
- **Sunucu:** Razer Blade 14 (2021), Fedora Linux
- **Mod:** Docker Swarm (single node)
- **Versiyon:** v0.27.0 (10 Subat 2026'da guncellendi, onceki: v0.26.6)
- **URL:** http://localhost:3000
- **Swagger:** http://localhost:3000/swagger

### Platform Bilesenler
```
Docker Swarm
├── dokploy (ana platform - port 3000)
├── dokploy-postgres (state DB - port 5432 internal)
├── dokploy-redis (cache - port 6379 internal)
└── dokploy-traefik (reverse proxy - port 80/443)
```

### Guncelleme Proseduru
```bash
docker pull dokploy/dokploy:vX.Y.Z
docker service update --image dokploy/dokploy:vX.Y.Z dokploy
# Port cakismasi Swarm tarafindan otomatik cozulur
# API 200 dogrulamasi yap: curl -s http://localhost:3000/api | head
```

---

## 2. Dokploy MCP Kurulumu

### Paket Secimi

| Paket | Repo | Stars | Versiyon | Kapsam |
|-------|------|-------|----------|--------|
| `dokploy-mcp` (YUKLU) | tacticlaunch/dokploy-mcp | 3 | 1.0.7 | 380 tool (en kapsamli) |
| `@ahdev/dokploy-mcp` (RESMI) | Dokploy/mcp | 108 | 1.6.0 | Sinirli (compose YOK) |
| `@ahdev/dokploy-mcp` (fork) | andradehenrique/dokploy-mcp | 16 | - | Sinirli (compose YOK) |

**Karar:** `tacticlaunch/dokploy-mcp` — OpenAPI spec'ten otomatik uretilmis, 380 tool, en kapsamli.

### MCP Config (`~/.claude.json`)

```json
{
  "mcpServers": {
    "DokployServer": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "dokploy-mcp", "--enable-tools", "compose/"],
      "env": {
        "DOKPLOY_URL": "http://localhost:3000",
        "DOKPLOY_API_KEY": "${DOKPLOY_API_KEY}"
      }
    }
  }
}
```

**API Key:** Dokploy UI > Settings > API > Generate Token
**DIKKAT:** API key'i asla git'e commit etme! `~/.claude.json` zaten `.gitignore`'da.

### Tool Aktivasyonu

dokploy-mcp "smart defaults" stratejisi kullanir:
- 380 total tool (Dokploy API'nin %100'u)
- Sadece 55 tool varsayilan olarak aktif
- 325 tool disabled (Compose, Postgres, MySQL, MariaDB, Mongo, Redis, vb.)

**Compose tool'lari aktiflestirmek icin:**
```
"args": ["-y", "dokploy-mcp", "--enable-tools", "compose/"]
```

**Alternatif (spesifik tool'lar):**
```
--enable-tools compose-stop,compose-start,compose-deploy,compose-redeploy,compose-one,compose-update,compose-loadServices,compose-delete,compose-import,compose-templates,compose-deployTemplate
```

**`--enable-tools` Mekanizmasi (teknik detay):**
- `@tacticlaunch/xmcp` framework, `node:util/parseArgs` ile CLI args parse eder
- `xa()` fonksiyonu tool filtering yapar
- Tool key format: `"src/tools/compose/stop.ts"` (build path)
- `"compose/"` pattern: path'te `compose` directory'yi match eder
- Config degisikligi sonrasi **Claude Code session restart gerekir** (deferred tools cache session basinda olusturuluyor)

---

## 3. API Bilgileri

### REST API
- Base URL: `http://localhost:3000/api`
- Auth: `x-api-key` header
- tRPC uzerinde kurulu
- Endpoint format: `POST /api/compose.stop`
- 383 endpoint, 37 router/tag

### Compose API Endpoint'leri (Dogrulanmis)
```
POST /api/compose.stop     → composeId (body)
POST /api/compose.start    → composeId (body)
POST /api/compose.deploy   → composeId (body)
POST /api/compose.redeploy → composeId (body)
POST /api/compose.delete   → composeId, deleteVolumes (body)
GET  /api/compose.one      → composeId (query)
POST /api/compose.update   → composeId + 70 optional fields
POST /api/compose.import   → base64, composeId
GET  /api/compose.loadServices → composeId (query)
GET  /api/compose.templates
```

### REST API Hafif Kontrol Ornekleri
```bash
# Sadece status (credential'i env'den al)
curl -s "http://localhost:3000/api/compose.one?composeId=ID" \
  -H "x-api-key: $DOKPLOY_API_KEY" | jq '{name, composeStatus}'

# Tum projeleri listele
curl -s "http://localhost:3000/api/project.all" \
  -H "x-api-key: $DOKPLOY_API_KEY" | jq '.[].name'
```

---

## 4. MCP Response Boyutu Optimizasyonu

### Problem
`compose-one` tool'u ~15K token dondurur (compose YAML + env vars + mount dosyalari).
Claude Code uyarisi: "Large MCP response (~15.2k tokens)"
Bu uyari **bilgilendirme amacli** — veri kaybi veya truncation YOK.

### Root Cause
`compose-one` tum detaylari tek seferde donuyor:
- composeFile (380+ satir YAML) → ~3K token
- env (tum environment variables) → ~2K token
- mounts[] (12 dosya, SQL + YAML + TypeScript icerikleri) → ~8K token
- deployments, domains, metadata → ~2K token

### Cozum: Duruma Gore Tool Secimi

| Ihtiyac | Kullan | Token |
|---------|--------|-------|
| Sadece status kontrolu | REST API: `compose.one` + jq `.composeStatus` | ~50 |
| Servis listesi | `compose-loadServices` (MCP) | ~200 |
| Tam detay (debug, analiz) | `compose-one` (MCP) — 15K uyarisi normal | ~15K |
| Status guncelleme | REST API: `compose.update` + `composeStatus` | ~50 |

### Pratik Kurallar
1. **Rutin kontrol:** `compose-loadServices` veya REST API kullan
2. **Derin analiz:** `compose-one` kullan, uyari normal
3. **Birden fazla compose:** Paralel cagir, ama hepsini `compose-one` ile cagirma
4. **Context tasarrufu:** Session basinda tum compose'lari `compose-one` ile cekme

---

## 5. Troubleshooting

### Config Degisikligi Yansimadi
- **Sebep:** Claude Code deferred tools listesi session basinda olusturuluyor
- **Cozum:** Claude Code'u tamamen kapat-ac (session restart)
- `claude mcp remove/add-json` config dosyasini degistirir ama calisan process'i yeniden baslatmaz

### Birden Fazla MCP Process
- **Sebep:** Farkli terminal'lerde (pts/0, pts/2, pts/3) ayri process'ler
- **Cozum:** Tum eski process'leri kill et, tek session'dan calis
- Process kill sonrasi Claude Code yeni process baslatmaz (diger session process'lerine baglanir)

### compose-update composeStatus Desteklemiyor
- **Sebep:** MCP tool'u bu alani schema'da tanimiyor
- **Cozum:** REST API fallback kullan:
```bash
curl -s -X POST "http://localhost:3000/api/compose.update" \
  -H "x-api-key: $DOKPLOY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"composeId":"...", "composeStatus":"done"}'
```

### project.remove API
- Dokploy MCP'de `project-remove` veya `project-delete` tool'u YOK
- REST API fallback:
```bash
curl -s -X POST "http://localhost:3000/api/project.remove" \
  -H "x-api-key: $DOKPLOY_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"projectId":"..."}'
```

---

## 6. Mimari: MCP vs REST API

```
Claude Code Session
├── MCP Tool (ToolSearch → compose-one, compose-loadServices, ...)
│   ├── Avantaj: Declarative, type-safe, auto-discovery
│   ├── Dezavantaj: 15K token response, session cache
│   └── Kullanim: Rutin operasyonlar, servis listesi
│
└── REST API (curl via Bash)
    ├── Avantaj: Lightweight, jq ile filtreleme, credential env'den
    ├── Dezavantaj: Manual URL/header yonetimi
    └── Kullanim: Status kontrol, bulk islem, MCP'de olmayan endpoint'ler
```

**Kural:** Once MCP dene, yoksa veya yetersizse REST API fallback.

---

## 7. Kaynaklar

- [tacticlaunch/dokploy-mcp](https://github.com/tacticlaunch/dokploy-mcp) - Yuklu MCP paketi (v1.0.7)
- [Dokploy/mcp](https://github.com/Dokploy/mcp) - Resmi MCP repo
- [Dokploy API Docs](https://docs.dokploy.com/docs/api)
- [Compose API Reference](https://docs.dokploy.com/docs/api/reference-compose)
- [Dokploy Releases](https://github.com/Dokploy/dokploy/releases)
- [PR #1: Compose tools](https://github.com/Dokploy/mcp/pull/1)
- [Issue #18: Compose request](https://github.com/Dokploy/mcp/issues/18)

---

*Olusturulma: 2026-02-12 | Son guncelleme: 2026-02-12*
