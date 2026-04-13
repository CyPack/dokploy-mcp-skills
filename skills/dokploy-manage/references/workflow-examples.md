# DokployServer - Workflow Ornekleri

Adim adim senaryolar. Her adimda kullanilan MCP tool belirtilmis.

---

## Senaryo 1: GitHub Reposundan Full Deployment

**Durum:** Kullanici GitHub'daki bir Node.js projesini deploy etmek istiyor.

```
Kullanici: "github.com/ayaz/my-api reposunu deploy et"

Adim 1: Proje Olustur
+-------------------------------------------+
| project-create(name="my-api")             |
| → projectId: "proj_abc123"                |
| → auto environmentId: "env_xyz789"        |
+-------------------------------------------+
              |
              v
Adim 2: Application Olustur
+-------------------------------------------+
| application-create(                       |
|   name="my-api",                          |
|   environmentId="env_xyz789"              |
| )                                         |
| → applicationId: "app_def456"             |
+-------------------------------------------+
              |
              v
Adim 3: GitHub Provider Ayarla
+-------------------------------------------+
| application-saveGithubProvider(           |
|   applicationId="app_def456",             |
|   owner="ayaz",                           |
|   repository="my-api",                    |
|   githubId=null,                          |
|   branch="main"                           |
| )                                         |
+-------------------------------------------+
              |
              v
Adim 4: Build Type Sec
+-------------------------------------------+
| application-saveBuildType(                |
|   applicationId="app_def456",             |
|   buildType="nixpacks",                   |
|   dockerContextPath=null,                 |
|   dockerBuildStage=null                   |
| )                                         |
+-------------------------------------------+
              |
              v
Adim 5: Env Vars Ayarla (gerekirse)
+-------------------------------------------+
| application-saveEnvironment(              |
|   applicationId="app_def456",             |
|   env="NODE_ENV=production\nPORT=3000"    |
| )                                         |
+-------------------------------------------+
              |
              v
Adim 6: Deploy
+-------------------------------------------+
| application-deploy(                       |
|   applicationId="app_def456",             |
|   title="Initial deployment"              |
| )                                         |
+-------------------------------------------+
              |
              v
Adim 7: Durum Kontrol
+-------------------------------------------+
| deployment-allByType(                     |
|   id="app_def456",                        |
|   type="application"                      |
| )                                         |
| → status: "done" / "error" / "running"    |
+-------------------------------------------+
```

---

## Senaryo 2: Template ile Hizli Deploy

**Durum:** Mevcut template'lerden birini (orn: Plausible Analytics) deploy etmek.

```
Kullanici: "analytics icin bir template deploy et"

Adim 1: Template Listele
+-------------------------------------------+
| compose-templates()                       |
| → [                                       |
|     { id: "plausible", name: "..." },     |
|     { id: "uptime-kuma", name: "..." },   |
|     { id: "grafana", name: "..." },       |
|     ...                                   |
|   ]                                       |
+-------------------------------------------+
              |
              v
Adim 2: Kullaniciya Sec (AskUserQuestion)
+-------------------------------------------+
| "Hangi template'i deploy etmek istersin?" |
| → Kullanici: "Plausible Analytics"        |
+-------------------------------------------+
              |
              v
Adim 3: Proje/Environment Hazirla
+-------------------------------------------+
| project-all() → mevcut proje var mi?      |
| Yoksa: project-create(name="analytics")   |
| → environmentId bul                       |
+-------------------------------------------+
              |
              v
Adim 4: Template Deploy
+-------------------------------------------+
| compose-deployTemplate(                   |
|   environmentId="env_xyz789",             |
|   id="plausible"                          |
| )                                         |
+-------------------------------------------+
              |
              v
Adim 5: Sonuc Bildir
+-------------------------------------------+
| "Plausible Analytics deploy edildi.        |
|  Port: 8000 (otomatik atanmis)            |
|  URL: http://localhost:8000"               |
+-------------------------------------------+
```

---

## Senaryo 3: Backup Zamanlama

**Durum:** Mevcut PostgreSQL veritabanina gunluk backup ayarlamak.

```
Kullanici: "nocobase icin gunluk backup ayarla"

Adim 1: ID Cozumle
+-------------------------------------------+
| project-all()                             |
| → projectId: "proj_nocobase"              |
|                                           |
| project-one("proj_nocobase")              |
| → environmentId → composeId bul           |
+-------------------------------------------+
              |
              v
Adim 2: Compose Service Detayi
+-------------------------------------------+
| compose-loadServices(composeId)           |
| → services: ["app", "postgres"]           |
|   postgres service → serviceName          |
+-------------------------------------------+
              |
              v
Adim 3: Backup Olustur
+-------------------------------------------+
| backup-create(                            |
|   name="nocobase-daily-backup",           |
|   schedule="0 2 * * *",                   |
|   prefix="nocobase-db-",                  |
|   destinationId="dest_local",             |
|   database="nocobase",                    |
|   databaseType="postgres",                |
|   composeId="comp_abc",                   |
|   serviceName="postgres",                 |
|   keepLatestCount=7                       |
| )                                         |
+-------------------------------------------+
              |
              v
Adim 4: Dogrulama
+-------------------------------------------+
| backup-one(backupId)                      |
| → schedule: "0 2 * * *"                   |
| → enabled: true                           |
| → keepLatestCount: 7                      |
|                                           |
| "Backup ayarlandi: Her gun 02:00'de       |
|  PostgreSQL backup alinacak.              |
|  Son 7 backup saklanacak."                |
+-------------------------------------------+

Acil Backup Gerekirse:
+-------------------------------------------+
| backup-manualBackupPostgres(backupId)     |
| → "Manuel backup baslatildi"              |
+-------------------------------------------+
```

---

## Senaryo 4: Custom Domain + SSL

**Durum:** Mevcut uygulamaya custom domain eklemek.

```
Kullanici: "nocobase.example.com domain'ini ekle"

Adim 1: Application/Compose ID Bul
+-------------------------------------------+
| project-all() → project-one()             |
| → applicationId veya composeId bul        |
+-------------------------------------------+
              |
              v
Adim 2: Domain Olustur
+-------------------------------------------+
| domain-create(                            |
|   ... applicationId/composeId,            |
|   host="nocobase.example.com",            |
|   https=true,                             |
|   certificateType="letsencrypt"           |
| )                                         |
+-------------------------------------------+
              |
              v
Adim 3: DNS Hatirlatmasi
+-------------------------------------------+
| "Domain eklendi. Simdi DNS ayari yap:     |
|                                           |
|  Tip: A Record                            |
|  Host: nocobase                           |
|  Value: <server-ip>                       |
|                                           |
|  SSL sertifikasi DNS yayilimi             |
|  sonrasi otomatik alinacak                |
|  (Let's Encrypt)."                        |
+-------------------------------------------+
              |
              v
Adim 4: Traefik Config Kontrol (opsiyonel)
+-------------------------------------------+
| application-readTraefikConfig(appId)      |
| → Mevcut Traefik routing kurallari        |
+-------------------------------------------+
```

---

## Senaryo 5: Rollback (Onceki Versiyona Don)

**Durum:** Son deploy hata verdi, onceki calisan versiyona donmek istiyor.

```
Kullanici: "my-api son deploy basarisiz, geri al"

Adim 1: Deployment Gecmisini Kontrol Et
+-------------------------------------------+
| deployment-allByType(                     |
|   id="app_def456",                        |
|   type="application"                      |
| )                                         |
| → [                                       |
|     { id: "dep_3", status: "error" },     |
|     { id: "dep_2", status: "done" },      |
|     { id: "dep_1", status: "done" }       |
|   ]                                       |
+-------------------------------------------+
              |
              v
Adim 2: Onceki Calisan Config'i Al
+-------------------------------------------+
| application-one("app_def456")             |
| → Mevcut config (git commit, image, vb.)  |
+-------------------------------------------+
              |
              v
Adim 3a: Docker Image ise → Onceki Tag
+-------------------------------------------+
| application-saveDockerProvider(            |
|   applicationId="app_def456",             |
|   dockerImage="my-api:v1.2.3"            |
| )                                         |
| → Onceki calisan tag'e geri don           |
+-------------------------------------------+

Adim 3b: Git ise → Onceki Commit
+-------------------------------------------+
| application-saveGithubProvider(           |
|   applicationId="app_def456",             |
|   branch="main"                           |
| )                                         |
| → veya belirli bir commit/tag             |
+-------------------------------------------+
              |
              v
Adim 4: Redeploy
+-------------------------------------------+
| application-redeploy("app_def456")        |
+-------------------------------------------+
              |
              v
Adim 5: Dogrulama
+-------------------------------------------+
| deployment-allByType(                     |
|   id="app_def456",                        |
|   type="application"                      |
| )                                         |
| → Son deployment: status="done"           |
|                                           |
| "Rollback basarili. Uygulama onceki       |
|  versiyonda calisiyor."                   |
+-------------------------------------------+
```

---

## Senaryo 6: Compose YAML Import ve Deploy

**Durum:** Kullanici elindeki docker-compose.yml'i Dokploy'a yukleyip deploy etmek istiyor.

```
Kullanici: "Bu compose'u deploy et:
  services:
    web:
      image: nginx:alpine
      ports:
        - '8080:80'"

Adim 1: Proje/Environment Hazirla
+-------------------------------------------+
| project-all() → Mevcut proje sec veya     |
| project-create(name="nginx-web")          |
| → environmentId al                        |
+-------------------------------------------+
              |
              v
Adim 2: Compose Olustur
+-------------------------------------------+
| compose-create(                           |
|   name="nginx-web",                       |
|   appName="nginx-web",                    |
|   projectId="proj_xxx",                   |
|   environmentId="env_yyy"                 |
| )                                         |
| → composeId: "comp_zzz"                   |
+-------------------------------------------+
              |
              v
Adim 3: YAML'i Base64 Encode + Import
+-------------------------------------------+
| YAML icerigi:                             |
|   services:                               |
|     web:                                  |
|       image: nginx:alpine                 |
|       ports:                              |
|         - '8080:80'                       |
|                                           |
| → Base64 encode                           |
| → compose-import(                         |
|     composeId="comp_zzz",                 |
|     base64="c2VydmljZXM6Cig..."           |
|   )                                       |
+-------------------------------------------+
              |
              v
Adim 4: Deploy
+-------------------------------------------+
| compose-deploy(composeId="comp_zzz")      |
+-------------------------------------------+
              |
              v
Adim 5: Service Kontrol
+-------------------------------------------+
| compose-loadServices(composeId)           |
| → services: ["web"]                       |
|                                           |
| deployment-allByCompose(composeId)        |
| → status: "done"                          |
|                                           |
| "nginx deploy edildi. http://localhost:8080|
|  adresinden erisebilirsin."               |
+-------------------------------------------+
```

---

## Hizli Referans: Yaygin Islem → Tool Eslesmesi

| Islem | Tool Sirasi |
|-------|-------------|
| Proje listele | `project-all` |
| App deploy (Docker) | `project-create` → `application-create` → `saveDockerProvider` → `application-deploy` |
| App deploy (Git) | `project-create` → `application-create` → `saveGithubProvider` → `saveBuildType` → `application-deploy` |
| Compose deploy | `project-create` → `compose-create` → `compose-import` → `compose-deploy` |
| Template deploy | `compose-templates` → `compose-deployTemplate` |
| Redeploy | `application-redeploy` veya `compose-redeploy` |
| Durdur/Baslat | `*-stop` / `*-start` |
| Backup ayarla | `backup-create` |
| Manuel backup | `backup-manualBackup{DB}` |
| Domain ekle | `domain-create` |
| Container listele | `server-all` → `docker-getContainers` |
| Container restart | `docker-restartContainer` |
| Monitoring | `application-readAppMonitoring` |
| Deployment gecmisi | `deployment-allByType` |
