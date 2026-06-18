---
mode: agent
description: 'Release checklist for intune-my-macs: validate changed artifacts, regenerate INTUNE-MY-MACS-DOCUMENTATION.md, update CHANGELOG.md, commit in logical units, and push to main (with confirmation). Run this when you have finished and tested a set of changes and want to ship them.'
---

# Ship to `main`

You are running the **release checklist** for the `intune-my-macs` repository. The user has finished and tested a set of changes in the working tree. Your job: get those changes onto `main` with documentation and changelog updated, in clean logical commits, then **pause for confirmation before pushing**.

Work autonomously through the steps below. Use real terminal/file tools — do not just describe the steps.

## Before you start

1. Run `git status` and `git --no-pager diff --stat HEAD`.
2. If the working tree is clean (nothing staged, unstaged, or untracked), tell the user there is nothing to ship and **stop**.
3. Summarise what changed and group the changes into logical units (one concern each).
4. Exclude anything that looks unrelated or accidental — stray editor buffers, secrets/tokens, large binaries, in-progress work. Call it out rather than committing it silently.

## Step 1 — Validate changed artifacts

For every added or modified artifact:

- **JSON policies** (`configurations/**/*.json`, `mde/*.json`): confirm they parse, and that Settings Catalog `settings[]` entries use **contiguous, 0-based string IDs** (`"0"`, `"1"`, `"2"`, …). Run the `get_errors` tool on them.
- **XML manifests** (`*.xml` containing `<MacIntuneManifest`): confirm they parse; `<ReferenceId>` follows the naming standard (see Repo facts) and is **unique** across the repo; `<SourceFile>` resolves to a real file; `<SettingsCount>` is plausible.
- **`.mobileconfig` / scripts (`.sh`, `.zsh`) / `.pkg`**: confirm a sibling `*.xml` manifest exists.

Fix any errors before continuing. If you cannot fix one, stop and report it.

## Step 2 — Regenerate documentation

If any artifact under `configurations/`, `mde/`, `scripts/`, `apps/`, or `custom attributes/` changed:

1. Regenerate the catalog: `python3 tools/Generate-ConfigurationDocumentation.py`
   - Add `--mde` **only** if the existing `INTUNE-MY-MACS-DOCUMENTATION.md` already documents the `mde/` folder (by default it does not).
2. Inspect `git --no-pager diff --stat -- INTUNE-MY-MACS-DOCUMENTATION.md` and spot-check the diff: it should reflect only the artifacts you changed. Nothing should be unexpectedly removed (e.g. a dropped MDE section means you used the wrong `--mde` setting).

Never hand-edit `INTUNE-MY-MACS-DOCUMENTATION.md` — it is generated.

## Step 3 — Update `CHANGELOG.md`

Add one row per logical change at the **top** of the table (newest first), matching the existing format exactly:

```
| YYYY-MM-DD | **Verb** short summary | Details, with every file path linked as [`path`](path) and any [#issue](url)/[#PR](url) references | Author |
```

- **Date** = today.
- **Verb** in bold: `Added` / `Changed` / `Fixed` / `Removed` / `Improved` / `Updated` / `Renamed`.
- **Details**: factual and concise; link every file path you mention.
- **Author**: derive from `git config user.name`. If unset, default to `Neil Johnson`.

## Step 4 — Commit

- Stage and commit in **logical units** (one concern per commit). Typical grouping:
  - artifact / code changes,
  - regenerated documentation + changelog (these can ride together, or with their artifact when that reads cleaner — use judgement).
- Write descriptive messages: a concise subject line, plus a bullet body for non-trivial changes.
- **Never** use `--no-verify`. **Never** force-push or `git reset --hard` published commits.

## Step 5 — Push (confirm first)

1. Show the commits that are ahead of the remote: `git --no-pager log --oneline origin/main..HEAD`.
2. **Ask the user to confirm** before pushing.
3. On confirmation: `git push origin main`.
4. Verify `git status -sb` shows the branch in sync with `origin/main`.

## Report

Summarise: commits created (with hashes), docs regenerated (artifact count delta), changelog rows added, and push status.

---

## Repo facts to respect

- **Distributed manifests** (`standards/manifest-standard.prd`): every artifact has a sibling `*.xml` with a `<MacIntuneManifest>` root. The loader (`Get-DistributedManifests` in `mainScript.ps1`) overrides the JSON `name` with `policyPrefix + <Name>`, so the JSON `name` field is cosmetic — the manifest `<Name>` is what ships.
- **Naming standard** (`standards/policy-naming-standard.prd`): reference IDs are `[TYPE]-[CATEGORY]-[NUMBER]`. TYPE: `POL` (Settings Catalog), `CMP` (compliance), `CFG` (`.mobileconfig`), `SCR` (script), `CAT` (custom attribute), `APP` (app/package). Always check for an existing collision before assigning a new number.
- **Intune token limitation**: `{{mail}}`, `{{userprincipalname}}`, `{{partialupn}}`, etc. resolve **only** in App Configuration policies and `.mobileconfig` profiles — **not** in Settings Catalog (`configurationPolicies`) policies. Leave them literal in source. `REPLACE_WITH_TENANT_ID` is substituted with the connected Entra tenant GUID at deploy time by `mainScript.ps1`; leave it literal in source too.
- **Generated docs**: `INTUNE-MY-MACS-DOCUMENTATION.md` is produced by `tools/Generate-ConfigurationDocumentation.py`. Always regenerate; never hand-edit.
- **Deploy is dry-run by default**: `mainScript.ps1` requires `--apply` to write to Intune (e.g. `pwsh ./mainScript.ps1 --assign-group "<group>" --apply`).
