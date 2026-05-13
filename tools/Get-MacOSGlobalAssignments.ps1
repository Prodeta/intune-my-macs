<#!
.SYNOPSIS
Lists macOS Intune objects (configuration policies, classic device configurations, custom configs, scripts, PKG apps) that are assigned to All Devices or All Users.

.DESCRIPTION
Queries Microsoft Graph (beta) for:
  * Settings Catalog configurationPolicies (platforms includes macOS)
  * Classic deviceConfigurations (odata type starts with #microsoft.graph.macOS)
  * Custom configurations (macOSCustomConfiguration)
  * Device shell scripts (macOS shell scripts)
  * macOS PKG Apps (#microsoft.graph.macOSPkgApp and #microsoft.graph.macOSLobApp)
For each object, retrieves its assignments and flags whether it is targeted to:
  - All Devices (allDevicesAssignmentTarget)
  - All Users (allLicensedUsersAssignmentTarget)
Outputs a table and (optionally) JSON/CSV.

.PARAMETER OutputJson
Also emit raw JSON array to stdout (after table).

.PARAMETER CsvPath
Optional path to write CSV export of results.

.EXAMPLE
./Get-MacOSGlobalAssignments.ps1

.EXAMPLE
./Get-MacOSGlobalAssignments.ps1 -OutputJson -CsvPath ./mac-global.csv

.NOTES
Requires Microsoft.Graph.Authentication (Connect-MgGraph) and sufficient Intune permissions (DeviceManagementConfiguration.Read.All, DeviceManagementApps.Read.All).
#>

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

param(
    [switch]$OutputJson,
    [string]$CsvPath,
    [switch]$Unassign,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Ensure-GraphConnection {
    if (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue)) {
        Write-Error "Microsoft Graph PowerShell SDK not installed. Install-Module Microsoft.Graph -Scope CurrentUser"
        exit 1
    }
    try {
        $ctx = Get-MgContext -ErrorAction Stop
        if (-not $ctx) { throw 'No context' }
    } catch {
        Write-Host 'Connecting to Microsoft Graph...' -ForegroundColor Cyan
        Connect-MgGraph -Scopes @(
            'DeviceManagementConfiguration.Read.All',
            'DeviceManagementApps.Read.All'
        ) | Out-Null
    }
}

function Invoke-GraphAllPages {
    param(
        [Parameter(Mandatory)] [string]$Uri,
        [hashtable]$Headers,
        [int]$PageSize = 100
    )
    $results = @()
    $next = "$Uri`?$top=$PageSize"
    while ($next) {
        $resp = Invoke-MgGraphRequest -Method GET -Uri $next -Headers $Headers
        if ($resp.value) { $results += $resp.value }
        $next = $resp.'@odata.nextLink'
    }
    return $results
}

function Get-AssignmentsForObject {
    param(
        [string]$Uri # full assignments URI
    )
    try {
        $resp = Invoke-MgGraphRequest -Method GET -Uri $Uri
        return $resp.value
    } catch {
        Write-Warning "Failed to query assignments: $Uri : $($_.Exception.Message)"
        return @()
    }
}

Ensure-GraphConnection

$betaBase = 'https://graph.microsoft.com/beta'

Write-Host 'Collecting configurationPolicies (settings catalog macOS)...' -ForegroundColor Cyan
$configPolicies = Invoke-GraphAllPages -Uri "$betaBase/deviceManagement/configurationPolicies" | Where-Object { $_.platforms -match 'macOS' }

Write-Host 'Collecting classic deviceConfigurations (macOS types)...' -ForegroundColor Cyan
$deviceConfigs = Invoke-GraphAllPages -Uri "$betaBase/deviceManagement/deviceConfigurations" | Where-Object { $_.'@odata.type' -like '#microsoft.graph.macOS*' }

Write-Host 'Collecting deviceShellScripts (macOS shell scripts)...' -ForegroundColor Cyan
# Use $expand=assignments to avoid separate per-script assignment calls that 400 on some tenants
try {
    $shellScriptsResponse = Invoke-MgGraphRequest -Method GET -Uri "$betaBase/deviceManagement/deviceShellScripts?$top=999&$expand=assignments"
    $deviceShellScripts = $shellScriptsResponse.value
} catch {
    Write-Warning "Failed expanded retrieval of deviceShellScripts: $($_.Exception.Message). Falling back to basic list (assignments may be incomplete)."
    $deviceShellScripts = Invoke-GraphAllPages -Uri "$betaBase/deviceManagement/deviceShellScripts"
}
 # Intune shell scripts endpoint is macOS-only, keep all

Write-Host 'Collecting macOS PKG apps...' -ForegroundColor Cyan
$mobileApps = Invoke-GraphAllPages -Uri "$betaBase/deviceAppManagement/mobileApps" | Where-Object { $_.'@odata.type' -in '#microsoft.graph.macOSPkgApp','#microsoft.graph.macOSLobApp' }

$rows = @()

# Settings catalog policies assignments
foreach ($p in $configPolicies) {
    $assignments = Get-AssignmentsForObject -Uri "$betaBase/deviceManagement/configurationPolicies/$($p.id)/assignments"
    $isAllDevices = $assignments.target.'@odata.type' -contains '#microsoft.graph.allDevicesAssignmentTarget'
    $isAllUsers   = $assignments.target.'@odata.type' -contains '#microsoft.graph.allLicensedUsersAssignmentTarget'
    if ($isAllDevices -or $isAllUsers) {
        $rows += [pscustomobject]@{
            Type        = 'SettingsCatalogPolicy'
            Name        = $p.name
            Id          = $p.id
            AllDevices  = $isAllDevices
            AllUsers    = $isAllUsers
            Platforms   = ($p.platforms -join ',')
        }
    }
}

# Classic / custom device configurations
foreach ($c in $deviceConfigs) {
    $assignments = Get-AssignmentsForObject -Uri "$betaBase/deviceManagement/deviceConfigurations/$($c.id)/assignments"
    $isAllDevices = $false; $isAllUsers = $false
    foreach ($a in $assignments) {
        $t = $a.target.'@odata.type'
        if ($t -eq '#microsoft.graph.allDevicesAssignmentTarget') { $isAllDevices = $true }
        if ($t -eq '#microsoft.graph.allLicensedUsersAssignmentTarget') { $isAllUsers = $true }
    }
    if ($isAllDevices -or $isAllUsers) {
        $rows += [pscustomobject]@{
            Type       = 'DeviceConfiguration'
            Name       = $c.displayName
            Id         = $c.id
            AllDevices = $isAllDevices
            AllUsers   = $isAllUsers
            Platforms  = 'macOS'
        }
    }
}

# Shell scripts (assignments already expanded when possible)
foreach ($s in $deviceShellScripts) {
    $expandedAssignments = @()
    if ($s.PSObject.Properties.Name -contains 'assignments' -and $s.assignments) {
        $expandedAssignments = $s.assignments
    } else {
        # Fallback (suppress 400 warnings): silently try direct endpoint
        try {
            $expandedAssignments = (Invoke-MgGraphRequest -Method GET -Uri "$betaBase/deviceManagement/deviceShellScripts/$($s.id)/assignments").value
        } catch {
            $expandedAssignments = @() # treat as none
        }
    }
    $isAllDevices = $false; $isAllUsers = $false
    foreach ($a in $expandedAssignments) {
        $t = $a.target.'@odata.type'
        if ($t -eq '#microsoft.graph.allDevicesAssignmentTarget') { $isAllDevices = $true }
        if ($t -eq '#microsoft.graph.allLicensedUsersAssignmentTarget') { $isAllUsers = $true }
    }
    if ($isAllDevices -or $isAllUsers) {
        $rows += [pscustomobject]@{
            Type       = 'ShellScript'
            Name       = $s.displayName
            Id         = $s.id
            AllDevices = $isAllDevices
            AllUsers   = $isAllUsers
            Platforms  = 'macOS'
        }
    }
}

# macOS Apps
foreach ($app in $mobileApps) {
    $assignments = Get-AssignmentsForObject -Uri "$betaBase/deviceAppManagement/mobileApps/$($app.id)/assignments"
    $isAllDevices = $false; $isAllUsers = $false
    foreach ($a in $assignments) {
        $t = $a.target.'@odata.type'
        if ($t -eq '#microsoft.graph.allDevicesAssignmentTarget') { $isAllDevices = $true }
        if ($t -eq '#microsoft.graph.allLicensedUsersAssignmentTarget') { $isAllUsers = $true }
    }
    if ($isAllDevices -or $isAllUsers) {
        $rows += [pscustomobject]@{
            Type       = 'macOSApp'
            Name       = $app.displayName
            Id         = $app.id
            AllDevices = $isAllDevices
            AllUsers   = $isAllUsers
            Platforms  = 'macOS'
        }
    }
}

if (-not $rows) {
    Write-Host 'No macOS objects assigned to All Devices or All Users.' -ForegroundColor Yellow
    return
}

$rows | Sort-Object Type, Name | Format-Table -AutoSize

if ($CsvPath) {
    try {
        $rows | Export-Csv -NoTypeInformation -Path $CsvPath -Encoding UTF8
        Write-Host "CSV written to $CsvPath" -ForegroundColor Green
    } catch { Write-Warning "Failed to write CSV: $($_.Exception.Message)" }
}

if ($OutputJson) {
    $rows | ConvertTo-Json -Depth 4
}

if ($Unassign) {
    Write-Host "\n-- Unassign mode: removing All Devices / All Users assignments --" -ForegroundColor Magenta
    if (-not $Force) {
        $resp = Read-Host "Type YES to continue (this will remove global assignments)"
        if ($resp -ne 'YES') { Write-Host 'Aborted.' -ForegroundColor Yellow; return }
    }

    foreach ($item in $rows) {
        switch ($item.Type) {
            'SettingsCatalogPolicy' {
                $id = $item.Id
                $assignUri = "$betaBase/deviceManagement/configurationPolicies/$id/assignments"
                $all = (Invoke-MgGraphRequest -Method GET -Uri $assignUri).value
                if (-not $all) { continue }
                $remaining = @()
                foreach ($a in $all) {
                    $t = $a.target.'@odata.type'
                    if ($t -in '#microsoft.graph.allDevicesAssignmentTarget','#microsoft.graph.allLicensedUsersAssignmentTarget') { continue }
                    $remaining += @{ target = $a.target }
                }
                $body = @{ assignments = $remaining } | ConvertTo-Json -Depth 6
                try {
                    Invoke-MgGraphRequest -Method POST -Uri "$betaBase/deviceManagement/configurationPolicies/$id/assign" -Body $body | Out-Null
                    Write-Host "Removed global assignment(s) from SettingsCatalogPolicy $id" -ForegroundColor Green
                } catch { Write-Warning "Failed to update assignments for configurationPolicy $id : $($_.Exception.Message)" }
            }
            'DeviceConfiguration' {
                $id = $item.Id
                $assignUri = "$betaBase/deviceManagement/deviceConfigurations/$id/assignments"
                $all = (Invoke-MgGraphRequest -Method GET -Uri $assignUri).value
                if (-not $all) { continue }
                $remaining = @()
                foreach ($a in $all) {
                    $t = $a.target.'@odata.type'
                    if ($t -in '#microsoft.graph.allDevicesAssignmentTarget','#microsoft.graph.allLicensedUsersAssignmentTarget') { continue }
                    $remaining += @{ target = $a.target }
                }
                $body = @{ assignments = $remaining } | ConvertTo-Json -Depth 6
                try {
                    Invoke-MgGraphRequest -Method POST -Uri "$betaBase/deviceManagement/deviceConfigurations/$id/assign" -Body $body | Out-Null
                    Write-Host "Removed global assignment(s) from DeviceConfiguration $id" -ForegroundColor Green
                } catch { Write-Warning "Failed to update assignments for deviceConfiguration $id : $($_.Exception.Message)" }
            }
            'macOSApp' {
                $id = $item.Id
                $assignUri = "$betaBase/deviceAppManagement/mobileApps/$id/assignments"
                $all = (Invoke-MgGraphRequest -Method GET -Uri $assignUri).value
                if (-not $all) { continue }
                $remaining = @()
                foreach ($a in $all) {
                    $t = $a.target.'@odata.type'
                    if ($t -in '#microsoft.graph.allDevicesAssignmentTarget','#microsoft.graph.allLicensedUsersAssignmentTarget') { continue }
                    $remaining += @{
                        '@odata.type' = '#microsoft.graph.mobileAppAssignment'
                        intent        = $a.intent
                        target        = $a.target
                    }
                }
                $body = @{ mobileAppAssignments = $remaining } | ConvertTo-Json -Depth 8
                try {
                    Invoke-MgGraphRequest -Method POST -Uri "$betaBase/deviceAppManagement/mobileApps/$id/assign" -Body $body | Out-Null
                    Write-Host "Removed global assignment(s) from macOSApp $id" -ForegroundColor Green
                } catch { Write-Warning "Failed to update assignments for macOSApp $id : $($_.Exception.Message)" }
            }
            'ShellScript' {
                $id = $item.Id
                $assignUri = "$betaBase/deviceManagement/deviceShellScripts/$id/assignments"
                $all = @()
                try { $all = (Invoke-MgGraphRequest -Method GET -Uri $assignUri).value } catch { }
                if (-not $all) { continue }
                $remaining = @()
                foreach ($a in $all) {
                    $t = $a.target.'@odata.type'
                    if ($t -in '#microsoft.graph.allDevicesAssignmentTarget','#microsoft.graph.allLicensedUsersAssignmentTarget') { continue }
                    $remaining += @{
                        '@odata.type' = '#microsoft.graph.deviceManagementScriptAssignment'
                        target        = $a.target
                    }
                }
                $body = @{ deviceManagementScriptAssignments = $remaining } | ConvertTo-Json -Depth 6
                try {
                    Invoke-MgGraphRequest -Method POST -Uri "$betaBase/deviceManagement/deviceShellScripts/$id/assign" -Body $body | Out-Null
                    Write-Host "Removed global assignment(s) from ShellScript $id" -ForegroundColor Green
                } catch { Write-Warning "Failed to update assignments for ShellScript $id : $($_.Exception.Message)" }
            }
        }
    }
    Write-Host "Unassign operation complete." -ForegroundColor Magenta
}
