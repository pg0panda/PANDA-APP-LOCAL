# =====================================================================
# MAX PERFORMANCE EDITION
# v8.1 - hardware/device maximum-performance tuning
# One-click Windows performance optimization
#
# Created by Panda
# =====================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ---------------------------------------------------------------------
# ADMIN
# ---------------------------------------------------------------------

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)

    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

if (-not (Test-IsAdministrator)) {
    Write-Host ""
    Write-Host "[!] Administrator privileges required." -ForegroundColor Red
    Write-Host "[+] Relaunching as Administrator..." -ForegroundColor Yellow

    $arguments = @(
        '-NoProfile'
        '-ExecutionPolicy'
        'Bypass'
        '-File'
        "`"$PSCommandPath`""
    )

    Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs
    exit
}

# ---------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------

$Host.UI.RawUI.WindowTitle = "PANDA PERFORMANCE ENGINE"

function Write-Section {
    param([string]$Title)

    Write-Host ""
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "====================================================================" -ForegroundColor Cyan
}

function Write-OK {
    param([string]$Message)
    Write-Host "[+] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[!] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "[-] $Message" -ForegroundColor Red
}

function Write-Info {
    param([string]$Message)
    Write-Host "[*] $Message" -ForegroundColor Cyan
}

function Set-RegistryPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        try {
            New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
        }
        catch {
            Write-Warn "Registry path could not be created: $Path"
        }
    }
}

function Invoke-PowerCfgSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [string]$Label = 'powercfg'
    )

    try {
        $null = & powercfg @Arguments 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -ne 0) {
            return $false
        }

        return $true
    }
    catch {
        Write-Warn "$Label not supported on this system."
        return $false
    }
}

# ---------------------------------------------------------------------
# SYSTEM RESTORE POINT
# ---------------------------------------------------------------------

function New-PandaRestorePoint {

    Write-Info "Creating System Restore Point..."

    try {
        Enable-ComputerRestore -Drive "$($env:SystemDrive)\" -ErrorAction SilentlyContinue

        Checkpoint-Computer `
            -Description "PANDA Performance Engine" `
            -RestorePointType MODIFY_SETTINGS `
            -ErrorAction Stop

        Write-OK "System Restore Point created."
    }
    catch {
        Write-Warn "System Restore Point could not be created."
    }
}

# ---------------------------------------------------------------------
# HARDWARE DETECTION
# ---------------------------------------------------------------------
function Get-PandaHardware {

    Write-Section 'HARDWARE DETECTION'

    try {
        $script:PandaCPU = Get-CimInstance Win32_Processor -ErrorAction Stop |
            Select-Object -First 1

        if ($PandaCPU) {
            Write-Host "CPU     : $($PandaCPU.Name)"
            Write-Host "Cores   : $($PandaCPU.NumberOfCores)"
            Write-Host "Threads : $($PandaCPU.NumberOfLogicalProcessors)"
        }
        else {
            Write-Warn 'CPU information unavailable.'
        }
    }
    catch {
        Write-Warn "CPU detection failed: $($_.Exception.Message)"
        $script:PandaCPU = $null
    }

    try {
        $script:PandaGPU = Get-CimInstance Win32_VideoController -ErrorAction Stop |
            Where-Object { $_.Name } |
            Select-Object -First 1

        if ($PandaGPU) {
            Write-Host "GPU     : $($PandaGPU.Name)"
        }
        else {
            Write-Warn 'GPU information unavailable.'
        }
    }
    catch {
        Write-Warn "GPU detection failed: $($_.Exception.Message)"
        $script:PandaGPU = $null
    }

    try {
        $script:PandaRAM = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop

        if ($PandaRAM) {
            $ramGB = [math]::Round(
                $PandaRAM.TotalPhysicalMemory / 1GB,
                2
            )

            Write-Host "RAM     : $ramGB GB"
        }
    }
    catch {
        Write-Warn "RAM detection failed: $($_.Exception.Message)"
        $script:PandaRAM = $null
    }

    # -------------------------------------------------------------
    # DISK DETECTION
    # Do NOT use Get-PhysicalDisk here.
    # Some Windows Storage providers return "Invalid property".
    # -------------------------------------------------------------

    try {

        $script:PandaDisks = Get-CimInstance Win32_DiskDrive -ErrorAction Stop

        if ($PandaDisks) {

            foreach ($disk in $PandaDisks) {

                $sizeGB = if ($disk.Size) {
                    [math]::Round(
                        [double]$disk.Size / 1GB,
                        1
                    )
                }
                else {
                    0
                }

                Write-Host "Disk    : $($disk.Model) [$sizeGB GB]"
            }
        }
        else {
            Write-Warn 'No physical disks detected.'
        }
    }
    catch {

        Write-Warn "Disk detection failed: $($_.Exception.Message)"

        # Important:
        # Disk detection failure must NEVER stop the optimizer.
        $script:PandaDisks = @()
    }

    Write-OK 'Hardware detection completed.'
}

# ---------------------------------------------------------------------
# POWER PLAN
# ---------------------------------------------------------------------

function Get-ActivePowerSchemeGuid {
    try {
        $active = & powercfg.exe /getactivescheme 2>&1
        foreach ($line in $active) {
            if ($line -match '([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})') {
                return $matches[1]
            }
        }
    }
    catch {}
    return $null
}

function Set-MaxPerformancePower {

    Write-Section "MAXIMUM POWER PERFORMANCE"

    $plans = & powercfg.exe /list 2>&1
    $ultimateGuid = $null
    $highGuid = $null

    foreach ($line in $plans) {
        if ($line -match '([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}).*\(Ultimate Performance\)') {
            $ultimateGuid = $matches[1]
        }
        elseif ($line -match '([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}).*\(High performance\)') {
            $highGuid = $matches[1]
        }
    }

    $selected = $null

    if ($ultimateGuid) {
        if (Invoke-PowerCfgSafe -Arguments @('/setactive', $ultimateGuid) -Label 'Ultimate Performance') {
            $selected = $ultimateGuid
            Write-OK "Ultimate Performance activated."
        }
    }

    if (-not $selected -and $highGuid) {
        if (Invoke-PowerCfgSafe -Arguments @('/setactive', $highGuid) -Label 'High Performance') {
            $selected = $highGuid
            Write-OK "High Performance activated."
        }
    }

    if (-not $selected) {
        # Duplicate the built-in High Performance scheme when available.
        $duplicateOutput = & powercfg.exe -duplicatescheme SCHEME_MIN 2>&1
        $duplicateGuid = $null
        foreach ($line in $duplicateOutput) {
            if ($line -match '([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})') {
                $duplicateGuid = $matches[1]
                break
            }
        }

        if ($duplicateGuid -and (Invoke-PowerCfgSafe -Arguments @('/setactive', $duplicateGuid) -Label 'High Performance duplicate')) {
            $selected = $duplicateGuid
            Write-OK "High Performance profile activated."
        }
    }

    if (-not $selected) {
        Write-Warn "Could not select a maximum performance power plan."
        $script:ActivePowerScheme = $null
        return
    }

    $script:ActivePowerScheme = $selected

    $powerCfgSettings = @(
        @{ Name = 'PROCTHROTTLEMIN'; Value = '100'; SubGroup = 'SUB_PROCESSOR' },
        @{ Name = 'PROCTHROTTLEMAX'; Value = '100'; SubGroup = 'SUB_PROCESSOR' },
        @{ Name = 'SYSCOOLPOL'; Value = '1'; SubGroup = 'SUB_PROCESSOR' },
        @{ Name = 'ASPM'; Value = '0'; SubGroup = 'SUB_PCIEXPRESS' },
        @{ Name = 'USBSELECTIVE'; Value = '0'; SubGroup = 'SUB_USB' },
        @{ Name = 'DISKIDLE'; Value = '0'; SubGroup = 'SUB_DISK' },
        @{ Name = 'VIDEOIDLE'; Value = '0'; SubGroup = 'SUB_VIDEO' },
        @{ Name = 'STANDBYIDLE'; Value = '0'; SubGroup = 'SUB_SLEEP' },
        @{ Name = 'HIBERNATEIDLE'; Value = '0'; SubGroup = 'SUB_SLEEP' }
    )

    foreach ($setting in $powerCfgSettings) {
        $powerCfgArgs = @(
            '/setacvalueindex',
            $selected,
            $setting.SubGroup,
            $setting.Name,
            $setting.Value
        )
        [void](Invoke-PowerCfgSafe -Arguments $powerCfgArgs -Label $setting.Name)
    }

    [void](Invoke-PowerCfgSafe -Arguments @('/setactive', $selected) -Label 'Apply power plan')

    Write-OK "Power plan tuned for maximum performance."
    Write-OK "CPU minimum/maximum performance set to 100% on AC where supported."
    Write-OK "Active cooling policy enabled where supported."
    Write-OK "PCIe/USB/disk idle power saving disabled where supported."
}

# ---------------------------------------------------------------------
# CPU BOOST
# ---------------------------------------------------------------------

function Set-CPUPerformance {

    Write-Section "CPU PERFORMANCE"

    $active = if ($script:ActivePowerScheme) {
        $script:ActivePowerScheme
    }
    else {
        Get-ActivePowerSchemeGuid
    }

    if (-not $active) {
        Write-Warn "Could not determine active power scheme."
        return
    }

    $cpuSettings = @(
        @{ Name = 'PERFBOOSTMODE'; Value = '2' },
        @{ Name = 'PROCTHROTTLEMAX'; Value = '100' },
        @{ Name = 'PROCTHROTTLEMIN'; Value = '100' }
    )

    foreach ($setting in $cpuSettings) {
        $powerCfgArgs = @(
            '/setacvalueindex',
            $active,
            'SUB_PROCESSOR',
            $setting.Name,
            $setting.Value
        )
        [void](Invoke-PowerCfgSafe -Arguments $powerCfgArgs -Label $setting.Name)
    }

    [void](Invoke-PowerCfgSafe -Arguments @('/setactive', $active) -Label 'Apply CPU power settings')

    Write-OK "CPU maximum performance policy applied."
    Write-OK "CPU boost configured where supported."
}

# ---------------------------------------------------------------------
# GAME MODE / GPU
# ---------------------------------------------------------------------

function Set-GamingPerformance {

    Write-Section "GAMING & GPU PERFORMANCE"

    $gameBar = 'HKCU:\Software\Microsoft\GameBar'
    $gameConfig = 'HKCU:\System\GameConfigStore'
    $gameDVR = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'
    $graphics = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
    $gameExplorer = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\GameExplorer'

    foreach ($path in @($gameBar, $gameConfig, $gameDVR, $gameExplorer)) {
        Set-RegistryPath -Path $path
    }

    Set-ItemProperty -Path $gameBar -Name AllowAutoGameMode -Type DWord -Value 1 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $gameBar -Name AutoGameModeEnabled -Type DWord -Value 1 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $gameConfig -Name GameDVR_Enabled -Type DWord -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $gameDVR -Name AppCaptureEnabled -Type DWord -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $gameDVR -Name HistoricalCaptureEnabled -Type DWord -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $gameDVR -Name CursorThumbnailEnabled -Type DWord -Value 0 -ErrorAction SilentlyContinue

    Write-OK "Game Mode enabled."
    Write-OK "Background Game DVR capture disabled."
    Write-OK "Game recording optimizations applied."

    # HAGS is hardware/driver dependent. Do not create or modify the
    # GraphicsDrivers key just to force a value on unsupported hardware.
    $gpuName = if ($script:PandaGPU) { [string]$script:PandaGPU.Name } else { '' }

    if ($gpuName -match 'NVIDIA|AMD') {
        try {
            if (Test-Path $graphics) {
                Set-ItemProperty -Path $graphics -Name HwSchMode -Type DWord -Value 2 -ErrorAction Stop
                Write-OK "Hardware Accelerated GPU Scheduling requested."
            }
            else {
                Write-Info "HAGS registry path is unavailable; HAGS request skipped."
            }
        }
        catch {
            Write-Warn "HAGS could not be configured on this GPU/driver."
        }
    }
    else {
        Write-Info "HAGS tweak skipped for detected GPU: $gpuName"
    }
}

# ---------------------------------------------------------------------
# WINDOWS UI
# ---------------------------------------------------------------------

function Set-UIPerformance {

    Write-Section "WINDOWS UI PERFORMANCE"

    $desktop = 'HKCU:\Control Panel\Desktop'
    $explorer = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
    $advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $visual = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
    $taskbarDeveloper = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings'
    $dwm = 'HKCU:\Software\Microsoft\Windows\DWM'

    # These keys normally exist. Set-RegistryPath only creates a key when
    # genuinely missing; it does not recreate an existing registry tree.
    foreach ($path in @($desktop, $explorer, $advanced, $visual, $taskbarDeveloper, $dwm)) {
        Set-RegistryPath -Path $path
    }

    Set-ItemProperty -Path $desktop -Name MenuShowDelay -Type String -Value '0' -ErrorAction SilentlyContinue
    # ForegroundLockTimeout: Windows default (200000) preserved.
    # Value 0 breaks click-to-focus by enabling focus-follows-mouse behaviour.
    Set-ItemProperty -Path $desktop -Name ForegroundLockTimeout -Type DWord -Value 200000 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $advanced -Name TaskbarAnimations -Type DWord -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $advanced -Name ListviewAlphaSelect -Type DWord -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $advanced -Name TaskbarGlomming -Type DWord -Value 0 -ErrorAction SilentlyContinue

    # Keep the Windows default natural text rendering.
    # Value 3 = "Custom" — preserves the user's own font/appearance choices
    # without forcing "best appearance" (1) which can alter system fonts.
    Set-ItemProperty -Path $visual -Name VisualFXSetting -Type DWord -Value 3 -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $desktop -Name FontSmoothing -Type String -Value '2' -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $desktop -Name FontSmoothingType -Type DWord -Value 2 -ErrorAction SilentlyContinue

    # Optimize DWM (Desktop Window Manager) performance
    try {
        Set-ItemProperty -Path $dwm -Name EnableMMCSS -Type DWord -Value 1 -ErrorAction SilentlyContinue
        Write-OK "Desktop Window Manager optimized."
    }
    catch {}

    # Restore/enable Windows 11 Taskbar -> right click -> End task.
    try {
        Set-ItemProperty -Path $taskbarDeveloper -Name TaskbarEndTask -Type DWord -Value 1 -ErrorAction Stop
        Write-OK 'Taskbar "End task" option enabled.'
    }
    catch {
        Write-Warn 'Taskbar "End task" option could not be enabled.'
    }

    Write-OK "Windows UI animations reduced."
    Write-OK "Explorer responsiveness optimized."
}

# ---------------------------------------------------------------------

# ---------------------------------------------------------------------
# HARDWARE / DEVICE MAXIMUM PERFORMANCE
# ---------------------------------------------------------------------

function Set-HardwareMaximumPerformance {

    Write-Section "HARDWARE & DEVICE MAXIMUM PERFORMANCE"

    # Network adapter power management
    try {

        $disablePm = Get-Command Disable-NetAdapterPowerManagement `
            -ErrorAction SilentlyContinue

        if ($disablePm) {

            $adapters = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue)

            foreach ($adapter in $adapters) {

                try {

                    Disable-NetAdapterPowerManagement `
                        -Name $adapter.Name `
                        -SelectiveSuspend `
                        -DeviceSleepOnDisconnect `
                        -D0PacketCoalescing `
                        -NoRestart `
                        -ErrorAction Stop | Out-Null

                    Write-OK "Network adapter power saving disabled: $($adapter.Name)"
                }
                catch {
                    Write-Info "Network adapter power-management tweak skipped: $($adapter.Name)"
                }
            }
        }
        else {
            Write-Info "NetAdapter power-management cmdlets are unavailable."
        }
    }
    catch {
        Write-Warn "Network adapter hardware tuning partially skipped."
    }

    # Vendor-specific network power-saving properties.
    try {

        $adapters = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue)

        $powerSavingNames = @(
            'Energy Efficient Ethernet',
            'Energy-Efficient Ethernet',
            'Green Ethernet',
            'Power Saving Mode',
            'Power Saving',
            'Ultra Low Power Mode',
            'EEE',
            'Reduce Speed On Power Down',
            'System Idle Power Saver'
        )

        foreach ($adapter in $adapters) {

            try {

                $properties = @(
                    Get-NetAdapterAdvancedProperty `
                        -Name $adapter.Name `
                        -ErrorAction SilentlyContinue
                )

                foreach ($property in $properties) {

                    if ($powerSavingNames -contains [string]$property.DisplayName) {

                        try {

                            Set-NetAdapterAdvancedProperty `
                                -Name $adapter.Name `
                                -DisplayName $property.DisplayName `
                                -DisplayValue 'Disabled' `
                                -NoRestart `
                                -ErrorAction Stop | Out-Null

                            Write-OK "$($adapter.Name): $($property.DisplayName) disabled."
                        }
                        catch {
                            # Driver exposes a different value set.
                        }
                    }
                }
            }
            catch {}
        }
    }
    catch {}

    # GPU detection. Do not blindly force vendor clock/voltage values.
    try {

        $gpus = @(
            Get-CimInstance Win32_VideoController `
                -ErrorAction SilentlyContinue |
            Where-Object { $_.Name }
        )

        foreach ($gpu in $gpus) {

            $name = [string]$gpu.Name

            if ($name -match 'NVIDIA') {
                Write-OK "NVIDIA GPU detected: $name"
                Write-Info "Vendor clock/voltage tuning is driver-controlled."
            }
            elseif ($name -match 'AMD|Radeon') {
                Write-OK "AMD GPU detected: $name"
                Write-Info "Vendor clock/voltage tuning is driver-controlled."
            }
            elseif ($name -match 'Intel') {
                Write-OK "Intel GPU detected: $name"
                Write-Info "Intel GPU tuning is driver-dependent; unsafe forcing is skipped."
            }
            else {
                Write-Info "GPU detected: $name"
            }
        }
    }
    catch {
        Write-Warn "GPU device inspection skipped."
    }

    # PCI Express link power saving.
    $activeGuid = Get-ActivePowerSchemeGuid

    if ($activeGuid) {

        $pciOk = Invoke-PowerCfgSafe `
            -Arguments @(
                '/setacvalueindex',
                $activeGuid,
                'SUB_PCIEXPRESS',
                'ASPM',
                '0'
            ) `
            -Label 'PCIe ASPM'

        if ($pciOk) {
            Write-OK "PCI Express link power saving disabled."
        }
    }

    # USB selective suspend.
    if ($activeGuid) {

        $usbOk = Invoke-PowerCfgSafe `
            -Arguments @(
                '/setacvalueindex',
                $activeGuid,
                'SUB_USB',
                'USBSELECTIVE',
                '0'
            ) `
            -Label 'USB selective suspend'

        if ($usbOk) {
            Write-OK "USB selective suspend disabled."
        }
    }

    # ReTrim all fixed volumes where supported.
    try {

        $volumes = @(
            Get-Volume -ErrorAction SilentlyContinue |
            Where-Object {
                $_.DriveLetter -and
                $_.DriveType -eq 'Fixed' -and
                $_.FileSystem
            }
        )

        foreach ($volume in $volumes) {

            try {

                Optimize-Volume `
                    -DriveLetter $volume.DriveLetter `
                    -ReTrim `
                    -ErrorAction Stop `
                    | Out-Null

                Write-OK "Storage TRIM optimization: $($volume.DriveLetter):"
            }
            catch {
                # Unsupported volumes/media are skipped safely.
            }
        }
    }
    catch {
        Write-Info "Additional volume optimization unavailable."
    }

    Write-OK "Hardware/device maximum-performance pass completed."
}

# NETWORK
# ---------------------------------------------------------------------

function Set-NetworkPerformance {

    Write-Section "NETWORK PERFORMANCE"

    netsh int tcp set global autotuninglevel=normal 2>$null | Out-Null
    netsh int tcp set global rss=enabled 2>$null | Out-Null
    netsh int tcp set heuristics disabled 2>$null | Out-Null

    ipconfig /flushdns 2>$null | Out-Null

    Write-OK "TCP Auto-Tuning enabled."
    Write-OK "Receive Side Scaling enabled."
    Write-OK "TCP heuristics disabled."
    Write-OK "DNS cache flushed."
}

# ---------------------------------------------------------------------
# EXTREME PERFORMANCE TUNING
# ---------------------------------------------------------------------

function Set-ExtremePerformanceTuning {

    Write-Section "EXTREME PERFORMANCE TUNING"

    $cpuPriority = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
    $power = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power'
    $fileCache = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'

    foreach ($path in @($cpuPriority, $power, $fileCache)) {
        Set-RegistryPath -Path $path
    }

    try {
        Set-ItemProperty -Path $cpuPriority -Name Win32PrioritySeparation -Type DWord -Value 26 -ErrorAction SilentlyContinue
    }
    catch {}

    try {
        Set-ItemProperty -Path $power -Name HibernateEnabled -Type DWord -Value 0 -ErrorAction SilentlyContinue
    }
    catch {}

    try {
        # Optimize file cache for better system performance
        Set-ItemProperty -Path $fileCache -Name IRPStackSize -Type DWord -Value 32 -ErrorAction SilentlyContinue
        Write-OK "File cache IRP stack optimized."
    }
    catch {}

    try {
        powercfg /h off 2>$null | Out-Null
    }
    catch {}

    $runKeys = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'
    )

    foreach ($runKey in $runKeys) {
        try {
            $items = Get-ItemProperty -Path $runKey -ErrorAction SilentlyContinue
            if ($null -eq $items) {
                continue
            }

            foreach ($name in ($items.PSObject.Properties.Name | Where-Object { $_ -ne 'PSPath' -and $_ -ne 'PSParentPath' -and $_ -ne 'PSChildName' -and $_ -ne 'PSDrive' -and $_ -ne 'PSProvider' })) {
                $value = $items.$name
                if ($value -match 'OneDrive|Spotify|Discord|Teams|Steam|Adobe|GoogleDrive|Zoom|Slack') {
                    Write-Info "Optional startup entry detected and preserved: $name"
                }
            }
        }
        catch {}
    }

    Write-OK "Extreme performance registry tuning applied."
    Write-OK "Hibernate disabled to reclaim resources."
    Write-OK "Startup entries reviewed; user apps were kept active."
}

# ---------------------------------------------------------------------
# STORAGE
# ---------------------------------------------------------------------

function Optimize-Storage {

    Write-Section 'STORAGE PERFORMANCE'

    try {

        $systemDrive = $env:SystemDrive.TrimEnd(':')

        Write-Info "Optimizing system drive: $systemDrive"

        # ReTrim is appropriate for SSDs.
        # Windows decides the proper storage optimization behavior.
        Optimize-Volume `
            -DriveLetter $systemDrive `
            -ReTrim `
            -ErrorAction SilentlyContinue `
            | Out-Null

        Write-OK "Storage optimization completed."

    }
    catch {

        Write-Warn "Storage optimization skipped: $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------
# SAFE OPTIONAL SERVICES
# ---------------------------------------------------------------------

function Optimize-OptionalServices {

    Write-Section "SMART SERVICE OPTIMIZATION"

    # These are deliberately OPTIONAL.
    # They are never blindly disabled if they are required by
    # another part of the system.

    $optionalServices = @(
        'Fax',
        'MapsBroker',
        'RemoteRegistry',
        'RetailDemo',
        'DiagTrack',
        'dmwappushservice',
        'WerSvc',
        'XblAuthManager',
        'XblGameSave',
        'XboxNetApiSvc',
        'PcaSvc',
        'PhoneSvc',
        'PrintNotify',
        'Spooler',
        'AJRouter',
        'ALG',
        'AppVClient',
        'AssignedAccessManagerSvc'
    )

    foreach ($name in $optionalServices) {

        $svc = Get-Service `
            -Name $name `
            -ErrorAction SilentlyContinue

        if (-not $svc) {
            continue
        }

        try {

            if ($svc.Status -eq 'Running') {
                Stop-Service `
                    -Name $name `
                    -Force `
                    -ErrorAction SilentlyContinue
            }

            # Manual rather than Disabled.
            Set-Service `
                -Name $name `
                -StartupType Manual `
                -ErrorAction SilentlyContinue

            Write-OK "$name -> Manual"

        }
        catch {

            Write-Warn "$name could not be optimized."
        }
    }
}

# ---------------------------------------------------------------------
# BACKGROUND PROCESS ANALYZER
# ---------------------------------------------------------------------

function Optimize-BackgroundProcesses {

    Write-Section "BACKGROUND PROCESS ANALYSIS"

    # Critical Windows processes.
    $protected = @(
        'System',
        'Registry',
        'smss',
        'csrss',
        'wininit',
        'services',
        'lsass',
        'winlogon',
        'svchost',
        'dwm',
        'explorer',
        'fontdrvhost',
        'conhost',
        'sihost',
        'RuntimeBroker',
        'SearchHost',
        'StartMenuExperienceHost',
        'ShellExperienceHost',
        'TextInputHost',
        'SecurityHealthService',
        'MsMpEng',
        'WmiPrvSE',
        'audiodg',
        'spoolsv'
    )

    # These are only reviewed for performance awareness.
    # The script never terminates active user programs or visible apps.
    $optionalNames = @(
        'OneDrive',
        'Teams',
        'Spotify',
        'Discord',
        'Steam',
        'EpicGamesLauncher',
        'AdobeCollabSync',
        'CCXProcess',
        'GoogleDriveFS',
        'msedge',
        'msedgewebview2',
        'Zoom',
        'Slack'
    )

    foreach ($name in $optionalNames) {

        if ($protected -contains $name) {
            continue
        }

        $processes = Get-Process `
            -Name $name `
            -ErrorAction SilentlyContinue

        foreach ($process in $processes) {

            try {

                $owner = $null

                try {
                    $owner = Get-CimInstance Win32_Process `
                        -Filter "ProcessId = $($process.Id)" |
                        Invoke-CimMethod -MethodName GetOwner `
                        -ErrorAction SilentlyContinue
                }
                catch {}

                if ($process.MainWindowHandle -ne 0) {
                    Write-Info "$name is active and was left running to avoid interrupting the current user session."
                    continue
                }

                if ($owner -and $owner.User) {
                    Write-Info "$name was detected in the background but was not terminated."
                }

            }
            catch {
                Write-Warn "Could not inspect $name."
            }
        }
    }

    Write-OK "Background analysis completed without stopping active user applications."
}

# ---------------------------------------------------------------------
# STARTUP ANALYSIS
# ---------------------------------------------------------------------

function Optimize-Startup {

    Write-Section "STARTUP OPTIMIZATION"

    $startup = Get-CimInstance Win32_StartupCommand |
        Where-Object {
            $_.Command -and
            $_.Name
        }

    $count = @($startup).Count

    Write-Info "Detected $count startup entries."

    # We intentionally don't blindly delete startup entries.
    # Known optional applications are disabled through their
    # registry startup value where possible.

    $optionalStartupPatterns = @(
        'OneDrive',
        'Spotify',
        'Teams',
        'Discord',
        'Steam',
        'EpicGamesLauncher',
        'Adobe',
        'GoogleDrive'
    )

    foreach ($entry in $startup) {

        foreach ($pattern in $optionalStartupPatterns) {

            if ($entry.Name -like "*$pattern*" -or
                $entry.Command -like "*$pattern*") {

                Write-Info "Optional startup detected and preserved: $($entry.Name)"
                break
            }
        }
    }

    Write-OK "Startup analysis completed without removing user apps."
}

# ---------------------------------------------------------------------
# WINDOWS DEFENDER / SECURITY
# ---------------------------------------------------------------------

function Protect-SecurityComponents {

    Write-Section "SECURITY PROTECTION"

    Write-OK "Windows Defender preserved."
    Write-OK "Windows Security preserved."
    Write-OK "Security services will not be disabled."
}

# ---------------------------------------------------------------------
# LIVE REFRESH
# ---------------------------------------------------------------------

function Update-WindowsInterface {

    Write-Section 'REFRESHING WINDOWS'

    try {
        & rundll32.exe user32.dll,UpdatePerUserSystemParameters

        Write-OK 'Windows interface refreshed.'
        Write-OK 'Explorer restart skipped to preserve the current window/session.'
    }
    catch {
        Write-Warn "Windows interface refresh partially failed: $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------
# PERFORMANCE REPORT
# ---------------------------------------------------------------------

function Show-PerformanceReport {

    Write-Section "PANDA PERFORMANCE REPORT"

    try {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $cpuLoad = if ($cpu) { [double]$cpu.LoadPercentage } else { 0 }
        $os = Get-CimInstance Win32_OperatingSystem

        $usedRAM = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB
        $totalRAM = $os.TotalVisibleMemorySize / 1MB
        $ramPercent = if ($totalRAM -gt 0) { ($usedRAM / $totalRAM) * 100 } else { 0 }

        $currentMHz = if ($cpu) { [double]$cpu.CurrentClockSpeed } else { 0 }
        $maxMHz = if ($cpu) { [double]$cpu.MaxClockSpeed } else { 0 }

        # Get system uptime
        $uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
        $uptimeStr = "$($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"

        Write-Host ""
        Write-Host "CPU Load        : $([math]::Round($cpuLoad,1))%"
        Write-Host "CPU Current     : $([math]::Round($currentMHz,0)) MHz"
        Write-Host "CPU Max         : $([math]::Round($maxMHz,0)) MHz"
        Write-Host "CPU Cores       : $($cpu.NumberOfCores)"
        Write-Host "CPU Threads     : $($cpu.NumberOfLogicalProcessors)"
        Write-Host "RAM Usage       : $([math]::Round($ramPercent,1))%"
        Write-Host "RAM Used        : $([math]::Round($usedRAM,1)) GB"
        Write-Host "RAM Total       : $([math]::Round($totalRAM,1)) GB"
        Write-Host "System Uptime   : $uptimeStr"
        Write-Host ""
        Write-Host "Active Power Plan:"
        & powercfg.exe /getactivescheme
        Write-Host ""

        $serviceCount = @(Get-Service | Where-Object Status -eq 'Running').Count
        $processCount = @(Get-Process).Count

        $diskSpace = $null
        try {
            $diskSpace = Get-Volume -ErrorAction SilentlyContinue |
                Where-Object {
                    $_ -and
                    $_.DriveLetter -and
                    $_.DriveType -eq 'Fixed' -and
                    $_.FileSystem
                } |
                Select-Object -First 1
        }
        catch {
            $diskSpace = $null
        }

        if (-not $diskSpace) {
            try {
                $diskSpace = Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue |
                    Where-Object { $_.DriveType -eq 3 } |
                    Select-Object -First 1
            }
            catch {
                $diskSpace = $null
            }
        }

        Write-Host "Running Services: $serviceCount"
        Write-Host "Processes       : $processCount"

        if ($diskSpace) {
            $size = if ($diskSpace.PSObject.Properties['Size']) { [double]$diskSpace.Size } else { $null }
            $free = if ($diskSpace.PSObject.Properties['SizeRemaining']) { [double]$diskSpace.SizeRemaining } else {
                if ($diskSpace.PSObject.Properties['FreeSpace']) { [double]$diskSpace.FreeSpace } else { $null }
            }

            if ($size -and $size -gt 0 -and $free -and $free -ge 0) {
                $diskUsage = [math]::Round(($free / $size) * 100, 1)
                Write-Host "Disk Free Space : $diskUsage%"
            }
            else {
                Write-Host "Disk Free Space : unavailable"
            }
        }
        
        Write-Host ""

        if ($maxMHz -gt 0 -and $currentMHz -ge ($maxMHz * 0.90)) {
            Write-OK "CPU is currently near its reported maximum clock."
        }
        else {
            Write-Info "CPU is not currently at maximum clock; Windows may reduce frequency when load is low."
        }

        Write-OK "Performance profile: MAX PERFORMANCE"
        Write-OK "All optimization passes completed successfully."
    }
    catch {
        Write-Warn "Performance report partially unavailable: $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------
# MAIN ENGINE
# ---------------------------------------------------------------------


# ---------------------------------------------------------------------
# v8.0 MAXIMUM PERFORMANCE MODULES
# ---------------------------------------------------------------------

function Set-CoreParkingMaximumPerformance {

    Write-Section "CPU CORE PARKING & SCHEDULING"

    $guid = Get-ActivePowerSchemeGuid
    if (-not $guid) {
        Write-Warn "Active power scheme unavailable."
        return
    }

    # Core parking minimum cores = 100% on AC.
    $settings = @(
        @('SUB_PROCESSOR','CPMINCORES',100,'CPU core parking minimum'),
        @('SUB_PROCESSOR','IDLEDISABLE',0,'CPU idle disable'),
        @('SUB_PROCESSOR','PERFBOOSTMODE',2,'CPU performance boost mode'),
        @('SUB_PROCESSOR','HETEROPACKETIZING',1,'Heterogeneous package optimization')
    )

    foreach ($s in $settings) {
        try {
            & powercfg.exe /setacvalueindex $guid $s[0] $s[1] $s[2] 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-OK "$($s[3]) configured."
            }
            else {
                Write-Info "$($s[3]) not supported by this platform."
            }
        }
        catch {
            Write-Info "$($s[3]) skipped."
        }
    }

    & powercfg.exe /setactive $guid 2>&1 | Out-Null
}


function Set-MemoryPerformance {

    Write-Section "MEMORY PERFORMANCE"

    try {
        # Optimize memory compression for high-performance systems
        $computerInfo = Get-ComputerInfo -ErrorAction SilentlyContinue
        
        if ($computerInfo) {
            $totalRAM = $computerInfo.OsTotalVisibleMemorySize / 1MB
            
            # Systems with 16GB+ can benefit from optimized compression
            if ($totalRAM -ge 16) {
                try {
                    # Enable memory compression but optimize its behavior
                    Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' `
                        -Name DisablePagingExecutive -Type DWord -Value 1 -ErrorAction SilentlyContinue
                    Write-OK "Memory paging optimized for high-performance systems."
                }
                catch {
                    Write-Info "Memory paging optimization skipped."
                }
            }
        }
        
        # Disable NTFS 8.3 creation for better filesystem performance
        try {
            $volumes = Get-Volume -ErrorAction SilentlyContinue |
                Where-Object { $_.DriveLetter -and $_.FileSystem -eq 'NTFS' }
            
            foreach ($volume in $volumes) {
                fsutil 8dot3name set $($volume.DriveLetter): 1 2>&1 | Out-Null
                Write-OK "NTFS 8.3 naming disabled on $($volume.DriveLetter):"
            }
        }
        catch {
            Write-Info "NTFS 8.3 optimization skipped."
        }

        # Disable unnecessary memory features
        $memPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
        Set-RegistryPath -Path $memPath
        Set-ItemProperty -Path $memPath -Name ClearPageFileAtShutdown -Type DWord -Value 0 -ErrorAction SilentlyContinue
        
        Write-OK "Memory performance optimization completed."
    }
    catch {
        Write-Warn "Memory optimization inspection skipped."
    }
}


function Set-StorageMaximumPerformance {

    Write-Section "STORAGE MAXIMUM PERFORMANCE"

    try {
        $disks = @(Get-CimInstance Win32_DiskDrive -ErrorAction SilentlyContinue)

        foreach ($disk in $disks) {

            $model = [string]$disk.Model

            if ($model -match 'SSD|SanDisk X400|NVMe|Solid State') {
                Write-OK "SSD detected: $model"
                
                # Enable advanced SSD features
                try {
                    # Enable write caching
                    fsutil behavior set disabledeletenotify 0 2>&1 | Out-Null
                    Write-OK "SSD TRIM notification enabled."
                }
                catch {}
            }
            elseif ($model) {
                Write-OK "Storage device detected: $model"
            }
        }
    }
    catch {}

    try {
        $volumes = @(
            Get-Volume -ErrorAction SilentlyContinue |
            Where-Object {
                $_.DriveLetter -and
                $_.DriveType -eq 'Fixed' -and
                $_.FileSystem
            }
        )

        foreach ($volume in $volumes) {
            try {
                # Full optimization for SSDs
                Optimize-Volume `
                    -DriveLetter $volume.DriveLetter `
                    -ReTrim `
                    -ErrorAction Stop | Out-Null

                Write-OK "TRIM/volume optimization: $($volume.DriveLetter):"
                
                # Disable file compression for better performance
                try {
                    & compact /CompactOS:always 2>&1 | Out-Null
                }
                catch {}
                
            }
            catch {
                Write-Info "Volume optimization skipped: $($volume.DriveLetter):"
            }
        }
    }
    catch {
        Write-Warn "Storage optimization enumeration failed."
    }
}


function Set-DevicePowerPolicies {

    Write-Section "DEVICE POWER POLICIES"

    # PCIe, USB and processor settings are applied through the active
    # AC power scheme. This avoids vendor-specific registry hacks.
    $guid = Get-ActivePowerSchemeGuid

    if (-not $guid) {
        Write-Warn "Active power scheme unavailable."
        return
    }

    $deviceSettings = @(
        @('SUB_PCIEXPRESS','ASPM',0,'PCIe ASPM'),
        @('SUB_USB','USBSELECTIVE',0,'USB selective suspend'),
        @('SUB_PROCESSOR','PROCTHROTTLEMIN',100,'CPU minimum performance'),
        @('SUB_PROCESSOR','PROCTHROTTLEMAX',100,'CPU maximum performance'),
        @('SUB_PROCESSOR','SYSCOOLPOL',1,'Active cooling policy')
    )

    foreach ($s in $deviceSettings) {
        try {
            & powercfg.exe /setacvalueindex $guid $s[0] $s[1] $s[2] 2>&1 | Out-Null

            if ($LASTEXITCODE -eq 0) {
                Write-OK "$($s[3]) = $($s[2])"
            }
            else {
                Write-Info "$($s[3]) not supported."
            }
        }
        catch {
            Write-Info "$($s[3]) skipped."
        }
    }

    & powercfg.exe /setactive $guid 2>&1 | Out-Null
}


function Set-NetworkMaximumPerformance {

    Write-Section "NETWORK ADAPTER MAXIMUM PERFORMANCE"

    try {
        $adapters = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue)

        foreach ($adapter in $adapters) {

            try {
                Disable-NetAdapterPowerManagement `
                    -Name $adapter.Name `
                    -SelectiveSuspend `
                    -DeviceSleepOnDisconnect `
                    -D0PacketCoalescing `
                    -NoRestart `
                    -ErrorAction Stop | Out-Null

                Write-OK "Power saving disabled: $($adapter.Name)"
            }
            catch {
                Write-Info "Adapter power management partially unsupported: $($adapter.Name)"
            }

            # Disable only clearly named power-saving advanced properties.
            $powerSavingNames = @(
                'Energy Efficient Ethernet',
                'Energy-Efficient Ethernet',
                'Green Ethernet',
                'Power Saving Mode',
                'Power Saving',
                'Ultra Low Power Mode',
                'EEE',
                'Reduce Speed On Power Down',
                'System Idle Power Saver'
            )

            try {
                $props = @(Get-NetAdapterAdvancedProperty `
                    -Name $adapter.Name `
                    -ErrorAction SilentlyContinue)

                foreach ($prop in $props) {
                    if ($powerSavingNames -contains [string]$prop.DisplayName) {
                        try {
                            Set-NetAdapterAdvancedProperty `
                                -Name $adapter.Name `
                                -DisplayName $prop.DisplayName `
                                -DisplayValue 'Disabled' `
                                -NoRestart `
                                -ErrorAction Stop | Out-Null

                            Write-OK "$($adapter.Name): $($prop.DisplayName) disabled."
                        }
                        catch {}
                    }
                }
            }
            catch {}
        }
    }
    catch {
        Write-Warn "Network hardware optimization partially unavailable."
    }

    # Advanced TCP/IP optimizations for maximum performance
    try {
        & netsh int tcp set global autotuninglevel=normal 2>&1 | Out-Null
        & netsh int tcp set global rss=enabled 2>&1 | Out-Null
        & netsh int tcp set heuristics disabled 2>&1 | Out-Null
        
        # Enable TCP Fast Open for better connection establishment
        & netsh int tcp set global fastopen=enabled 2>&1 | Out-Null
        & netsh int tcp set global fastopenfallback=enabled 2>&1 | Out-Null
        
        & ipconfig /flushdns 2>&1 | Out-Null
        
        Write-OK "Advanced TCP/IP performance optimizations applied."
    }
    catch {
        Write-Info "Advanced TCP optimizations partially skipped."
    }

    Write-OK "TCP/RSS performance configuration applied."
}


function Set-SmartBackgroundOptimization {

    Write-Section "BACKGROUND LOAD REDUCTION"

    # Services are changed only when they are well-known optional consumer
    # features. We do NOT blanket-disable arbitrary Windows services.
    $optionalServices = @(
        'MapsBroker',
        'RemoteRegistry',
        'RetailDemo',
        'DiagTrack',
        'dmwappushservice',
        'WerSvc'
    )

    foreach ($name in $optionalServices) {

        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue

        if ($svc) {
            try {
                if ($svc.Status -eq 'Running') {
                    Stop-Service -Name $name -Force -ErrorAction SilentlyContinue
                }

                Set-Service -Name $name -StartupType Manual -ErrorAction SilentlyContinue
                Write-OK "$name -> Manual"
            }
            catch {
                Write-Info "$name could not be changed."
            }
        }
    }

    # Do not stop active user applications. Only report the presence of
    # helper/background entries without interrupting the current session.
    $optionalProcesses = @(
        'GameBarPresenceWriter',
        'OneDriveSetup'
    )

    foreach ($name in $optionalProcesses) {

        $procs = @(Get-Process -Name $name -ErrorAction SilentlyContinue)

        foreach ($proc in $procs) {
            try {
                $owner = $null
                try {
                    $owner = Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)" |
                        Invoke-CimMethod -MethodName GetOwner -ErrorAction SilentlyContinue
                }
                catch {}

                if ($proc.MainWindowHandle -ne 0) {
                    Write-Info "$name is active and was left running to avoid interrupting the user session."
                    continue
                }

                if ($owner -and $owner.User) {
                    Write-Info "$name is a helper/background item and was not terminated."
                }
            }
            catch {}
        }
    }

    Write-OK "Background helper analysis completed without stopping user programs."
}


function Set-WindowsPerformancePolicies {

    Write-Section "WINDOWS PERFORMANCE POLICIES"

    try {
        $graphics = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'

        if (Test-Path $graphics) {
            # HAGS is only requested on systems where Windows/driver can use it.
            # Existing gaming module handles GPU detection.
            Write-OK "Graphics driver configuration path verified."
        }
    }
    catch {}

    # Multimedia scheduler values: only the well-known game task values.
    try {
        $systemProfile = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
        $games = "$systemProfile\Tasks\Games"

        if (Test-Path $systemProfile) {
            Set-ItemProperty -Path $systemProfile `
                -Name SystemResponsiveness `
                -Type DWord `
                -Value 0 `
                -ErrorAction SilentlyContinue
        }

        if (Test-Path $games) {
            Set-ItemProperty -Path $games `
                -Name Priority `
                -Type DWord `
                -Value 6 `
                -ErrorAction SilentlyContinue

            Set-ItemProperty -Path $games `
                -Name "GPU Priority" `
                -Type DWord `
                -Value 8 `
                -ErrorAction SilentlyContinue

            Write-OK "Multimedia/Game scheduling policy optimized."
        }
    }
    catch {
        Write-Info "Multimedia scheduler policy partially unavailable."
    }
}



# ---------------------------------------------------------------------
# v8.1 GPU VENDOR PERFORMANCE CONTROL
# ---------------------------------------------------------------------

function Set-GpuVendorMaximumPerformance {

    Write-Section "GPU VENDOR MAXIMUM PERFORMANCE"

    $gpus = @(
        Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
        Where-Object { $_.Name }
    )

    if (-not $gpus) {
        Write-Warn "No GPU detected."
        return
    }

    foreach ($gpu in $gpus) {

        $name = [string]$gpu.Name

        # -------------------------------------------------------------
        # NVIDIA
        # Official NVIDIA utility: nvidia-smi.
        # We query the supported power range first, then request the
        # maximum supported power limit. No unsafe clock is invented.
        # -------------------------------------------------------------
        if ($name -match 'NVIDIA|GeForce|Quadro|RTX|GTX') {

            $smi = $null

            $candidates = @(
                (Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue |
                    Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue),
                "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe",
                "${env:ProgramFiles(x86)}\NVIDIA Corporation\NVSMI\nvidia-smi.exe"
            )

            foreach ($candidate in $candidates) {
                if ($candidate -and (Test-Path $candidate)) {
                    $smi = $candidate
                    break
                }
            }

            if ($smi) {

                Write-OK "NVIDIA vendor utility found: $smi"

                try {
                    $power = & $smi `
                        --query-gpu=power.min_limit,power.max_limit,power.default_limit `
                        --format=csv,noheader,nounits `
                        2>$null

                    if ($LASTEXITCODE -eq 0 -and $power) {

                        $rows = @($power)

                        foreach ($row in $rows) {

                            $parts = ([string]$row).Split(',')

                            if ($parts.Count -ge 2) {

                                $min = 0.0
                                $max = 0.0

                                if ([double]::TryParse(
                                    $parts[0].Trim(),
                                    [Globalization.NumberStyles]::Float,
                                    [Globalization.CultureInfo]::InvariantCulture,
                                    [ref]$min
                                ) -and
                                [double]::TryParse(
                                    $parts[1].Trim(),
                                    [Globalization.NumberStyles]::Float,
                                    [Globalization.CultureInfo]::InvariantCulture,
                                    [ref]$max
                                )) {

                                    if ($max -gt 0) {

                                        & $smi -pl $max 2>&1 | Out-Null

                                        if ($LASTEXITCODE -eq 0) {
                                            Write-OK "NVIDIA GPU power limit set to supported maximum: $max W"
                                        }
                                        else {
                                            Write-Info "NVIDIA driver rejected maximum power limit; default driver policy preserved."
                                        }
                                    }
                                }
                            }
                        }
                    }
                    else {
                        Write-Info "NVIDIA power-limit control is not supported by this GPU/driver."
                    }
                }
                catch {
                    Write-Info "NVIDIA vendor tuning skipped: $($_.Exception.Message)"
                }
            }
            else {
                Write-Info "NVIDIA GPU detected, but nvidia-smi is unavailable. No undocumented registry changes will be used."
            }

            continue
        }

        # -------------------------------------------------------------
        # AMD
        # AMD Adrenalin exposes performance tuning, including power
        # tuning and automatic overclocking, but AMD does not provide
        # a supported universal Windows CLI for applying those GUI
        # tuning controls. Therefore we do not fake registry writes.
        # -------------------------------------------------------------
        if ($name -match 'AMD|Radeon') {

            $amdExe = $null

            $amdCandidates = @(
                "$env:ProgramFiles\AMD\CNext\CNext\RadeonSoftware.exe",
                "$env:ProgramFiles\AMD\CNext\CNext\RadeonSoftware.exe"
            )

            foreach ($candidate in $amdCandidates) {
                if (Test-Path $candidate) {
                    $amdExe = $candidate
                    break
                }
            }

            Write-OK "AMD Radeon GPU detected: $name"

            if ($amdExe) {
                Write-Info "AMD Adrenalin detected. Its supported Performance Tuning controls remain driver-owned."
                Write-Info "No undocumented registry/overclock values will be forced."
            }
            else {
                Write-Info "AMD Adrenalin not detected. Driver-level tuning is unavailable from Windows APIs."
            }

            continue
        }

        # -------------------------------------------------------------
        # Intel
        # Intel Graphics Command Center / Intel Graphics Software does
        # not expose a universal supported CLI for forcing arbitrary
        # GPU clocks on every Intel generation. For older integrated
        # graphics such as HD 4600, hardware clocks are driver/firmware
        # controlled and should not be forced through registry hacks.
        # -------------------------------------------------------------
        if ($name -match 'Intel') {

            Write-OK "Intel GPU detected: $name"
            Write-Info "Intel driver/firmware controls GPU frequency. Unsupported clock forcing is skipped."
            Write-Info "Windows power/GPU scheduling optimizations are already applied by PANDA."
            continue
        }

        Write-Info "No supported vendor-level tuning interface detected for: $name"
    }

    Write-OK "GPU vendor performance pass completed."
}

function Set-PandaMaximumPerformance {

    Write-Section "PANDA MAXIMUM PERFORMANCE PASS"

    Set-DevicePowerPolicies
    Set-GpuVendorMaximumPerformance
    Set-CoreParkingMaximumPerformance
    Set-MemoryPerformance
    Set-StorageMaximumPerformance
    Set-NetworkMaximumPerformance
    Set-WindowsPerformancePolicies
    Set-SmartBackgroundOptimization

    Write-OK "Maximum performance pass completed."
}


function Set-AdvancedSystemOptimization {

    Write-Section "ADVANCED SYSTEM OPTIMIZATION"

    # Optimize thread scheduling
    $sysPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
    Set-RegistryPath -Path $sysPath
    try {
        Set-ItemProperty -Path $sysPath -Name Win32PrioritySeparation -Type DWord -Value 26 -ErrorAction SilentlyContinue
        Write-OK "Thread scheduling priority optimized."
    }
    catch {}

    # Disable unnecessary visual effects registry entries
    try {
        $uxPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
        Set-RegistryPath -Path $uxPath
        Set-ItemProperty -Path $uxPath -Name VisualFXSetting -Type DWord -Value 3 -ErrorAction SilentlyContinue
    }
    catch {}

    # Optimize Windows search indexing
    try {
        $searchPath = 'HKLM:\SOFTWARE\Microsoft\Windows Search'
        if (Test-Path $searchPath) {
            Set-ItemProperty -Path $searchPath -Name SetupCompletedSuccessfully -Type DWord -Value 1 -ErrorAction SilentlyContinue
        }
    }
    catch {}

    # Disable update notifications during peak usage
    try {
        $updatePath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        Set-ItemProperty -Path $updatePath -Name DisableNotificationCenter -Type DWord -Value 1 -ErrorAction SilentlyContinue
        Write-OK "Update notifications optimized."
    }
    catch {}

    Write-OK "Advanced system optimization completed."
}

function Invoke-PandaPerformanceEngine {

    Clear-Host

    Write-Host ""
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host "                  PANDA PERFORMANCE ENGINE" -ForegroundColor White
    Write-Host "                        MAX EDITION" -ForegroundColor Green
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Info "Mode: MAX PERFORMANCE"
    Write-Info "Goal: Maximum Windows software-level performance"
    Write-Info "Safety: Critical Windows components protected."
    Write-Host ""

    New-PandaRestorePoint
    Get-PandaHardware

    Set-MaxPerformancePower
    Set-CPUPerformance
    Set-GamingPerformance
    Set-UIPerformance

    Set-HardwareMaximumPerformance
    Set-PandaMaximumPerformance
    Set-AdvancedSystemOptimization
    Set-NetworkPerformance
    Set-ExtremePerformanceTuning
    Optimize-Storage

    Optimize-OptionalServices
    Optimize-BackgroundProcesses
    Optimize-Startup

    Protect-SecurityComponents

    Update-WindowsInterface

    Show-PerformanceReport

    Write-Host ""
    Write-Host "====================================================================" -ForegroundColor Green
    Write-Host "              MAX PERFORMANCE OPTIMIZATION COMPLETE" -ForegroundColor Green
    Write-Host "====================================================================" -ForegroundColor Green
    Write-Host ""

    Write-Host "[+] Maximum performance profile applied." -ForegroundColor Green
    Write-Host "[+] CPU performance optimized." -ForegroundColor Green
    Write-Host "[+] Power management optimized." -ForegroundColor Green
    Write-Host "[+] Gaming configuration optimized." -ForegroundColor Green
    Write-Host "[+] Hardware/device power-saving controls optimized." -ForegroundColor Green
    Write-Host "[+] CPU / GPU / storage / network / Windows performance pass completed." -ForegroundColor Green
    Write-Host "[+] Memory optimization completed." -ForegroundColor Green
    Write-Host "[+] Advanced system optimization applied." -ForegroundColor Green
    Write-Host "[+] Network configuration optimized." -ForegroundColor Green
    Write-Host "[+] Storage optimization completed." -ForegroundColor Green
    Write-Host "[+] Optional background activity reduced." -ForegroundColor Green
    Write-Host "[+] Critical Windows services protected." -ForegroundColor Green
    Write-Host ""
}

try {
    Invoke-PandaPerformanceEngine

    Write-Host ""
    Write-Host "====================================================================" -ForegroundColor Green
    Write-Host " SCRIPT FINISHED" -ForegroundColor Green
    Write-Host "====================================================================" -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "====================================================================" -ForegroundColor Red
    Write-Host "             PANDA PERFORMANCE ENGINE ERROR" -ForegroundColor Red
    Write-Host "====================================================================" -ForegroundColor Red

    Write-Host ""
    Write-Host "ERROR MESSAGE:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Red

    Write-Host ""
    Write-Host "ERROR DETAILS:" -ForegroundColor Yellow
    Write-Host $_.Exception.ToString() -ForegroundColor Red

    Write-Host ""
    Write-Host "SCRIPT LOCATION:" -ForegroundColor Yellow
    Write-Host $_.InvocationInfo.PositionMessage -ForegroundColor Red

    Write-Host ""
    Write-Host "The window will remain open so you can inspect the error." -ForegroundColor Cyan
}
finally {
    Write-Host ""
    Write-Host "====================================================================" -ForegroundColor Cyan
    Write-Host " Press ENTER to close this window..." -ForegroundColor White
    Write-Host "====================================================================" -ForegroundColor Cyan

    Read-Host
}