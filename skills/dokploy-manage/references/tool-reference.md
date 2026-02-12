# DokployServer - Tool Parametre Referansi

98 tool'un detayli parametre tablolari. Kategoriye gore gruplanmis.
`*` = zorunlu parametre.

---

## 1. Project (4 tool)

### project-all
Parametre yok. Tum projeleri listeler.

### project-create
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| name | string | * | Proje adi (min 1 karakter) |
| description | string | | Proje aciklamasi |
| env | string | | Environment variables |

### project-one
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| projectId | string | * | Proje ID |

### project-update
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| projectId | string | * | Proje ID |
| name | string | * | Yeni proje adi |
| description | string | | Aciklama |
| env | string | | Env vars |

---

## 2. Environment (3 tool)

### environment-create
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| name | string | * | Environment adi |
| projectId | string | * | Ait oldugu proje |
| description | string | | Aciklama |

### environment-one
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| environmentId | string | * | Environment ID |

### environment-update
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| environmentId | string | * | Environment ID |
| name | string | | Yeni ad |
| description | string | | Yeni aciklama |

---

## 3. Application (24 tool)

### application-create
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| name | string | * | Uygulama adi (min 1) |
| environmentId | string | * | Hedef environment |
| appName | string | | Teknik app adi |
| description | string/null | | Aciklama |
| serverId | string/null | | Hedef server |

### application-one
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| applicationId | string | * | Uygulama ID |

### application-deploy
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| applicationId | string | * | Deploy edilecek app |
| title | string | | Deploy basligi |
| description | string | | Deploy aciklamasi |

### application-redeploy
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| applicationId | string | * | Tekrar deploy |

### application-start / application-stop / application-reload
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| applicationId | string | * | Hedef app |

### application-markRunning
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| applicationId | string | * | Running olarak isaretle |

### application-move
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| applicationId | string | * | Tasinacak app |
| environmentId | string | * | Hedef environment |

### application-cancelDeployment / application-cleanQueues
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| applicationId | string | * | Hedef app |

### application-saveEnvironment
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| applicationId | string | * | App ID |
| env | string/null | | Env vars (KEY=VALUE\nKEY2=VALUE2) |
| buildArgs | string/null | | Build argumanlari |

### application-saveBuildType
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| applicationId | string | * | App ID |
| buildType | enum | * | `dockerfile`, `nixpacks`, `heroku_buildpacks`, `paketo_buildpacks`, `static`, `railpack` |
| dockerContextPath | string/null | * | Docker context yolu |
| dockerBuildStage | string/null | * | Multi-stage build stage |
| dockerfile | string/null | | Dockerfile icerigi |
| publishDirectory | string/null | | Publish dizini (static icin) |

### application-saveDockerProvider
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| applicationId | string | * | App ID |
| dockerImage | string/null | | Image adi (orn: nginx:latest) |
| username | string/null | | Registry kullanici |
| password | string/null | | Registry sifre |
| registryUrl | string/null | | Registry URL |

### application-saveGithubProvider
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| applicationId | string | * | App ID |
| owner | string/null | * | Repo sahibi |
| githubId | string/null | * | GitHub integration ID |
| repository | string/null | | Repo adi |
| branch | string/null | | Branch |
| buildPath | string/null | | Build yolu |

### application-saveGitProvider (Generic Git)
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| applicationId | string | * | App ID |
| gitUrl | string | * | Git repo URL (SSH/HTTPS) |
| branch | string | * | Branch |
| buildPath | string | | Build yolu |

### application-disconnectGitProvider
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| applicationId | string | * | Git baglantisi kesilecek app |

### application-readTraefikConfig
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| applicationId | string | * | App ID |

### application-updateTraefikConfig
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| applicationId | string | * | App ID |
| traefikConfig | string | * | Yeni Traefik YAML/TOML config |

### application-readAppMonitoring
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| appName | string | * | Uygulama teknik adi |

### application-update (90+ Parametre)

**Temel parametreler:**
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| applicationId | string | * | App ID (tek zorunlu) |
| name | string | | Uygulama adi |
| description | string/null | | Aciklama |
| enabled | boolean/null | | Aktif/pasif |
| env | string/null | | Env vars |

**Build ayarlari:**
| Parametre | Tip | Enum |
|-----------|-----|------|
| buildType | enum | dockerfile, nixpacks, heroku_buildpacks, paketo_buildpacks, static, railpack |
| sourceType | enum | github, docker, git, gitlab, bitbucket, gitea, drop |
| dockerImage | string/null | |
| dockerfile | string/null | |

**Kaynak limitleri:**
| Parametre | Tip | Aciklama |
|-----------|-----|----------|
| cpuLimit | string/null | Orn: "0.5" (yarim core) |
| cpuReservation | string/null | Garanti CPU |
| memoryLimit | string/null | Orn: "512M" |
| memoryReservation | string/null | Garanti RAM |
| replicas | number | Replika sayisi |

> NOT: Sadece `applicationId` zorunlu. Diger parametreler opsiyonel —
> sadece degistirmek istedigini gonder.

---

## 4. Compose (25 tool)

### compose-create
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| name | string | * | Compose adi (min 1) |
| appName | string | * | Teknik app adi |
| projectId | string | * | Proje ID |
| environmentId | string | * | Environment ID |
| description | string | | Aciklama |
| serverId | string | | Hedef server |

### compose-one
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| composeId | string | * | Compose ID |

### compose-deploy / compose-redeploy / compose-start / compose-stop
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| composeId | string | * | Compose ID |

### compose-delete (CRITICAL!)
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| composeId | string | * | Silinecek compose |
| deleteVolumes | boolean | * | **true = DATA LOSS!** |

### compose-import
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| composeId | string | * | Hedef compose |
| base64 | string | * | Base64 encoded YAML |

### compose-deployTemplate
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| environmentId | string | * | Hedef environment |
| id | string | * | Template ID |

### compose-templates
Parametre yok. Mevcut template'leri listeler.

### compose-loadServices / compose-loadMountsByService
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| composeId | string | * | Compose ID |

### compose-move
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| composeId | string | * | Tasinacak compose |
| environmentId | string | * | Hedef environment |

---

## 5. Deployment (5 tool)

### deployment-all
Parametre yok. Tum deployment'lar.

### deployment-allByCompose
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| composeId | string | * | Compose deployment'lari |

### deployment-allByServer
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| serverId | string | * | Server deployment'lari |

### deployment-allByType
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| id | string | * | Kaynak ID |
| type | enum | * | `application`, `compose`, `server`, `schedule`, `previewDeployment`, `backup`, `volumeBackup` |

### deployment-killProcess
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| deploymentId | string | * | Sonlandirilacak deploy |

---

## 6. Docker (7 tool)

### docker-getContainers
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| serverId | string | * | Server ID |

### docker-getContainersByAppLabel
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| serverId | string | * | Server ID |
| appName | string | * | App adi |
| type | enum | * | `standalone`, `swarm` |

### docker-getContainersByAppNameMatch
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| serverId | string | * | Server ID |
| appName | string | * | Eslesecek isim |

### docker-getConfig
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| serverId | string | * | Server ID |
| containerId | string | * | Container ID |

### docker-restartContainer
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| serverId | string | * | Server ID |
| containerId | string | * | Restart edilecek container |

---

## 7. Backup (11 tool)

### backup-create
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| name | string | * | Backup adi |
| schedule | string | * | Cron ifadesi (orn: `0 2 * * *`) |
| prefix | string | * | Dosya on eki |
| destinationId | string | * | Hedef depolama |
| database | string | * | DB adi |
| databaseType | enum | * | `postgres`, `mysql`, `mariadb`, `mongo`, `web-server` |
| keepLatestCount | number/null | | Saklanacak backup sayisi |

### backup-one
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| backupId | string | * | Backup ID |

### backup-manualBackup{Postgres,MySql,Mariadb,Mongo,Compose,WebServer}
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| backupId | string | * | Tetiklenecek backup config |

---

## 8-11. Domain, Registry, User, Server

### domain-create / domain-update / domain-one / domain-all
Domain CRUD. `domainId` ile yonetilir.

### registry-create / registry-update / registry-one / registry-all / registry-remove / registry-testRegistry
Registry CRUD. `registryId` ile yonetilir. `registryType` = "cloud".

### user-all / user-get / user-one / user-update
Kullanici yonetimi. `userId` ile.

### server-all / server-one / server-create / server-update / server-getDefaultCommand
Server yonetimi. `serverId` ile. Multi-node destegi.
