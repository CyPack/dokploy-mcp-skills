# DokployServer - Workflow Ornekleri

Adim adim senaryolar. Her adimda kullanilan MCP tool belirtilmis.

---

## Senaryo 1: GitHub Reposundan Full Deployment

**Durum:** Kullanici GitHub'daki bir Node.js projesini deploy etmek istiyor.

```
Kullanici: "github.com/user/my-api reposunu deploy et"

Adim 1: Proje Olustur
  project-create(name="my-api")
  → projectId + auto environmentId

Adim 2: Application Olustur
  application-create(name="my-api", environmentId)
  → applicationId

Adim 3: GitHub Provider Ayarla
  application-saveGithubProvider(applicationId, owner, repository, branch="main")

Adim 4: Build Type Sec
  application-saveBuildType(applicationId, buildType="nixpacks", ...)

Adim 5: Env Vars (gerekirse)
  application-saveEnvironment(applicationId, env="NODE_ENV=production\nPORT=3000")

Adim 6: Deploy
  application-deploy(applicationId, title="Initial deployment")

Adim 7: Durum Kontrol
  deployment-allByType(id=applicationId, type="application")
  → status: "done" / "error" / "running"
```

---

## Senaryo 2: Template ile Hizli Deploy

```
Kullanici: "analytics icin bir template deploy et"

Adim 1: Template Listele
  compose-templates()
  → [{ id: "plausible", name: "..." }, ...]

Adim 2: Kullaniciya Sec (AskUserQuestion)

Adim 3: Proje/Environment Hazirla
  project-all() veya project-create(name="analytics")

Adim 4: Template Deploy
  compose-deployTemplate(environmentId, id="plausible")
```

---

## Senaryo 3: Backup Zamanlama

```
Kullanici: "nocobase icin gunluk backup ayarla"

Adim 1: ID Cozumle
  project-all() → project-one(projectId) → composeId bul

Adim 2: Service Detayi
  compose-loadServices(composeId)
  → services: ["app", "postgres"]

Adim 3: Backup Olustur
  backup-create(
    name="nocobase-daily-backup",
    schedule="0 2 * * *",
    prefix="nocobase-db-",
    destinationId="...",
    database="nocobase",
    databaseType="postgres",
    composeId="...",
    serviceName="postgres",
    keepLatestCount=7
  )

Adim 4: Dogrulama
  backup-one(backupId)
  → schedule, enabled, keepLatestCount
```

---

## Senaryo 4: Custom Domain + SSL

```
Kullanici: "nocobase.example.com domain'ini ekle"

Adim 1: ID Bul
  project-all() → project-one() → applicationId/composeId

Adim 2: Domain Olustur
  domain-create(host="nocobase.example.com", https=true, certificateType="letsencrypt")

Adim 3: DNS Hatirlatmasi
  "DNS A record ayarla: nocobase → <server-ip>
   SSL sertifikasi DNS yayilimi sonrasi otomatik alinacak."
```

---

## Senaryo 5: Rollback

```
Kullanici: "my-api son deploy basarisiz, geri al"

Adim 1: Deployment Gecmisi
  deployment-allByType(id=applicationId, type="application")
  → [dep_3: error, dep_2: done, dep_1: done]

Adim 2: Onceki Config
  application-one(applicationId)

Adim 3: Onceki Versiyon
  application-saveDockerProvider(applicationId, dockerImage="my-api:v1.2.3")
  veya
  application-saveGithubProvider(applicationId, branch="main")

Adim 4: Redeploy
  application-redeploy(applicationId)

Adim 5: Dogrulama
  deployment-allByType → status="done"
```

---

## Senaryo 6: Compose YAML Import ve Deploy

```
Kullanici: "Bu compose'u deploy et: [YAML]"

Adim 1: Proje/Environment Hazirla
  project-create(name="...") veya project-all()

Adim 2: Compose Olustur
  compose-create(name, appName, projectId, environmentId)
  → composeId

Adim 3: YAML Base64 Encode + Import
  compose-import(composeId, base64=encode(YAML))

Adim 4: Deploy
  compose-deploy(composeId)

Adim 5: Service Kontrol
  compose-loadServices(composeId)
  deployment-allByCompose(composeId)
  → status: "done"
```

---

## Hizli Referans: Islem → Tool Eslesmesi

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
