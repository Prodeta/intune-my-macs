# Customization Guide

> ⚠️ **Proof of Concept — not for production use.** The artifacts in this repository are sample code. Review, test, and adapt every change in a non-production tenant before considering it for production-managed devices. See [SUPPORT.md](SUPPORT.md).

How to configure, edit, and extend the artifacts in this repository.

## How the Project Works

Every deployable artifact (policy, script, app, custom attribute, etc.) consists of two files:

1. **Source file** — The actual payload (`.json`, `.mobileconfig`, `.sh`, `.zsh`, `.pkg`)
2. **XML manifest** — A sibling `.xml` file that tells `mainScript.ps1` how to deploy it

The main script recursively discovers all `*.xml` files containing `<MacIntuneManifest>`, parses them, and deploys the referenced source files to Intune via Microsoft Graph API.

## Artifact Types

| Type | Manifest `<Type>` | Source Format | Location |
|------|-------------------|---------------|----------|
| Settings Catalog Policy | `Policy` | `.json` | `configurations/intune/` or `configurations/entra/` |
| Custom Configuration Profile | `CustomConfig` | `.mobileconfig` | `configurations/intune/` |
| Compliance Policy | `Compliance` | `.json` | `configurations/intune/` |
| Enrollment Restriction | `EnrollmentRestriction` | `.json` | `configurations/intune/` |
| Shell Script | `Script` | `.sh` or `.zsh` | `scripts/intune/` |
| Application Package | `Package` | `.pkg` | `apps/` |
| Custom Attribute | `CustomAttribute` | `.sh` or `.zsh` | `custom attributes/` |
| Resource | `Resource` | any | `resources/` |

## Naming Convention

All artifacts use a reference ID in the format: `[TYPE]-[CATEGORY]-[NUMBER]`

**Type codes:** `POL` (policy), `CMP` (compliance), `CFG` (custom config), `SCR` (script), `CAT` (custom attribute), `APP` (application)

**Category codes:** `SEC` (security), `SYS` (system), `APP` (applications), `IDP` (identity), `MDE` (Defender), `UTL` (utilities), `CMP` (compliance)

**Number ranges:** `001-099` for core items, `100-999` for everything else. Numbers are never reused.

**File names** use lowercase with hyphens: `pol-sec-001-filevault.json` / `pol-sec-001-filevault.xml`

**Display names** use the format: `[Reference] - [Descriptive Name]` (e.g., `POL-SEC-001 - FileVault Disk Encryption`). The deployment prefix (`[intune-my-macs]`) is added automatically by `mainScript.ps1`.

---

## Editing Existing Artifacts

### Edit a Settings Catalog Policy

Settings Catalog policies are stored as JSON files exported from the Microsoft Graph API.

**Example:** To change the FileVault recovery key rotation in `configurations/intune/pol-sec-001-filevault.json`:

1. Open the `.json` file and locate the setting by its `settingDefinitionId`
2. Modify the `value` field (for choice settings) or the `simpleSettingValue` (for simple settings)
3. Update `<SettingsCount>` in the sibling `.xml` manifest if you added or removed settings
4. Run in dry-run mode to validate: `.\mainScript.ps1 --tenant-id <id> --config`
5. Apply: `.\mainScript.ps1 --tenant-id <id> --config --apply`

**JSON structure reference:**
```json
{
    "settingInstance": {
        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
        "settingDefinitionId": "com.apple.mcx.filevault2_enable",
        "choiceSettingValue": {
            "value": "com.apple.mcx.filevault2_enable_on"
        }
    }
}
```

> **Tip:** To find valid values for a setting, use the Intune Settings Catalog UI to configure the setting you want, then export the policy via Graph Explorer (`GET /beta/deviceManagement/configurationPolicies/{id}?$expand=settings`).

### Edit a Custom Configuration Profile

Custom profiles are `.mobileconfig` plist files.

**Example:** To change the screensaver idle time in `configurations/intune/cfg-sec-002-screensaver-idle.mobileconfig`:

1. Open the `.mobileconfig` in a text editor or Xcode
2. Modify the payload keys/values within the `<dict>` sections
3. No manifest changes needed unless the description is affected

### Edit a Shell Script

**Example:** To change which apps the onboarding monitor watches in `scripts/intune/scr-utl-100-dialog-onboarding.sh`:

1. Find the `APPS_TO_MONITOR` array in the script
2. Add, remove, or modify entries using the format: `"Display Name|/path/to/App.app|com.package.receipt.id"`
3. Update the `.xml` manifest description if the behavior changed significantly

Script execution settings are controlled in the XML manifest:

```xml
<Script>
    <RunAsAccount>system</RunAsAccount>              <!-- system or user -->
    <BlockExecutionNotifications>true</BlockExecutionNotifications>
    <ExecutionFrequency>PT0S</ExecutionFrequency>    <!-- PT0S = once, or ISO 8601 duration -->
    <RetryCount>3</RetryCount>                       <!-- 0-10 -->
</Script>
```

### Edit a Compliance Policy

Compliance policies use the same JSON format as Settings Catalog policies. Edit the `.json` file directly, modifying the compliance rules and scheduled actions.

### Edit an App Package

To update a PKG to a newer version:

1. Replace the `.pkg` file in `apps/` with the new version
2. Update `<PrimaryBundleVersion>` in the `.xml` manifest
3. Update `<Description>` if the version number is mentioned there

---

## Adding New Artifacts

### Add a New Settings Catalog Policy

1. **Export the policy JSON from Intune** using Graph Explorer:
   ```
   GET https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/{id}?$expand=settings
   ```
   Or configure the policy in the Intune portal and export it.

2. **Save the JSON** to the appropriate directory:
   ```
   configurations/intune/pol-sec-007-new-policy.json
   ```

3. **Create the XML manifest** as a sibling file (`pol-sec-007-new-policy.xml`):
   ```xml
   <MacIntuneManifest>
     <ReferenceId>POL-SEC-007</ReferenceId>
     <Version>1.0</Version>
     <Type>Policy</Type>
     <Name>POL-SEC-007 - Your Policy Name</Name>
     <Description>What this policy does (keep under 200 chars).</Description>
     <Platform>macOS</Platform>
     <Category>Security</Category>
     <SourceFile>configurations/intune/pol-sec-007-new-policy.json</SourceFile>
     <SettingsCount>5</SettingsCount>
   </MacIntuneManifest>
   ```

4. **Validate** with a dry run:
   ```powershell
   .\mainScript.ps1 --tenant-id <id> --config
   ```

### Add a New Custom Configuration Profile

1. **Create or export the `.mobileconfig`** file (from Apple Configurator, iMazing Profile Editor, or manually).

2. **Save it** to `configurations/intune/`:
   ```
   configurations/intune/cfg-sec-003-new-profile.mobileconfig
   ```

3. **Create the XML manifest** (`cfg-sec-003-new-profile.xml`):
   ```xml
   <MacIntuneManifest>
     <ReferenceId>CFG-SEC-003</ReferenceId>
     <Version>1.0</Version>
     <Type>CustomConfig</Type>
     <Name>CFG-SEC-003 - Your Profile Name</Name>
     <Description>What this profile configures.</Description>
     <Platform>macOS</Platform>
     <Category>Security</Category>
     <SourceFile>configurations/intune/cfg-sec-003-new-profile.mobileconfig</SourceFile>
   </MacIntuneManifest>
   ```

### Add a New Shell Script

1. **Write your shell script** (`.sh` for bash, `.zsh` for zsh):
   ```
   scripts/intune/scr-sys-200-your-script.sh
   ```
   Include a standard header:
   ```bash
   #!/bin/bash
   ############################################################################################
   ## Your Script Name
   ## VER 1.0.0
   ## Purpose: Brief description
   ############################################################################################
   ```

2. **Create the XML manifest** (`scr-sys-200-your-script.xml`):
   ```xml
   <MacIntuneManifest>
     <ReferenceId>SCR-SYS-200</ReferenceId>
     <Version>1.0</Version>
     <Type>Script</Type>
     <Name>SCR-SYS-200 - Your Script Name</Name>
     <Description>What this script does.</Description>
     <Platform>macOS</Platform>
     <Category>System Configuration</Category>
     <SourceFile>scripts/intune/scr-sys-200-your-script.sh</SourceFile>
     <Script>
       <RunAsAccount>system</RunAsAccount>
       <BlockExecutionNotifications>true</BlockExecutionNotifications>
       <ExecutionFrequency>PT0S</ExecutionFrequency>
       <RetryCount>3</RetryCount>
     </Script>
   </MacIntuneManifest>
   ```

**Script execution settings:**

| Setting | Options | Notes |
|---------|---------|-------|
| `RunAsAccount` | `system` or `user` | Use `system` for most management tasks |
| `BlockExecutionNotifications` | `true` / `false` | Hide Intune script notifications from users |
| `ExecutionFrequency` | ISO 8601 duration | `PT0S` = run once, `PT1H` = every hour, `P1D` = daily |
| `RetryCount` | `0` - `10` | Number of retries on failure |

### Add a New Application Package

1. **Place the `.pkg` file** in `apps/`:
   ```
   apps/app-utl-002-your-app.pkg
   ```

2. **Create the XML manifest** (`app-utl-002-your-app.xml`):
   ```xml
   <MacIntuneManifest>
     <ReferenceId>APP-UTL-002</ReferenceId>
     <Version>1.0</Version>
     <Type>Package</Type>
     <Name>APP-UTL-002 - Your App Name</Name>
     <Description>What this app does.</Description>
     <Platform>macOS</Platform>
     <Category>Config</Category>
     <SourceFile>apps/app-utl-002-your-app.pkg</SourceFile>
     <Package>
       <PrimaryBundleId>com.example.yourapp</PrimaryBundleId>
       <PrimaryBundleVersion>1.0.0</PrimaryBundleVersion>
       <Publisher>Publisher Name</Publisher>
       <MinimumSupportedOperatingSystem>v13_0</MinimumSupportedOperatingSystem>
       <IgnoreVersionDetection>true</IgnoreVersionDetection>
     </Package>
   </MacIntuneManifest>
   ```

   To find the bundle ID of a `.pkg`:
   ```bash
   pkgutil --expand YourApp.pkg /tmp/expanded && cat /tmp/expanded/PackageInfo
   ```

   Optional pre/post-install scripts can be specified:
   ```xml
   <Package>
     <PreInstallScript>apps/your-app_pre.sh</PreInstallScript>
     <PostInstallScript>apps/your-app_post.sh</PostInstallScript>
     ...
   </Package>
   ```

### Add a New Custom Attribute

1. **Write the attribute script** (must output a single string value):
   ```
   custom attributes/cat-sys-102-your-attribute.zsh
   ```

2. **Create the XML manifest** (`cat-sys-102-your-attribute.xml`):
   ```xml
   <MacIntuneManifest>
     <ReferenceId>CAT-SYS-102</ReferenceId>
     <Version>1.0</Version>
     <Type>CustomAttribute</Type>
     <Name>CAT-SYS-102 - Your Attribute Name</Name>
     <Description>What this attribute reports.</Description>
     <Platform>macOS</Platform>
     <Category>Device Information</Category>
     <SourceFile>custom attributes/cat-sys-102-your-attribute.zsh</SourceFile>
     <CustomAttribute>
       <CustomAttributeType>string</CustomAttributeType>
     </CustomAttribute>
   </MacIntuneManifest>
   ```

### Add a New Compliance Policy

1. **Export or create the compliance JSON** (same Graph API format as Settings Catalog).

2. **Save and create the manifest** following the same pattern:
   ```xml
   <MacIntuneManifest>
     <ReferenceId>CMP-CMP-002</ReferenceId>
     <Version>1.0</Version>
     <Type>Compliance</Type>
     <Name>CMP-CMP-002 - Your Compliance Policy</Name>
     <Description>Compliance requirements.</Description>
     <Platform>macOS</Platform>
     <Category>Compliance</Category>
     <SourceFile>configurations/intune/cmp-cmp-002-your-policy.json</SourceFile>
   </MacIntuneManifest>
   ```

---

## Excluding Artifacts from Deployment

You don't need to delete files to exclude them. Use the CLI selectors to deploy only what you need:

```powershell
# Deploy only scripts
.\mainScript.ps1 --tenant-id <id> --scripts --apply

# Deploy only policies and compliance
.\mainScript.ps1 --tenant-id <id> --config --apply

# Deploy only apps
.\mainScript.ps1 --tenant-id <id> --apps --apply
```

MDE artifacts (in the `mde/` folder) are excluded by default. Add `--mde` to include them.

To permanently remove an artifact, delete both the source file and its `.xml` manifest.

---

## Validation and Testing

### Dry Run (Default)

Every run without `--apply` is a dry run that previews what will be created:

```powershell
.\mainScript.ps1 --tenant-id <id> --assign-group "Mac Management"
```

### Check for Duplicate Settings

Use the built-in tool to detect conflicts across policies:

```powershell
.\tools\Find-DuplicatePayloadSettings.ps1
```

### Regenerate Documentation

After making changes, update the auto-generated documentation:

```bash
python tools/Generate-ConfigurationDocumentation.py
```

---

## Quick Reference: Manifest Templates

<details>
<summary>Policy</summary>

```xml
<MacIntuneManifest>
  <ReferenceId>POL-SEC-NNN</ReferenceId>
  <Version>1.0</Version>
  <Type>Policy</Type>
  <Name>POL-SEC-NNN - Display Name</Name>
  <Description>Description.</Description>
  <Platform>macOS</Platform>
  <Category>Security</Category>
  <SourceFile>configurations/intune/pol-sec-nnn-slug.json</SourceFile>
  <SettingsCount>0</SettingsCount>
</MacIntuneManifest>
```
</details>

<details>
<summary>CustomConfig</summary>

```xml
<MacIntuneManifest>
  <ReferenceId>CFG-SEC-NNN</ReferenceId>
  <Version>1.0</Version>
  <Type>CustomConfig</Type>
  <Name>CFG-SEC-NNN - Display Name</Name>
  <Description>Description.</Description>
  <Platform>macOS</Platform>
  <Category>Security</Category>
  <SourceFile>configurations/intune/cfg-sec-nnn-slug.mobileconfig</SourceFile>
</MacIntuneManifest>
```
</details>

<details>
<summary>Script</summary>

```xml
<MacIntuneManifest>
  <ReferenceId>SCR-SYS-NNN</ReferenceId>
  <Version>1.0</Version>
  <Type>Script</Type>
  <Name>SCR-SYS-NNN - Display Name</Name>
  <Description>Description.</Description>
  <Platform>macOS</Platform>
  <Category>Config</Category>
  <SourceFile>scripts/intune/scr-sys-nnn-slug.sh</SourceFile>
  <Script>
    <RunAsAccount>system</RunAsAccount>
    <BlockExecutionNotifications>true</BlockExecutionNotifications>
    <ExecutionFrequency>PT0S</ExecutionFrequency>
    <RetryCount>3</RetryCount>
  </Script>
</MacIntuneManifest>
```
</details>

<details>
<summary>Package</summary>

```xml
<MacIntuneManifest>
  <ReferenceId>APP-UTL-NNN</ReferenceId>
  <Version>1.0</Version>
  <Type>Package</Type>
  <Name>APP-UTL-NNN - Display Name</Name>
  <Description>Description.</Description>
  <Platform>macOS</Platform>
  <Category>Config</Category>
  <SourceFile>apps/app-utl-nnn-slug.pkg</SourceFile>
  <Package>
    <PrimaryBundleId>com.example.app</PrimaryBundleId>
    <PrimaryBundleVersion>1.0.0</PrimaryBundleVersion>
    <Publisher>Publisher</Publisher>
    <MinimumSupportedOperatingSystem>v13_0</MinimumSupportedOperatingSystem>
    <IgnoreVersionDetection>true</IgnoreVersionDetection>
  </Package>
</MacIntuneManifest>
```
</details>

<details>
<summary>CustomAttribute</summary>

```xml
<MacIntuneManifest>
  <ReferenceId>CAT-SYS-NNN</ReferenceId>
  <Version>1.0</Version>
  <Type>CustomAttribute</Type>
  <Name>CAT-SYS-NNN - Display Name</Name>
  <Description>Description.</Description>
  <Platform>macOS</Platform>
  <Category>Device Information</Category>
  <SourceFile>custom attributes/cat-sys-nnn-slug.zsh</SourceFile>
  <CustomAttribute>
    <CustomAttributeType>string</CustomAttributeType>
  </CustomAttribute>
</MacIntuneManifest>
```
</details>

<details>
<summary>Compliance</summary>

```xml
<MacIntuneManifest>
  <ReferenceId>CMP-CMP-NNN</ReferenceId>
  <Version>1.0</Version>
  <Type>Compliance</Type>
  <Name>CMP-CMP-NNN - Display Name</Name>
  <Description>Description.</Description>
  <Platform>macOS</Platform>
  <Category>Compliance</Category>
  <SourceFile>configurations/intune/cmp-cmp-nnn-slug.json</SourceFile>
</MacIntuneManifest>
```
</details>

<details>
<summary>EnrollmentRestriction</summary>

```xml
<MacIntuneManifest>
  <ReferenceId>POL-SYS-NNN</ReferenceId>
  <Version>1.0</Version>
  <Type>EnrollmentRestriction</Type>
  <Name>POL-SYS-NNN - Display Name</Name>
  <Description>Description.</Description>
  <Platform>macOS</Platform>
  <Category>System Configuration</Category>
  <SourceFile>configurations/intune/pol-sys-nnn-slug.json</SourceFile>
  <SettingsCount>0</SettingsCount>
</MacIntuneManifest>
```
</details>
