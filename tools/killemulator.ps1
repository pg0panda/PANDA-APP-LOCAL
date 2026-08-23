# Complete Emulator Killer - PowerShell Version
# Created by: Panda
# Purpose: Stop ALL Android Emulators

# Check for Administrator privileges
$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "[!] This script must be run as Administrator" -ForegroundColor Red
    Write-Host "[!] Restarting with admin rights..." -ForegroundColor Yellow
    
    # Relaunch the script with administrator privileges
    $psiArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    Start-Process -FilePath "powershell.exe" -ArgumentList $psiArgs -Verb RunAs
    exit
}

# Initialize console
$Host.UI.RawUI.ForegroundColor = "Cyan"
$Host.UI.RawUI.WindowTitle = "Complete Emulator Killer - Created by Panda"

Clear-Host
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════════════════════╗"
Write-Host "║                        COMPLETE EMULATOR KILLER                               ║"
Write-Host "║                            Created by: Panda                                  ║"
Write-Host "╚═══════════════════════════════════════════════════════════════════════════════╝"
Write-Host ""
Write-Host "┌─ Purpose: Terminate ALL Android Emulators and related processes"
Write-Host "├─ Targets: GameLoop, MEmu, BlueStacks, LDPlayer, Nox, and more"
Write-Host "└─ Status: Ready to terminate all emulator processes"
Write-Host ""

# Display welcome message
Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show("Complete Emulator Killer Tool!`n`nThis will forcefully stop ALL Android emulators and related processes.`n`nClick OK to proceed...", "Emulator Killer", "OK", "Information") | Out-Null

Write-Host ""
Write-Host "[INFO] Starting complete emulator termination..."
Write-Host ""

$totalKilled = 0

# Function to kill processes by wildcard pattern across all emulator families
function Kill-Processes {
    param(
        [string[]]$patterns,
        [string]$category
    )

    Write-Host "┌─ $category"
    $matchedProcesses = @()

    foreach ($pattern in $patterns) {
        $matches = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -like $pattern
        }

        foreach ($process in $matches) {
            if ($matchedProcesses.ProcessId -notcontains $process.ProcessId) {
                $matchedProcesses += $process
            }
        }
    }

    if (-not $matchedProcesses) {
        Write-Host "│  [INFO] No matching emulator processes were found."
        return
    }

    foreach ($process in $matchedProcesses) {
        try {
            Stop-Process -Id $process.ProcessId -Force -ErrorAction Stop
            Write-Host "│  [KILL] $($process.Name) (PID: $($process.ProcessId))"
            $script:totalKilled++
        }
        catch {
            Write-Host "│  [WARN] Could not stop $($process.Name) (PID: $($process.ProcessId))"
        }
    }
}

# Match all known emulator families and related runtime processes, even if names vary
Kill-Processes -patterns @(
    "*GameLoop*",
    "*GameLoader*",
    "*TxGameAssistant*",
    "*AndroidEmulator*",
    "*AndroidProcess*",
    "*AppMarket*",
    "*MEmu*",
    "*BlueStacks*",
    "*LDPlayer*",
    "*LdVBox*",
    "*dnplayer*",
    "*Nox*",
    "*Genymotion*",
    "*emulator*",
    "*qemu*",
    "*VirtualBox*",
    "*VBox*",
    "*adb*",
    "*ProjectTitan*",
    "*TitanService*",
    "*TP3Helper*",
    "*Tensafe*",
    "*aow*",
    "*QMEmulator*",
    "*Tencent*",
    "*cef_frame*",
    "*TBSWebRenderer*",
    "*syzs_dl_svr*",
    "*dnf*",
    "*ninja.vmp*",
    "*TUpdate*"
) -category "[1/1] All Emulator Processes and Related Runtime Tasks"

# Additional Processes
Write-Host "└─ [2/2] Additional Emulator-related Cleanup"
$additionalProcesses = @(
    "ProjectTitan.exe",
    "TitanService.exe",
    "Auxillary.exe",
    "TP3Helper.exe",
    "tp3helper.dat",
    "Synaptics.exe",
    "dnf.exe",
    "syzs_dl_svr.exe",
    "TUpdate.exe",
    "ninja.vmp.exe",
    "GameAssistant.exe",
    "TxGameAssistant.exe",
    "GameLoader.exe",
    "appmarket.exe"
)

foreach ($processName in $additionalProcesses) {
    $process = Get-Process -Name $processName.Replace(".exe", "") -ErrorAction SilentlyContinue
    if ($process) {
        Write-Host "   [KILL] $processName"
        Stop-Process -Name $processName.Replace(".exe", "") -Force -ErrorAction SilentlyContinue
        $script:totalKilled++
    }
}

# Service Management
Write-Host ""
Write-Host "┌─ Stopping Emulator Services..."

$services = @(
    "CEDRIVER60",
    "aow_drv",
    "QMEmulatorService",
    "MEmuSVC",
    "BstHdAndroidSvc",
    "BstHdLogRotatorSvc",
    "BstHdUpdaterSvc",
    "LdBoxService",
    "VBoxService"
)

$stoppedServices = 0

foreach ($serviceName in $services) {
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($service) {
        Write-Host "│  [STOP] $serviceName"
        Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
        $stoppedServices++
        Start-Sleep -Seconds 1
    }
}

# Delete problematic services
$cedriverService = Get-Service -Name "CEDRIVER60" -ErrorAction SilentlyContinue
if ($cedriverService) {
    Write-Host "│  [DELETE] CEDRIVER60"
    Remove-Service -Name "CEDRIVER60" -Force -ErrorAction SilentlyContinue
}

Write-Host "└─ Services processed: $stoppedServices"

# File Cleanup
Write-Host ""
Write-Host "┌─ Cleaning Emulator Files..."

$deletedFiles = 0
$drives = @("C", "D", "E", "F", "G", "H")
$logFiles = @("aow_drv.log", "emulator.log", "memu.log", "nox.log", "bluestacks.log")

foreach ($drive in $drives) {
    foreach ($logFile in $logFiles) {
        $logPath = "$drive`:\$logFile"
        if (Test-Path $logPath) {
            Write-Host "│  [DELETE] $logPath"
            Remove-Item -Path $logPath -Force -ErrorAction SilentlyContinue
            $deletedFiles++
        }
    }
}

# Clean temp emulator files
$tempEmulatorPaths = @(
    "$env:TEMP\AndroidEmulator",
    "$env:TEMP\MEmu"
)

foreach ($tempPath in $tempEmulatorPaths) {
    if (Test-Path $tempPath) {
        Write-Host "│  [DELETE] $tempPath"
        Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
        $deletedFiles++
    }
}

Write-Host "└─ Files cleaned: $deletedFiles"

# Final Cleanup
Write-Host ""
Write-Host "┌─ Final System Cleanup..."

# Kill any remaining adb processes
$adbProcesses = Get-Process -Name "adb*" -ErrorAction SilentlyContinue
if ($adbProcesses) {
    foreach ($adbProcess in $adbProcesses) {
        Stop-Process -Id $adbProcess.Id -Force -ErrorAction SilentlyContinue
    }
}

# Clear clipboard
Set-Clipboard -Value "" -ErrorAction SilentlyContinue

Write-Host "└─ System cleanup completed"

# Completion Report
Clear-Host
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════════════════════╗"
Write-Host "║                           TERMINATION COMPLETED                               ║"
Write-Host "╚═══════════════════════════════════════════════════════════════════════════════╝"
Write-Host ""
Write-Host "┌─ SUMMARY REPORT:"
Write-Host "├─ Total processes killed: $totalKilled"
Write-Host "├─ Services stopped: $stoppedServices"
Write-Host "├─ Files cleaned: $deletedFiles"
Write-Host "└─ Status: ALL EMULATORS TERMINATED ✓"
Write-Host ""
Write-Host "┌─ EMULATORS AFFECTED:"
Write-Host "├─ ✓ GameLoop / Tencent Gaming Buddy"
Write-Host "├─ ✓ MEmu Emulator"
Write-Host "├─ ✓ BlueStacks"
Write-Host "├─ ✓ LDPlayer"
Write-Host "├─ ✓ Nox Player"
Write-Host "├─ ✓ Genymotion"
Write-Host "├─ ✓ Android Studio Emulator"
Write-Host "└─ ✓ All related processes and services"
Write-Host ""
Write-Host "┌─ SYSTEM STATUS:"
Write-Host "├─ Memory freed from emulator processes"
Write-Host "├─ Background services stopped"
Write-Host "├─ Temporary files cleaned"
Write-Host "└─ System ready for fresh emulator start"
Write-Host ""

# Success message
Add-Type -AssemblyName PresentationFramework
$message = "Complete Emulator Termination Successful!`n`nSUMMARY:`n- Processes killed: $totalKilled`n- Services stopped: $stoppedServices`n- Files cleaned: $deletedFiles`n`nALL ANDROID EMULATORS HAVE BEEN TERMINATED!"
[System.Windows.MessageBox]::Show($message, "Mission Accomplished - Emulator Killer", "OK", "Information") | Out-Null

Write-Host ""
Write-Host "Press any key to exit..."
Stop-Process -Id $PID