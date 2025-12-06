################################################################################
# BcContainerHelper - Interactive Container Admin Menu                        #
# Expert-Optimized: Choose which operations to run                            #
################################################################################

<#
.SYNOPSIS
    Interactive menu for Business Central container management operations.

.DESCRIPTION
    Allows you to select and run individual container operations:
    - Restart container
    - View status and resources
    - Remove container
    - View logs
    - Fix AL Test permissions
#>

# Verify running as Administrator
# $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
# if (-not $isAdmin) {
#     Write-Host "ERROR: This script requires Administrator privileges!" -ForegroundColor Red
#     Write-Host "Please restart PowerShell as Administrator." -ForegroundColor Yellow
#     pause
#     exit 1
# }

Clear-Host

# Ensure BC PowerShell modules are loaded for Get-BcContainerAppInfo compatibility
# This prevents "Get-NavAppInfo not recognized" errors in containers
try {
    Write-Host "[→] Initializing Business Central modules..." -ForegroundColor Gray
    $moduleLoaded = $false

    # Try to load Microsoft.Dynamics.Nav.Apps.Management first (older modules)
    if (-not (Get-Command Get-NavAppInfo -ErrorAction SilentlyContinue)) {
        try {
            Import-Module Microsoft.Dynamics.Nav.Apps.Management -ErrorAction SilentlyContinue
            $moduleLoaded = $true
        }
        catch {
            # Module not available, BcContainerHelper will handle internally
        }
    }
    else {
        $moduleLoaded = $true
    }

    if ($moduleLoaded) {
        Write-Host "[✓] BC modules ready" -ForegroundColor Green
    }
    else {
        Write-Host "[i] BC modules not found locally - BcContainerHelper will use container modules" -ForegroundColor Cyan
    }
}
catch {
    # Non-critical, BcContainerHelper can continue
    Write-Host "[i] Module loading skipped" -ForegroundColor Gray
}

# Container configuration - prompt user to select container
Write-Host "╔════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  BC Container Admin - Select Container                                 ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Available containers:" -ForegroundColor Yellow
Write-Host ""

$availableContainers = @(Get-BcContainers)

if ($availableContainers.Count -gt 0) {
    for ($i = 0; $i -lt $availableContainers.Count; $i++) {
        Write-Host "  [$($i + 1)] $($availableContainers[$i])" -ForegroundColor White
    }
}
else {
    Write-Host "  No containers found" -ForegroundColor Red
    Write-Host ""
    pause
    exit 1
}

Write-Host ""
Write-Host "  [Q] Quit" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "Select container by number or enter name (Q to quit)"

if ($choice.ToUpper() -eq 'Q') {
    Write-Host "Goodbye!" -ForegroundColor Green
    exit 0
}

# Check if input is a number
if ([int]::TryParse($choice, [ref]$null)) {
    $index = [int]$choice - 1
    if ($index -ge 0 -and $index -lt $availableContainers.Count) {
        $containerName = $availableContainers[$index]
    }
    else {
        Write-Host "ERROR: Invalid selection!" -ForegroundColor Red
        pause
        exit 1
    }
}
else {
    # Treat input as container name
    $containerName = $choice
}

if ([string]::IsNullOrWhiteSpace($containerName)) {
    Write-Host "ERROR: Container name cannot be empty!" -ForegroundColor Red
    pause
    exit 1
}

# Helper function to safely get container app info with proper module loading
function Get-ContainerAppsInfo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$containerName
    )

    try {
        # Try using Get-BcContainerAppInfo with implicit module loading
        $apps = Get-BcContainerAppInfo -containerName $containerName -ErrorAction Stop
        return $apps
    }
    catch {
        # Fallback: Ensure modules are loaded in container context
        try {
            Write-Host "[i] Attempting module-aware app query..." -ForegroundColor Gray
            $scriptBlock = {
                # Load required modules inside container
                if (-not (Get-Command Get-NavAppInfo -ErrorAction SilentlyContinue)) {
                    Get-Module | Where-Object { $_.Name -like '*Nav*' -or $_.Name -like '*Business*Central*' } | Import-Module -Force -ErrorAction SilentlyContinue
                }

                # Query apps
                Get-NavAppInfo -ServerInstance BC -Tenant default -TenantSpecificProperties |
                Select-Object -Property AppId, Name, Publisher, Version, IsPublished, IsInstalled
            }

            $apps = Invoke-ScriptInBcContainer -containerName $containerName -scriptblock $scriptBlock -ErrorAction Stop
            return $apps
        }
        catch {
            Write-Host "[!] Failed to retrieve app information: $($_.Exception.Message)" -ForegroundColor Red
            throw
        }
    }
}

function Show-Menu {
    Write-Host "╔════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  BC Container Admin - Interactive Menu                                 ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Target Container: $containerName" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Select Operation:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] Restart Container" -ForegroundColor White
    Write-Host "  [2] Stop Container" -ForegroundColor White
    Write-Host "  [3] View Container Status & Resources" -ForegroundColor White
    Write-Host "  [4] View Container Logs" -ForegroundColor White
    Write-Host "  [5] Remove Container & Cleanup Cache" -ForegroundColor Red
    Write-Host "  [6] Import License" -ForegroundColor White
    Write-Host "  [7] Fix BcContainerHelperPermissions Permissions" -ForegroundColor White
    Write-Host "  [8] Show Non-Microsoft Apps" -ForegroundColor White
    Write-Host "  [9] Uninstall/Unpublish Non-Microsoft Apps" -ForegroundColor Red
    Write-Host "  [10] Install Apps from Folder" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [S] Switch Container" -ForegroundColor Cyan
    Write-Host "  [L] List All Containers" -ForegroundColor White
    Write-Host "  [Q] Quit" -ForegroundColor Gray
    Write-Host ""
}

function Restart-Container {
    Write-Host ""
    Write-Host "━━━ Restarting Container ━━━" -ForegroundColor Yellow

    $container = Get-BcContainers | Where-Object { $_ -eq $containerName }

    if ($container) {
        Write-Host "[→] Stopping container: $containerName" -ForegroundColor Gray
        Stop-BcContainer -containerName $containerName

        Write-Host "[→] Starting container: $containerName" -ForegroundColor Gray
        Start-BcContainer -containerName $containerName

        Write-Host "[✓] Container restarted successfully" -ForegroundColor Green
    }
    else {
        Write-Host "[!] Container '$containerName' not found" -ForegroundColor Red
    }

    Write-Host ""
    pause
}

function Stop-Container {
    Write-Host ""
    Write-Host "━━━ Stopping Container ━━━" -ForegroundColor Yellow

    $container = Get-BcContainers | Where-Object { $_ -eq $containerName }

    if ($container) {
        Write-Host "[→] Stopping container: $containerName" -ForegroundColor Gray
        Stop-BcContainer -containerName $containerName

        Write-Host "[✓] Container stopped successfully" -ForegroundColor Green
    }
    else {
        Write-Host "[!] Container '$containerName' not found" -ForegroundColor Red
    }

    Write-Host ""
    pause
}

function Show-ContainerStatus {
    Write-Host ""
    Write-Host "━━━ Container Status ━━━" -ForegroundColor Yellow
    Write-Host ""

    Get-BcContainers -includeLabels | Format-Table -AutoSize

    Write-Host ""
    Write-Host "Docker Resource Usage:" -ForegroundColor Cyan
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

    Write-Host ""
    pause
}

function Show-ContainerLogs {
    Write-Host ""
    Write-Host "━━━ Container Logs ━━━" -ForegroundColor Yellow

    $container = Get-BcContainers | Where-Object { $_ -eq $containerName }

    if ($container) {
        Write-Host "[→] How many lines? (default: 50)" -ForegroundColor Gray
        $lines = Read-Host "Lines"
        if ([string]::IsNullOrWhiteSpace($lines)) { $lines = 50 }

        Write-Host "[→] Fetching last $lines lines..." -ForegroundColor Gray
        docker logs $containerName --tail $lines
    }
    else {
        Write-Host "[!] Container '$containerName' not found" -ForegroundColor Red
    }

    Write-Host ""
    pause
}

function Remove-ContainerWithConfirmation {
    Write-Host ""
    Write-Host "━━━ Remove Container ━━━" -ForegroundColor Red
    Write-Host ""
    Write-Host "WARNING: This will permanently delete the container!" -ForegroundColor Red
    Write-Host "Container name: $containerName" -ForegroundColor Yellow
    Write-Host ""

    $confirm = Read-Host "Type 'YES' to confirm deletion"

    if ($confirm -eq 'YES') {
        $container = Get-BcContainers | Where-Object { $_ -eq $containerName }

        if ($container) {
            Write-Host "[→] Stopping container..." -ForegroundColor Gray
            Stop-BcContainer -containerName $containerName -ErrorAction SilentlyContinue

            Write-Host "[→] Removing container..." -ForegroundColor Gray
            Remove-BcContainer -containerName $containerName

            Write-Host "[✓] Container removed" -ForegroundColor Green

            Write-Host "[→] Flushing cache (keeping last 2 days)..." -ForegroundColor Gray
            Flush-ContainerHelperCache -KeepDays 2

            Write-Host "[✓] Cleanup complete" -ForegroundColor Green
        }
        else {
            Write-Host "[!] Container '$containerName' not found" -ForegroundColor Red
        }
    }
    else {
        Write-Host "[!] Deletion cancelled" -ForegroundColor Yellow
    }

    Write-Host ""
    pause
}

function Import-License {
    Write-Host ""
    Write-Host "━━━ Importing License ━━━" -ForegroundColor Yellow
    Write-Host ""

    $defaultLicensePath = "C:\MILBAINAB\_License\NAB DEV License.bclicense"

    Write-Host "Default license path:" -ForegroundColor Cyan
    Write-Host "  $defaultLicensePath" -ForegroundColor Yellow
    Write-Host ""

    $useDefault = Read-Host "Use this path? (Y/N, default: Y)"

    if ([string]::IsNullOrWhiteSpace($useDefault)) {
        $useDefault = 'Y'
    }

    if ($useDefault.ToUpper() -ne 'Y') {
        do {
            Write-Host ""
            Write-Host "Enter the full path to the license file (or 'C' to cancel):" -ForegroundColor Cyan
            $licensePath = Read-Host "Path"

            if ([string]::IsNullOrWhiteSpace($licensePath)) {
                Write-Host "[!] License path cannot be empty!" -ForegroundColor Red
                continue
            }

            if ($licensePath.ToUpper() -eq 'C') {
                Write-Host "[!] License import cancelled" -ForegroundColor Yellow
                Write-Host ""
                pause
                return
            }

            # Verify the license file exists
            if (-not (Test-Path $licensePath)) {
                Write-Host "[!] License file not found at: $licensePath" -ForegroundColor Red
                Write-Host ""
                $retry = Read-Host "Try another path? (Y/N)"
                if ($retry.ToUpper() -ne 'Y') {
                    Write-Host "[!] License import cancelled" -ForegroundColor Yellow
                    Write-Host ""
                    pause
                    return
                }
                continue
            }
            else {
                break
            }
        } while ($true)
    }
    else {
        $licensePath = $defaultLicensePath

        # Verify the license file exists
        if (-not (Test-Path $licensePath)) {
            Write-Host "[!] License file not found at: $licensePath" -ForegroundColor Red
            Write-Host ""
            Write-Host "Would you like to specify a different path?" -ForegroundColor Cyan
            $retry = Read-Host "Use custom path? (Y/N)"
            if ($retry.ToUpper() -eq 'Y') {
                # Recursively call this function to let user enter custom path
                Write-Host ""
                pause
                Import-License
                return
            }
            else {
                Write-Host "[!] License import cancelled" -ForegroundColor Yellow
                Write-Host ""
                pause
                return
            }
        }
    }

    $container = Get-BcContainers | Where-Object { $_ -eq $containerName }

    if ($container) {
        try {
            Write-Host ""
            Write-Host "[→] Disabling Task Scheduler..." -ForegroundColor Gray
            Set-BcContainerServerConfiguration -ContainerName $containerName -KeyName "EnableTaskScheduler" -KeyValue "false"

            Write-Host "[→] Restarting container..." -ForegroundColor Gray
            Restart-BcContainer -containerName $containerName

            Write-Host "[→] Importing license file..." -ForegroundColor Gray
            Write-Host "    $licensePath" -ForegroundColor Gray
            Import-BcContainerLicense -containerName $containerName -licenseFile $licensePath -restart

            Write-Host "[✓] License imported successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "[!] License import failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "[!] Container '$containerName' not found" -ForegroundColor Red
    }

    Write-Host ""
    pause
}

function Fix-BcContainerHelperPermissions {
    Write-Host ""
    Write-Host "━━━ Fixing AL Test Runner Permissions ━━━" -ForegroundColor Yellow

    try {
        Write-Host "[→] Checking and fixing permissions..." -ForegroundColor Gray
        Check-BcContainerHelperPermissions -Fix
        Write-Host "[✓] Permissions fixed - should work in VS Code" -ForegroundColor Green
    }
    catch {
        Write-Host "[!] Permission fix failed: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
    pause
}

function List-AllContainers {
    Write-Host ""
    Write-Host "━━━ All BC Containers ━━━" -ForegroundColor Yellow
    Write-Host ""

    $containers = Get-BcContainers

    if ($containers) {
        $containers | ForEach-Object {
            Write-Host "  • $_" -ForegroundColor White
        }
    }
    else {
        Write-Host "  No containers found" -ForegroundColor Gray
    }

    Write-Host ""
    pause
}

function Show-NonMicrosoftApps {
    Write-Host ""
    Write-Host "━━━ Non-Microsoft Apps in Container ━━━" -ForegroundColor Yellow
    Write-Host ""

    $container = Get-BcContainers | Where-Object { $_ -eq $containerName }

    if ($container) {
        try {
            Write-Host "[→] Querying apps in container: $containerName" -ForegroundColor Gray
            Write-Host ""

            # Get non-Microsoft apps using helper function
            $apps = Get-ContainerAppsInfo -containerName $containerName | Where-Object { $_.Publisher -ne 'Microsoft' } | Sort-Object Publisher, Name

            if ($apps) {
                Write-Host "Found $($apps.Count) non-Microsoft app(s):" -ForegroundColor Green
                Write-Host ""
                $apps | Format-Table -AutoSize -Property Publisher, Name, Version, IsPublished, IsInstalled
            }
            else {
                Write-Host "[!] No non-Microsoft apps found in container" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "[!] Failed to retrieve app information: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    else {
        Write-Host "[!] Container '$containerName' not found" -ForegroundColor Red
    }

    Write-Host ""
    pause
}

function Uninstall-NonMicrosoftApps {
    Write-Host ""
    Write-Host "━━━ Uninstall/Unpublish Non-Microsoft Apps ━━━" -ForegroundColor Red
    Write-Host ""

    $container = Get-BcContainers | Where-Object { $_ -eq $containerName }

    if (-not $container) {
        Write-Host "[!] Container '$containerName' not found" -ForegroundColor Red
        Write-Host ""
        pause
        return
    }

    try {
        Write-Host "[→] Querying non-Microsoft apps in container: $containerName" -ForegroundColor Gray
        Write-Host ""

        # Get non-Microsoft apps from container using helper function
        $apps = Get-ContainerAppsInfo -containerName $containerName | Where-Object { $_.Publisher -ne 'Microsoft' } | Sort-Object Publisher, Name

        if (-not $apps) {
            Write-Host "[!] No non-Microsoft apps found in container" -ForegroundColor Yellow
            Write-Host ""
            pause
            return
        }

        # Display apps with numbers
        Write-Host "Available apps to uninstall/unpublish:" -ForegroundColor Yellow
        Write-Host ""

        $appList = @($apps)
        for ($i = 0; $i -lt $appList.Count; $i++) {
            $app = $appList[$i]
            $status = @()
            if ($app.IsInstalled) { $status += "Installed" }
            if ($app.IsPublished) { $status += "Published" }
            $statusText = $status -join ", "

            Write-Host ("  [{0,2}] {1,-30} {2,-20} v{3} ({4})" -f ($i + 1), $app.Name, $app.Publisher, $app.Version, $statusText) -ForegroundColor White
        }

        Write-Host ""
        Write-Host "Enter app numbers to uninstall (comma-separated, e.g., 1,3,5) or 'A' for all:" -ForegroundColor Cyan
        Write-Host "Press 'C' to cancel" -ForegroundColor Gray
        Write-Host ""

        $selection = Read-Host "Selection"

        if ([string]::IsNullOrWhiteSpace($selection) -or $selection.ToUpper() -eq 'C') {
            Write-Host ""
            Write-Host "[!] Operation cancelled" -ForegroundColor Yellow
            Write-Host ""
            pause
            return
        }

        # Parse selection
        $selectedApps = @()
        if ($selection.ToUpper() -eq 'A') {
            $selectedApps = $appList
        }
        else {
            $indices = $selection -split ',' | ForEach-Object { $_.Trim() }
            foreach ($idx in $indices) {
                if ([int]::TryParse($idx, [ref]$null)) {
                    $index = [int]$idx - 1
                    if ($index -ge 0 -and $index -lt $appList.Count) {
                        $selectedApps += $appList[$index]
                    }
                    else {
                        Write-Host "[!] Invalid selection: $idx" -ForegroundColor Red
                    }
                }
            }
        }

        if ($selectedApps.Count -eq 0) {
            Write-Host ""
            Write-Host "[!] No valid apps selected" -ForegroundColor Red
            Write-Host ""
            pause
            return
        }

        # Ask about unpublishing
        Write-Host ""
        Write-Host "Do you want to unpublish the apps after uninstalling? (Y/N, default: N)" -ForegroundColor Cyan
        $unpublish = Read-Host "Unpublish"
        $shouldUnpublish = $unpublish.ToUpper() -eq 'Y'

        # Confirmation
        Write-Host ""
        Write-Host "WARNING: You are about to process the following apps:" -ForegroundColor Red
        Write-Host ""
        foreach ($app in $selectedApps) {
            Write-Host "  • $($app.Name) v$($app.Version) by $($app.Publisher)" -ForegroundColor Yellow
        }
        Write-Host ""
        if ($shouldUnpublish) {
            Write-Host "Actions: UNINSTALL + UNPUBLISH" -ForegroundColor Red
        }
        else {
            Write-Host "Actions: UNINSTALL ONLY" -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host "Type 'YES' to confirm:" -ForegroundColor Cyan
        $confirm = Read-Host "Confirm"

        if ($confirm -ne 'YES') {
            Write-Host ""
            Write-Host "[!] Operation cancelled" -ForegroundColor Yellow
            Write-Host ""
            pause
            return
        }

        # Process apps
        Write-Host ""
        Write-Host "[→] Processing apps..." -ForegroundColor Gray
        Write-Host ""

        $successCount = 0
        $failCount = 0

        foreach ($app in $selectedApps) {
            Write-Host "Processing: $($app.Name) v$($app.Version)" -ForegroundColor Cyan

            try {
                # Uninstall if installed
                if ($app.IsInstalled) {
                    Write-Host "  [→] Uninstalling from tenant..." -ForegroundColor Gray
                    UnInstall-BcContainerApp `
                        -containerName $containerName `
                        -tenant 'default' `
                        -appName $app.Name `
                        -publisher $app.Publisher `
                        -version $app.Version `
                        -doNotSaveData `
                        -force
                    Write-Host "  [✓] Uninstalled" -ForegroundColor Green
                }

                # Unpublish if requested and published
                if ($shouldUnpublish -and $app.IsPublished) {
                    Write-Host "  [→] Unpublishing from container..." -ForegroundColor Gray
                    UnPublish-BcContainerApp `
                        -containerName $containerName `
                        -appName $app.Name `
                        -publisher $app.Publisher `
                        -version $app.Version
                    Write-Host "  [✓] Unpublished" -ForegroundColor Green
                }

                $successCount++
                Write-Host ""
            }
            catch {
                Write-Host "  [!] Failed: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host ""
                $failCount++
            }
        }

        # Summary
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
        Write-Host "Summary:" -ForegroundColor Cyan
        Write-Host "  Success: $successCount" -ForegroundColor Green
        Write-Host "  Failed:  $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

        # Show remaining apps
        Write-Host ""
        Write-Host "[→] Querying remaining non-Microsoft apps..." -ForegroundColor Gray
        Write-Host ""

        try {
            $remainingApps = Get-ContainerAppsInfo -containerName $containerName | Where-Object { $_.Publisher -ne 'Microsoft' }

            if ($remainingApps) {
                $remainingCount = @($remainingApps).Count
                Write-Host "Remaining non-Microsoft apps in container ($remainingCount):" -ForegroundColor Yellow
                Write-Host ""
                $remainingApps | Format-Table -AutoSize -Property Publisher, Name, Version, IsPublished, IsInstalled
            }
            else {
                Write-Host "[✓] No non-Microsoft apps remaining in container" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "[!] Could not retrieve remaining apps: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "[!] Error during operation: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
    pause
}

function Install-AppsFromFolder {
    Write-Host ""
    Write-Host "━━━ Install Apps from Folder ━━━" -ForegroundColor Cyan
    Write-Host ""

    $container = Get-BcContainers | Where-Object { $_ -eq $containerName }

    if (-not $container) {
        Write-Host "[!] Container '$containerName' not found" -ForegroundColor Red
        Write-Host ""
        pause
        return
    }

    # Get folder path from user
    Write-Host "Enter the full path to the folder containing .app files:" -ForegroundColor Cyan
    Write-Host "(Press 'C' to cancel)" -ForegroundColor Gray
    Write-Host ""
    $folderPath = Read-Host "Folder path"

    if ([string]::IsNullOrWhiteSpace($folderPath) -or $folderPath.ToUpper() -eq 'C') {
        Write-Host ""
        Write-Host "[!] Operation cancelled" -ForegroundColor Yellow
        Write-Host ""
        pause
        return
    }

    # Verify folder exists
    if (-not (Test-Path $folderPath -PathType Container)) {
        Write-Host ""
        Write-Host "[!] Folder not found: $folderPath" -ForegroundColor Red
        Write-Host ""
        pause
        return
    }

    # Find all .app files
    Write-Host ""
    Write-Host "[→] Searching for .app files..." -ForegroundColor Gray
    Write-Host ""

    $appFiles = @(Get-ChildItem -Path $folderPath -Recurse -Filter "*.app" | Select-Object -ExpandProperty FullName)

    if ($appFiles.Count -eq 0) {
        Write-Host "[!] No .app files found in folder" -ForegroundColor Red
        Write-Host ""
        pause
        return
    }

    Write-Host "Found $($appFiles.Count) app file(s):" -ForegroundColor Green
    Write-Host ""
    foreach ($app in $appFiles) {
        $fileName = Split-Path $app -Leaf
        Write-Host "  • $fileName" -ForegroundColor White
    }

    # Ask about unpublishing old versions
    Write-Host ""
    Write-Host "Unpublish old versions after successful upgrade? (Y/N, default: Y)" -ForegroundColor Cyan
    Write-Host "(Recommended: Y to keep container clean)" -ForegroundColor Gray
    $unpubOld = Read-Host "Unpublish old"
    $unpublishOld = [string]::IsNullOrWhiteSpace($unpubOld) -or $unpubOld.ToUpper() -eq 'Y'

    Write-Host ""
    Write-Host "[→] Analyzing apps and detecting installation strategy..." -ForegroundColor Gray
    Write-Host ""

    try {
        # Get currently installed/published apps using helper function
        Write-Host "[→] Retrieving currently installed apps..." -ForegroundColor Gray
        $currentApps = Get-ContainerAppsInfo -containerName $containerName

        # Sort apps by dependencies using BcContainerHelper
        $sortedApps = Sort-AppFilesByDependencies -containerName $containerName -appFiles $appFiles

        # Analyze each app to determine action
        $installPlan = @()
        foreach ($appFile in $sortedApps) {
            # Get app metadata from file using BcContainerHelper (no modules required)
            $appJson = Get-AppJsonFromAppFile -appFile $appFile
            # Convert to compatible object with standard property names
            $appInfo = [PSCustomObject]@{
                AppId = $appJson.id
                Name = $appJson.name
                Publisher = $appJson.publisher
                Version = $appJson.version
            }

            $existingApp = $currentApps | Where-Object {
                $_.AppId -eq $appInfo.AppId -and $_.IsInstalled -eq $true
            }

            $action = "New Install"
            $actionColor = "Green"

            if ($existingApp) {
                $newVersion = [Version]$appInfo.Version
                $oldVersion = [Version]$existingApp.Version

                if ($newVersion -gt $oldVersion) {
                    $action = "Upgrade (v$oldVersion → v$newVersion)"
                    $actionColor = "Yellow"
                }
                elseif ($newVersion -eq $oldVersion) {
                    $action = "Skip (same version)"
                    $actionColor = "Gray"
                }
                else {
                    $action = "Downgrade (v$oldVersion → v$newVersion)"
                    $actionColor = "Red"
                }
            }

            $installPlan += [PSCustomObject]@{
                File = Split-Path $appFile -Leaf
                Name = $appInfo.Name
                Publisher = $appInfo.Publisher
                Version = $appInfo.Version
                Action = $action
                ActionColor = $actionColor
                AppFile = $appFile
                AppInfo = $appInfo
                ExistingApp = $existingApp
            }
        }

        # Display installation plan
        Write-Host "Installation Plan:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host ("  {0,-40} {1,-25} {2}" -f "App Name", "Publisher", "Action") -ForegroundColor White
        Write-Host ("  {0,-40} {1,-25} {2}" -f ("-" * 40), ("-" * 25), ("-" * 30)) -ForegroundColor Gray

        foreach ($plan in $installPlan) {
            Write-Host ("  {0,-40} {1,-25} " -f $plan.Name, $plan.Publisher) -NoNewline -ForegroundColor White
            Write-Host $plan.Action -ForegroundColor $plan.ActionColor
        }

        # Confirmation
        Write-Host ""
        Write-Host "Settings:" -ForegroundColor Yellow
        Write-Host "  Container:     $containerName" -ForegroundColor White
        Write-Host "  Unpublish old: $(if ($unpublishOld) { 'Yes' } else { 'No' })" -ForegroundColor White
        Write-Host ""
        Write-Host "Type 'YES' to proceed:" -ForegroundColor Cyan
        $confirm = Read-Host "Confirm"

        if ($confirm -ne 'YES') {
            Write-Host ""
            Write-Host "[!] Operation cancelled" -ForegroundColor Yellow
            Write-Host ""
            pause
            return
        }

        Write-Host ""
        Write-Host "[→] Starting installation..." -ForegroundColor Gray
        Write-Host ""

        # Process each app according to plan
        $successCount = 0
        $failCount = 0
        $upgradeCount = 0
        $newInstallCount = 0
        $skipCount = 0
        $totalApps = $installPlan.Count
        $oldVersionsToUnpublish = @()

        for ($i = 0; $i -lt $totalApps; $i++) {
            $plan = $installPlan[$i]
            $appNumber = $i + 1

            Write-Host "[$appNumber/$totalApps] $($plan.Name) v$($plan.Version)" -ForegroundColor Cyan

            try {
                # Skip if same version
                if ($plan.Action -like "Skip*") {
                    Write-Host "  [i] Same version already installed, skipping..." -ForegroundColor Gray
                    $skipCount++
                    Write-Host ""
                    continue
                }

                # Determine if upgrade or new install
                $isUpgrade = $plan.Action -like "Upgrade*" -or $plan.Action -like "Downgrade*"

                # Build parameters for Publish-BcContainerApp
                $publishParams = @{
                    containerName = $containerName
                    appFile = $plan.AppFile
                    skipVerification = $true
                    sync = $true
                }

                if ($isUpgrade) {
                    $publishParams.Add('upgrade', $true)
                    Write-Host "  [→] Publishing with upgrade (data migration)..." -ForegroundColor Gray
                }
                else {
                    $publishParams.Add('install', $true)
                    Write-Host "  [→] Publishing with install..." -ForegroundColor Gray
                }

                # Publish the app
                Publish-BcContainerApp @publishParams

                Write-Host "  [✓] Success" -ForegroundColor Green
                $successCount++

                if ($isUpgrade) {
                    $upgradeCount++

                    # Track old version for unpublishing
                    if ($unpublishOld -and $plan.ExistingApp) {
                        $oldVersionsToUnpublish += [PSCustomObject]@{
                            Name = $plan.ExistingApp.Name
                            Publisher = $plan.ExistingApp.Publisher
                            Version = $plan.ExistingApp.Version
                        }
                    }
                }
                else {
                    $newInstallCount++
                }

                Write-Host ""
            }
            catch {
                Write-Host "  [!] Failed: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host ""
                $failCount++

                # Ask if user wants to continue
                if ($i -lt ($totalApps - 1)) {
                    Write-Host "Continue with remaining apps? (Y/N, default: Y)" -ForegroundColor Yellow
                    $continue = Read-Host "Continue"
                    if ($continue.ToUpper() -eq 'N') {
                        Write-Host ""
                        Write-Host "[!] Installation aborted by user" -ForegroundColor Yellow
                        break
                    }
                    Write-Host ""
                }
            }
        }

        # Unpublish old versions if requested
        if ($unpublishOld -and $oldVersionsToUnpublish.Count -gt 0) {
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
            Write-Host "Unpublishing old versions..." -ForegroundColor Yellow
            Write-Host ""

            foreach ($oldApp in $oldVersionsToUnpublish) {
                try {
                    Write-Host "  [→] Unpublishing $($oldApp.Name) v$($oldApp.Version)..." -ForegroundColor Gray
                    UnPublish-BcContainerApp `
                        -containerName $containerName `
                        -appName $oldApp.Name `
                        -publisher $oldApp.Publisher `
                        -version $oldApp.Version
                    Write-Host "  [✓] Unpublished" -ForegroundColor Green
                }
                catch {
                    Write-Host "  [!] Failed to unpublish: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            Write-Host ""
        }

        # Summary
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
        Write-Host "Installation Summary:" -ForegroundColor Cyan
        Write-Host "  Total apps:      $totalApps" -ForegroundColor White
        Write-Host "  Successful:      $successCount" -ForegroundColor Green
        Write-Host "    - New installs: $newInstallCount" -ForegroundColor Cyan
        Write-Host "    - Upgrades:     $upgradeCount" -ForegroundColor Cyan
        Write-Host "  Skipped:         $skipCount" -ForegroundColor Gray
        Write-Host "  Failed:          $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Gray" })
        if ($unpublishOld -and $oldVersionsToUnpublish.Count -gt 0) {
            Write-Host "  Old unpublished: $($oldVersionsToUnpublish.Count)" -ForegroundColor Yellow
        }
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

        # Show installed non-Microsoft apps
        if ($successCount -gt 0) {
            Write-Host ""
            Write-Host "[→] Querying installed non-Microsoft apps..." -ForegroundColor Gray
            Write-Host ""

            try {
                $installedApps = Get-ContainerAppsInfo -containerName $containerName | Where-Object { $_.Publisher -ne 'Microsoft' } | Sort-Object Publisher, Name

                if ($installedApps) {
                    $installedCount = @($installedApps).Count
                    Write-Host "Non-Microsoft apps now in container ($installedCount):" -ForegroundColor Green
                    Write-Host ""
                    $installedApps | Format-Table -AutoSize -Property Publisher, Name, Version, IsPublished, IsInstalled
                }
            }
            catch {
                Write-Host "[!] Could not retrieve app list: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Host "[!] Error during installation: $($_.Exception.Message)" -ForegroundColor Red
    }

    Write-Host ""
    pause
}

function Switch-Container {
    Write-Host ""
    Write-Host "━━━ Switch Container ━━━" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Available containers:" -ForegroundColor Yellow
    Write-Host ""

    $availableContainers = @(Get-BcContainers)

    if ($availableContainers.Count -gt 0) {
        for ($i = 0; $i -lt $availableContainers.Count; $i++) {
            if ($availableContainers[$i] -eq $containerName) {
                Write-Host "  [$($i + 1)] $($availableContainers[$i]) (current)" -ForegroundColor Green
            }
            else {
                Write-Host "  [$($i + 1)] $($availableContainers[$i])" -ForegroundColor White
            }
        }
    }
    else {
        Write-Host "  No containers found" -ForegroundColor Red
        Write-Host ""
        pause
        return
    }

    Write-Host ""
    Write-Host "  [C] Cancel" -ForegroundColor Gray
    Write-Host ""

    $choice = Read-Host "Select container by number or enter name (C to cancel)"

    if ($choice.ToUpper() -eq 'C') {
        Write-Host "[!] Container switch cancelled" -ForegroundColor Yellow
        Write-Host ""
        pause
        return
    }

    # Check if input is a number
    if ([int]::TryParse($choice, [ref]$null)) {
        $index = [int]$choice - 1
        if ($index -ge 0 -and $index -lt $availableContainers.Count) {
            $newContainerName = $availableContainers[$index]
        }
        else {
            Write-Host ""
            Write-Host "ERROR: Invalid selection!" -ForegroundColor Red
            Write-Host ""
            pause
            return
        }
    }
    else {
        # Treat input as container name
        $newContainerName = $choice
    }

    if ([string]::IsNullOrWhiteSpace($newContainerName)) {
        Write-Host ""
        Write-Host "ERROR: Container name cannot be empty!" -ForegroundColor Red
        Write-Host ""
        pause
        return
    }

    # Verify the container exists
    $containerExists = Get-BcContainers | Where-Object { $_ -eq $newContainerName }
    if (-not $containerExists) {
        Write-Host ""
        Write-Host "ERROR: Container '$newContainerName' not found!" -ForegroundColor Red
        Write-Host ""
        pause
        return
    }

    # Update the global container name
    $script:containerName = $newContainerName
    Write-Host ""
    Write-Host "[✓] Container switched to: $newContainerName" -ForegroundColor Green
    Write-Host ""
    pause
}

# Main menu loop
do {
    Clear-Host
    Show-Menu

    $choice = Read-Host "Enter choice"

    switch ($choice.ToUpper()) {
        '1' { Restart-Container }
        '2' { Stop-Container }
        '3' { Show-ContainerStatus }
        '4' { Show-ContainerLogs }
        '5' { Remove-ContainerWithConfirmation }
        '6' { Import-License }
        '7' { Fix-BcContainerHelperPermissions }
        '8' { Show-NonMicrosoftApps }
        '9' { Uninstall-NonMicrosoftApps }
        '10' { Install-AppsFromFolder }
        'S' { Switch-Container }
        'L' { List-AllContainers }
        'Q' {
            Write-Host ""
            Write-Host "Goodbye!" -ForegroundColor Green
            Write-Host ""
            exit
        }
        default {
            Write-Host ""
            Write-Host "Invalid choice. Press any key to continue..." -ForegroundColor Red
            pause
        }
    }
} while ($true)
