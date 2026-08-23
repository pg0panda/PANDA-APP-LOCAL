# FIX 98 - PowerShell Version
# Created by Panda

# Check for Administrator privileges
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

$Host.UI.RawUI.WindowTitle = "WELCOME $env:USERNAME"
$Host.UI.RawUI.ForegroundColor = "Cyan"

Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show("WELCOME... this tool will fix gameloop 98 !", "CREATED BY Panda", "OK", "Information") | Out-Null

Write-Host "Terminating emulator-related processes..."
$processesToKill = @("AndroidEmulator.exe","AndroidEmulatorEx.exe","GameLoader.exe","appmarket.exe","androidemulator.exe","androidemulatoren.exe","AndroidProcess.exe","aow_exe.exe","QMEmulatorService.exe","RuntimeBroker.exe","adb.exe","adb2.exe","ProjectTitan.exe","TitanService.exe","MEmuHeadless.exe","MEmuSVC.exe","MEmu.exe","MEmuConsole.exe","ldnews.exe","MemuService.exe","Synaptics.exe","dnf.exe","Auxillary.exe","TP3Helper.exe","TBSWebRenderer.exe")
foreach ($process in $processesToKill) {
    Stop-Process -Name $process.Replace(".exe", "") -Force -ErrorAction SilentlyContinue
}

Write-Host "Stopping and deleting emulator-related services..."
$servicesToStop = @("CEDRIVER60","aow_drv","QMEmulatorService","MEmuSVC")
foreach ($service in $servicesToStop) {
    Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
    Remove-Service -Name $service -ErrorAction SilentlyContinue
}

Write-Host "Cleaning up log files..."
Remove-Item -Path "C:\aow_drv.log" -Force -ErrorAction SilentlyContinue

function Remove-TargetFilesRecursively {
    param(
        [string[]]$Targets,
        [string]$Description
    )

    $drives = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -in 2,3 } | Select-Object -ExpandProperty DeviceID
    $matchedAny = $false

    foreach ($drive in $drives) {
        foreach ($target in $Targets) {
            $items = Get-ChildItem -Path $drive -Filter $target -Recurse -Force -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                try {
                    if ($item.PSIsContainer) {
                        Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                    }
                    else {
                        Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
                    }

                    $matchedAny = $true
                    Write-Host "Deleted: $($item.FullName)"
                }
                catch {
                    Write-Host "Could not delete: $($item.FullName)" -ForegroundColor Yellow
                }
            }
        }
    }

    if (-not $matchedAny) {
        Write-Host "[X] $Description not found in any partition."
    }
    else {
        Write-Host "[?] $Description deleted from available partitions."
    }
}

$Host.UI.RawUI.WindowTitle = "FIX 98 - Created by PANDA"

Write-Host "Searching all partitions for AOW files..."
Remove-TargetFilesRecursively -Targets @("0", "367", "30", "30.ini") -Description "AOW_Rootfs_100 target files"

Write-Host "Searching all partitions for aow_drv.log..."
Remove-TargetFilesRecursively -Targets @("aow_drv.log") -Description "aow_drv.log files"

Write-Host "Searching all partitions for TxGameAssistant folders..."
$drives = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -in 2,3 } | Select-Object -ExpandProperty DeviceID
$foundFolder = $false
foreach ($drive in $drives) {
    $folder = Get-ChildItem -Path $drive -Directory -Filter "TxGameAssistant" -Recurse -Force -ErrorAction SilentlyContinue
    foreach ($item in $folder) {
        $path = Join-Path $item.FullName "AOW_Rootfs_100"
        if (Test-Path $path) {
            $foundFolder = $true
            Write-Host "Found: $path"
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Deleted: $path"
        }
    }
}
if (-not $foundFolder) {
    Write-Host "[X] TxGameAssistant folder not found in any partition."
}

Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show("Done", "CREATED BY Panda", "OK", "Information") | Out-Null

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")