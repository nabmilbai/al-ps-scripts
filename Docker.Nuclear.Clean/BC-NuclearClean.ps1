#!/usr/bin/env powershell
<#
.SYNOPSIS
    Business Central Container Nuclear Clean - Step 4 Implementation

.DESCRIPTION
    Performs a complete cleanup of all Docker containers and corrupted layer data.
    This is the "nuclear option" that resolves layer format errors and container issues.

    What it does:
    1. Stops all running containers
    2. Removes all containers (running and stopped)
    3. Prunes Docker system (removes unused images, networks, volumes, layer cache)
    4. Restarts Docker service

    Based on Freddy Kristiansen & Tobias Fenster BC DevOps best practices.

.EXAMPLE
    .\BC-NuclearClean.ps1
    .\BC-NuclearClean.ps1 -SkipPrompts
    .\BC-NuclearClean.ps1 -Verbose
#>

param(
    [switch]$SkipPrompts = $false,
    [switch]$Verbose = $false
)

# Color output
$colors = @{
    Success = 'Green'
    Error   = 'Red'
    Warning = 'Yellow'
    Info    = 'Cyan'
    Header  = 'Magenta'
}

function Write-Header {
    param([string]$Message)
    Write-Host "`n" + ("=" * 80) -ForegroundColor $colors.Header
    Write-Host $Message -ForegroundColor $colors.Header
    Write-Host ("=" * 80) -ForegroundColor $colors.Header
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor $colors.Success
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $colors.Error
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor $colors.Warning
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor $colors.Info
}

# ============================================================================
# STEP 1: STOP ALL CONTAINERS
# ============================================================================

function Invoke-StopAllContainers {
    Write-Header "STEP 1/4: STOPPING ALL RUNNING CONTAINERS"

    try {
        # Get all running containers
        $runningContainers = docker ps -q

        if ($runningContainers) {
            Write-Info "Found running containers:"
            docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"

            Write-Warning-Custom "Stopping all containers..."
            docker stop $runningContainers -ErrorAction Stop | Out-Null

            Write-Success "All containers stopped"
            Start-Sleep -Seconds 2
        }
        else {
            Write-Info "No running containers found"
        }

        return $true
    }
    catch {
        Write-Error-Custom "Failed to stop containers: $_"
        return $false
    }
}

# ============================================================================
# STEP 2: REMOVE ALL CONTAINERS
# ============================================================================

function Invoke-RemoveAllContainers {
    Write-Header "STEP 2/4: REMOVING ALL CONTAINERS (RUNNING & STOPPED)"

    try {
        # Get all containers (running and stopped)
        $allContainers = docker ps -aq

        if ($allContainers) {
            Write-Info "Found all containers:"
            docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"

            Write-Warning-Custom "Removing all containers..."
            docker rm $allContainers -f -ErrorAction Stop | Out-Null

            Write-Success "All containers removed"
            Write-Info "Container data has been deleted"
            Start-Sleep -Seconds 2
        }
        else {
            Write-Info "No containers found to remove"
        }

        return $true
    }
    catch {
        Write-Error-Custom "Failed to remove containers: $_"
        return $false
    }
}

# ============================================================================
# STEP 3: PRUNE SYSTEM (NUCLEAR LAYER CLEANUP)
# ============================================================================

function Invoke-PruneSystem {
    Write-Header "STEP 3/4: PRUNING DOCKER SYSTEM (CLEARING LAYER CACHE)"

    Write-Warning-Custom "This step will:"
    Write-Info "  • Remove unused images"
    Write-Info "  • Remove unused networks"
    Write-Info "  • Remove unused volumes"
    Write-Info "  • Clear layer cache (FIXES LAYER FORMAT ERRORS)"
    Write-Info ""
    Write-Warning-Custom "This is the critical step that resolves layer format errors (0xc0370112)"

    if (-not $SkipPrompts) {
        $confirm = Read-Host "Proceed with system prune? (y/n)"
        if ($confirm -ne 'y') {
            Write-Info "System prune skipped"
            return $false
        }
    }

    try {
        Write-Info "Running: docker system prune -a --volumes -f"
        Write-Warning-Custom "This may take 2-5 minutes..."

        $pruneOutput = docker system prune -a --volumes -f -ErrorAction Stop

        Write-Success "System prune completed"
        Write-Info "Output:"
        $pruneOutput | ForEach-Object { Write-Info "  $_" }

        Start-Sleep -Seconds 2
        return $true
    }
    catch {
        Write-Error-Custom "Failed to prune system: $_"
        return $false
    }
}

# ============================================================================
# STEP 4: RESTART DOCKER SERVICE
# ============================================================================

function Invoke-RestartDocker {
    Write-Header "STEP 4/4: RESTARTING DOCKER SERVICE"

    try {
        Write-Info "Current Docker service status:"
        Get-Service docker | Format-Table Name, Status

        Write-Warning-Custom "Restarting Docker service..."
        Restart-Service -Name docker -Force -ErrorAction Stop

        Write-Info "Waiting for Docker to restart (10 seconds)..."
        Start-Sleep -Seconds 10

        # Verify Docker is running
        $dockerStatus = Get-Service -Name docker
        if ($dockerStatus.Status -eq 'Running') {
            Write-Success "Docker service restarted successfully"
            Write-Info "Final Docker service status:"
            Get-Service docker | Format-Table Name, Status
            return $true
        }
        else {
            Write-Error-Custom "Docker service did not restart properly"
            return $false
        }
    }
    catch {
        Write-Error-Custom "Failed to restart Docker: $_"
        Write-Warning-Custom "Try restarting Docker Desktop manually or restart your computer"
        return $false
    }
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

function Invoke-NuclearClean {
    Write-Header "BUSINESS CENTRAL CONTAINER NUCLEAR CLEAN"
    Write-Info "Step 4: Clean All Layers - Complete Implementation"
    Write-Info ""
    Write-Warning-Custom "WARNING: This will DELETE all containers and corrupted layer data"
    Write-Info "After completion, you can pull fresh images and create new containers"
    Write-Info ""

    if (-not $SkipPrompts) {
        Write-Warning-Custom "This operation cannot be undone"
        $finalConfirm = Read-Host "Do you want to continue? (type 'yes' to proceed)"
        if ($finalConfirm -ne 'yes') {
            Write-Info "Operation cancelled"
            return $false
        }
    }

    # Track success/failure
    $step1_success = Invoke-StopAllContainers
    if (-not $step1_success) { return $false }

    $step2_success = Invoke-RemoveAllContainers
    if (-not $step2_success) { return $false }

    $step3_success = Invoke-PruneSystem
    if (-not $step3_success) { return $false }

    $step4_success = Invoke-RestartDocker
    if (-not $step4_success) { return $false }

    # Final Summary
    Write-Header "NUCLEAR CLEAN COMPLETED SUCCESSFULLY"
    Write-Success "Step 1: All containers stopped ✓"
    Write-Success "Step 2: All containers removed ✓"
    Write-Success "Step 3: System pruned (corrupted layers cleared) ✓"
    Write-Success "Step 4: Docker service restarted ✓"
    Write-Info ""
    Write-Info "Your system is now clean and ready for new Business Central containers"
    Write-Success "You can now pull fresh images and create new containers"
    Write-Info ""
    Write-Info "Next steps:"
    Write-Info "  1. docker pull mcr.microsoft.com/businesscentral/sandbox:latest"
    Write-Info "  2. docker run ... or use BcContainerHelper"

    return $true
}

# Execute main function
Invoke-NuclearClean

Write-Host "`n"
