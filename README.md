# FormFlow — Dockerized 3-Tier App with CI/CD

Group project deliverable. See `WORKSHEET.md` for the Phase 0 design (tier boundaries, tagging strategy,
secrets plan) and `INCIDENT_REPORT_TEMPLATE.md` for the required rollback incident report.

## Stack
- **frontend**: static HTML/JS served by Nginx, reverse-proxies `/api/*` to backend
- **backend**: Node/Express API (`/health`, `/api/version`, `/api/status`)
- **db**: Postgres, not exposed outside the Docker network
- **CI/CD**: GitHub Actions — build → tag (git SHA, never `latest`) → push to Docker Hub → SSH deploy to VM

## Local run (before pushing anywhere)

```bash
cp .env.example .env
# edit .env with real local values

DOCKERHUB_USER=youruser BACKEND_TAG=sha-local FRONTEND_TAG=sha-local \
  docker compose build backend frontend  # or docker build each with --build-arg GIT_SHA etc.

docker compose --env-file .env up -d
curl http://localhost/api/version
curl http://localhost/health
```

## VM setup (one-time)

```bash
# On the VM:
sudo mkdir -p /opt/formflow
cd /opt/formflow
git clone <your-repo-url> .
cp .env.example .env
chmod 600 .env
# fill in real DB_PASSWORD, JWT_SECRET, DOCKERHUB_USER
touch CURRENT_VERSION
```

Then set these as GitHub Actions repo secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `VM_HOST`,
`VM_USER`, `SSH_PRIVATE_KEY`.

## Deploying

Push to `main`. The pipeline in `.github/workflows/deploy.yml`:
1. Builds both images, tags each with `sha-<short-sha>` (and `v<semver>` if the commit is git-tagged)
2. Pushes to Docker Hub — no bare `latest` tag is ever pushed
3. SSHes into the VM, pulls the exact SHA tag, restarts only `backend`/`frontend` (db untouched)
4. Verifies `/api/version` on the VM matches the tag it just deployed
5. Appends the result to `/opt/formflow/CURRENT_VERSION`

To check what's live right now, from anywhere:
```bash
curl http://<vm-ip>/api/version
# or on the VM:
tail -n 1 /opt/formflow/CURRENT_VERSION
```

## Rolling back

```bash
# on the VM, inside /opt/formflow
./scripts/rollback.sh backend  sha-<previous-good-sha>
./scripts/rollback.sh frontend sha-<previous-good-sha>
./scripts/rollback.sh all      sha-<previous-good-sha>
```

The script pulls the already-built image (no rebuild), restarts only the affected tier(s), waits for the
healthcheck, and verifies `/api/version` matches before declaring success. See `WORKSHEET.md` §2.2 for
the full reasoning behind this being the rollback procedure.

## Deliverables checklist mapping

| Required | Where |
|---|---|
| Dockerfiles | `backend/Dockerfile`, `frontend/Dockerfile` |
| docker-compose.yml | `docker-compose.yml` |
| GitHub Actions workflow | `.github/workflows/deploy.yml` |
| Worksheet | `WORKSHEET.md` |
| Rollback procedure (tested + screenshotted) | `scripts/rollback.sh` + `screenshots/` (add your own after performing it) |
| Incident report | `INCIDENT_REPORT_TEMPLATE.md` (fill in with real evidence) |
