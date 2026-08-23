# Advanced Temp Files Cleaner v3.0 - PowerShell Version
# Created by Panda

$script:errors = 0
$script:processed = 0

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

function Count-Items {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    return (Get-ChildItem -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object).Count
}

function Remove-SafeContents {
    param(
        [string]$TargetDir,
        [string]$Description,
        [switch]$AllowRootDelete
    )

    if (-not (Test-Path -LiteralPath $TargetDir)) {
        Write-Host "   INFO: $Description not found"
        return
    }

    $count = Count-Items -Path $TargetDir
    if ($count -eq 0) {
        Write-Host "   INFO: $Description - No files to clean"
        return
    }

    try {
        Get-ChildItem -LiteralPath $TargetDir -Recurse -Force -ErrorAction Stop | Remove-Item -Force -Recurse -ErrorAction Stop
        if ($AllowRootDelete) {
            Remove-Item -LiteralPath $TargetDir -Force -Recurse -ErrorAction Stop
        }
        $script:processed += $count
        Write-Host "   SUCCESS: $Description - Cleaned $count items"
    }
    catch {
        Write-Host "   WARNING: $Description - Some files could not be cleaned" -ForegroundColor Yellow
        $script:errors++
    }
}

function Remove-TempPattern {
    param(
        [string]$BasePath,
        [string]$Pattern,
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $BasePath)) {
        Write-Host "   INFO: $Description not found"
        return
    }

    $items = Get-ChildItem -LiteralPath $BasePath -Filter $Pattern -File -Recurse -ErrorAction SilentlyContinue
    if (-not $items -or $items.Count -eq 0) {
        Write-Host "   INFO: $Description - No matching files"
        return
    }

    try {
        $items | Remove-Item -Force -ErrorAction Stop
        $script:processed += $items.Count
        Write-Host "   SUCCESS: $Description - Cleaned $($items.Count) files"
    }
    catch {
        Write-Host "   WARNING: $Description - Could not remove all matching files" -ForegroundColor Yellow
        $script:errors++
    }
}

Ensure-Admin
$Host.UI.RawUI.WindowTitle = "Advanced Temp Files Cleaner v3.0 - Created by Panda"
$Host.UI.RawUI.ForegroundColor = "Cyan"

Write-Host ""
Write-Host "==================================================================="
Write-Host "                    Advanced Temp Files Cleaner v3.0              "
Write-Host "                         Created by Panda                        "
Write-Host "==================================================================="
Write-Host ""
Write-Host "Starting full temporary files cleanup..."
Write-Host ""

Write-Host "[1/15] Cleaning user temp files..."
Remove-SafeContents -TargetDir $env:TEMP -Description "User Temp Files"

Write-Host "[2/15] Cleaning Windows temp files..."
Remove-SafeContents -TargetDir "$env:windir\Temp" -Description "Windows Temp Files"

Write-Host "[3/15] Cleaning system temp folder..."
if (Test-Path "C:\tmp") { Remove-SafeContents -TargetDir "C:\tmp" -Description "System Tmp Files" }

Write-Host "[4/15] Cleaning Java temp files..."
if (Test-Path "$env:LOCALAPPDATA\Temp\javac") { Remove-SafeContents -TargetDir "$env:LOCALAPPDATA\Temp\javac" -Description "Java Temp Files" }

Write-Host "[5/15] Cleaning Prefetch files..."
Remove-TempPattern -BasePath "C:\Windows\Prefetch" -Pattern "*.pf" -Description "Prefetch Files"

Write-Host "[6/15] Cleaning recent files..."
Remove-SafeContents -TargetDir "$env:APPDATA\Microsoft\Windows\Recent" -Description "Recent Files"

Write-Host "[7/15] Cleaning Windows Update cache..."
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
Stop-Service -Name bits -Force -ErrorAction SilentlyContinue
Stop-Service -Name dosvc -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
if (Test-Path "$env:windir\SoftwareDistribution\Download") {
    Remove-SafeContents -TargetDir "$env:windir\SoftwareDistribution\Download" -Description "Windows Update Cache"
}
Start-Service -Name bits -ErrorAction SilentlyContinue
Start-Service -Name wuauserv -ErrorAction SilentlyContinue
Start-Service -Name dosvc -ErrorAction SilentlyContinue

Write-Host "[8/15] Cleaning system cache..."
Remove-SafeContents -TargetDir "$env:LOCALAPPDATA\Microsoft\Windows\INetCache" -Description "Internet Cache"
Remove-SafeContents -TargetDir "$env:LOCALAPPDATA\Temp" -Description "Local Temp Files"

Write-Host "[9/15] Cleaning browser cache..."
$browserRoots = @(
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache"
)
foreach ($path in $browserRoots) {
    if (Test-Path -LiteralPath $path) { Remove-SafeContents -TargetDir $path -Description "Browser Cache" }
}

Write-Host "[10/15] Cleaning Firefox cache..."
$firefoxProfiles = Get-ChildItem -Path "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue
foreach ($profile in $firefoxProfiles) {
    $cachePath = Join-Path $profile.FullName "cache2"
    if (Test-Path -LiteralPath $cachePath) { Remove-SafeContents -TargetDir $cachePath -Description "Firefox Cache" }
    $sqliteFiles = @("places.sqlite", "cookies.sqlite")
    foreach ($file in $sqliteFiles) {
        $item = Join-Path $profile.FullName $file
        if (Test-Path -LiteralPath $item) {
            try { Remove-Item -LiteralPath $item -Force -ErrorAction Stop; $script:processed++ }
            catch { $script:errors++ }
        }
    }
}

Write-Host "[11/15] Cleaning Windows logs older than 30 days..."
if (Test-Path "C:\Windows\Logs") {
    $oldLogs = Get-ChildItem -Path "C:\Windows\Logs" -Filter "*.log" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) }
    if ($oldLogs) {
        try { $oldLogs | Remove-Item -Force -ErrorAction Stop; $script:processed += $oldLogs.Count; Write-Host "   SUCCESS: Cleaned old log files" }
        catch { Write-Host "   WARNING: Could not clean some log files" -ForegroundColor Yellow; $script:errors++ }
    }
}

Write-Host "[12/15] Cleaning crash dumps..."
if (Test-Path "C:\Windows\Minidump") {
    Remove-TempPattern -BasePath "C:\Windows\Minidump" -Pattern "*.dmp" -Description "Crash Dumps"
}

Write-Host "[13/15] Cleaning old setup logs..."
if (Test-Path "$env:windir\Panther") { Remove-SafeContents -TargetDir "$env:windir\Panther" -Description "Setup Logs" }

Write-Host "[14/15] Cleaning temporary installer files..."
$installTemps = @(
    "$env:SystemDrive\$Windows.~BT",
    "$env:SystemDrive\$Windows.~LS",
    "$env:SystemDrive\Temp",
    "$env:ProgramData\Package Cache",
    "$env:ProgramData\TEMP"
)
foreach ($path in $installTemps) {
    if (Test-Path -LiteralPath $path) { Remove-SafeContents -TargetDir $path -Description "Installer Temp Files" }
}

Write-Host "[15/15] Emptying recycle bin..."
try {
    Clear-RecycleBin -Force -ErrorAction Stop
    Write-Host "   SUCCESS: Recycle bin emptied"
}
catch {
    try {
        Get-ChildItem -Path "$env:SystemDrive\$Recycle.Bin" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction Stop
        Write-Host "   SUCCESS: Recycle bin emptied via fallback"
    }
    catch {
        Write-Host "   WARNING: Could not empty recycle bin" -ForegroundColor Yellow
        $script:errors++
    }
}

Write-Host ""
Write-Host "Running Windows Disk Cleanup utility..."
Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:1" -Wait -WindowStyle Hidden

Clear-Host
Write-Host ""
Write-Host "==================================================================="
Write-Host "                 FULL TEMP CLEANUP COMPLETED!                  "
Write-Host "==================================================================="
Write-Host "   Temporary files cleaned                                       "
Write-Host "   Browser caches cleared                                        "
Write-Host "   Windows cache cleaned                                         "
Write-Host "   Crash dumps removed                                           "
Write-Host "   Logs cleaned                                                  "
Write-Host "   Recycle bin emptied                                           "
Write-Host "==================================================================="
Write-Host "   Items processed: $script:processed"
Write-Host "   Errors encountered: $script:errors"
Write-Host "==================================================================="
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")