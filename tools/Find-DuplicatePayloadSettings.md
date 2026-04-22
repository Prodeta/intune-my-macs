# Find-DuplicatePayloadSettings.ps1

A PowerShell script that analyzes Intune configuration files to identify duplicate and conflicting settings across your macOS policies.

## Overview

This script scans your repository for Intune configuration files (Settings Catalog JSON, mobileconfig plists, and compliance policies) and identifies:

- **Conflicts** - The same setting defined with **different values** across multiple policies
- **Redundancies** - The same setting defined with **identical values** across multiple policies

This helps maintain a clean, conflict-free Intune deployment by catching overlapping configurations before deployment.

## Why This Matters

When multiple Intune policies target the same device and configure the same setting, conflicts can lead to:

- Unpredictable behavior (which policy "wins"?)
- Troubleshooting difficulties
- Configuration drift
- Compliance audit issues

This script proactively identifies these issues in your configuration-as-code repository.

## Requirements

- **PowerShell 7+** (cross-platform) or Windows PowerShell 5.1
- **macOS** (for .mobileconfig parsing via `plutil`) - JSON analysis works on any platform

## Supported File Types

| File Type | Extension | Description |
| ----------- | ----------- | ------------- |
| Settings Catalog | `.json` | Intune Settings Catalog policies |
| Compliance Policy | `.json` | Device compliance policies |
| Custom Profile | `.mobileconfig` | Apple configuration profiles (plist format) |

## Usage

### Basic Usage

```powershell
# Run from repository root
pwsh ./tools/Find-DuplicatePayloadSettings.ps1
```

Or:

```powershell
# Run from tools directory
cd tools
pwsh ./Find-DuplicatePayloadSettings.ps1
```

### Parameters

| Parameter | Type | Default | Description |
| ----------- | ------ | --------- | ------------- |
| `-Path` | String | Script location | Root path to search for configuration files |
| `-OutputFormat` | String | `Console` | Output format: `Console`, `CSV`, or `JSON` |
| `-OutputFile` | String | (auto-generated) | Path for CSV/JSON output file |

### Examples

#### Analyze and Display Results in Console

```powershell
pwsh ./tools/Find-DuplicatePayloadSettings.ps1
```

#### Export Results to CSV

```powershell
pwsh ./tools/Find-DuplicatePayloadSettings.ps1 -OutputFormat CSV -OutputFile ./reports/duplicates.csv
```

#### Export Results to JSON

```powershell
pwsh ./tools/Find-DuplicatePayloadSettings.ps1 -OutputFormat JSON -OutputFile ./reports/duplicates.json
```

#### Analyze a Specific Directory

```powershell
pwsh ./tools/Find-DuplicatePayloadSettings.ps1 -Path /path/to/configs
```

## Output

### Console Output

The script provides detailed, color-coded output:

```text
🔍 Analyzing configuration files in: /path/to/repo

📂 Collecting configuration files...
   Found 15 configuration files

📄 Processing: pol-sec-001-filevault - pol-sec-001-filevault.json
   Found 8 settings:
      • com.apple.MCX_FileVaultOptions.Enable = true
      • com.apple.MCX_FileVaultOptions.Defer = true
      ...

🔎 Finding duplicate settings...

⚠️  Found 3 duplicate settings across configurations

⚠️  CONFLICTS - Same setting with different values:

Setting: com.apple.screensaver.idleTime
  ⚠️  CONFLICT DETECTED - Different values in different policies!
  Occurrences: 2
  Found in these policies:
    • pol-sec-002-screensaver - Screensaver Idle Policy
      File: configurations/intune/pol-sec-002-screensaver-idle.json
      Value: 300
    • pol-sec-005-screensaver - Screensaver Security Policy
      File: configurations/intune/pol-sec-005-screensaver.json
      Value: 600

ℹ️  DUPLICATES - Same setting with same value (redundant):

Setting: com.apple.MCX.FileVaultEnable
  Occurrences: 2
  Found in these policies:
    • pol-sec-001-filevault - FileVault Policy
    • cmp-cmp-001-macos-baseline - macOS Baseline Compliance
      Value: true

Summary:
  Total configurations analyzed: 15
  Total settings found: 127
  Total unique settings: 98
  Duplicate settings: 3
    - Conflicts (different values): 1
    - Redundant (same values): 2
```

### CSV/JSON Export Format

Exported files contain:

| Field | Description |
| ------- | ------------- |
| `SettingId` | The setting identifier (e.g., `com.apple.screensaver.idleTime`) |
| `OccurrenceCount` | Number of policies containing this setting |
| `HasConflict` | `true` if values differ across policies |
| `Configurations` | List of policy names (pipe-separated) |
| `ReferenceIds` | List of policy reference IDs |
| `Values` | All values found (pipe-separated) |
| `SourceFiles` | File paths containing this setting |

## How It Works

1. **File Discovery** - Searches these paths for configuration files:
   - `configurations/intune/*.json`
   - `configurations/entra/*.json`
   - `mde/*.json`
   - `configurations/**/*.mobileconfig`

2. **Setting Extraction** - Parses each file to extract individual settings:
   - **Settings Catalog**: Recursively processes `settings[].settingInstance` structures
   - **Compliance Policies**: Extracts property-based settings
   - **Mobileconfig**: Uses `plutil` to convert plist to JSON, then extracts payload settings

3. **Metadata Enrichment** - Reads companion `.xml` manifest files for policy metadata (ReferenceId, Name, Type)

4. **Duplicate Detection** - Builds an index of all settings and identifies:
   - Settings appearing in multiple files
   - Whether values match (redundant) or differ (conflict)

5. **Report Generation** - Outputs results to console or file

## Interpreting Results

### Conflicts (🔴 Critical)

**Same setting, different values** - These require immediate attention:

```text
⚠️  CONFLICT DETECTED - Different values in different policies!
```

**Resolution**: Determine which value is correct and remove the setting from other policies, or consolidate into a single policy.

### Redundancies (🟡 Warning)

**Same setting, same value** - These are technically harmless but indicate configuration debt:

```text
ℹ️  DUPLICATES - Same setting with same value (redundant)
```

**Resolution**: Consider consolidating into a single policy or intentionally leaving for layered policy design.

## Best Practices

1. **Run before commits** - Include in your CI/CD pipeline or pre-commit hooks
2. **Review conflicts immediately** - Conflicts can cause unpredictable device behavior
3. **Document intentional duplicates** - If redundancy is intentional (e.g., layered policies), document why
4. **Use with assignment analysis** - Duplicates only matter if policies target the same devices

## Integration with CI/CD

```yaml
# Example: GitHub Actions
- name: Check for duplicate settings
  run: |
    pwsh ./tools/Find-DuplicatePayloadSettings.ps1 -OutputFormat JSON -OutputFile ./duplicate-report.json
    if (Get-Content ./duplicate-report.json | ConvertFrom-Json | Where-Object HasConflict) {
      Write-Error "Conflicting settings detected!"
      exit 1
    }
```

## Related Tools

- [Export-MacOSConfigPolicies.ps1](Export-MacOSConfigPolicies.md) - Export policies from Intune
- [Get-MacOSGlobalAssignments.ps1](Get-MacOSGlobalAssignments.ps1) - View policy assignments
- [Generate-ConfigurationDocumentation.py](Generate-ConfigurationDocumentation.py) - Generate documentation

## Limitations

- `.mobileconfig` parsing requires macOS (uses native `plutil` command)
- Only analyzes files in the repository, not live Intune policies
- Does not account for policy assignment targeting (all policies are analyzed regardless of which devices they target)

## Troubleshooting

| Issue | Solution |
| ------- | ---------- |
| "Failed to parse JSON file" | Check for malformed JSON syntax |
| "Failed to parse mobileconfig" | Ensure running on macOS with `plutil` available |
| No files found | Verify `-Path` points to repository root with standard folder structure |
| False positives for collections | Settings with indexed names like `setting[0]` are deduplicated per-file |
