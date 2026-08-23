# CleanDisk Pro Enhanced - PowerShell Version
# Created by PANDA

$script:cleaned_files = 0
$script:freed_space = 0
$script:session_started = Get-Date

function Ensure-Admin {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host "" 
        Write-Host "[!] This script must be run as Administrator" -ForegroundColor Red
        Write-Host "[!] Restarting with administrator rights..." -ForegroundColor Yellow
        $psiArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        Start-Process -FilePath "powershell.exe" -ArgumentList $psiArgs -Verb RunAs | Out-Null
        exit
    }
}

function Show-Header {
    Clear-Host
    $Host.UI.RawUI.WindowTitle = "CleanDisk Pro Enhanced - Created by PANDA"
    $Host.UI.RawUI.ForegroundColor = "Cyan"
    Write-Host ""
    Write-Host "   ================================================================"
    Write-Host "      CLEAN DISK - By PANDA"
    Write-Host "   ================================================================"
    Write-Host ""
    Write-Host "   System Information:"
    Write-Host "   - OS: $([System.Environment]::OSVersion.VersionString)"
    Write-Host "   - Computer: $env:COMPUTERNAME"
    Write-Host "   - User: $env:USERNAME"
    Write-Host "   - Date: $(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')"
    Write-Host ""
}

function Remove-DirectoryContentsSafely {
    param(
        [string]$Path,
        [switch]$SkipRoot
    )

    if (-not $Path) { return }
    if (-not (Test-Path -LiteralPath $Path)) { return }

    try {
        $items = Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop
        foreach ($item in $items) {
            try {
                if ($item.PSIsContainer) {
                    Remove-Item -LiteralPath $item.FullName -Recurse -Force -ErrorAction Stop
                }
                else {
                    Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
                }
                $script:cleaned_files += 1
            }
            catch {
                Write-Host "  [!] Skipped: $($item.FullName)" -ForegroundColor Yellow
            }
        }

        if (-not $SkipRoot) {
            try {
                Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
            }
            catch {
                Write-Host "  [!] Could not delete root: $Path" -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host "  [!] Unable to access folder: $Path" -ForegroundColor Yellow
    }
}

function Invoke-BrowserCleanup {
    $users = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue
    foreach ($user in $users) {
        $root = $user.FullName

        $browserPaths = @(
            "$root\AppData\Local\Google\Chrome\User Data\Default\Cache",
            "$root\AppData\Local\Google\Chrome\User Data\Default\Code Cache",
            "$root\AppData\Local\Google\Chrome\User Data\Default\History",
            "$root\AppData\Local\Google\Chrome\User Data\Default\Cookies",
            "$root\AppData\Local\Microsoft\Edge\User Data\Default\Cache",
            "$root\AppData\Local\Microsoft\Edge\User Data\Default\Code Cache",
            "$root\AppData\Local\Microsoft\Edge\User Data\Default\History",
            "$root\AppData\Local\Microsoft\Edge\User Data\Default\Cookies",
            "$root\AppData\Local\Mozilla\Firefox\Profiles"
        )

        foreach ($path in $browserPaths) {
            if (Test-Path -LiteralPath $path) {
                if ($path -match "Firefox") {
                    Get-ChildItem -LiteralPath $path -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                        $profile = $_.FullName
                        @("cache2", "places.sqlite", "cookies.sqlite") | ForEach-Object {
                            $item = Join-Path $profile $_
                            if (Test-Path -LiteralPath $item) {
                                Remove-Item -LiteralPath $item -Recurse -Force -ErrorAction SilentlyContinue
                            }
                        }
                    }
                }
                else {
                    Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

function Show-MainMenu {
    Show-Header
    Write-Host "   ==================[ MAIN MENU ]=================="
    Write-Host "   1. Quick Clean (Temporary Files)"
    Write-Host "   2. Deep System Repair & Malware Scan"
    Write-Host "   3. Browser Cleanup"
    Write-Host "   4. Registry Cleanup & Optimization"
    Write-Host "   5. Disk Space Analyzer"
    Write-Host "   6. System Health Check"
    Write-Host "   7. Full Repair (Recommended)"
    Write-Host "   8. View Cleanup Statistics"
    Write-Host "   9. Exit"
    Write-Host "   =================================================="
    Write-Host ""
    $choice = Read-Host "   Select Option [1-9]"

    switch ($choice) {
        "1" { Quick-Clean }
        "2" { Deep-Clean }
        "3" { Browser-Clean }
        "4" { Registry-Clean }
        "5" { Disk-Analyzer }
        "6" { Health-Check }
        "7" { Full-Repair }
        "8" { Show-Stats }
        "9" { Shutdown }
        default {
            Write-Host "   Invalid choice! Please select 1-9." -ForegroundColor Red
            Start-Sleep -Seconds 2
            Show-MainMenu
        }
    }
}

function Quick-Clean {
    Show-Header
    Write-Host "[1] Starting Quick Cleanup..." -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""

    $targets = @(
        $env:TEMP,
        $env:LOCALAPPDATA + "\Temp",
        $env:windir + "\Temp",
        "C:\Windows\Prefetch",
        "$env:APPDATA\Microsoft\Windows\Recent"
    )

    foreach ($target in $targets) {
        if (Test-Path -LiteralPath $target) {
            Write-Host "Cleaning: $target"
            Remove-DirectoryContentsSafely -Path $target -SkipRoot
        }
    }

    Write-Host ""
    Write-Host "[✓] Quick clean completed successfully!" -ForegroundColor Green
    Write-Host "Files processed: $script:cleaned_files"
    Read-Host "Press Enter to continue"
    Show-MainMenu
}

function Deep-Clean {
    Show-Header
    Write-Host "[2] Starting Deep System Repair & Security Scan..." -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Phase 1: Temporary file system cleanup..."
    $targets = @(
        $env:TEMP,
        $env:LOCALAPPDATA + "\Temp",
        $env:windir + "\Temp",
        "$env:windir\SoftwareDistribution\Download",
        "$env:windir\Logs",
        "C:\Windows\Prefetch"
    )

    foreach ($target in $targets) {
        if (Test-Path -LiteralPath $target) {
            Remove-DirectoryContentsSafely -Path $target -SkipRoot
        }
    }

    Write-Host "Phase 2: Windows Defender scan..."
    $defender = "$env:ProgramFiles\Windows Defender\MpCmdRun.exe"
    if (Test-Path $defender) {
        & $defender -Scan -ScanType 2
    }
    else {
        Write-Host "Windows Defender not found."
    }

    Write-Host "Phase 3: Repair system files..."
    $sfc = Get-Command sfc.exe -ErrorAction SilentlyContinue
    if ($sfc) {
        & sfc.exe /scannow
    }

    $dism = Get-Command dism.exe -ErrorAction SilentlyContinue
    if ($dism) {
        & dism.exe /online /cleanup-image /restorehealth
    }

    Write-Host ""
    Write-Host "[✓] Deep repair completed. Please review the results above." -ForegroundColor Green
    Read-Host "Press Enter to continue"
    Show-MainMenu
}

function Browser-Clean {
    Show-Header
    Write-Host "[3] Cleaning Browser Data..." -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    Invoke-BrowserCleanup
    Write-Host ""
    Write-Host "[✓] Browser cleanup completed." -ForegroundColor Green
    Read-Host "Press Enter to continue"
    Show-MainMenu
}

function Registry-Clean {
    Show-Header
    Write-Host "[4] Registry Cleanup and Optimization..." -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""

    $safeKeys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU"
    )

    foreach ($key in $safeKeys) {
        if (Test-Path $key) {
            Remove-Item -Path $key -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "Registry temporary entries cleaned."
    Write-Host "Note: Some registry changes take effect after restart." -ForegroundColor Yellow
    Read-Host "Press Enter to continue"
    Show-MainMenu
}

function Disk-Analyzer {
    Show-Header
    Write-Host "[5] Disk Space Analysis..." -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    Write-Host ""

    $drives = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
    foreach ($drive in $drives) {
        $letter = $drive.DeviceID.TrimEnd(':')
        $freeGB = [math]::Round($drive.FreeSpace / 1GB, 2)
        $totalGB = [math]::Round($drive.Size / 1GB, 2)
        $usedGB = [math]::Round(($drive.Size - $drive.FreeSpace) / 1GB, 2)

        Write-Host "Drive ${letter}:"
        Write-Host "  Total: $totalGB GB"
        Write-Host "  Used:  $usedGB GB"
        Write-Host "  Free:  $freeGB GB"

        $tempFiles = Get-ChildItem -Path "$($drive.DeviceID)\" -Recurse -Include "*.log", "*.tmp", "*.cache", "*.old" -ErrorAction SilentlyContinue | Measure-Object
        Write-Host "  Temporary files found: $($tempFiles.Count)"
        Write-Host ""
    }

    Write-Host "Analysis completed." -ForegroundColor Green
    Read-Host "Press Enter to continue"
    Show-MainMenu
}

function Health-Check {
    Show-Header
    Write-Host "[6] System Health Check..." -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Checking file integrity..."
    $sfc = Get-Command sfc.exe -ErrorAction SilentlyContinue
    if ($sfc) {
        & sfc.exe /verifyonly
    }

    Write-Host "Checking disk health..."
    $systemDrive = (Get-Volume | Where-Object { $_.DriveLetter -eq $env:SystemDrive.TrimEnd(':') }).DriveLetter
    if ($systemDrive) {
        & chkdsk.exe "$systemDrive`:" /scan
    }

    Write-Host "Checking Windows Update service..."
    $svc = Get-Service -Name wuauserv -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq 'Running') {
        Write-Host "[✓] Windows Update service is running." -ForegroundColor Green
    }
    else {
        Write-Host "[!] Windows Update service needs attention." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "System health check completed." -ForegroundColor Green
    Read-Host "Press Enter to continue"
    Show-MainMenu
}

function Full-Repair {
    Show-Header
    Write-Host "[7] Full Repair - Safe System Recovery & Disk Cleaning" -ForegroundColor Cyan
    Write-Host "=====================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This process safely performs the main Windows repairs:" -ForegroundColor Yellow
    Write-Host "- Cleanup temporary files"
    Write-Host "- Clean browsers and caches"
    Write-Host "- Repair system files"
    Write-Host "- Scan for malware"
    Write-Host "- Check disk health"
    Write-Host "- Optimize the system environment"
    Write-Host ""
    $confirm = Read-Host "Do you want to continue? [Y/N]"
    if ($confirm -notmatch '^(Y|Yes)$') {
        Write-Host "Full repair cancelled." -ForegroundColor Yellow
        Read-Host "Press Enter to continue"
        Show-MainMenu
        return
    }

    Write-Host "Step 1: Cleaning temporary files..."
    $targets = @(
        $env:TEMP,
        $env:LOCALAPPDATA + "\Temp",
        $env:windir + "\Temp",
        "C:\Windows\Prefetch",
        "$env:windir\SoftwareDistribution\Download",
        "$env:APPDATA\Microsoft\Windows\Recent"
    )
    foreach ($target in $targets) {
        if (Test-Path -LiteralPath $target) {
            Remove-DirectoryContentsSafely -Path $target -SkipRoot
        }
    }

    Write-Host "Step 2: Cleaning browser data..."
    Invoke-BrowserCleanup

    Write-Host "Step 3: Cleaning Windows Update cache..."
    $updateCache = "$env:windir\SoftwareDistribution"
    if (Test-Path $updateCache) {
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $updateCache -Recurse -Force -ErrorAction SilentlyContinue
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    }

    Write-Host "Step 4: Repairing system files..."
    $sfc = Get-Command sfc.exe -ErrorAction SilentlyContinue
    if ($sfc) {
        & sfc.exe /scannow
    }

    $dism = Get-Command dism.exe -ErrorAction SilentlyContinue
    if ($dism) {
        & dism.exe /online /cleanup-image /restorehealth
    }

    Write-Host "Step 5: Malware scan..."
    $defender = "$env:ProgramFiles\Windows Defender\MpCmdRun.exe"
    if (Test-Path $defender) {
        & $defender -Scan -ScanType 2
    }

    Write-Host "Step 6: Disk integrity check..."
    $diskLetter = (Get-Volume | Where-Object { $_.DriveLetter -ne $null } | Select-Object -First 1).DriveLetter
    if ($diskLetter) {
        & chkdsk.exe "$($diskLetter):" /scan
    }

    Write-Host ""
    Write-Host "[✓] Full repair process finished." -ForegroundColor Green
    Write-Host "Please reboot if Windows asks for repairs or file restoration."
    Read-Host "Press Enter to continue"
    Show-MainMenu
}

function Show-Stats {
    Show-Header
    Write-Host "[8] Cleanup Statistics..." -ForegroundColor Cyan
    Write-Host "========================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   Current Session Statistics:"
    Write-Host "   - Script runtime: $((Get-Date) - $script:session_started)"
    Write-Host "   - Files processed: $script:cleaned_files"
    Write-Host "   - System state: Optimized"
    Write-Host ""
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $totalMemory = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeMemory = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    Write-Host "   - Total physical memory: $totalMemory GB"
    Write-Host "   - Available physical memory: $freeMemory GB"
    Write-Host ""
    Write-Host "   Disk Space (C:):"
    $disk = Get-PSDrive -Name C -ErrorAction SilentlyContinue
    if ($disk) {
        $freeSpace = [math]::Round($disk.Free / 1GB, 2)
        Write-Host "   - Free space: $freeSpace GB"
    }
    Write-Host ""
    Read-Host "Press Enter to continue"
    Show-MainMenu
}

function Shutdown {
    Clear-Host
    Write-Host ""
    Write-Host "   ================================================================"
    Write-Host "      THANK YOU FOR USING CLEANDISK PRO ENHANCED!"
    Write-Host "   ================================================================"
    Write-Host "" 
    Write-Host "[i] Script execution complete." -ForegroundColor Gray
    Write-Host "   ================================================================"
    Read-Host "Press ENTER to close this window"
    exit 0
}

Ensure-Admin
Show-Header
Read-Host "Press Enter to continue"
Show-MainMenu