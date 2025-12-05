# Business Central Container Admin Menu

Interactive PowerShell tool for managing Business Central Docker containers locally. Choose which container to work with, then select operations to perform.

## Quick Start

Run the script in PowerShell:
```powershell
.\Admin.Containers.AsMenu.ps1
```

You'll be prompted to select a container, then presented with an interactive menu of operations.

---

## The 10 Main Options

### [1] Restart Container
**What it does:** Stops the container completely, then starts it back up.

**When to use:**
- Container is acting strange or unresponsive
- After making configuration changes that require a restart
- When you want a clean state without removing data

---

### [2] Stop Container
**What it does:** Stops the running container gracefully.

**When to use:**
- You're done working and want to free up system resources (CPU, memory)
- You need to stop the container temporarily without deleting it
- Container is using too much memory

---

### [3] View Container Status & Resources
**What it does:** Shows a table of all Business Central containers and their current resource usage (CPU, memory, network).

**When to use:**
- You want to see which containers are running
- Checking how much memory/CPU the container is using
- Troubleshooting performance issues

---

### [4] View Container Logs
**What it does:** Displays the Docker container logs (system messages and errors).

**When to use:**
- Container failed to start or crashed
- Looking for error messages to troubleshoot a problem
- Checking what happened in the container recently

---

### [5] Remove Container & Cleanup Cache
**What it does:** Permanently deletes the container and clears the BcContainerHelper cache (keeping 2 days of history).

**When to use:**
- You want to start completely fresh with a new container
- Freeing up significant disk space
- Removing an old/unused container

**⚠️ Warning:** This is permanent and cannot be undone. Data inside the container will be lost.

---

### [6] Import License
**What it does:** Loads a Business Central license file (.bclicense) into the container so it can run with a valid license.

**When to use:**
- After creating a new container (it needs a license to function)
- Your trial license expired
- Switching to a different license

**Note:** The script looks for a license at `C:\MILBAINAB\_License\NAB DEV License.bclicense` by default. You can specify a different path if needed.

---

### [7] Fix BcContainerHelper Permissions
**What it does:** Fixes permissions and settings that AL Test Runner needs to work properly in VS Code.

**When to use:**
- AL tests won't run from VS Code
- You get permission errors when trying to run tests
- After fresh installation of BcContainerHelper

---

### [8] Show Non-Microsoft Apps
**What it does:** Lists all apps in the container that are NOT from Microsoft (your custom apps and third-party apps).

**When to use:**
- You want to see what apps you've installed
- Checking app versions and publisher information
- Before uninstalling apps (to know what's there)

---

### [9] Uninstall/Unpublish Non-Microsoft Apps
**What it does:** Selectively removes non-Microsoft apps from the container. Can uninstall only (keep code) or fully unpublish (remove code).

**When to use:**
- Removing custom apps you no longer need
- Cleaning up the container before deployment
- Testing app removal and reinstallation

**Options:** Select which apps to remove, choose whether to just uninstall or fully unpublish.

---

### [10] Install Apps from Folder
**What it does:** Publishes .app files from a folder into the container. Automatically detects if it's a new install, upgrade, or downgrade and handles dependencies.

**When to use:**
- Deploying newly built .app files to the container
- Testing app installations before going to production
- Upgrading apps to new versions

**Features:**
- Shows installation plan before executing
- Automatically sorts apps by dependencies
- Can skip code signing verification (for dev/test)
- Can unpublish old app versions after upgrade

---

## Additional Menu Options

- **[S] Switch Container** - Change which container you're working with
- **[L] List All Containers** - See all available containers
- **[Q] Quit** - Exit the menu

---

## Prerequisites

- PowerShell (Windows)
- Docker Desktop installed and running
- BcContainerHelper PowerShell module installed
- Business Central container(s) created

## Typical Workflow

1. Run the script
2. Select your container
3. Choose an operation from the menu
4. Follow the prompts (usually yes/no or file paths)
5. Menu returns after operation completes
6. Repeat or press Q to quit
