@echo off
REM Business Central Nuclear Clean Launcher
REM Step 4: Clean All Layers - Complete Docker System Reset

setlocal enabledelayedexpansion

REM Get the script directory
set SCRIPT_DIR=%~dp0
set PS_SCRIPT=%SCRIPT_DIR%BC-NuclearClean.ps1

REM Check if script exists
if not exist "%PS_SCRIPT%" (
    echo ERROR: BC-NuclearClean.ps1 not found in %SCRIPT_DIR%
    pause
    exit /b 1
)

REM Run PowerShell with the script
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*

REM Pause so user can see output
pause
