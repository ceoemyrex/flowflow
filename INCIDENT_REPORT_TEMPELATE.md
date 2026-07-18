# Incident Report — FormFlow

> Fill this in after you deliberately break something (bad deploy, bad config, etc.), perform the rollback
> for real, and screenshot each step. This is not a hypothetical exercise — the brief requires it be
> "performed once and screenshotted."

## Summary
- **Date/time (UTC):**
- **Reported by:**
- **Severity:**
- **Duration (detection → resolution):**

## Symptom
What did you observe, and how did you observe it? Attach the actual evidence (paste command output,
log excerpt, or a screenshot reference) — not a description of what you'd expect to see.

- Observed behavior:
- Command/log/screenshot that surfaced it:
```
$ curl -sf http://<vm-ip>/api/version
<paste actual output here>
```

## Investigation Trail
List what you checked, **in order**, and what each check ruled in or out. This is the part graders look
at most closely — it shows whether you debugged systematically or guessed.

1. Checked: ______ → Ruled out / confirmed: ______
2. Checked: ______ → Ruled out / confirmed: ______
3. Checked: ______ → Ruled out / confirmed: ______

## Root Cause
State it in one or two sentences. Not "the deploy broke," but the actual mechanism — e.g. "the backend
container was started with a stale `.env` missing `DB_PASSWORD`, so Postgres auth failed and every API
request 500'd."

## Fix
What did you change, and what's the before/after proof?

- **Before (broken):**
```
<command output / screenshot reference showing the failure>
```
- **Change made:** (e.g. `./scripts/rollback.sh backend sha-<previous-good-sha>`)
- **After (fixed):**
```
<command output / screenshot reference showing /api/version matching the rolled-back tag,
 and /health returning 200>
```

## Design Reflection
One paragraph. Did the Phase 0 design (separate tiers, immutable SHA tags, `CURRENT_VERSION` file,
health-checked deploys) make this failure more or less likely, and easier or harder to catch than it
would've been with the old "SSH in and copy files" approach? What would you change about the *design* —
not just this one fix — to reduce the chance of a similar incident next time?

---
*Screenshots referenced above should be attached alongside this report in the submission folder
(e.g. `screenshots/01-symptom.png`, `screenshots/02-rollback-command.png`, `screenshots/03-verified-fix.png`).*
