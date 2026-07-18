# FormFlow — Phase 0 Design Worksheet

## 2.1 Tier Boundaries

| Container | Contains | Does NOT contain |
|---|---|---|
| **frontend** | Static built assets (HTML/JS/CSS) served by Nginx. Nginx also reverse-proxies `/api/*` to the backend so the browser only ever talks to one origin. | No app logic, no DB driver, no secrets. |
| **backend** | Node/Express API: business logic, auth, `/api/version`, `/health`, DB client (pg). | No static asset serving, no direct internet exposure of the DB port. |
| **database** | Postgres, data volume only. | No application code. Never exposed outside the Docker network — only `backend` can reach port 5432. |

**Why three separate containers instead of one monolith:**

- **Independent versioning.** The founder's core ask is "what version is running right now." If frontend and backend are baked into one image, a backend-only bugfix forces a full frontend rebuild/redeploy too, and the "version" answer becomes ambiguous (which half changed?). Separate images = separate, precise version tags per tier.
- **Independent scaling/restart blast radius.** If the backend crashes, we can restart *just* that container without dropping the CORS/static layer, and vice versa. A monolith means one bad deploy takes down everything, including static assets that didn't even change.
- **Independent rollback.** If a bad backend release breaks something, we roll back the backend tag only — the frontend and DB stay untouched, which is faster and lower-risk than rolling back a combined artifact.
- **DB isolation is a security boundary, not just an organizational one.** Postgres should never be reachable from outside the Docker network. Splitting it into its own container with no published port is the only way to enforce that with Compose networking.

## 2.2 Versioning and Tagging Strategy

**Never `latest`.** Every image pushed to Docker Hub gets two tags, both applied at build time in CI:

1. **Immutable tag — the source of truth:** `sha-<git-short-sha>` (e.g. `formflow-backend:sha-a1b2c3d`). This is what's actually deployed. It's unique per commit, so it can never mean two different things.
2. **Human-readable tag — for release notes only:** `v<semver>` (e.g. `v1.4.0`), applied only when the commit is also tagged in git as a release. This is informational, not what deploy scripts key off of.

We also maintain one **moving pointer tag**, `stable`, which the *deploy* job (not the build job) re-points to whichever SHA tag was just successfully deployed and health-checked. `stable` is a convenience label for humans pulling the "current known-good" image manually — it is never what the automated pipeline deploys from, because moving tags are exactly the ambiguity we're trying to avoid.

**How we know what's live, at any moment, with certainty:**

- On every successful deploy, the CI pipeline SSHes into the VM and writes the deployed SHA tag to `/opt/formflow/CURRENT_VERSION` (plain text, one line per tier: `backend=sha-a1b2c3d`, `frontend=sha-e4f5g6h`).
- The backend also bakes its own build SHA into the image at build time (`ARG GIT_SHA`) and exposes it live at `GET /api/version` → `{"service":"backend","version":"sha-a1b2c3d","builtAt":"..."}`. The frontend does the same and shows it in a small footer badge.
- So "what's running right now" has two independent, always-agreeing answers: cat a file on the VM, or curl the running container. If they ever disagree, that itself is a symptom worth investigating.

**Rollback procedure, step by step:**

1. Identify the last known-good SHA tag. Source: `/opt/formflow/CURRENT_VERSION` history (we don't overwrite it, we append with a timestamp) or the GitHub Actions run history (every successful deploy is logged with its SHA tag).
2. On the VM, run `./scripts/rollback.sh <service> <sha-tag>` (checked into the repo, deployed alongside the app — see `scripts/rollback.sh`). This pulls the specific tagged image from Docker Hub (never rebuilds, never touches `main`), and does `docker compose up -d --no-deps <service>` so only that tier restarts.
3. Script waits for the container healthcheck to pass, then curls `/health` and `/api/version` and asserts the version matches the tag we rolled back to.
4. `CURRENT_VERSION` is updated with the rollback event, timestamp, and operator, so the rollback itself is part of the version history, not a silent edit.
5. Total rollback time target: under 2 minutes, since it's a pull + restart of one container, not a rebuild.

## 2.3 Secrets Handling Plan

| Secret | Lives in | Reaches the container via |
|---|---|---|
| `DB_PASSWORD` | GitHub Actions repo secrets (build/deploy time) + `/opt/formflow/.env` on the VM (runtime, `chmod 600`, owned by deploy user) | `env_file` in `docker-compose.yml`, injected as an environment variable — never an `ARG`/`ENV` baked into a Dockerfile layer |
| `JWT_SECRET` | Same as above | Same as above |
| `DOCKERHUB_TOKEN` (push access) | GitHub Actions repo secrets only | Used only inside the `docker/login-action` step in CI, never written to disk |
| `SSH_PRIVATE_KEY` (deploy access to VM) | GitHub Actions repo secrets only | Used only inside `appleboy/ssh-action`, never checked out into the repo |
| `VM_HOST` / `VM_USER` | GitHub Actions repo secrets | Passed as workflow inputs to the SSH action |

**Explicit statements, per the brief:**
- No secret is ever hardcoded in a Dockerfile (`ENV`/`ARG` for secrets is banned in this repo, code-reviewed against).
- No secret is ever committed to the repo. `.env` is in `.gitignore`; only `.env.example` (placeholder values) is committed.
- Secrets reach containers exclusively through Compose's `env_file`/`environment` mechanism at *runtime*, not through the image itself — meaning a leaked image on Docker Hub (which is effectively public once pushed) never leaks a credential.
- GitHub Actions secrets are scoped to the repo and masked automatically in logs.

**Divergence note:** if the actual build ends up passing `BUILD_VERSION`/`GIT_SHA` as a Dockerfile `ARG`, that's fine and expected — those are non-sensitive build metadata, not secrets, and are exactly what `/api/version` needs baked in at build time.
