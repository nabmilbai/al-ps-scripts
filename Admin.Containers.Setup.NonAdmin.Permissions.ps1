################################################################################
# BcContainerHelper - Non-Admin Permissions Setup v2 (SIMPLIFIED)             #
# Expert Solution: Minimal approach that works on all PowerShell versions     #
################################################################################

<#
.SYNOPSIS
    Simplified one-time setup for non-admin Docker & BcContainerHelper access.

.DESCRIPTION
    Focuses on the essential permissions that work reliably:
    1. docker-users group membership (most important)
    2. BcContainerHelper folder permissions
    3. Hosts file permissions

.NOTES
    Removed problematic Docker pipe manipulation - group membership is sufficient.
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Username = $env:USERNAME
)

# Verify Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: Administrator Rights Required!" -ForegroundColor Red
    Write-Host "Right-click PowerShell → 'Run as Administrator'" -ForegroundColor Yellow
    pause
    exit 1
}

Clear-Host
Write-Host "╔════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  BcContainerHelper - Non-Admin Setup (Simplified v2)                   ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target user: $Username" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Continue? (Y/N)"
if ($confirm -ne 'Y') { exit 0 }

Write-Host ""
$hasErrors = $false

# ═══════════════════════════════════════════════════════════════════════════
# STEP 1: ADD TO DOCKER-USERS GROUP (MOST IMPORTANT)
# ═══════════════════════════════════════════════════════════════════════════

Write-Host "━━━ Step 1: Docker Users Group ━━━" -ForegroundColor Yellow

try {
    $dockerGroup = Get-LocalGroup -Name "docker-users" -ErrorAction SilentlyContinue

    if ($dockerGroup) {
        $members = Get-LocalGroupMember -Group "docker-users" -ErrorAction SilentlyContinue
        $isMember = $members | Where-Object { $_.Name -like "*$Username*" }

        if ($isMember) {
            Write-Host "[✓] Already member of docker-users" -ForegroundColor Green
        } else {
            Add-LocalGroupMember -Group "docker-users" -Member $Username -ErrorAction Stop
            Write-Host "[✓] Added to docker-users group" -ForegroundColor Green
            Write-Host "[!] MUST LOG OUT AND LOG BACK IN!" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[!] docker-users group not found (Docker Engine only?)" -ForegroundColor Yellow
        Write-Host "[i] This is OK for Docker Engine (not Desktop)" -ForegroundColor Gray
    }
} catch {
    Write-Host "[✗] Failed: $($_.Exception.Message)" -ForegroundColor Red
    $hasErrors = $true
}

Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════
# STEP 2: BCCONTAINERHELPER FOLDER
# ═══════════════════════════════════════════════════════════════════════════

Write-Host "━━━ Step 2: BcContainerHelper Folder ━━━" -ForegroundColor Yellow

$bcFolder = "C:\ProgramData\BcContainerHelper"

try {
    if (-not (Test-Path $bcFolder)) {
        New-Item -Path $bcFolder -ItemType Directory -Force | Out-Null
        Write-Host "[→] Created folder: $bcFolder" -ForegroundColor Gray
    }

    $acl = Get-Acl $bcFolder
    $permission = $Username, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
    $acl.SetAccessRule($rule)
    Set-Acl $bcFolder $acl

    Write-Host "[✓] Permissions granted" -ForegroundColor Green
} catch {
    Write-Host "[✗] Failed: $($_.Exception.Message)" -ForegroundColor Red
    $hasErrors = $true
}

Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════
# STEP 3: HOSTS FILE
# ═══════════════════════════════════════════════════════════════════════════

Write-Host "━━━ Step 3: Hosts File ━━━" -ForegroundColor Yellow

$hostsFile = "C:\Windows\System32\drivers\etc\hosts"

try {
    $acl = Get-Acl $hostsFile
    $permission = $Username, "Modify", "Allow"
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission
    $acl.SetAccessRule($rule)
    Set-Acl $hostsFile $acl

    Write-Host "[✓] Permissions granted" -ForegroundColor Green
} catch {
    Write-Host "[✗] Failed: $($_.Exception.Message)" -ForegroundColor Red
    $hasErrors = $true
}

Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════
# STEP 4: BCCONTAINERHELPER PERMISSION CHECK (OPTIONAL)
# ═══════════════════════════════════════════════════════════════════════════

Write-Host "━━━ Step 4: BcContainerHelper Permission Check ━━━" -ForegroundColor Yellow

try {
    # Check if BcContainerHelper module exists
    if (Get-Module -ListAvailable -Name BcContainerHelper) {
        Import-Module BcContainerHelper -ErrorAction Stop
        Check-BcContainerHelperPermissions -Fix -ErrorAction Stop
        Write-Host "[✓] Permissions verified" -ForegroundColor Green
    } else {
        Write-Host "[i] BcContainerHelper not installed yet - skipping" -ForegroundColor Gray
    }
} catch {
    Write-Host "[!] Could not run check: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "[i] This is OK if module not installed" -ForegroundColor Gray
}

Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════

if ($hasErrors) {
    Write-Host "╔════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║  Setup Completed with Warnings                                         ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
} else {
    Write-Host "╔════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║  Setup Complete!                                                       ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
}

Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. LOG OUT and LOG BACK IN (or restart)" -ForegroundColor Yellow
Write-Host ""
Write-Host "  2. Test as REGULAR USER:" -ForegroundColor White
Write-Host "     docker ps" -ForegroundColor Gray
Write-Host "     Get-BcContainers" -ForegroundColor Gray
Write-Host "     whoami /groups | findstr docker" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. If tests work:" -ForegroundColor White
Write-Host "     → Open VS Code as regular user" -ForegroundColor Green
Write-Host "     → No 'Run as Administrator' needed!" -ForegroundColor Green
Write-Host ""
