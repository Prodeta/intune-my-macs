# Get-MacOSGlobalAssignments.ps1

A PowerShell script that identifies macOS Intune objects assigned to "All Devices" or "All Users" — and optionally removes those global assignments.

## Overview

This script queries Microsoft Graph to find macOS-related Intune configurations that have broad, tenant-wide assignments. It helps identify potential security and compliance concerns where policies, scripts, or apps are deployed without scoped targeting.

### What It Scans

| Object Type | Graph API Resource | Description |
| ------------ | ------------------- | ------------- |
| **Settings Catalog Policies** | `configurationPolicies` | Modern Intune settings catalog policies targeting macOS |
| **Device Configurations** | `deviceConfigurations` | Classic device configuration profiles (custom configs, endpoint protection, etc.) |
| **Shell Scripts** | `deviceShellScripts` | macOS shell scripts deployed via Intune |
| **macOS Apps** | `mobileApps` | PKG and LOB apps (`macOSPkgApp`, `macOSLobApp`) |

### What It Detects

The script flags objects assigned to:

- **All Devices** (`allDevicesAssignmentTarget`) - Applies to every device in the tenant
- **All Users** (`allLicensedUsersAssignmentTarget`) - Applies to all licensed users

## Requirements

- **PowerShell 7+** (cross-platform) or Windows PowerShell 5.1
- **Microsoft Graph PowerShell SDK** - `Microsoft.Graph.Authentication` module
- **Permissions**:
  - `DeviceManagementConfiguration.Read.All` (for policies and scripts)
  - `DeviceManagementApps.Read.All` (for apps)
  - `DeviceManagementConfiguration.ReadWrite.All` (only if using `-Unassign`)

## Usage

### Basic Usage - List Global Assignments

```powershell
pwsh ./tools/Get-MacOSGlobalAssignments.ps1
```

Output:

```text
Collecting configurationPolicies (settings catalog macOS)...
Collecting classic deviceConfigurations (macOS types)...
Collecting deviceShellScripts (macOS shell scripts)...
Collecting macOS PKG apps...

Type                  Name                           Id                                   AllDevices AllUsers Platforms
----                  ----                           --                                   ---------- -------- ---------
DeviceConfiguration   FileVault Policy               abc12345-...                         True       False    macOS
SettingsCatalogPolicy macOS Security Baseline        def67890-...                         True       True     macOS
ShellScript           Install Rosetta                ghi11111-...                         True       False    macOS
macOSApp              Company Portal                 jkl22222-...                         False      True     macOS
```

### Parameters

| Parameter | Type | Default | Description |
| ----------- | ------ | --------- | ------------- |
| `-OutputJson` | Switch | `$false` | Output raw JSON array to stdout after the table |
| `-CsvPath` | String | (none) | Path to export results as CSV |
| `-Unassign` | Switch | `$false` | **⚠️ Destructive** - Remove global assignments from discovered objects |
| `-Force` | Switch | `$false` | Skip confirmation prompt when using `-Unassign` |

### Examples

#### Export Results to CSV

```powershell
pwsh ./tools/Get-MacOSGlobalAssignments.ps1 -CsvPath ./reports/global-assignments.csv
```

#### Output JSON for Pipeline Processing

```powershell
pwsh ./tools/Get-MacOSGlobalAssignments.ps1 -OutputJson | ConvertFrom-Json | Where-Object AllDevices
```

#### Export Both CSV and JSON

```powershell
pwsh ./tools/Get-MacOSGlobalAssignments.ps1 -CsvPath ./global.csv -OutputJson > ./global.json
```

#### Remove Global Assignments (Interactive)

```powershell
pwsh ./tools/Get-MacOSGlobalAssignments.ps1 -Unassign
```

You'll be prompted to type `YES` to confirm.

#### Remove Global Assignments (Non-Interactive)

```powershell
pwsh ./tools/Get-MacOSGlobalAssignments.ps1 -Unassign -Force
```

**⚠️ Warning**: This immediately removes All Devices/All Users assignments without confirmation.

## Output

### Console Table

| Column | Description |
| -------- | ------------- |
| `Type` | Object type: `SettingsCatalogPolicy`, `DeviceConfiguration`, `ShellScript`, `macOSApp` |
| `Name` | Display name of the object |
| `Id` | Intune object GUID |
| `AllDevices` | `True` if assigned to All Devices |
| `AllUsers` | `True` if assigned to All Users |
| `Platforms` | Platform(s) the object targets |

### CSV Export

Same columns as console output, suitable for Excel or reporting tools.

### JSON Output

```json
[
  {
    "Type": "DeviceConfiguration",
    "Name": "FileVault Policy",
    "Id": "abc12345-6789-0123-4567-890abcdef012",
    "AllDevices": true,
    "AllUsers": false,
    "Platforms": "macOS"
  }
]
```

## The `-Unassign` Feature

### What It Does

When `-Unassign` is specified, the script:

1. Lists all objects with global assignments (as normal)
2. Prompts for confirmation (unless `-Force` is used)
3. For each object, retrieves current assignments
4. Removes only `allDevicesAssignmentTarget` and `allLicensedUsersAssignmentTarget` assignments
5. **Preserves** any group-based or other scoped assignments

### Use Cases

- **Security Audit Remediation** - Quickly remove overly broad assignments identified in an audit
- **Zero Trust Implementation** - Transition from "allow all" to scoped group-based targeting
- **Tenant Cleanup** - Remove accidental global deployments

### Safety Features

- Requires explicit `YES` confirmation (case-sensitive)
- `-Force` flag required for automation
- Only modifies assignment targeting, not policy content
- Preserves all non-global assignments

### Example Unassign Output

```text
-- Unassign mode: removing All Devices / All Users assignments --
Type YES to continue (this will remove global assignments): YES

Removed global assignment(s) from DeviceConfiguration abc12345-...
Removed global assignment(s) from SettingsCatalogPolicy def67890-...
Removed global assignment(s) from ShellScript ghi11111-...
Removed global assignment(s) from macOSApp jkl22222-...

Unassign operation complete.
```

## Authentication

The script uses the Microsoft Graph PowerShell SDK for authentication:

```powershell
# First run - interactive browser authentication
pwsh ./tools/Get-MacOSGlobalAssignments.ps1

# Subsequent runs use cached credentials
```

### Pre-authenticate with Specific Scopes

```powershell
# Read-only scopes for listing
Connect-MgGraph -Scopes @(
    'DeviceManagementConfiguration.Read.All',
    'DeviceManagementApps.Read.All'
)

# Read-write scopes for unassign feature
Connect-MgGraph -Scopes @(
    'DeviceManagementConfiguration.ReadWrite.All',
    'DeviceManagementApps.ReadWrite.All'
)
```

## Common Use Cases

### Security Audit

Identify all macOS policies with overly permissive targeting:

```powershell
# Generate audit report
pwsh ./tools/Get-MacOSGlobalAssignments.ps1 -CsvPath ./audit/global-assignments-$(Get-Date -Format 'yyyyMMdd').csv
```

### CI/CD Compliance Check

```powershell
# Fail pipeline if any global assignments exist
$results = pwsh ./tools/Get-MacOSGlobalAssignments.ps1 -OutputJson | ConvertFrom-Json
if ($results.Count -gt 0) {
    Write-Error "Found $($results.Count) objects with global assignments!"
    exit 1
}
```

### Scheduled Monitoring

```powershell
# Weekly check for new global assignments
$results = pwsh ./tools/Get-MacOSGlobalAssignments.ps1 -OutputJson | ConvertFrom-Json
if ($results) {
    # Send alert via email, Teams, etc.
    Send-AlertNotification -Message "Global assignments detected: $($results.Name -join ', ')"
}
```

## Troubleshooting

| Issue | Solution |
| ------- | ---------- |
| "Microsoft Graph PowerShell SDK not installed" | Run `Install-Module Microsoft.Graph -Scope CurrentUser` |
| "Insufficient privileges" | Ensure account has Intune Administrator or appropriate read permissions |
| "Failed to query assignments" warnings | Some objects may have restricted access; verify permissions |
| Shell script assignments show as empty | API limitation; script uses `$expand=assignments` where supported |
| `-Unassign` fails with 403 | Need `ReadWrite.All` scopes instead of `Read.All` |

## Security Considerations

- **Read-only by default** - Without `-Unassign`, no changes are made
- **Audit trail** - Use `-CsvPath` to capture before/after state when using `-Unassign`
- **Principle of least privilege** - This script helps enforce scoped targeting
- **Change management** - Always test `-Unassign` in a non-production tenant first

## Related Tools

- [Export-MacOSConfigPolicies.ps1](Export-MacOSConfigPolicies.md) - Export policy configurations
- [Find-DuplicatePayloadSettings.ps1](Find-DuplicatePayloadSettings.md) - Find duplicate settings
- [Get-IntuneAgentProcessingOrder.ps1](Get-IntuneAgentProcessingOrder.ps1) - View policy processing order

## Notes

- Uses Microsoft Graph **beta** endpoint for full macOS support
- Shell scripts endpoint (`deviceShellScripts`) is macOS-specific; no platform filter needed
- The script only surfaces macOS objects, even though some APIs return cross-platform data
