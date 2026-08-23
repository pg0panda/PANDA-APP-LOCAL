# =========================================================
#   ADVANCED VIRTUAL MEMORY MANAGER
#   Professional Edition v3.0
#   Fixed + Optimized + Clean Edition
# =========================================================

# =========================
# Auto Run As Admin
# =========================
$currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Start-Process powershell.exe `
        -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`"" `
        -Verb RunAs
    exit
}

# =========================
# Config
# =========================
$BackupFolder = "$env:ProgramData\VMemManager"
$BackupFile   = Join-Path $BackupFolder "backup.json"

if (-not (Test-Path $BackupFolder)) {
    New-Item -ItemType Directory -Path $BackupFolder -Force | Out-Null
}

# =========================
# Helpers
# =========================
function Write-Color {
    param(
        [string]$Text,
        [string]$Color = "White"
    )

    Write-Host $Text -ForegroundColor $Color
}

function Pause-Script {
    Write-Host ""
    Write-Color "Press Enter to continue..." DarkGray
    Read-Host | Out-Null
}

function Show-Banner {
    Clear-Host

    Write-Color "========================================================" Cyan
    Write-Color "      ADVANCED VIRTUAL MEMORY MANAGER v3.0             " Green
    Write-Color "========================================================" Cyan
    Write-Color "[!] Please, restart your PC after finished. (Recommended to choose SSD)" Red
    Write-Host ""
}

# =========================
# System Info
# =========================
function Get-SystemInfo {

    $cs = Get-CimInstance Win32_ComputerSystem
    $os = Get-CimInstance Win32_OperatingSystem

    $totalRAMGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    $freeRAMGB  = [math]::Round(($os.FreePhysicalMemory * 1KB) / 1GB, 2)
    $usedRAMGB  = [math]::Round($totalRAMGB - $freeRAMGB, 2)

    return [PSCustomObject]@{
        TotalRAMGB = $totalRAMGB
        FreeRAMGB  = $freeRAMGB
        UsedRAMGB  = $usedRAMGB
    }
}

# =========================
# PageFile Info
# =========================
function Get-CurrentPageFile {

    $settings = Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue
    $usage    = Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue
    $cs       = Get-CimInstance Win32_ComputerSystem

    return [PSCustomObject]@{
        AutoManaged = $cs.AutomaticManagedPagefile
        Settings     = $settings
        Usage        = $usage
    }
}

# =========================
# Show Status
# =========================
function Show-CurrentStatus {

    $sys = Get-SystemInfo
    $pf  = Get-CurrentPageFile

    Write-Color "---- RAM -----------------------------------------------" DarkCyan
    Write-Color "  Total RAM : $($sys.TotalRAMGB) GB" Yellow
    Write-Color "  Used RAM  : $($sys.UsedRAMGB) GB" Yellow
    Write-Color "  Free RAM  : $($sys.FreeRAMGB) GB" Yellow

    Write-Host ""

    Write-Color "---- Virtual Memory ------------------------------------" DarkCyan

    if ($pf.AutoManaged) {
        Write-Color "  Mode : Windows Managed" Green
    }
    else {
        Write-Color "  Mode : Manual" Cyan
    }

    if ($pf.Settings) {

        foreach ($item in $pf.Settings) {

            $initGB = [math]::Round($item.InitialSize / 1024, 2)
            $maxGB  = [math]::Round($item.MaximumSize / 1024, 2)

            Write-Color "  Drive   : $($item.Name)" White
            Write-Color "  Initial : $($item.InitialSize) MB ($initGB GB)" White
            Write-Color "  Maximum : $($item.MaximumSize) MB ($maxGB GB)" White
        }
    }
    else {
        Write-Color "  No custom pagefile found." DarkGray
    }

    Write-Host ""
}

# =========================
# Disk List
# =========================
function Get-DiskList {

    $list = @()

    # Build DriveLetter -> MediaType map using physical disk info
    $driveTypeMap = @{}

    try {
        $physicalDisks = Get-PhysicalDisk -ErrorAction SilentlyContinue

        foreach ($pd in $physicalDisks) {

            $mediaType = switch ($pd.MediaType) {
                'SSD'     { 'SSD' }
                'HDD'     { 'HDD' }
                'SCM'     { 'SCM' }
                default   { 'HDD' }   # Unspecified -> assume HDD
            }

            $partitions = Get-Partition -DiskNumber $pd.DeviceId -ErrorAction SilentlyContinue

            foreach ($part in $partitions) {
                if ($part.DriveLetter) {
                    $driveTypeMap["$($part.DriveLetter):"] = $mediaType
                }
            }
        }
    }
    catch { }

    $drives = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"

    foreach ($disk in $drives) {

        $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
        $sizeGB = [math]::Round($disk.Size / 1GB, 2)

        $recommended = if ($freeGB -gt 15) { "YES" } else { "NO" }

        $mediaType = if ($driveTypeMap.ContainsKey($disk.DeviceID)) {
            $driveTypeMap[$disk.DeviceID]
        } else {
            'Unknown'
        }

        $list += [PSCustomObject]@{
            Drive       = $disk.DeviceID
            Type        = $mediaType
            FreeGB      = $freeGB
            TotalGB     = $sizeGB
            Recommended = $recommended
        }
    }

    return $list
}

# =========================
# Backup
# =========================
function Backup-Settings {

    $pf = Get-CurrentPageFile

    $data = [PSCustomObject]@{
        Timestamp   = Get-Date
        AutoManaged = $pf.AutoManaged
        Settings    = $pf.Settings | Select-Object Name, InitialSize, MaximumSize
    }

    $data | ConvertTo-Json -Depth 5 | Set-Content $BackupFile -Encoding UTF8

    Write-Color "Backup created successfully." Green
}

# =========================
# Apply PageFile
# =========================
function Apply-PageFile {

    param(
        [string]$Drive,
        [int]$InitialMB,
        [int]$MaximumMB
    )

    try {

        if (-not (Test-Path "$Drive\")) {
            Write-Color "Drive not found." Red
            return
        }

        if ($InitialMB -le 0 -or $MaximumMB -le 0) {
            Write-Color "Invalid size values." Red
            return
        }

        if ($MaximumMB -lt $InitialMB) {
            Write-Color "Maximum must be bigger than Initial." Red
            return
        }

        $cs = Get-CimInstance Win32_ComputerSystem

        Set-CimInstance -InputObject $cs -Property @{
            AutomaticManagedPagefile = $false
        } | Out-Null

        # Use registry directly — New-CimInstance for Win32_PageFileSetting
        # throws HRESULT 0x8004102b on Windows 10/11 (value out of range WMI bug).
        $regKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        $pagefilePath = "$Drive\pagefile.sys $InitialMB $MaximumMB"
        Set-ItemProperty -Path $regKey -Name "PagingFiles" -Value $pagefilePath

        Write-Host ""
        Write-Color "Virtual Memory Updated Successfully!" Green
        Write-Color "Drive   : $Drive" Cyan
        Write-Color "Initial : $InitialMB MB" Cyan
        Write-Color "Maximum : $MaximumMB MB" Cyan
        Write-Host ""
        Write-Color "Restart your PC to apply changes." Yellow
    }
    catch {
        Write-Color "ERROR: $($_.Exception.Message)" Red
    }
}

# =========================
# Restore Default
# =========================
function Restore-WindowsDefault {

    try {

        $cs = Get-CimInstance Win32_ComputerSystem

        Set-CimInstance -InputObject $cs -Property @{
            AutomaticManagedPagefile = $true
        } | Out-Null

        $old = Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue

        if ($old) {
            $old | Remove-CimInstance -ErrorAction SilentlyContinue
        }

        Write-Host ""
        Write-Color "Windows automatic management restored." Green
        Write-Color "Restart required." Yellow
    }
    catch {
        Write-Color "ERROR: $($_.Exception.Message)" Red
    }
}

# =========================
# Disable Virtual Memory
# =========================
function Disable-VirtualMemory {

    $confirm = Read-Host "Type YES to disable virtual memory"

    if ($confirm -ne "YES") {
        Write-Color "Cancelled." DarkGray
        return
    }

    try {

        $cs = Get-CimInstance Win32_ComputerSystem

        Set-CimInstance -InputObject $cs -Property @{
            AutomaticManagedPagefile = $false
        } | Out-Null

        $old = Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue

        if ($old) {
            $old | Remove-CimInstance -ErrorAction SilentlyContinue
        }

        Write-Host ""
        Write-Color "Virtual Memory Disabled." Green
        Write-Color "Restart required." Yellow
    }
    catch {
        Write-Color "ERROR: $($_.Exception.Message)" Red
    }
}

# =========================
# Restore Backup
# =========================
function Restore-Backup {

    if (-not (Test-Path $BackupFile)) {
        Write-Color "No backup found." Red
        return
    }

    try {

        $backup = Get-Content $BackupFile -Raw | ConvertFrom-Json

        $cs = Get-CimInstance Win32_ComputerSystem

        if ($backup.AutoManaged) {

            Set-CimInstance -InputObject $cs -Property @{
                AutomaticManagedPagefile = $true
            } | Out-Null

            Write-Color "Automatic mode restored." Green
        }
        else {

            Set-CimInstance -InputObject $cs -Property @{
                AutomaticManagedPagefile = $false
            } | Out-Null

            $old = Get-CimInstance Win32_PageFileSetting -ErrorAction SilentlyContinue

            if ($old) {
                $old | Remove-CimInstance -ErrorAction SilentlyContinue
                Start-Sleep 1
            }

            # Restore via registry (same fix as Apply-PageFile)
            $regKey2 = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
            $entries = @()
            foreach ($item in $backup.Settings) {
                $bDrive = $item.Name.Substring(0, 2)
                $entries += "$bDrive\pagefile.sys $($item.InitialSize) $($item.MaximumSize)"
            }
            Set-ItemProperty -Path $regKey2 -Name "PagingFiles" -Value $entries

            Write-Color "Backup restored successfully." Green
        }

        Write-Color "Restart required." Yellow
    }
    catch {
        Write-Color "ERROR: $($_.Exception.Message)" Red
    }
}

# =========================================================
# MAIN LOOP
# =========================================================

$Host.UI.RawUI.WindowTitle = "Advanced Virtual Memory Manager v3.0"

while ($true) {

    Show-Banner
    Show-CurrentStatus

    $diskList = Get-DiskList

    Write-Color "---- Drives --------------------------------------------" DarkCyan

    $diskList | Format-Table Drive, Type, FreeGB, TotalGB, Recommended -AutoSize

    Write-Host ""

    Write-Color "================ MENU ==================================" Cyan
    Write-Color "  [1] Automatic Optimization" White
    Write-Color "  [2] Custom Configuration" White
    Write-Color "  [3] Disable Virtual Memory" White
    Write-Color "  [4] Restore Windows Default" White
    Write-Color "  [5] Backup Current Settings" White
    Write-Color "  [6] Restore Backup" White
    Write-Color "  [7] Exit" White
    Write-Color "========================================================" Cyan

    Write-Host ""

    $choice = Read-Host "Select Option"

    switch ($choice) {

"1" {

            $sys = Get-SystemInfo

            # Priority:
            # 1- SSD drives first
            # 2- Must keep at least 15GB free
            # 3- Then choose highest free space

            $physicalDisks = Get-PhysicalDisk -ErrorAction SilentlyContinue

            $ssdLetters = @()

            foreach ($pd in $physicalDisks) {

                if ($pd.MediaType -eq 'SSD') {

                    $partitions = Get-Partition -DiskNumber $pd.DeviceId -ErrorAction SilentlyContinue

                    foreach ($part in $partitions) {

                        if ($part.DriveLetter) {
                            $ssdLetters += "$($part.DriveLetter):"
                        }
                    }
                }
            }

            $eligibleDisks = $diskList | Where-Object { $_.FreeGB -gt 15 }

            $best = $eligibleDisks |
                Sort-Object @(
                    @{ Expression = { if ($ssdLetters -contains $_.Drive) { 1 } else { 0 } }; Descending = $true },
                    @{ Expression = { $_.FreeGB }; Descending = $true }
                ) |
                Select-Object -First 1

            if (-not $best) {
                Write-Color "No suitable drive found." Red
                Pause-Script
                break
            }

            # -------------------------------------------------------
            # Balanced calculation based on system need, not disk size
            # -------------------------------------------------------
            # Ideal values based purely on RAM
            $idealInitial = [math]::Round($sys.TotalRAMGB * 1024 * 1.5)   # 1.5x RAM
            $idealMaximum = [math]::Round($sys.TotalRAMGB * 1024 * 3)     # 3x  RAM

            # Hard cap: never use more than 40% of total disk size
            $diskCapMB    = [math]::Round($best.TotalGB * 1024 * 0.15)

            # Always leave 15 GB free (SSD) or 25 GB free (HDD)
            $isSSD = $ssdLetters -contains $best.Drive
            $reservedMB   = if ($isSSD) { 20 * 1024 } else { 30 * 1024 }
            $availableMB  = [math]::Round($best.FreeGB * 1024) - $reservedMB

            # Effective ceiling = smallest of: ideal max, 15% of disk, available space
            $ceiling = [math]::Min($idealMaximum, [math]::Min($diskCapMB, $availableMB))

            $maximum = $ceiling
            $initial = $idealInitial

            # Clamp initial and maximum within safe range
            if ($maximum -lt 2048) {
                Write-Color "Not enough free space available for safe optimization." Red
                Pause-Script
                break
            }

            if ($initial -gt $maximum) {
                $initial = [math]::Round($maximum * 0.7)
            }

            if ($initial -ge $maximum) {
                $initial = [math]::Round($maximum * 0.5)
            }

            $initialGB = [math]::Round($initial / 1024, 1)
            $maximumGB = [math]::Round($maximum / 1024, 1)

            Write-Host ""
            Write-Color "---- Optimization Plan --------------------------------" DarkCyan
            Write-Color "  Drive      : $($best.Drive) [$($best.Type)]" White
            Write-Color "  RAM        : $($sys.TotalRAMGB) GB" White
            Write-Color "  Initial    : $initial MB  ($initialGB GB)" White
            Write-Color "  Maximum    : $maximum MB  ($maximumGB GB)" White
            Write-Color "  Free after : $([math]::Round($best.FreeGB - ($maximum / 1024), 1)) GB" White
            Write-Host ""

            $confirm = Read-Host "Apply? (Y/N)"
            if ($confirm -notmatch '^[Yy]$') {
                Write-Color "Cancelled." DarkGray
                Pause-Script
                break
            }

            Backup-Settings

            Apply-PageFile `
                -Drive $best.Drive `
                -InitialMB $initial `
                -MaximumMB $maximum

            Pause-Script
        }

        "2" {

            # Show numbered drive list
            Write-Color "---- Select Drive --------------------------------------" DarkCyan
            $i = 1
            foreach ($d in $diskList) {
                Write-Color "  [$i] $($d.Drive)  [$($d.Type)]   Free: $($d.FreeGB) GB / Total: $($d.TotalGB) GB" White
                $i++
            }
            Write-Host ""

            $driveChoice = Read-Host "Select Drive Number"

            if ($driveChoice -notmatch '^\d+$') {
                Write-Color "Invalid choice." Red
                Pause-Script
                break
            }

            $driveIndex = [int]$driveChoice - 1

            if ($driveIndex -lt 0 -or $driveIndex -ge $diskList.Count) {
                Write-Color "Number out of range." Red
                Pause-Script
                break
            }

            $drive = $diskList[$driveIndex].Drive

            Write-Color "Selected: $drive" Cyan
            Write-Host ""

            $initialStr = Read-Host "Initial Size (MB)"
            $maximumStr = Read-Host "Maximum Size (MB)"

            if ($initialStr -notmatch '^\d+$' -or $maximumStr -notmatch '^\d+$') {
                Write-Color "Invalid numbers." Red
                Pause-Script
                break
            }

            $initial = [int]$initialStr
            $maximum = [int]$maximumStr

            Backup-Settings

            Apply-PageFile `
                -Drive $drive `
                -InitialMB $initial `
                -MaximumMB $maximum

            Pause-Script
        }

        "3" {
            Backup-Settings
            Disable-VirtualMemory
            Pause-Script
        }

        "4" {
            Backup-Settings
            Restore-WindowsDefault
            Pause-Script
        }

        "5" {
            Backup-Settings
            Pause-Script
        }

        "6" {
            Restore-Backup
            Pause-Script
        }

        "7" {
            Stop-Process -Id $PID
        }

        default {
            Write-Color "Invalid option." Red
            Pause-Script
        }
    }
}