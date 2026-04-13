---
maturity: sonnet
maturity_score: 8
lesson_count: 40
name: dokploy-manage
description: |
  Dokploy self-hosted PaaS platform yonetimi (MCP API + Playwright troubleshooting).
  Deploy icin DokployServer MCP API kullanir.
  UI sorunlarinda Playwright ile browser katmanini test eder.

  PLATFORM: Dokploy (30.2k GitHub stars) - Docker + Traefik mimarisi
  URL: http://localhost:3000

  KULLANIM DURUMLARI:
  - Uygulama deploy et, redeploy, rollback
  - Compose service olustur ve deploy et (GOLDEN PATH: REST API ile composeFile set et)
  - Docker container yonetimi (restart, logs, status)
  - Backup zamanlama ve manuel tetikleme
  - Domain / SSL yonetimi
  - Proje ve environment yonetimi
  - Registry (Docker Hub, GHCR, private) yonetimi
  - Deployment gecmisi ve izleme
  - UI sorun giderme (Playwright ile browser katmani test)

  TRIGGERS: dokploy, deploy, redeploy, rollback, compose deploy,
  backup, domain, ssl, traefik, container restart, deployment,
  waha, whatsapp api, connection failed, not connected

  KRITIK KURALLAR:
  1. compose-update MCP ile composeFile GUNCELLENMIYOR → REST API kullan
  2. application-saveEnvironment env var Docker Swarm'a GECMIYOR → compose YAML kullan
  3. Kullanici UI hatasi bildirdi + server curl OK → HEMEN Playwright ac
  4. compose-create icin appName + projectId ZORUNLU
  5. project-delete MCP'de YOK → REST API curl kullan
  6. compose-import HICBIR ZAMAN CALISMAZ (YAML:"not valid JSON", JSON:"Cannot read properties undefined") → KULLANMA
  7. REST API PATH: /api/trpc/compose.update  (NOT /api/compose.update)
  8. REST API AUTH: x-api-key: KEY header    (NOT Authorization: Bearer — CALISMAZ)
  9. REST API BODY: {"json": {...}} tRPC wrapper ZORUNLU
  10. DEPLOY SONRASI: verify-deploy.sh MUTLAKA calistir (kanitsiz "tamamlandi" DEME)
  11. MONITORING: monitor-all.sh cron aktif — her 5dk Dokploy servislerini izler, WA bildirim gonderir

  PLAYWRIGHT OTO-TETIK:
  Kullanici hata bildirdi + sunucu tarafinda sorun yok → Playwright ile UI kontrol zorunlu!
  "Calisıyor gibi gorunuyor" DEME, git bak.
user-invocable: true
allowed-tools: mcp__DokployServer__*
auto-load-context:
  - "dokploy"
  - "deploy"
  - "redeploy"
  - "rollback"
  - "compose deploy"
  - "container restart"
  - "backup schedule"
---

# DokployServer - Platform Yonetim Skill'i

Dokploy self-hosted PaaS platformunu **MCP API** ile yonetir.
Proje olusturma, uygulama deploy, compose yonetimi, backup, domain ve daha fazlasi.

## Architecture

```
+---------------------------------------------------------+
|                    Claude Code                          |
|                   (MCP Client)                          |
+----------------------------+----------------------------+
                             | MCP Protocol (stdio)
                             v
+---------------------------------------------------------+
|               DokployServer (MCP)                       |
|            dokploy-mcp (npx)                            |
|                                                         |
|  11 Kategori, 98 Tool                                   |
|  application/ compose/ deployment/ docker/              |
|  backup/ project/ environment/ domain/                  |
|  registry/ user/ server/                                |
+----------------------------+----------------------------+
                             | REST API (Bearer Token)
                             v
+---------------------------------------------------------+
|              Dokploy Platform                           |
|                                                         |
|  +----------+  +---------+  +--------+  +----------+   |
|  | Traefik  |  | Docker  |  | Swarm  |  | Postgres |   |
|  | (Proxy)  |  | Engine  |  | Mode   |  | (State)  |   |
|  +----------+  +---------+  +--------+  +----------+   |
|                                                         |
|  URL: http://localhost:3000                              |
+---------------------------------------------------------+
```

**MCP Config:** `~/.claude.json` (user-scoped, global)
- `DOKPLOY_URL`: Dokploy API endpoint
- `DOKPLOY_API_KEY`: API Bearer token (Settings > API'den alinir)

**Compose Tool Aktivasyonu:** dokploy-mcp v1.0.7'de compose tool'lar varsayilan olarak `disabled`.
Aktiflestirmek icin `args`'a `"--enable-tools", "compose/"` ekle:
```json
"args": ["-y", "dokploy-mcp", "--enable-tools", "compose/"]
```
Config degisikligi sonrasi Claude Code session restart gerekir (deferred tools cache).

**Dokploy Versiyonu:** v0.28.3 (4 Mart 2026) - Docker Swarm modunda calisir (autolock KAPALI).
**Disaster Recovery:** `references/disaster-recovery.md` — tum credential'lar ve recovery komutlari.

## Kavram Hiyerarsisi

```
Server (fiziksel/sanal sunucu)
  └── Project (mantiksal gruplama)
       └── Environment (production, staging, dev)
            ├── Application (tek container, git/docker kaynak)
            │   ├── Domain (custom domain + SSL)
            │   ├── Deployment (deploy gecmisi)
            │   └── Backup (zamanlanmis/manuel)
            └── Compose (docker-compose stack, coklu service)
                ├── Domain
                ├── Deployment
                └── Backup
```

**ID Zinciri:** Cogu islem icin once project-all → project-one (environmentId) → target tool.
Her kaynak kendi ID'si ile yonetilir (projectId, environmentId, applicationId, composeId, vb.)

## Tool Kategorileri (11 Kategori, 98 Tool)

### 1. Project (4 tool + 1 REST fallback) - SAFE

| Tool | Risk | Aciklama |
|------|------|----------|
| `project-all` | READ | Tum projeleri listele |
| `project-one` | READ | Proje detayi (environments dahil) |
| `project-create` | LOW | Yeni proje olustur |
| `project-update` | LOW | Proje adini/aciklamasini guncelle |
| ~~`project-delete`~~ | **REST API** | MCP'de YOK → REST fallback kullan (asagiya bak) |

> **project-remove REST fallback** (MCP'de bu tool yoktur, her zaman curl kullan):
> ```bash
> DOKPLOY_KEY=$(cat ~/.claude.json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['mcpServers']['DokployServer']['env']['DOKPLOY_API_KEY'])")
> curl -s -X POST "http://localhost:3000/api/project.remove" \
>   -H "x-api-key: $DOKPLOY_KEY" \
>   -H "Content-Type: application/json" \
>   -d '{"projectId":"PROJECT_ID_BURAYA"}'
> ```
> Onay: projectId + deleteVolumes tercihi AskUserQuestion ile MUTLAKA sorulacak.

### 2. Environment (3 tool) - SAFE

| Tool | Risk | Aciklama |
|------|------|----------|
| `environment-create` | LOW | Yeni environment olustur (projectId gerekli) |
| `environment-one` | READ | Environment detayi |
| `environment-update` | LOW | Environment guncelle |

### 3. Application (24 tool) - DIKKATLI

| Tool | Risk | Aciklama |
|------|------|----------|
| `application-create` | LOW | Yeni uygulama olustur |
| `application-one` | READ | Uygulama detayi |
| `application-update` | MEDIUM | Uygulama ayarlarini guncelle (90+ parametre) |
| `application-deploy` | MEDIUM | Uygulamayi deploy et |
| `application-redeploy` | MEDIUM | Tekrar deploy et |
| `application-start` | LOW | Uygulamayi baslat |
| `application-stop` | MEDIUM | Uygulamayi durdur |
| `application-reload` | MEDIUM | Uygulamayi reload et |
| `application-markRunning` | LOW | Durum isaretleme |
| `application-move` | LOW | Baska projeye tasi |
| `application-cancelDeployment` | LOW | Deploy iptal |
| `application-cleanQueues` | LOW | Kuyruk temizle |
| `application-saveEnvironment` | MEDIUM | Env vars guncelle |
| `application-saveBuildType` | MEDIUM | Build type ayarla |
| `application-saveDockerProvider` | MEDIUM | Docker image kaynak |
| `application-saveGithubProvider` | MEDIUM | GitHub repo baglantisi |
| `application-saveGitlabProvider` | MEDIUM | GitLab repo baglantisi |
| `application-saveGiteaProvider` | MEDIUM | Gitea repo baglantisi |
| `application-saveBitbucketProvider` | MEDIUM | Bitbucket repo baglantisi |
| `application-saveGitProvider` | MEDIUM | Generic git repo |
| `application-disconnectGitProvider` | LOW | Git baglantisini kes |
| `application-readTraefikConfig` | READ | Traefik config oku |
| `application-updateTraefikConfig` | HIGH | Traefik config guncelle |
| `application-readAppMonitoring` | READ | Monitoring verileri |

### 4. Compose (25 tool) - DIKKATLI

> **NOT:** Compose tool'lar varsayilan olarak disabled'dir. `--enable-tools compose/` ile aktif edilir.
> Aktif degilse REST API fallback: `curl -X GET/POST http://localhost:3000/api/compose.*`

| Tool | Risk | Aciklama |
|------|------|----------|
| `compose-create` | LOW | Yeni compose service olustur |
| `compose-one` | READ | Compose detayi |
| `compose-update` | MEDIUM | Compose guncelle (YAML dahil) |
| `compose-deploy` | MEDIUM | Compose deploy et |
| `compose-redeploy` | MEDIUM | Tekrar deploy et |
| `compose-start` | LOW | Compose baslat |
| `compose-stop` | MEDIUM | Compose durdur |
| `compose-delete` | **CRITICAL** | Compose sil (deleteVolumes ile DATA LOSS!) |
| `compose-import` | MEDIUM | Base64 compose YAML import et |
| `compose-move` | LOW | Baska projeye tasi |
| `compose-cancelDeployment` | LOW | Deploy iptal |
| `compose-cleanQueues` | LOW | Kuyruk temizle |
| `compose-templates` | READ | Template listesi |
| `compose-deployTemplate` | MEDIUM | Template'den deploy |
| `compose-processTemplate` | READ | Template onizleme |
| `compose-isolatedDeployment` | MEDIUM | Izole deploy (test) |
| `compose-loadServices` | READ | Compose service listesi |
| `compose-loadMountsByService` | READ | Service mount'lari |
| `compose-fetchSourceType` | READ | Kaynak tipi sorgula |
| `compose-getConvertedCompose` | READ | Convert edilmis YAML |
| `compose-getDefaultCommand` | READ | Varsayilan komut |
| `compose-getTags` | READ | Mevcut tag'ler |
| `compose-randomizeCompose` | MEDIUM | Port/secret randomize |
| `compose-refreshToken` | LOW | Token yenile |
| `compose-disconnectGitProvider` | LOW | Git baglantisini kes |

### 5. Deployment (5 tool) - SAFE

| Tool | Risk | Aciklama |
|------|------|----------|
| `deployment-all` | READ | Tum deployment'lar |
| `deployment-allByCompose` | READ | Compose deployment'lari |
| `deployment-allByServer` | READ | Server deployment'lari |
| `deployment-allByType` | READ | Tipe gore (application, compose, backup, vb.) |
| `deployment-killProcess` | MEDIUM | Deploy islemini sonlandir |

### 6. Docker (7 tool) - DIKKATLI

| Tool | Risk | Aciklama |
|------|------|----------|
| `docker-getContainers` | READ | Tum container'lar (serverId gerekli) |
| `docker-getContainersByAppLabel` | READ | Label'a gore container |
| `docker-getContainersByAppNameMatch` | READ | isim eslesmesine gore |
| `docker-getServiceContainersByAppName` | READ | Service container'lari |
| `docker-getStackContainersByAppName` | READ | Stack container'lari |
| `docker-getConfig` | READ | Container config |
| `docker-restartContainer` | MEDIUM | Container restart |

### 7. Backup (11 tool) - SAFE

| Tool | Risk | Aciklama |
|------|------|----------|
| `backup-create` | LOW | Backup zamanlama olustur |
| `backup-one` | READ | Backup detayi |
| `backup-update` | LOW | Backup zamanlamasini guncelle |
| `backup-remove` | MEDIUM | Backup zamanlamasini sil |
| `backup-listBackupFiles` | READ | Backup dosya listesi |
| `backup-manualBackupPostgres` | LOW | Manuel PostgreSQL backup |
| `backup-manualBackupMySql` | LOW | Manuel MySQL backup |
| `backup-manualBackupMariadb` | LOW | Manuel MariaDB backup |
| `backup-manualBackupMongo` | LOW | Manuel MongoDB backup |
| `backup-manualBackupCompose` | LOW | Manuel Compose backup |
| `backup-manualBackupWebServer` | LOW | Manuel web server backup |

### 8. Domain (4 tool) - MEDIUM

| Tool | Risk | Aciklama |
|------|------|----------|
| `domain-all` | READ | Tum domain'ler |
| `domain-create` | MEDIUM | Domain ekle (SSL otomatik) |
| `domain-one` | READ | Domain detayi |
| `domain-update` | MEDIUM | Domain guncelle |

### 9. Registry (6 tool) - MEDIUM

| Tool | Risk | Aciklama |
|------|------|----------|
| `registry-all` | READ | Tum registry'ler |
| `registry-create` | MEDIUM | Registry ekle (credential) |
| `registry-one` | READ | Registry detayi |
| `registry-update` | MEDIUM | Registry guncelle |
| `registry-remove` | MEDIUM | Registry sil |
| `registry-testRegistry` | READ | Registry baglanti testi |

### 10. User (4 tool) - SAFE

| Tool | Risk | Aciklama |
|------|------|----------|
| `user-all` | READ | Tum kullanicilar |
| `user-get` | READ | Mevcut kullanici |
| `user-one` | READ | Kullanici detayi |
| `user-update` | LOW | Kullanici guncelle |

### 11. Server (5 tool) - MEDIUM

| Tool | Risk | Aciklama |
|------|------|----------|
| `server-all` | READ | Tum server'lar |
| `server-one` | READ | Server detayi |
| `server-create` | MEDIUM | Remote server ekle |
| `server-update` | MEDIUM | Server guncelle |
| `server-getDefaultCommand` | READ | Varsayilan server komutu |

---

## Davranis Kurallari (ZORUNLU)

### 1. Risk-Bazli Onay Sistemi

**READ tool'lari:** Onaysiz calistirilabilir.

**LOW risk tool'lari:** Bilgi vererek calistir.

**MEDIUM risk tool'lari:** Islem oncesi kullaniciya ne yapilacagini bildir.
Ornek: "nocobase uygulamasini deploy ediyorum. Onayliyor musun?"

**HIGH/CRITICAL risk tool'lari:** AskUserQuestion ile MUTLAKA onay al.
Ozellikle `compose-delete` icin `deleteVolumes: true` DATA LOSS'a neden olur!

```
compose-delete → AskUserQuestion:
  "Bu compose service'i silmek istiyorsun.
   Volume'leri de silmek istiyor musun? (DATA LOSS!)"
  Secenekler: "Sadece service (volume'ler kalsin)" / "Herseyi sil (DATA LOSS)"
```

### 2. ID Cozumleme Protokolu

Kullanici isim ile istek yapar (orn: "nocobase'i deploy et").
Claude ID'yi bulmali:

```
1. project-all() → projectId bul
2. project-one(projectId) → environments listesi → environmentId
3. Environment iceriginden applicationId veya composeId bul
4. Hedef tool'u cagir
```

Her adimi kullaniciya gostermeden sessizce yap.
Birden fazla eslesme varsa → AskUserQuestion ile sor.

### 3. Deploy Oncesi Kontrol

Deploy veya redeploy oncesi:
1. Mevcut durumu kontrol et (application-one veya compose-one)
2. Eger zaten running ise → "Zaten calisiyor, redeploy mi istiyorsun?" sor
3. Env vars bos ise → uyar

### 4. Compose YAML Import Kurallari

`compose-import` tool'u base64 encoded YAML kabul eder.
Kullanicidan ham YAML gelirse:
1. YAML syntax'ini dogrula
2. Base64'e cevir
3. `compose-import(composeId, base64)` ile gonder

### 5. Deployment Takibi

Deploy sonrasi:
1. `deployment-allByCompose(composeId)` veya `deployment-allByType(id, "application")` ile durum kontrol et
2. Son deployment'in status'unu kullaniciya bildir
3. Hata varsa → log kontrolu oner

### 6. Backup Best Practice

Backup olusturulurken:
- `schedule` parametresi cron formati: `0 2 * * *` (her gun saat 02:00)
- `prefix` benzersiz olmali (ornek: `nocobase-db-`)
- `keepLatestCount` ayarla (varsayilan 5)
- `destinationId` gerekli → once mevcut destination'lari kontrol et

---

## Kullanici Istekleri → Tool Mapping

### Proje Listeleme / Bilgi Alma
```
User: "projeleri goster", "ne var ne yok"
→ project-all()
→ Sonuc: proje listesi (ad, environmentId, application/compose sayisi)
```

### Proje Silme (CRITICAL - REST API)
```
User: "voicebox projesini sil", "projeyi kaldır"
→ 1. project-all() → projectId bul
→ 2. AskUserQuestion: "İçindeki tüm compose/app'ler de silinsin mi? Volume'ler?"
→ 3. İçindeki compose'ları önce compose-delete() ile sil (deleteVolumes seçime göre)
→ 4. REST API ile projeyi sil:
     DOKPLOY_KEY=$(cat ~/.claude.json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['mcpServers']['DokployServer']['env']['DOKPLOY_API_KEY'])")
     curl -s -X POST "http://localhost:3000/api/project.remove" \
       -H "x-api-key: $DOKPLOY_KEY" \
       -H "Content-Type: application/json" \
       -d '{"projectId":"PROJECT_ID"}'
→ NOT: MCP'de project-delete tool'u YOKTUR. Her zaman REST API kullan.
```

### Yeni Proje Olusturma
```
User: "yeni proje olustur: my-app"
→ project-create(name="my-app")
→ Sonuc: projectId ve otomatik olusturulan environmentId
```

### Application Deploy (Docker Image)
```
User: "nginx deploy et"
→ 1. project-all() → projectId bul veya yeni olustur
→ 2. project-one(projectId) → environmentId al
→ 3. application-create(name="nginx", environmentId)
→ 4. application-saveDockerProvider(applicationId, dockerImage="nginx:latest")
→ 5. application-deploy(applicationId)
```

### Application Deploy (GitHub Repo)
```
User: "github.com/user/repo deploy et"
→ 1. Proje/environment hazirla (yukaridaki gibi)
→ 2. application-create(name, environmentId)
→ 3. application-saveGithubProvider(applicationId, owner, repository, branch)
→ 4. application-saveBuildType(applicationId, buildType="nixpacks"|"dockerfile")
→ 5. application-deploy(applicationId)
```

### Compose Deploy (YAML)
```
User: "bu compose'u deploy et: [YAML]"
→ 1. Proje/environment hazirla
→ 2. compose-create(name, appName, projectId, environmentId)
→ 3. compose-import(composeId, base64=encode(YAML))
→ 4. compose-deploy(composeId)
```

### Template Deploy
```
User: "template'lerden birini deploy et"
→ 1. compose-templates() → template listesi goster
→ 2. Kullanici secer
→ 3. compose-deployTemplate(environmentId, id=templateId)
```

### Redeploy
```
User: "nocobase'i tekrar deploy et"
→ 1. ID cozumle (project-all → compose-one veya application-one)
→ 2. compose-redeploy(composeId) veya application-redeploy(applicationId)
```

### Durdur / Baslat
```
User: "nocobase'i durdur"
→ compose-stop(composeId) veya application-stop(applicationId)

User: "nocobase'i baslat"
→ compose-start(composeId) veya application-start(applicationId)
```

### Domain Ekleme
```
User: "nocobase.example.com domain ekle"
→ 1. ID cozumle
→ 2. domain-create(applicationId/composeId ile iliskili parametreler)
→ Let's Encrypt otomatik SSL saglar
```

### Deployment Gecmisi
```
User: "son deployment'lar ne durumda"
→ deployment-all() veya deployment-allByCompose(composeId)
→ Sonuc: tarih, status (done/error/running), sure
```

### Backup Zamanlama
```
User: "nocobase db'si icin gunluk backup ayarla"
→ 1. backup-create(
      name="nocobase-daily",
      schedule="0 2 * * *",
      prefix="nocobase-db-",
      destinationId=...,
      database="nocobase",
      databaseType="postgres",
      composeId=...
   )
```

### Manuel Backup
```
User: "nocobase'in backup'ini hemen al"
→ 1. Backup config ID'yi bul
→ 2. backup-manualBackupPostgres(backupId) veya ilgili DB tipi
```

### Container Yonetimi
```
User: "container'lari goster"
→ 1. server-all() → serverId
→ 2. docker-getContainers(serverId)

User: "nocobase container'ini restart et"
→ docker-restartContainer(serverId, containerId)
```

### Monitoring
```
User: "nocobase'in kaynak kullanimi"
→ application-readAppMonitoring(appName)
```

### Traefik Config
```
User: "traefik yapilandirmasini goster"
→ application-readTraefikConfig(applicationId)
```

---

## Build Types

| Build Type | Aciklama | Kaynak |
|-----------|----------|--------|
| `dockerfile` | Repo'daki Dockerfile | Git repo |
| `nixpacks` | Otomatik algilama (Node, Python, Go, vb.) | Git repo |
| `heroku_buildpacks` | Heroku buildpack uyumlu | Git repo |
| `paketo_buildpacks` | Cloud Native Buildpacks | Git repo |
| `static` | Statik site (HTML/CSS/JS) | Git repo |
| `railpack` | Rails uyumlu | Git repo |

**Onerilen:** Cogu proje icin `nixpacks` en kolay secenektir - otomatik dil/framework algilama.

## Hata Durumlari

| Hata | Nedeni | Cozum |
|------|--------|-------|
| `401 Unauthorized` | API key gecersiz/eksik | Settings > API'den yeni key olustur |
| `404 Not Found` | Yanlis ID veya silinmis kaynak | project-all ile ID'leri yeniden kontrol et |
| `Application not found` | applicationId gecersiz | ID cozumleme protokolunu takip et |
| `Compose not found` | composeId gecersiz | project-one ile environment icerigini kontrol et |
| `Deploy failed` | Build hatasi, image bulunamadi | deployment-allByType ile log kontrol et |
| `Port conflict` | Port zaten kullaniliyor | Compose YAML'da portu degistir |
| `Volume permission denied` | Docker Swarm SELinux | Named volume kullan, bind mount degil |
| `Connection refused` | Dokploy servisi calismiyior | `docker service ls` ile kontrol et |
| `Base64 decode error` | compose-import hatali encoding | YAML → UTF-8 → base64 encode kontrol et |

---

## Kritik Uyarilar

1. **compose-delete DATA LOSS:** `deleteVolumes: true` ile cagrildiginda tum veriler kaybolur.
   MUTLAKA kullanicidan onay al. Mumkunse once backup al.

2. **API Key Guvenligi:** DOKPLOY_API_KEY `.claude.json`'da saklaniyor.
   Bu dosyayi ASLA paylasilabilir repoya commit etme.

3. **compose-import Base64:** Compose YAML'i `base64` encode etmen gerekir.
   Bash ile: `echo -n "YAML_CONTENT" | base64`

4. **application-update 90+ Parametre:** Sadece degistirmek istedigin parametreleri gonder,
   `applicationId` disindaki parametrelerin hepsi opsiyonel.

5. **Swarm vs Standalone:** Dokploy Docker Swarm modunda calisir.
   Container restart icin `docker-restartContainer` kullan, direkt `docker restart` degil.

6. **Environment Otomatik Olusturma:** Proje olusturuldiginda otomatik olarak
   bir default environment olusur. Ekstra environment lazim degilse yenisini olusturmana gerek yok.

7. **Server ID Zorunlulugu:** Docker ve bazi deployment tool'lari `serverId` ister.
   `server-all()` ile once server ID'yi al.

8. **MCP Environment Variables Bug (KRITIK):** `application-saveEnvironment` ve `compose-update`
   calisiyor gorunuyor AMA container'a env var'lar iletilmiyor. Container inspect'de gorunmez.
   **COZUM:** Database gerektiren uygulamalarda (PostgreSQL, MySQL) veya ozel env gerektiren
   uygulamalarda DIREK Manuel docker-compose ile deploy et. MCP workflow guvenilmez.

9. **Compose File Update Bug:** `compose-update` composeFile alanini guncellemiyor.
   **COZUM:** Compose silip yeniden olustur VEYA REST API: `curl -X PATCH http://localhost:3000/api/compose/{composeId}`

10. **Evolution API / Database Gerektiren Uygulamalar:** DATABASE_PROVIDER zorunlu.
    Gecerli degerler: `postgresql`, `mysql`, `psql_bouncer`. `sqlite` veya `false` CALISMAZ.
    DATABASE_ENABLED=false bile calismiyor. PostgreSQL ile birlikte deploy et.

---

**Referans Dosyalari:**
- `references/tool-reference.md` → 98 tool'un detayli parametre tablolari
- `references/workflow-examples.md` → Adim adim senaryo ornekleri

**Skill Metadata:**
- Created: 2026-02-12
- Updated: 2026-02-22
- Version: 1.2.0
- Author: Ayaz + Claude Sonnet 4.6
- MCP Server: DokployServer (dokploy-mcp v1.0.7, tacticlaunch)
- Dokploy Platform: v0.27.0
- Tool Count: 98 aktif (55 default + 25 compose via --enable-tools + 18 diger)

**v1.2.0 Degisiklikleri:**
- Playwright oto-tetik kurali eklendi (UI hata = browser katmani test)
- WAHA deploy golden path eklendi (port 3002, NOWEB, 3 auth katmani)
- WAHA dashboard "Server connection failed" fix dokumanlandi
- Browser localStorage pattern eklendi (edge cases)
- Multi-katmanlı auth mimarisi aciklandi
- errors.md tamamen yeniden yazildi (deploy karar agaci, MCP guvenilmez alanlar)
- golden-paths.md genisletildi (9 senaryo, adim adim talimatlar)
- SKILL.md KRITIK KURALLAR bolumu eklendi
