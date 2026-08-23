# GameLoop Fix Tool - PowerShell Version
# Created by: Panda (Enhanced)
# Purpose: Complete GameLoop removal from all visible roots and traces

function Ensure-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host ""
        Write-Host "[!] This script must be run as Administrator" -ForegroundColor Red
        Write-Host "[!] Restarting with admin rights..." -ForegroundColor Yellow
        $psiArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Start-Process -FilePath "powershell.exe" -ArgumentList $psiArgs -Verb RunAs | Out-Null
        exit
    }
}

function Remove-ItemSafe {
    param(
        [string]$Path,
        [string]$Label
    )

    if (-not $Path) { return }
    if (-not (Test-Path -LiteralPath $Path)) { return }

    try {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
        Write-Host "Deleted: $Path"
    }
    catch {
        Write-Host "Could not delete: $Path" -ForegroundColor Yellow
    }
}

function Stop-GameLoopProcesses {
    Write-Host "Stopping all GameLoop-related processes..."

    $patterns = @(
        "*GameLoop*","*GameLoader*","*txgameassistant*","*TxGameAssistant*",
        "*AndroidEmulator*","*AppMarket*","*QMEmulator*","*aow*","*Tensafe*",
        "*ProjectTitan*","*TitanService*","*TBSWebRenderer*","*cef_frame*",
        "*Tencent*","*qqlogin*","*dnf*","*ldnews*","*AndroidRenderer*",
        "*TP3Helper*","*AndroidProcess*","*syzs_dl_svr*"
    )

    $processes = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue
    foreach ($proc in $processes) {
        $name = $proc.Name
        $matched = $false
        foreach ($pattern in $patterns) {
            if ($name -like $pattern) { $matched = $true; break }
        }

        if ($matched) {
            try {
                Stop-Process -Id $proc.ProcessId -Force -ErrorAction Stop
                Write-Host "Stopped process: $($proc.Name)"
            }
            catch {
                Write-Host "Could not stop process: $($proc.Name)" -ForegroundColor Yellow
            }
        }
    }
}

function Remove-GameLoopServices {
    Write-Host "Stopping and removing GameLoop services..."

    $serviceNames = @(
        "aow_drv","Tensafe","QMEmulatorService","MEmuSVC","AndroidEmulator","GameLoop",
        "ProjectTitan","TitanService","AppMarket","TencentDL","TBSWebRenderer","TxGameAssistant"
    )

    foreach ($name in $serviceNames) {
        $svc = Get-CimInstance Win32_Service -Filter "Name = '$name'" -ErrorAction SilentlyContinue
        if ($svc) {
            try {
                Stop-Service -Name $svc.Name -Force -ErrorAction Stop
                Write-Host "Stopped service: $($svc.Name)"
            }
            catch {
                Write-Host "Could not stop service: $($svc.Name)" -ForegroundColor Yellow
            }

            try {
                $svc.Delete() | Out-Null
                Write-Host "Removed service: $($svc.Name)"
            }
            catch {
                Write-Host "Could not remove service: $($svc.Name)" -ForegroundColor Yellow
            }
        }
    }
}

function Remove-GameLoopTasks {
    if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
        Write-Host "Removing scheduled tasks..."
        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match 'GameLoop|Tencent|TxGameAssistant|AndroidEmulator|ProjectTitan|Tensafe' }
        foreach ($task in $tasks) {
            try {
                Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction Stop
                Write-Host "Removed task: $($task.TaskName)"
            }
            catch {
                Write-Host "Could not remove task: $($task.TaskName)" -ForegroundColor Yellow
            }
        }
    }
}

function Remove-RegistryTreeMatch {
    param([string[]]$Roots)

    Write-Host "Cleaning registry keys..."
    $patterns = 'Tencent|txgameassistant|TxGameAssistant|GameLoop|AndroidEmulator|aow_drv|QMEmulatorService|ProjectTitan|Tensafe|MobileGamePC|AppMarket'

    foreach ($root in $Roots) {
        try {
            $items = Get-ChildItem -Path $root -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                $name = $item.Name
                if ($name -match $patterns) {
                    try {
                        Remove-Item -Path $item.PSPath -Recurse -Force -ErrorAction Stop
                        Write-Host "Removed registry key: $($item.PSPath)"
                    }
                    catch {
                        Write-Host "Could not remove registry key: $($item.PSPath)" -ForegroundColor Yellow
                    }
                }
            }
        }
        catch { }
    }

    $runKeys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    )

    foreach ($key in $runKeys) {
        try {
            $values = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
            foreach ($value in $values) {
                $valueData = (Get-ItemProperty -Path $key -Name $value -ErrorAction SilentlyContinue).$value
                if ($value -match 'GameLoop|Tencent|AndroidEmulator|TxGameAssistant|ProjectTitan|Tensafe|AppMarket' -or $valueData -match 'GameLoop|Tencent|AndroidEmulator|TxGameAssistant|ProjectTitan|Tensafe|AppMarket') {
                    Remove-ItemProperty -Path $key -Name $value -ErrorAction SilentlyContinue
                    Write-Host "Removed Run entry: $value"
                }
            }
        }
        catch { }
    }
}

function Remove-PathList {
    param([string[]]$Paths)

    foreach ($path in $Paths) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            Remove-ItemSafe -Path $path -Label "path"
        }
    }
}

function Remove-FilesByName {
    param(
        [string[]]$Names,
        [string]$Description
    )

    $drives = Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -in 2,3 } | Select-Object -ExpandProperty DeviceID
    $found = $false

    foreach ($drive in $drives) {
        foreach ($name in $Names) {
            $items = Get-ChildItem -Path $drive -Filter $name -Recurse -Force -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                try {
                    Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                    Write-Host "Deleted: $($item.FullName)"
                    $found = $true
                }
                catch {
                    Write-Host "Could not delete: $($item.FullName)" -ForegroundColor Yellow
                }
            }
        }
    }

    if ($found) {
        Write-Host "[?] $Description removed from one or more partitions."
    }
    else {
        Write-Host "[X] $Description not found in any partition."
    }
}

function Remove-GameLoopFolders {
    Write-Host "Scanning all drives for GameLoop installation folders..."

    $drives = Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -in 2,3 } | Select-Object -ExpandProperty DeviceID
    $folderNames = @("txgameassistant", "GameLoop", "Tencent", "AndroidEmulator", "ProjectTitan", "Tensafe", "AppMarket")

    foreach ($drive in $drives) {
        foreach ($name in $folderNames) {
            $matches = Get-ChildItem -Path $drive -Force -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $name }
            foreach ($match in $matches) {
                try {
                    Remove-Item -LiteralPath $match.FullName -Recurse -Force -ErrorAction Stop
                    Write-Host "Deleted folder: $($match.FullName)"
                }
                catch {
                    Write-Host "Could not delete folder: $($match.FullName)" -ForegroundColor Yellow
                }
            }
        }
    }
}

Ensure-Admin
$Host.UI.RawUI.ForegroundColor = "Cyan"
$Host.UI.RawUI.WindowTitle = "GameLoop Complete Removal - Created by Panda"

Write-Host ""
Write-Host "==============================================================="
Write-Host "             COMPLETE GAMELOOP ROOT-LEVEL REMOVAL             "
Write-Host "==============================================================="
Write-Host "This will terminate all related GameLoop and emulator activity, then remove installed files and registry traces."
Write-Host ""
$confirmation = Read-Host "Do you want to permanently delete GameLoop and all related traces from this computer? Type YES to continue"
if ($confirmation -notmatch '^YES$') {
    Write-Host "Deletion cancelled by user. No files or registry entries were removed."
    exit
}

Stop-GameLoopProcesses
Remove-GameLoopServices
Remove-GameLoopTasks

Write-Host ""
Write-Host "Deleting GameLoop registry traces..."
$registryRoots = @(
    "HKCU:\Software",
    "HKLM:\SOFTWARE",
    "HKLM:\SYSTEM",
    "HKU:\",
    "HKCR:\"
)
Remove-RegistryTreeMatch -Roots $registryRoots

Write-Host ""
Write-Host "Deleting GameLoop user data..."
$userDataPaths = @(
    "$env:USERPROFILE\AppData\Roaming\Tencent",
    "$env:USERPROFILE\AppData\Local\Tencent",
    "$env:USERPROFILE\AppData\LocalLow\Tencent",
    "$env:USERPROFILE\AppData\Roaming\TxGameAssistant",
    "$env:USERPROFILE\AppData\Local\TxGameAssistant",
    "$env:USERPROFILE\AppData\Roaming\GameLoop",
    "$env:USERPROFILE\AppData\Local\GameLoop",
    "$env:USERPROFILE\AppData\Roaming\AndroidTbox",
    "$env:USERPROFILE\AppData\Local\AndroidTbox",
    "$env:USERPROFILE\AppData\Local\Temp\GameLoop",
    "$env:USERPROFILE\AppData\Local\Temp\Tencent"
)
Remove-PathList -Paths $userDataPaths

Write-Host ""
Write-Host "Deleting common installation directories..."
$installRoots = @(
    "C:\ProgramData\Tencent",
    "C:\ProgramData\TxGameAssistant",
    "C:\ProgramData\GameLoop",
    "D:\ProgramData\Tencent",
    "D:\ProgramData\TxGameAssistant",
    "E:\ProgramData\Tencent",
    "E:\ProgramData\TxGameAssistant",
    "F:\ProgramData\Tencent",
    "F:\ProgramData\TxGameAssistant",
    "C:\Program Files\txgameassistant",
    "C:\Program Files\GameLoop",
    "D:\Program Files\txgameassistant",
    "D:\Program Files\GameLoop",
    "E:\Program Files\txgameassistant",
    "E:\Program Files\GameLoop",
    "F:\Program Files\txgameassistant",
    "F:\Program Files\GameLoop"
)
Remove-PathList -Paths $installRoots

Write-Host ""
Remove-GameLoopFolders

Write-Host ""
Write-Host "Deleting GameLoop executables and logs from all partitions..."
Remove-FilesByName -Names @(
    "aow_drv.log","GameLoop.exe","AppMarket.exe","AndroidEmulator.exe","QMEmulatorService.exe",
    "Tensafe.exe","ProjectTitan.exe","txplatform.exe","AndroidRenderer.exe","TxGameAssistant.exe",
    "GameLoader.exe","TencentDL.exe","cef_frame_demo.exe","cef_frame_render.exe"
) -Description "GameLoop executables and logs"

Write-Host ""
Write-Host "Removing shortcuts and start-menu entries..."
$shortcutPaths = @(
    "$env:USERPROFILE\Desktop\GameLoop.lnk",
    "$env:USERPROFILE\Desktop\AndroidEmulator.lnk",
    "$env:USERPROFILE\Desktop\TencentGameAssistant.lnk",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\GameLoop.lnk",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\AndroidEmulator.lnk",
    "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\GameLoop.lnk",
    "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\TxGameAssistant.lnk"
)
Remove-PathList -Paths $shortcutPaths

Write-Host ""
Write-Host "Emptying Recycle Bin..."
try {
    Clear-RecycleBin -Force -ErrorAction Stop
    Write-Host "Recycle Bin emptied."
}
catch {
    Write-Host "Could not empty Recycle Bin automatically." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==============================================================="
Write-Host "                GAMELOOP REMOVAL FINALIZED                  "
Write-Host "==============================================================="
Write-Host "The system was scanned and all visible GameLoop traces were removed where possible."
Write-Host "Please restart the PC to finalize the cleanup."
Write-Host "Press Enter to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")