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
| herokuVersion | string/null | | Heroku versiyon |
| railpackVersion | string/null | | Railpack versiyon |
| isStaticSpa | boolean/null | | SPA mi? |

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
| triggerType | enum | | `push`, `tag` |
| enableSubmodules | boolean | | Submodule aktif |
| watchPaths | string[] | | Izlenecek yollar |

### application-saveGitlabProvider
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| applicationId | string | * | App ID |
| gitlabId | string/null | * | GitLab ID |
| gitlabProjectId | number/null | * | GitLab proje ID |
| gitlabOwner | string/null | * | Owner |
| gitlabRepository | string/null | * | Repo |
| gitlabBranch | string/null | * | Branch |
| gitlabBuildPath | string/null | * | Build yolu |
| gitlabPathNamespace | string/null | * | Namespace |
| enableSubmodules | boolean | | Submodule |
| watchPaths | string[] | | Watch paths |

### application-saveGitProvider (Generic Git)
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| applicationId | string | * | App ID |
| gitUrl | string | * | Git repo URL (SSH/HTTPS) |
| branch | string | * | Branch |
| buildPath | string | | Build yolu |
| username | string | | Git kullanici |
| password | string | | Git sifre/token |

### application-saveGiteaProvider
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| applicationId | string | * | App ID |
| giteaId | string/null | * | Gitea ID |
| giteaOwner | string/null | * | Owner |
| giteaRepository | string/null | * | Repo |
| giteaBranch | string/null | * | Branch |
| giteaBuildPath | string/null | * | Build yolu |
| enableSubmodules | boolean | | Submodule |
| watchPaths | string[] | | Watch paths |

### application-saveBitbucketProvider
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| applicationId | string | * | App ID |
| bitbucketId | string/null | * | Bitbucket ID |
| bitbucketOwner | string/null | * | Owner |
| bitbucketRepository | string/null | * | Repo |
| bitbucketBranch | string/null | * | Branch |
| bitbucketBuildPath | string/null | * | Build yolu |
| enableSubmodules | boolean | | Submodule |
| watchPaths | string[] | | Watch paths |

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
| buildPath | string/null | |
| dockerContextPath | string/null | |
| dockerBuildStage | string/null | |
| buildArgs | string/null | |

**Kaynak limitleri:**
| Parametre | Tip | Aciklama |
|-----------|-----|----------|
| cpuLimit | string/null | Orn: "0.5" (yarim core) |
| cpuReservation | string/null | Garanti CPU |
| memoryLimit | string/null | Orn: "512M" |
| memoryReservation | string/null | Garanti RAM |
| replicas | number | Replika sayisi |

**Swarm ayarlari (ileri duzey):**
healthCheckSwarm, labelsSwarm, modeSwarm, networkSwarm,
placementSwarm, restartPolicySwarm, rollbackConfigSwarm,
updateConfigSwarm, stopGracePeriodSwarm

**Preview deployment ayarlari:**
previewBuildArgs, previewEnv, previewPort, previewPath,
previewHttps, previewLimit, previewWildcard,
previewCertificateType (letsencrypt/none/custom),
previewCustomCertResolver, previewLabels,
previewRequireCollaboratorPermissions

> NOT: Sadece `applicationId` zorunlu. Diger parametreler opsiyonel -
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

### compose-update
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| composeId | string | * | Compose ID |
| (+ compose config fields) | | | |

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
| baseUrl | string | | Base URL |
| serverId | string | | Hedef server |

### compose-templates
Parametre yok. Mevcut template'leri listeler.

### compose-processTemplate
Template onizleme. Template ID ve parametreler.

### compose-isolatedDeployment
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| composeId | string | * | Test deploy |

### compose-loadServices / compose-loadMountsByService
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| composeId | string | * | Compose ID |

### compose-fetchSourceType / compose-getConvertedCompose / compose-getDefaultCommand / compose-getTags
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| composeId | string | * | Compose ID |

### compose-randomizeCompose
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| composeId | string | * | Port ve secret'lari randomize et |

### compose-move
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| composeId | string | * | Tasinacak compose |
| environmentId | string | * | Hedef environment |

### compose-cancelDeployment / compose-cleanQueues / compose-refreshToken / compose-disconnectGitProvider
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| composeId | string | * | Compose ID |

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

### docker-getServiceContainersByAppName / docker-getStackContainersByAppName
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| serverId | string | * | Server ID |
| appName | string | * | App adi |

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
| applicationId | string/null | | App ID |
| composeId | string/null | | Compose ID |
| postgresId | string/null | | PG service ID |
| mysqlId | string/null | | MySQL service ID |
| mariadbId | string/null | | MariaDB service ID |
| mongoId | string/null | | Mongo service ID |
| serviceName | string/null | | Service adi |
| enabled | boolean/null | | Aktif mi |
| keepLatestCount | number/null | | Saklanacak backup sayisi |
| metadata | any | | Ek metadata |

### backup-one
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| backupId | string | * | Backup ID |

### backup-update
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| backupId | string | * | Backup ID |
| schedule | string | * | Cron |
| prefix | string | * | Prefix |
| destinationId | string | * | Hedef |
| database | string | * | DB adi |
| serviceName | string/null | * | Service |
| databaseType | enum | * | DB tipi |
| enabled | boolean/null | | Aktif mi |
| keepLatestCount | number/null | | Saklama sayisi |
| metadata | any | | Metadata |

### backup-remove
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| backupId | string | * | Silinecek backup |

### backup-listBackupFiles
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| destinationId | string | * | Depolama ID |
| search | string | * | Arama terimi |
| serverId | string | | Server ID |

### backup-manualBackup{Postgres,MySql,Mariadb,Mongo,Compose,WebServer}
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| backupId | string | * | Tetiklenecek backup config |

---

## 8. Domain (4 tool)

### domain-all
Parametre yok. Tum domain'ler.

### domain-create
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| (domain config) | | | Detay icin API docs |

### domain-one
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| domainId | string | * | Domain ID |

### domain-update
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| domainId | string | * | Guncelle |

---

## 9. Registry (6 tool)

### registry-all
Parametre yok.

### registry-create
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| registryName | string | * | Registry adi |
| username | string | * | Kullanici |
| password | string | * | Sifre |
| registryUrl | string (URI) | * | URL |
| registryType | const "cloud" | * | Tip |
| imagePrefix | string/null | * | Image on eki |
| serverId | string | | Server |

### registry-one
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| registryId | string | * | Registry ID |

### registry-update
Registry ID + guncellenecek alanlar.

### registry-remove
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| registryId | string | * | Silinecek |

### registry-testRegistry
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| registryId | string | * | Test edilecek |

---

## 10. User (4 tool)

### user-all
Parametre yok.

### user-get
Parametre yok. Mevcut kullaniciyi dondurur.

### user-one
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| userId | string | * | Kullanici ID |

### user-update
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| userId | string | * | Kullanici ID |
| (+ user fields) | | | |

---

## 11. Server (5 tool)

### server-all
Parametre yok.

### server-one
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| serverId | string | * | Server ID |

### server-create
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| name | string | * | Server adi |
| (+ server config) | | | IP, SSH key, vb. |

### server-update
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| serverId | string | * | Server ID |
| (+ fields) | | | |

### server-getDefaultCommand
| Parametre | Tip | Zorunlu | Aciklama |
|-----------|-----|---------|----------|
| serverId | string | * | Server ID |
