<!-- Copyright (c) Microsoft Corporation. -->
<!-- Licensed under the MIT License. -->

# AGENTS.md — intune-my-macs

Canonical entry point for humans and coding agents working in this repository.
Start here, then follow the links below to the detailed docs and standards.

> **What this repo is:** a **proof-of-concept** toolkit that deploys a Microsoft
> Intune device configuration (policies, compliance, scripts, apps, optional
> Microsoft Defender for Endpoint) into a tenant from a single script. It is
> **sample/evaluation code, not a hardened production baseline** — see
> [README.md](README.md). Classification: **non-production**.

## Repository map

Platform artifact content lives under a per-platform folder (today: `macOS/`);
the deployment engine and developer tooling live at the repository root.

| Path | What lives here |
| --- | --- |
| `mainScript.ps1` | The deployment engine (PowerShell 7+). Selects a platform folder via `--platform` (default `macOS`), discovers that folder's artifact manifests, and creates/updates/deletes Intune objects via Microsoft Graph. |
| `Start-IntuneMyMacs.ps1` | macOS-only SwiftDialog GUI frontend for `mainScript.ps1`. |
| `macOS/` | All macOS artifact content (the deployable trees below). |
| `macOS/configurations/` | Settings Catalog policies (`.json`), custom configuration profiles (`.mobileconfig`), and compliance policies, grouped by area (`entra/`, `intune/`, `office/`, `Secure Enterprise Browser/`). |
| `macOS/apps/` | Application deployment manifests and helper scripts. |
| `macOS/custom attributes/` | macOS custom attribute scripts (`.zsh`/`.sh`) and their manifests. |
| `macOS/scripts/intune/` | Device shell scripts deployed via Intune (install/config). |
| `macOS/mde/` | Microsoft Defender for Endpoint onboarding, settings, and install script (opt-in via `--mde`). |
| `macOS/resources/` | Shared assets (e.g. wallpaper). |
| `tools/` | Local developer tooling (export, dedupe, doc generation, assignment reporting, fork-sync, verify). See [tools/README.md](tools/README.md). |
| `standards/` | The naming and manifest standards every artifact must follow. |
| `tools/verify.sh` | One-command local validation loop (run before pushing). |
| `.github/prompts/ship.prompt.md` | The release checklist (validate, regenerate docs, changelog, commit, push). |

## The manifest model (read this first)

Every deployable artifact (a `.json`, `.mobileconfig`, script, or `.pkg`) is
paired with a **sibling `.xml` manifest** containing a `<MacIntuneManifest>`
element. `mainScript.ps1` discovers artifacts by **scanning the selected
platform folder (e.g. `macOS/`) for these XML manifests** — a file without a
manifest is never deployed. Each manifest carries a unique `<ReferenceId>`, a
`<SourceFile>` that must resolve to a real file, and a `<SettingsCount>`.
Reference IDs follow the `TYPE-CATEGORY-NUMBER` standard (e.g. `POL-SEC-001`).

See [standards/policy-naming-standard.prd](standards/policy-naming-standard.prd)
and [standards/manifest-standard.prd](standards/manifest-standard.prd) for the
full rules, and [docs/conventions.md](docs/conventions.md) for the day-to-day
conventions an agent must follow.

## Build / run / validate loop

There is no compiled build. The fast local loop is:

```bash
# 1. Validate every artifact parses and scripts are syntactically sound:
./tools/verify.sh

# 2. Preview a deployment (dry-run is the default — nothing is created):
pwsh ./mainScript.ps1 --assign-group "Intune Mac Pilot"

# 3. Apply for real (only against an evaluation tenant):
pwsh ./mainScript.ps1 --assign-group "Intune Mac Pilot" --apply
```

`--platform` defaults to `macOS`; see [README.md](README.md) for the full flag
list. Run `./tools/verify.sh` before every push. When artifacts under `macOS/`
change, regenerate the catalog with
`python3 tools/Generate-ConfigurationDocumentation.py` (never hand-edit
`INTUNE-MY-MACS-DOCUMENTATION.md` — it is generated).

## Conventions an agent must follow

- Follow the reference-ID and display-name standards for any new artifact, and
  add a matching `.xml` manifest with a **unique** `<ReferenceId>`.
- Keep Settings Catalog `settings[]` IDs **contiguous and 0-based** (`"0"`,
  `"1"`, `"2"`, …).
- Add the Microsoft copyright header to every new source file
  (`# Copyright (c) Microsoft Corporation.` / `# Licensed under the MIT
  License.`). Never remove a pre-existing third-party copyright notice.
- Keep changes small and in logical units; update `CHANGELOG.md` (newest first).
- Full detail: [docs/conventions.md](docs/conventions.md).

## Key references

- [README.md](README.md) — quick start and what gets deployed.
- [CUSTOMIZATION-GUIDE.md](CUSTOMIZATION-GUIDE.md) — how to adapt the toolkit.
- [INTUNE-MY-MACS-DOCUMENTATION.md](INTUNE-MY-MACS-DOCUMENTATION.md) — generated payload catalog.
- [CONTRIBUTING.md](CONTRIBUTING.md) · [SECURITY.md](SECURITY.md) · [SUPPORT.md](SUPPORT.md).
- [.github/prompts/ship.prompt.md](.github/prompts/ship.prompt.md) — the release checklist.
