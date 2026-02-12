# Battle-Tested Patterns

Proven workflows and patterns from real usage. These save time and prevent common mistakes.

---

## Golden Paths

| Scenario | Steps | Prerequisites |
|----------|-------|---------------|
| GitHub repo deploy | `project-create` > `application-create` > `saveGithubProvider` > `saveBuildType(nixpacks)` > `application-deploy` > `deployment-allByType` | API key ready |
| Template deploy | `compose-templates` > user selects > `project-all/create` > `compose-deployTemplate(environmentId, templateId)` | Project/environment exists |
| Backup scheduling | `project-all` > `project-one` > `compose-loadServices` > `backup-create(schedule, prefix, keepLatestCount)` > `backup-one` verify | composeId + serviceName known |
| Domain + SSL | `project-all` > resolve ID > `domain-create(host, https=true, certificateType=letsencrypt)` > DNS reminder | DNS A record must be set |
| Rollback | `deployment-allByType` > find last working version > `saveDockerProvider/saveGithubProvider` > `application-redeploy` > verify | Deployment history exists |
| Compose YAML import | prepare project/env > `compose-create` > YAML to base64 > `compose-import` > `compose-deploy` > `compose-loadServices` | Valid YAML |
| Enable compose tools | Add `"--enable-tools", "compose/"` to MCP config args > restart Claude Code session | Config change + restart |
| REST API fallback | When compose MCP tools missing: `curl -X GET/POST http://localhost:3000/api/compose.{one,loadServices,stop,start,deploy}` | API key + composeId |
| Lightweight status check | Use REST API + jq instead of `compose-one` (50 tokens vs 15K): `curl ... compose.one?composeId=X \| jq '{name,composeStatus}'` | Context savings needed |
| Fix stuck composeStatus | Containers running but status=error > REST API: `POST compose.update {"composeId":"...","composeStatus":"done"}` | composeId known |

## Key Insights

1. **MCP tool response sizes vary wildly.** `compose-one` returns ~15K tokens (full YAML + mounts). Use `compose-loadServices` (~200 tokens) for routine checks.

2. **Session restart is mandatory after config changes.** Claude Code builds its deferred tools list at session start. `claude mcp remove/add` changes the config file but doesn't restart the running process.

3. **Not all API operations are exposed via MCP.** `project-remove`, `composeStatus` updates, and some admin operations require REST API fallback via curl.

4. **ID resolution is always needed.** Users say names ("nocobase"), Claude needs IDs. The chain is always: `project-all` > `project-one(projectId)` > get `environmentId` > find target `applicationId`/`composeId`.

5. **Docker Swarm changes container management.** Don't use `docker restart` directly — use the `docker-restartContainer` MCP tool or `docker service update`.

6. **Compose delete is destructive.** `compose-delete` with `deleteVolumes: true` causes permanent data loss. Always confirm with the user and suggest a backup first.
