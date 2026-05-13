<#
Simple listing of assigned macOS device shell scripts and macOS apps.
Optional -Prefix filter. All complexity (group lookups, hex, colors, debug) removed.
#>

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

param(
    [Parameter(Mandatory=$false)]
    [string]$Prefix
)

Connect-MgGraph -Scopes "DeviceManagementScripts.Read.All,DeviceManagementApps.Read.All" -NoWelcome | Out-Null

# Get shell scripts (only those with assignments)
$scriptUri = "https://graph.microsoft.com/beta/deviceManagement/deviceShellScripts?`$expand=assignments"
$scripts = Invoke-MgGraphRequest -Method GET -Uri $scriptUri | Select-Object -ExpandProperty value | Where-Object { $_.assignments -and $_.assignments.Count -gt 0 }
$scripts | ForEach-Object { $_ | Add-Member -NotePropertyName Kind -NotePropertyValue 'Script' -Force }

# Get assigned macOS apps (pkg/dmg)
$appUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$filter=(isof('microsoft.graph.macOSDmgApp') or isof('microsoft.graph.macOSPkgApp')) and isAssigned eq true"
$apps = Invoke-MgGraphRequest -Method GET -Uri $appUri | Select-Object -ExpandProperty value
$apps | ForEach-Object { $_ | Add-Member -NotePropertyName Kind -NotePropertyValue 'App' -Force }

$items = $scripts + $apps
if ($Prefix) {
    $items = $items | Where-Object { $_.displayName -and $_.displayName.StartsWith($Prefix, [System.StringComparison]::OrdinalIgnoreCase) }
}

$items = $items | Sort-Object displayName

Write-Host "Items returned: $($items.Count)" -ForegroundColor Cyan
if (-not $items -or $items.Count -eq 0) { return }

$i = 1
function Get-TypeTag {
    param([string]$Kind)
    switch ($Kind) {
        'Script' { return "`e[33m[Script]`e[0m" } # Yellow
        'App'    { return "`e[32m[App]`e[0m" }    # Green
        default  { return "[$Kind]" }
    }
}
foreach ($item in $items) {
    # Scripts return an assignments collection we can count; macOS apps often only expose isAssigned unless we separately query /assignments
    if ($item.Kind -eq 'App') {
        $assigned = if ($item.isAssigned -eq $true) { 'Yes' } else { 'No' }
    } else {
        $assigned = if ($item.assignments -and $item.assignments.Count -gt 0) { 'Yes' } else { 'No' }
    }
    $tag = Get-TypeTag $item.Kind
    Write-Host ("{0,2}. {1} {2} (Assigned: {3})" -f $i, $tag, $item.displayName, $assigned)
    $i++
}
