---
name: dokploy-manage
description: |
  Dokploy self-hosted PaaS platform yonetimi (MCP API).
  Browser automation KULLANMAZ - Direkt DokployServer MCP API ile calisir.

  PLATFORM: Dokploy (30.2k GitHub stars) - Docker + Traefik mimarisi

  KULLANIM DURUMLARI:
  - Uygulama deploy et, redeploy, rollback
  - Compose service olustur ve deploy et
  - Docker container yonetimi (restart, logs, status)
  - Backup zamanlama ve manuel tetikleme
  - Domain / SSL yonetimi
  - Proje ve environment yonetimi
  - Registry (Docker Hub, GHCR, private) yonetimi
  - Server yonetimi (multi-node)
  - Deployment gecmisi ve izleme

  TRIGGERS: dokploy, deploy, redeploy, rollback, compose deploy,
  backup, domain, ssl, traefik, container restart, deployment

  CONTEXT: Kullanici Dokploy platformu ile ilgili islem istiyor

  KRiTiK: Bu skill MCP API kullanir. Playwright plugin KULLANMA!
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

### 1. Project (4 tool) - SAFE

| Tool | Risk | Aciklama |
|------|------|----------|
| `project-all` | READ | Tum projeleri listele |
| `project-one` | READ | Proje detayi (environments dahil) |
| `project-create` | LOW | Yeni proje olustur |
| `project-update` | LOW | Proje adini/aciklamasini guncelle |

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

### Compose Deploy (YAML)
```
User: "bu compose'u deploy et: [YAML]"
→ 1. Proje/environment hazirla
→ 2. compose-create(name, appName, projectId, environmentId)
→ 3. compose-import(composeId, base64=encode(YAML))
→ 4. compose-deploy(composeId)
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
```

### Domain Ekleme
```
User: "nocobase.example.com domain ekle"
→ 1. ID cozumle
→ 2. domain-create(host, https=true, certificateType="letsencrypt")
→ Let's Encrypt otomatik SSL saglar
```

### Container Yonetimi
```
User: "container'lari goster"
→ 1. server-all() → serverId
→ 2. docker-getContainers(serverId)
```

---

## Hata Durumlari

| Hata | Nedeni | Cozum |
|------|--------|-------|
| `401 Unauthorized` | API key gecersiz/eksik | Settings > API'den yeni key olustur |
| `404 Not Found` | Yanlis ID veya silinmis kaynak | project-all ile ID'leri yeniden kontrol et |
| `Deploy failed` | Build hatasi, image bulunamadi | deployment-allByType ile log kontrol et |
| `Port conflict` | Port zaten kullaniliyor | Compose YAML'da portu degistir |
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

4. **Swarm vs Standalone:** Dokploy Docker Swarm modunda calisir.
   Container restart icin `docker-restartContainer` kullan, direkt `docker restart` degil.

5. **Environment Otomatik Olusturma:** Proje olusturuldiginda otomatik olarak
   bir default environment olusur.

---

**Referans Dosyalari:**
- `references/tool-reference.md` → 98 tool'un detayli parametre tablolari
- `references/workflow-examples.md` → Adim adim senaryo ornekleri
- `references/setup-guide.md` → Dokploy + MCP kurulum detaylari

**Skill Metadata:**
- Version: 1.1.0
- MCP Server: DokployServer (dokploy-mcp v1.0.7, tacticlaunch)
- Tool Count: 98 aktif (55 default + 25 compose via --enable-tools + 18 diger)
