# ==========================================
# Windows Repair & Optimization Tool v13.0
# ==========================================

param(
    [switch]$AnalysisOnly,
    [ValidateSet('Quick','Deep','Expert')]
    [string]$Mode = 'Quick',
    [int]$AutoSelect = 0
)

$global:AnalysisOnly = $AnalysisOnly

# ==========================================
# 1. إجبار التشغيل كمسؤول
# ==========================================
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

if (-not $global:AnalysisOnly -and -not $currentPrincipal.IsInRole($adminRole)) {
    $scriptPath = $PSCommandPath
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    try {
        Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs -ErrorAction Stop
        exit
    } catch {
        Write-Host "============================================" -ForegroundColor Red
        Write-Host " Error: Run this tool as Administrator!    " -ForegroundColor Red
        Write-Host "============================================" -ForegroundColor Red
        Pause; exit
    }
}

# ==========================================
# 2. متغيرات التقرير العالمية
# ==========================================
$global:ReportData = @()
$global:ReportStartTime = Get-Date
$global:SystemInfo = @{}
$global:RemediationCount = 0
$global:RemediationLog = @()

Function Add-ReportEntry {
    param(
        [string]$Section,
        [string]$Task,
        [string]$Status,   # SUCCESS / WARNING / FAILED / INFO
        [string]$Detail = ""
    )
    $global:ReportData += [PSCustomObject]@{
        Time    = (Get-Date).ToString("HH:mm:ss")
        Section = $Section
        Task    = $Task
        Status  = $Status
        Detail  = $Detail
    }
}

# ==========================================
# 3. جمع معلومات النظام
# ==========================================
Function Get-SystemInfo {
    try {
        $os          = Get-CimInstance Win32_OperatingSystem
        $cpu         = Get-CimInstance Win32_Processor | Select-Object -First 1
        $logicalDisk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

        $ram = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)

        # Drive Type
        try {
            $partition = Get-Partition -DriveLetter C -ErrorAction Stop
            $diskObj   = Get-Disk -Number $partition.DiskNumber -ErrorAction Stop

            $physicalDisk = Get-PhysicalDisk | Where-Object {
                $_.FriendlyName -eq $diskObj.FriendlyName
            }

            if ($physicalDisk -and $physicalDisk.MediaType) {
                $driveType = $physicalDisk.MediaType.ToString()
            }
            else {
                $driveType = "Unknown"
            }
        }
        catch {
            $driveType = "Unknown"
        }

        $global:SystemInfo = @{
            OS        = $os.Caption
            Build     = $os.BuildNumber
            CPU       = $cpu.Name
            RAM_GB    = $ram
            DriveType = if ([string]::IsNullOrWhiteSpace($driveType)) {
                "Unknown"
            }
            else {
                $driveType
            }
            DiskFree  = [math]::Round($logicalDisk.FreeSpace / 1GB, 2)
            DiskTotal = [math]::Round($logicalDisk.Size / 1GB, 2)
            Hostname  = $env:COMPUTERNAME
            User      = $env:USERNAME
        }
    }
    catch {
        $global:SystemInfo = @{
            Error = $_.Exception.Message
        }
    }
}

# ==========================================
# 4. دوال الفحص الذكي والإصلاح
# ==========================================

Function Add-RemediationEntry {
    param(
        [string]$Task,
        [string]$Detail,
        [string]$Status = 'SUCCESS'
    )

    $global:RemediationCount++
    $global:RemediationLog += [PSCustomObject]@{
        Task    = $Task
        Status  = $Status
        Detail  = $Detail
    }

    Add-ReportEntry "Diagnostics" $Task $Status $Detail
}

Function Write-StatusLine {
    param(
        [string]$Type,
        [string]$Message,
        [string]$Color = 'White'
    )

    $icon = switch ($Type) {
        'OK' { '✅' }
        'WARN' { '⚠️' }
        'FAIL' { '❌' }
        'INFO' { 'ℹ️' }
        default { '•' }
    }

    Write-Host ("  {0} {1}" -f $icon, $Message) -ForegroundColor $Color
}

Function Invoke-HardwareHealthCheck {
    param([string]$Mode = 'Quick')

    Write-Host "  Checking hardware health..." -ForegroundColor Yellow
    $findings = @()

    try {
        $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
        if ($battery -and $battery.BatteryStatus -ne 2) {
            $findings += "Battery status is not normal (Code $($battery.BatteryStatus))."
        }
    } catch {}

    try {
        $physicalDisks = Get-PhysicalDisk -ErrorAction SilentlyContinue
        foreach ($disk in $physicalDisks) {
            if ($disk.HealthStatus -and $disk.HealthStatus -ne 'Healthy') {
                $findings += "Drive $($disk.FriendlyName) health: $($disk.HealthStatus)."
            }
        }
    } catch {}

    try {
        $temps = Get-CimInstance Win32_TemperatureProbe -ErrorAction SilentlyContinue
        foreach ($temp in $temps) {
            if ($temp.CurrentReading -and [int]$temp.CurrentReading -gt 80) {
                $findings += "Temperature probe reports high heat: $($temp.CurrentReading)C."
            }
        }
    } catch {}

    # ACPI Thermal Zone (بديل أدق شغال على أغلب الأجهزة عكس Win32_TemperatureProbe)
    try {
        $thermalZones = Get-CimInstance -Namespace "root/wmi" -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
        foreach ($zone in $thermalZones) {
            if ($zone.CurrentTemperature) {
                $celsius = [math]::Round(($zone.CurrentTemperature / 10) - 273.15, 1)
                if ($celsius -gt 85) {
                    $findings += "ACPI thermal zone reports high heat: ${celsius}C."
                }
            }
        }
    } catch {}

    # حرارة الديسكات عبر Storage Reliability Counters (أدق من الـ probe العام)
    try {
        $physicalDisksForTemp = Get-PhysicalDisk -ErrorAction SilentlyContinue
        foreach ($disk in $physicalDisksForTemp) {
            try {
                $reliability = $disk | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
                if ($reliability -and $reliability.Temperature -and [int]$reliability.Temperature -gt 60) {
                    $findings += "Drive $($disk.FriendlyName) temperature high: $($reliability.Temperature)C."
                }
            } catch {}
        }
    } catch {}

    # حالة كارت الشاشة (GPU) - الاسم، حالة الدرايفر، وتاريخه
    try {
        $gpus = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
        foreach ($gpu in $gpus) {
            if ($gpu.Status -and $gpu.Status -ne 'OK') {
                $findings += "GPU '$($gpu.Name)' status: $($gpu.Status)."
            }
            $driverAgeNote = ""
            if ($gpu.DriverDate) {
                try {
                    $driverDate = [Management.ManagementDateTimeConverter]::ToDateTime($gpu.DriverDate)
                    $ageMonths = [math]::Round(((Get-Date) - $driverDate).Days / 30)
                    if ($ageMonths -gt 18) {
                        $findings += "GPU '$($gpu.Name)' driver is old (~$ageMonths months, $($gpu.DriverVersion))."
                    }
                    $driverAgeNote = " | Driver: $($gpu.DriverVersion) ($($driverDate.ToString('yyyy-MM-dd')))"
                } catch {}
            }
            Add-ReportEntry "Diagnostics" "GPU Info" "INFO" "$($gpu.Name)$driverAgeNote"
        }
    } catch {}

    if ($findings.Count -gt 0) {
        Add-ReportEntry "Diagnostics" "Hardware Health" "WARNING" ($findings -join ' ')
        Write-StatusLine -Type 'WARN' -Message 'Hardware health issues detected.' -Color Yellow
    } else {
        Add-ReportEntry "Diagnostics" "Hardware Health" "SUCCESS" "No obvious hardware health issues detected."
        Write-StatusLine -Type 'OK' -Message 'Hardware health looks normal.' -Color Green
    }
}

Function Invoke-StartupAndServicesAnalysis {
    param([string]$Mode = 'Quick')

    Write-Host "  Analyzing startup items and services..." -ForegroundColor Yellow

    $startupItems = @()
    $regPaths = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Scope = 'HKLM' },
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Scope = 'HKCU' }
    )

    foreach ($reg in $regPaths) {
        if (Test-Path $reg.Path) {
            $props = Get-ItemProperty $reg.Path -ErrorAction SilentlyContinue
            $props.PSObject.Properties | Where-Object { $_.Name -notlike 'PS*' } | ForEach-Object {
                $rawVal = $_.Value
                $parsedPath = ''
                if ($rawVal -match '"([^"]+)"') { $parsedPath = $matches[1] }
                else { $parsedPath = ($rawVal -split ' ')[0] }
                $startupItems += [PSCustomObject]@{ Name = $_.Name; Exists = (Test-Path $parsedPath -ErrorAction SilentlyContinue) }
            }
        }
    }

    $deadItems = @($startupItems | Where-Object { $_.Exists -eq $false })
    $stoppedServices = @(Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'Running' -and $_.StartType -eq 'Automatic' })

    if ($deadItems.Count -gt 0 -or $stoppedServices.Count -gt 0) {
        $detail = "Found $($deadItems.Count) dead startup entries and $($stoppedServices.Count) services not running."
        Add-ReportEntry "Diagnostics" "Startup and Services" "WARNING" $detail
        Write-StatusLine -Type 'WARN' -Message 'Startup/service concerns detected.' -Color Yellow

        if (-not $global:AnalysisOnly) {
            $removedStartupCount = 0
            foreach ($item in $deadItems | Select-Object -First 20) {
                foreach ($reg in $regPaths) {
                    try {
                        Remove-ItemProperty -Path $reg.Path -Name $item.Name -Force -ErrorAction Stop
                        $removedStartupCount++
                    } catch {}
                }
            }

            if ($removedStartupCount -gt 0) {
                Add-RemediationEntry -Task "Startup Cleanup" -Detail "Removed $removedStartupCount dead startup entries from the registry." -Status 'SUCCESS'
            }

            $restartedServices = @()
            foreach ($svc in $stoppedServices | Select-Object -First 10) {
                try {
                    Set-Service -Name $svc.Name -StartupType Automatic -ErrorAction Stop
                    Start-Service -Name $svc.Name -ErrorAction Stop
                    $restartedServices += $svc.Name
                } catch {}
            }

            if ($restartedServices.Count -gt 0) {
                Add-RemediationEntry -Task "Service Recovery" -Detail "Restarted and enabled automatic startup for: $($restartedServices -join ', ')." -Status 'SUCCESS'
            }
        } else {
            Add-RemediationEntry -Task "Startup Cleanup" -Detail "Analysis-only mode: dead startup entries would be removed and stopped services would be restarted." -Status 'INFO'
        }
    } else {
        Add-ReportEntry "Diagnostics" "Startup and Services" "SUCCESS" "No obvious startup or service issues found."
        Write-StatusLine -Type 'OK' -Message 'Startup services look healthy.' -Color Green
    }
}

Function Invoke-EventLogAnalysis {
    param([string]$Mode = 'Quick')

    Write-Host "  Reviewing recent event log errors..." -ForegroundColor Yellow

    try {
        $events = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 2,3; StartTime = (Get-Date).AddDays(-2) } -MaxEvents 15 -ErrorAction SilentlyContinue)
        $appEvents = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; Level = 2,3; StartTime = (Get-Date).AddDays(-2) } -MaxEvents 15 -ErrorAction SilentlyContinue)
        $allEvents = @($events + $appEvents) | Select-Object -First 20

        if ($allEvents.Count -gt 0) {
            $sample = ($allEvents | Select-Object -First 5 | ForEach-Object { "$($_.ProviderName) [$($_.Id)]" }) -join '; '
            Add-ReportEntry "Diagnostics" "Event Log Analysis" "WARNING" "Recent errors found: $sample"
            Write-StatusLine -Type 'WARN' -Message 'Recent event log errors were detected.' -Color Yellow

            if (-not $global:AnalysisOnly) {
                try {
                    Restart-Service -Name EventLog -ErrorAction Stop
                    Add-RemediationEntry -Task "Event Log Recovery" -Detail "Restarted the Windows Event Log service to refresh the log store." -Status 'SUCCESS'
                } catch {
                    Add-RemediationEntry -Task "Event Log Recovery" -Detail "Could not restart the Event Log service: $($_.Exception.Message)" -Status 'WARNING'
                }
            } else {
                Add-RemediationEntry -Task "Event Log Recovery" -Detail "Analysis-only mode: the Event Log service would be restarted to refresh recent errors." -Status 'INFO'
            }
        } else {
            Add-ReportEntry "Diagnostics" "Event Log Analysis" "SUCCESS" "No recent event log errors were found."
            Write-StatusLine -Type 'OK' -Message 'Event logs look clean.' -Color Green
        }
    } catch {
        Add-ReportEntry "Diagnostics" "Event Log Analysis" "INFO" "Event log analysis skipped: $($_.Exception.Message)"
    }
}

Function Invoke-NetworkDeepCheck {
    param([string]$Mode = 'Quick')

    Write-Host "  Performing deeper network checks..." -ForegroundColor Yellow

    $issues = @()
    try {
        $upAdapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
        if (-not $upAdapter) { $issues += 'No active network adapter was found.' }
    } catch {}

    try {
        $internet = Test-Connection -ComputerName '8.8.8.8' -Count 1 -Quiet -ErrorAction SilentlyContinue
        if (-not $internet) { $issues += 'No internet connectivity to public DNS server.' }
    } catch {}

    try {
        $dns = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 3
        if (-not $dns) { $issues += 'DNS server information was not returned.' }
    } catch {}

    if ($issues.Count -gt 0) {
        Add-ReportEntry "Diagnostics" "Network Deep Check" "WARNING" ($issues -join ' ')
        Write-StatusLine -Type 'WARN' -Message 'Network anomalies were detected.' -Color Yellow

        if (-not $global:AnalysisOnly) {
            $repairSteps = @()
            try { netsh winsock reset | Out-Null; $repairSteps += 'winsock reset' } catch {}
            try { netsh int ip reset | Out-Null; $repairSteps += 'IP stack reset' } catch {}
            try { ipconfig /flushdns | Out-Null; $repairSteps += 'DNS cache flush' } catch {}

            if ($repairSteps.Count -gt 0) {
                Add-RemediationEntry -Task "Network Repair" -Detail "Applied network fixes: $($repairSteps -join ', ')." -Status 'SUCCESS'
            } else {
                Add-RemediationEntry -Task "Network Repair" -Detail "Network issues were detected but no safe repair steps could be applied." -Status 'WARNING'
            }
        } else {
            Add-RemediationEntry -Task "Network Repair" -Detail "Analysis-only mode: the network stack would be reset and DNS cache would be flushed." -Status 'INFO'
        }
    } else {
        Add-ReportEntry "Diagnostics" "Network Deep Check" "SUCCESS" "Network connectivity and DNS look healthy."
        Write-StatusLine -Type 'OK' -Message 'Network checks passed.' -Color Green
    }
}

Function Invoke-MemoryDiagnosticCheck {
    param([string]$Mode = 'Quick')

    Write-Host "  Checking memory diagnostic options..." -ForegroundColor Yellow

    if ($global:AnalysisOnly) {
        Add-ReportEntry "Diagnostics" "Memory Diagnostic" "INFO" "Analysis-only mode: memory diagnostic would be scheduled on next reboot."
        Write-Host "  [INFO] Memory diagnostic was not executed because analysis-only mode is active." -ForegroundColor DarkCyan
        return
    }

    $diagPath = "$env:SystemRoot\System32\MdSched.exe"
    if (Test-Path $diagPath) {
        Start-Process $diagPath -ArgumentList '/scanonnextboot' -NoNewWindow -Wait -ErrorAction SilentlyContinue
        Add-ReportEntry "Diagnostics" "Memory Diagnostic" "SUCCESS" "Memory diagnostic scheduled on next reboot."
        Write-Host "  [OK] Memory diagnostic scheduled." -ForegroundColor Green
    } else {
        Add-ReportEntry "Diagnostics" "Memory Diagnostic" "WARNING" "MdSched.exe was not found."
        Write-Host "  [WARN] Memory diagnostic utility was not found." -ForegroundColor Yellow
    }
}

Function Show-DiagnosticSummary {
    param([string]$Mode = 'Quick')

    $diagEntries = @($global:ReportData | Where-Object { $_.Section -eq 'Diagnostics' })
    $warnCount = @($diagEntries | Where-Object { $_.Status -eq 'WARNING' }).Count
    $failCount = @($diagEntries | Where-Object { $_.Status -eq 'FAILED' }).Count
    $successCount = @($diagEntries | Where-Object { $_.Status -eq 'SUCCESS' }).Count

    $severity = 'Healthy'
    if ($failCount -gt 0 -or $warnCount -ge 3) { $severity = 'High' }
    elseif ($warnCount -gt 0) { $severity = 'Medium' }

    Write-Host "" 
    Write-Host "=== Smart Diagnosis Summary ===" -ForegroundColor Cyan
    Write-Host "Mode: $Mode | Severity: $severity | Warnings: $warnCount | Failures: $failCount | Successes: $successCount | Applied Fixes: $global:RemediationCount" -ForegroundColor White

    foreach ($entry in $diagEntries) {
        Write-Host " - [$($entry.Status)] $($entry.Task): $($entry.Detail)" -ForegroundColor Gray
    }

    if ($global:RemediationLog.Count -gt 0) {
        Write-Host "Applied fixes:" -ForegroundColor Green
        foreach ($fix in $global:RemediationLog) {
            Write-Host " - [$($fix.Status)] $($fix.Task): $($fix.Detail)" -ForegroundColor Green
        }
    }

    $summaryFile = "$env:USERPROFILE\Desktop\SmartDiagnosis_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $diagEntries | ForEach-Object { "[$($_.Status)] $($_.Task) - $($_.Detail)" } | Set-Content -Path $summaryFile -Encoding UTF8
    Add-ReportEntry "Diagnostics" "Summary Report" "SUCCESS" "Saved summary to $summaryFile"
    Write-Host "Summary saved to: $summaryFile" -ForegroundColor Green
}

Function Invoke-AdvancedHealthScan {
    param([ValidateSet('Quick','Deep','Expert')][string]$Mode = 'Quick')

    Write-Host "" 
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  Smart System Diagnosis ($Mode)" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan

    Invoke-HardwareHealthCheck -Mode $Mode
    Invoke-StartupAndServicesAnalysis -Mode $Mode
    Invoke-EventLogAnalysis -Mode $Mode

    if ($Mode -in @('Deep','Expert')) {
        Invoke-NetworkDeepCheck -Mode $Mode
    }

    if ($Mode -eq 'Expert') {
        Invoke-MemoryDiagnosticCheck -Mode $Mode
    }

    Show-DiagnosticSummary -Mode $Mode
}

Function Invoke-CheckMyPC {
    # ==========================================
    # Check My PC = فحص شامل زي الشيك أب في المستشفى
    # المرحلة 1: تشخيص كامل (زي تحليل الدم والأشعة)
    # المرحلة 2: علاج تلقائي لأي مشكلة يتم اكتشافها، ويكمل حتى لو فشلت خطوة
    # ==========================================

    Clear-Host
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "          CHECK MY PC — Full Checkup       " -ForegroundColor Green
    Write-Host "  Diagnosing your PC like a medical checkup " -ForegroundColor Yellow
    Write-Host "  then treating anything found automatically" -ForegroundColor Yellow
    Write-Host "  Please wait, this may take 15-60 min.     " -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Green
    Start-Sleep -Seconds 2

    Add-ReportEntry "Check My PC" "Checkup Started" "INFO" "Mode: Expert"

    # ==========================================
    # STAGE 1: الفحص الشامل (Vitals / Diagnosis)
    # ==========================================
    Write-Host ""
    Write-Host "STAGE 1: Full Diagnosis (Vitals Check)" -ForegroundColor Cyan
    Write-Host "--------------------------------------------" -ForegroundColor DarkGray
    try {
        Invoke-AdvancedHealthScan -Mode 'Expert'
    } catch {
        Write-Host "  [FAIL] Diagnosis stage hit an error, continuing to treatment..." -ForegroundColor Red
        Add-ReportEntry "Check My PC" "Full Diagnosis" "FAILED" $_.Exception.Message
    }

    # ==========================================
    # STAGE 2: العلاج التلقائي (Treat & Continue)
    # كل خطوة معزولة بـ try/catch، لو خطوة فشلت بيسجلها وبيكمل اللي بعدها
    # ==========================================
    Write-Host ""
    Write-Host "STAGE 2: Automatic Treatment" -ForegroundColor Cyan
    Write-Host "--------------------------------------------" -ForegroundColor DarkGray

    $steps = @(
        @{ Name="Restore Point";             Fn={ Invoke-RestorePoint } },
        @{ Name="Windows Update Repair";     Fn={ Invoke-WindowsUpdateRepair } },
        @{ Name="SFC + DISM";                Fn={ Invoke-SystemRepair } },
        @{ Name="WMI Repository Repair";     Fn={ Invoke-WMIRepair } },
        @{ Name="Disk Check (scheduled)";    Fn={ Invoke-DiskRepair } },
        @{ Name="Disk Cleanup + Optimize";   Fn={ Invoke-DiskCleanup } },
        @{ Name="Network Reset + DNS";       Fn={ Invoke-NetworkRepair } },
        @{ Name="Boot Repair";               Fn={ Invoke-BootRepair } },
        @{ Name="Store Cache Reset";         Fn={ Invoke-AppStoreReset } },
        @{ Name="Safe Store Repair";         Fn={ Invoke-UWPStoreRepair } },
        @{ Name="Permissions Repair";        Fn={ Invoke-PermissionsRepair } },
        @{ Name="Malware Scan (Defender)";   Fn={ Invoke-MalwareScan } },
        @{ Name="Registry Cleanup";          Fn={ Invoke-RegistryCleanup } },
        @{ Name="Startup Manager";           Fn={ Invoke-StartupManager } },
        @{ Name="Services Repair";           Fn={ Invoke-ServicesRepair } },
        @{ Name="Driver Updates Scan";       Fn={ Invoke-DriverUpdate } },
        @{ Name="Performance Optimization";  Fn={ Invoke-PerformanceOptimization } },
        @{ Name="App Startup Fix";           Fn={ Invoke-AppStartupFix } },
        @{ Name=".NET Framework Repair";     Fn={ Invoke-DotNetRepair } },
        @{ Name="Remove Bloatware / PUP";    Fn={ Invoke-BloatwareRemoval } }
    )

    $total = $steps.Count
    $i = 0
    foreach ($step in $steps) {
        $i++
        Write-Host ""
        Write-Host "[$i/$total] $($step.Name)" -ForegroundColor Cyan
        Write-Host "--------------------------------------------" -ForegroundColor DarkGray
        try {
            & $step.Fn
        } catch {
            Write-Host "  [FAIL] $($step.Name) hit an error, skipping and continuing..." -ForegroundColor Red
            Add-ReportEntry "Check My PC" $step.Name "FAILED" $_.Exception.Message
        }
    }

    # ==========================================
    # STAGE 3: تقرير الفحص النهائي
    # ==========================================
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "   CHECKUP COMPLETE — Generating Report...  " -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Add-ReportEntry "Check My PC" "Checkup Finished" "SUCCESS" "Diagnosis + automatic treatment completed"
    Export-HtmlReport
    Write-Host "   A SYSTEM RESTART IS RECOMMENDED.         " -ForegroundColor Yellow
}

Function Invoke-RestorePoint {
    Write-Host "  Creating System Restore Point..." -ForegroundColor Yellow
    try {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "BeforeFullRepair_v13" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "  [OK] Restore point created." -ForegroundColor Green
        Add-ReportEntry "System Repair" "Create Restore Point" "SUCCESS"
    } catch {
        Write-Host "  [SKIP] Restore point skipped." -ForegroundColor Gray
        Add-ReportEntry "System Repair" "Create Restore Point" "WARNING" "Skipped: $($_.Exception.Message)"
    }
}

Function Invoke-WindowsUpdateRepair {
    Write-Host "  Repairing Windows Update Components..." -ForegroundColor Yellow
    try {
        Stop-Service -Name wuauserv,bits,cryptsvc -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        if (Test-Path "$env:systemroot\SoftwareDistribution") {
            Rename-Item "$env:systemroot\SoftwareDistribution" "SoftwareDistribution.old" -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path "$env:systemroot\System32\catroot2") {
            Rename-Item "$env:systemroot\System32\catroot2" "catroot2.old" -Force -ErrorAction SilentlyContinue
        }
        Start-Service -Name wuauserv,bits,cryptsvc -ErrorAction SilentlyContinue
        Write-Host "  [OK] Windows Update components repaired." -ForegroundColor Green
        Add-ReportEntry "System Repair" "Windows Update Repair" "SUCCESS"
    } catch {
        Write-Host "  [FAIL] $_" -ForegroundColor Red
        Add-ReportEntry "System Repair" "Windows Update Repair" "FAILED" $_.Exception.Message
    }
}

Function Invoke-SystemRepair {
    Write-Host "  Running SFC..." -ForegroundColor Yellow
    $sfcOut = sfc /scannow 2>&1 | Out-String
    if ($sfcOut -match "did not find any integrity violations" -or $sfcOut -match "successfully repaired") {
        Write-Host "  [OK] SFC completed." -ForegroundColor Green
        Add-ReportEntry "System Repair" "SFC /scannow" "SUCCESS" ($sfcOut -replace "`r`n"," " | Select-String "Windows Resource" | Select-Object -First 1)
    } else {
        Write-Host "  [WARN] SFC found issues." -ForegroundColor Yellow
        Add-ReportEntry "System Repair" "SFC /scannow" "WARNING" "Check CBS.log for details"
    }

    Write-Host "  Running DISM RestoreHealth..." -ForegroundColor Yellow
    $dismOut = DISM /Online /Cleanup-Image /RestoreHealth 2>&1 | Out-String
    if ($dismOut -match "operation completed successfully" -or $dismOut -match "No component store corruption") {
        Write-Host "  [OK] DISM completed." -ForegroundColor Green
        Add-ReportEntry "System Repair" "DISM RestoreHealth" "SUCCESS"
    } else {
        Write-Host "  [WARN] DISM may have found issues." -ForegroundColor Yellow
        Add-ReportEntry "System Repair" "DISM RestoreHealth" "WARNING" "Check DISM.log"
    }
    Write-Host "  Running Deep Component Cleanup (DISM)..." -ForegroundColor Yellow
    DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1 | Out-Null
}

Function Invoke-DiskRepair {
    Write-Host "  Scheduling Disk Check (chkdsk /f /r) on next reboot..." -ForegroundColor Yellow
    $out = & cmd /c "echo Y | chkdsk C: /f /r" 2>&1 | Out-String
    if ($out -match "scheduled" -or $out -match "next time") {
        Write-Host "  [OK] Disk check scheduled for next reboot." -ForegroundColor Green
        Add-ReportEntry "Disk" "chkdsk /f /r" "SUCCESS" "Will run on next restart"
    } else {
        Write-Host "  [INFO] chkdsk output: $($out.Trim())" -ForegroundColor Gray
        Add-ReportEntry "Disk" "chkdsk /f /r" "INFO" $out.Trim()
    }
}

Function Invoke-DiskCleanup {
    Write-Host "  Cleaning temporary files..." -ForegroundColor Yellow
    $cleaned = 0
    $tempFolders = @("$env:TEMP", "$env:windir\Temp", "$env:windir\Prefetch")
    foreach ($folder in $tempFolders) {
        if (Test-Path $folder) {
            $items = Get-ChildItem -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
            $cleaned += $items.Count
            $items | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
    Write-Host "  [OK] Cleaned $cleaned items from temp folders." -ForegroundColor Green
    Add-ReportEntry "Disk" "Temp Files Cleanup" "SUCCESS" "Removed $cleaned items"

    # Windows.old
    if (Test-Path "C:\Windows.old") {
        Write-Host "  Removing Windows.old folder..." -ForegroundColor Yellow
        try {
            & cmd /c "rd /s /q C:\Windows.old" 2>&1 | Out-Null
            Write-Host "  [OK] Windows.old removed." -ForegroundColor Green
            Add-ReportEntry "Disk" "Remove Windows.old" "SUCCESS"
        } catch {
            Write-Host "  [WARN] Could not remove Windows.old fully." -ForegroundColor Yellow
            Add-ReportEntry "Disk" "Remove Windows.old" "WARNING" $_.Exception.Message
        }
    } else {
        Add-ReportEntry "Disk" "Remove Windows.old" "INFO" "Not found, skipped"
    }

    # Event Logs
    Write-Host "  Clearing old Event Logs..." -ForegroundColor Yellow
    try {
        Get-EventLog -List -ErrorAction SilentlyContinue | ForEach-Object {
            Clear-EventLog -LogName $_.Log -ErrorAction SilentlyContinue
        }
        Write-Host "  [OK] Event logs cleared." -ForegroundColor Green
        Add-ReportEntry "Disk" "Clear Event Logs" "SUCCESS"
    } catch {
        Add-ReportEntry "Disk" "Clear Event Logs" "WARNING" $_.Exception.Message
    }

    # Defrag / TRIM حسب نوع الـ Drive
    Write-Host "  Detecting drive type..." -ForegroundColor Yellow
    try {
        $partition = Get-Partition -DriveLetter C -ErrorAction Stop
        $disk      = Get-Disk -Number $partition.DiskNumber -ErrorAction Stop
        $mediaType = $disk.MediaType
        Write-Host "  Drive type: $mediaType" -ForegroundColor Gray
        if ($mediaType -eq "HDD") {
            Write-Host "  Running Defragmentation (HDD)..." -ForegroundColor Yellow
            Optimize-Volume -DriveLetter C -Defrag -ErrorAction SilentlyContinue
            Add-ReportEntry "Disk" "Defragmentation (HDD)" "SUCCESS"
        } else {
            Write-Host "  Running TRIM (SSD/NVMe)..." -ForegroundColor Yellow
            Optimize-Volume -DriveLetter C -ReTrim -ErrorAction SilentlyContinue
            Add-ReportEntry "Disk" "TRIM (SSD)" "SUCCESS"
        }
    } catch {
        Write-Host "  Running TRIM as safe fallback..." -ForegroundColor Yellow
        Optimize-Volume -DriveLetter C -ReTrim -ErrorAction SilentlyContinue
        Add-ReportEntry "Disk" "TRIM (fallback)" "WARNING" "Drive type unknown"
    }

    # Shadow Copies
    Write-Host "  Cleaning old Shadow Copies..." -ForegroundColor Yellow
    try {
        $shadows = Get-CimInstance Win32_ShadowCopy -ErrorAction SilentlyContinue
        if ($shadows) {
            $shadows | Remove-CimInstance -ErrorAction SilentlyContinue
            Write-Host "  [OK] $($shadows.Count) shadow copies removed." -ForegroundColor Green
            Add-ReportEntry "Disk" "Shadow Copies Cleanup" "SUCCESS" "Removed $($shadows.Count) copies"
        } else {
            Write-Host "  [INFO] No shadow copies found." -ForegroundColor Gray
            Add-ReportEntry "Disk" "Shadow Copies Cleanup" "INFO" "None found"
        }
    } catch {
        Add-ReportEntry "Disk" "Shadow Copies Cleanup" "WARNING" $_.Exception.Message
    }
}

Function Invoke-NetworkRepair {
    Write-Host "  Resetting Network Stack..." -ForegroundColor Yellow
    ipconfig /flushdns 2>&1 | Out-Null
    nbtstat -R 2>&1 | Out-Null
    nbtstat -RR 2>&1 | Out-Null
    netsh int ip reset 2>&1 | Out-Null
    netsh winsock reset 2>&1 | Out-Null
    Write-Host "  [OK] Network stack reset." -ForegroundColor Green
    Add-ReportEntry "Network" "Network Stack Reset" "SUCCESS"

    # DNS Benchmark & Switch
    Write-Host "  Testing DNS servers..." -ForegroundColor Yellow
    $dnsServers = @{
        "Cloudflare" = "1.1.1.1"
        "Google"     = "8.8.8.8"
        "OpenDNS"    = "208.67.222.222"
    }
    $bestDns  = $null
    $bestTime = [int]::MaxValue

    foreach ($name in $dnsServers.Keys) {
        try {
            $ip      = $dnsServers[$name]
            $result  = Measure-Command { Resolve-DnsName -Name "google.com" -Server $ip -Type A -ErrorAction Stop }
            $ms      = [int]$result.TotalMilliseconds
            Write-Host "    $name ($ip): ${ms}ms" -ForegroundColor Gray
            if ($ms -lt $bestTime) { $bestTime = $ms; $bestDns = $ip; $bestName = $name }
        } catch {
            Write-Host "    $name : Unreachable" -ForegroundColor DarkGray
        }
    }

    if ($bestDns) {
        Write-Host "  [OK] Fastest DNS: $bestName ($bestDns) - ${bestTime}ms" -ForegroundColor Green
        # تطبيق الـ DNS على كل الـ adapters النشطة
        $adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
        foreach ($adapter in $adapters) {
            Set-DnsClientServerAddress -InterfaceIndex $adapter.InterfaceIndex -ServerAddresses $bestDns -ErrorAction SilentlyContinue
        }
        Add-ReportEntry "Network" "DNS Optimization" "SUCCESS" "Set to $bestName ($bestDns) - ${bestTime}ms"
    } else {
        Write-Host "  [WARN] Could not reach any DNS server." -ForegroundColor Yellow
        Add-ReportEntry "Network" "DNS Optimization" "WARNING" "No DNS server reachable"
    }

    # Hosts File Repair
    Write-Host "  Checking Hosts file..." -ForegroundColor Yellow
    $hostsPath    = "$env:windir\System32\drivers\etc\hosts"
    $defaultHosts = "# Copyright (c) 1993-2009 Microsoft Corp.`r`n#`r`n# This is a sample HOSTS file used by Microsoft TCP/IP for Windows.`r`n#`r`n# 127.0.0.1       localhost`r`n# ::1             localhost`r`n127.0.0.1       localhost`r`n::1             localhost`r`n"
    $currentHosts = Get-Content $hostsPath -Raw -ErrorAction SilentlyContinue
    $suspiciousEntries = $currentHosts -split "`n" | Where-Object { $_ -notmatch "^#" -and $_ -match "\S" -and $_ -notmatch "localhost" }

    if ($suspiciousEntries.Count -gt 0) {
        Write-Host "  [WARN] Found $($suspiciousEntries.Count) non-default entries in hosts file." -ForegroundColor Yellow
        Write-Host "  Backing up and resetting hosts file..." -ForegroundColor Yellow
        Copy-Item $hostsPath "$hostsPath.bak" -Force -ErrorAction SilentlyContinue
        Set-Content -Path $hostsPath -Value $defaultHosts -Encoding UTF8 -ErrorAction SilentlyContinue
        Write-Host "  [OK] Hosts file reset. Backup saved as hosts.bak" -ForegroundColor Green
        Add-ReportEntry "Network" "Hosts File Repair" "WARNING" "Found and removed $($suspiciousEntries.Count) suspicious entries"
    } else {
        Write-Host "  [OK] Hosts file is clean." -ForegroundColor Green
        Add-ReportEntry "Network" "Hosts File Check" "SUCCESS" "No suspicious entries"
    }
}

Function Invoke-BootRepair {
    Write-Host "  Repairing Boot Configuration..." -ForegroundColor Yellow
    if (!(Test-Path "C:\backup")) { New-Item -Path "C:\backup" -ItemType Directory | Out-Null }
    bcdedit /export C:\backup\BCD_Backup 2>&1 | Out-Null

    # فحص نوع الإقلاع الحالي للجهاز
    if ($env:firmware_type -eq "UEFI" -or (bcdedit | Out-String -Stream | Select-String "path.*efi")) {
        Write-Host "  [INFO] UEFI System Detected. Repairing BCD via bcdboot..." -ForegroundColor Cyan
        & bcdboot C:\Windows /s C: /f UEFI 2>&1 | Out-Null
    } else {
        Write-Host "  [INFO] Legacy/MBR System Detected. Running bootrec..." -ForegroundColor Cyan
        bootrec /fixmbr  2>&1 | Out-Null
        bootrec /fixboot 2>&1 | Out-Null
    }
    bootrec /scanos  2>&1 | Out-Null
    bootrec /rebuildbcd 2>&1 | Out-Null
    Write-Host "  [OK] Boot configuration repaired. Backup at C:\backup\BCD_Backup" -ForegroundColor Green
    Add-ReportEntry "System Repair" "BCD Repair + Backup" "SUCCESS"
}

Function Invoke-AppStoreReset {
    Write-Host "  Resetting Windows Store cache..." -ForegroundColor Yellow
    try {
        Start-Process "wsreset.exe" -NoNewWindow -Wait
        Write-Host "  [OK] Store cache cleared." -ForegroundColor Green
        Add-ReportEntry "System Repair" "Windows Store Reset" "SUCCESS"
    } catch {
        Write-Host "  [FAIL]" -ForegroundColor Red
        Add-ReportEntry "System Repair" "Windows Store Reset" "FAILED" $_.Exception.Message
    }
}

Function Invoke-FullNetworkReset {
    Write-Host "Performing FULL Network Reset..." -ForegroundColor Yellow
    Write-Host "WARNING: This will remove all network adapters." -ForegroundColor Red
    $confirm = Read-Host "Are you sure? (y/n)"
    if ($confirm -eq 'y') {
        try {
            $minutes = 0
            do {
                $inputStr = Read-Host "Restart delay in minutes"
                if ($inputStr -match "^\d+$") { $minutes = [int]$inputStr }
                else { Write-Host "Enter a valid number." -ForegroundColor Red }
            } while ($minutes -eq 0)
            $seconds = $minutes * 60
            Start-Process "netcfg" -ArgumentList "-d" -NoNewWindow -Wait
            Write-Host "[OK] Network adapters removed." -ForegroundColor Green
            Write-Host "Restarting in $minutes minute(s)..." -ForegroundColor Cyan
            Start-Process "shutdown.exe" -ArgumentList "/r /t $seconds /f" -NoNewWindow
            Add-ReportEntry "Network" "Full Network Reset" "SUCCESS" "Reboot in $minutes min"
            exit
        } catch {
            Write-Host "[FAIL] $_" -ForegroundColor Red
            Add-ReportEntry "Network" "Full Network Reset" "FAILED" $_.Exception.Message
        }
    } else {
        Write-Host "Cancelled." -ForegroundColor Yellow
    }
}

Function Invoke-PermissionsRepair {
    Write-Host "  Repairing System Permissions..." -ForegroundColor Yellow
    $paths = @("$env:systemroot", "${env:ProgramFiles}", "${env:ProgramFiles(x86)}")
    foreach ($path in $paths) {
        if (Test-Path $path) {
            icacls $path /reset /T /C /Q 2>&1 | Out-Null
            icacls $path /grant "Administrators:(OI)(CI)F" /T /C /Q 2>&1 | Out-Null
            icacls $path /grant "SYSTEM:(OI)(CI)F" /T /C /Q 2>&1 | Out-Null
            Write-Host "  [OK] $path" -ForegroundColor Green
        }
    }
    Add-ReportEntry "System Repair" "Permissions Repair (icacls)" "SUCCESS"
}

Function Invoke-MalwareScan {
    $scanType   = "2"
    $scanLabel  = "Full"

    if (-not $global:AnalysisOnly) {
        Write-Host "  Choose Defender scan type:" -ForegroundColor Cyan
        Write-Host "   1. Quick Scan (few minutes)" -ForegroundColor White
        Write-Host "   2. Full Scan (may take several hours)" -ForegroundColor White
        $choice = Read-Host "  Choice (default 1)"
        if ($choice -eq "2") { $scanType = "2"; $scanLabel = "Full" }
        else { $scanType = "1"; $scanLabel = "Quick" }
    }

    Write-Host "  Starting Windows Defender $scanLabel Scan..." -ForegroundColor Yellow
    if ($scanLabel -eq "Full") { Write-Host "  This may take several hours." -ForegroundColor Yellow }

    try {
        $defenderPath = "$env:ProgramFiles\Windows Defender\MpCmdRun.exe"
        if (Test-Path $defenderPath) {
            Start-Process $defenderPath -ArgumentList "-Scan -ScanType $scanType" -NoNewWindow -Wait
            Write-Host "  [OK] $scanLabel scan completed. Check Protection History for details." -ForegroundColor Green
            Add-ReportEntry "Security" "Defender $scanLabel Scan" "SUCCESS"
        } else {
            Write-Host "  [WARN] Windows Defender not found." -ForegroundColor Yellow
            Add-ReportEntry "Security" "Defender $scanLabel Scan" "WARNING" "MpCmdRun.exe not found"
        }
    } catch {
        Add-ReportEntry "Security" "Defender $scanLabel Scan" "FAILED" $_.Exception.Message
    }
}

# ==========================================
# دالة جديدة - Bloatware / PUP Removal
# ==========================================
Function Invoke-BloatwareRemoval {
    Write-Host "  Scanning for known bloatware / PUP programs..." -ForegroundColor Yellow

    # قايمة أسماء (أو أجزاء من أسماء) لبرامج Bloatware/PUP معروفة وآمن حذفها
    $bloatSignatures = @(
        "McAfee", "Norton Security", "WildTangent", "Candy Crush", "Booking.com",
        "Disney Magic Kingdoms", "March of Empires", "Roblox", "Spotify Ads",
        "CyberLink", "Amazon Alexa", "Speedtest", "Facebook", "Xbox Game Bar Plugin",
        "Skype for Windows 10", "Power2Go", "PowerDVD", "Dropbox Promotion",
        "AVG", "Avast Free Antivirus Trial", "Driver Booster", "Driver Easy",
        "MyWebSearch", "Ask Toolbar", "Yahoo Toolbar", "Search Protect"
    )

    $foundPrograms = @()

    # 1. برامج مثبتة عادية (Uninstall registry)
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    foreach ($regPath in $uninstallPaths) {
        if (Test-Path $regPath) {
            Get-ItemProperty $regPath -ErrorAction SilentlyContinue | ForEach-Object {
                foreach ($sig in $bloatSignatures) {
                    if ($_.DisplayName -and $_.DisplayName -match [regex]::Escape($sig)) {
                        $foundPrograms += [PSCustomObject]@{
                            Name        = $_.DisplayName
                            UninstallStr = $_.UninstallString
                            Type        = "Win32"
                        }
                    }
                }
            }
        }
    }

    # 2. تطبيقات UWP/AppX المطابقة للقايمة
    $foundAppx = @()
    try {
        $appxPackages = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        foreach ($pkg in $appxPackages) {
            foreach ($sig in $bloatSignatures) {
                if ($pkg.Name -match [regex]::Escape($sig)) {
                    $foundAppx += $pkg
                }
            }
        }
    } catch {}

    $totalFound = $foundPrograms.Count + $foundAppx.Count
    if ($totalFound -eq 0) {
        Write-Host "  [OK] No known bloatware/PUP detected." -ForegroundColor Green
        Add-ReportEntry "Bloatware" "Bloatware Scan" "SUCCESS" "No known bloatware detected"
        return
    }

    Write-Host "  [WARN] Found $totalFound potential bloatware/PUP item(s):" -ForegroundColor Yellow
    foreach ($p in $foundPrograms) { Write-Host "    - $($p.Name) (Win32)" -ForegroundColor Yellow }
    foreach ($a in $foundAppx)     { Write-Host "    - $($a.Name) (AppX)" -ForegroundColor Yellow }
    Add-ReportEntry "Bloatware" "Bloatware Scan" "WARNING" "Found $totalFound item(s): $((@($foundPrograms.Name) + @($foundAppx.Name)) -join ', ')"

    if ($global:AnalysisOnly) {
        Add-ReportEntry "Bloatware" "Bloatware Removal" "INFO" "Analysis-only mode: these items would be uninstalled/removed."
        return
    }

    $confirm = Read-Host "  Remove all detected item(s) above? (y/n)"
    if ($confirm -ne 'y') {
        Write-Host "  Skipped." -ForegroundColor Gray
        Add-ReportEntry "Bloatware" "Bloatware Removal" "INFO" "Removal skipped by user"
        return
    }

    $removed = 0
    $failed  = 0

    foreach ($p in $foundPrograms) {
        try {
            if ($p.UninstallStr -match "msiexec") {
                $productCode = ($p.UninstallStr -replace ".*(\{[0-9A-Fa-f\-]+\}).*", '$1')
                Start-Process "msiexec.exe" -ArgumentList "/x $productCode /quiet /norestart" -Wait -ErrorAction Stop
            } else {
                Start-Process "cmd.exe" -ArgumentList "/c `"$($p.UninstallStr)`" /quiet /norestart" -Wait -ErrorAction Stop
            }
            $removed++
        } catch { $failed++ }
    }

    foreach ($a in $foundAppx) {
        try {
            $a | Remove-AppxPackage -AllUsers -ErrorAction Stop
            $removed++
        } catch { $failed++ }
    }

    Write-Host "  [OK] Removed $removed item(s), $failed failed." -ForegroundColor Green
    Add-ReportEntry "Bloatware" "Bloatware Removal" "SUCCESS" "Removed $removed item(s), $failed failed"
}

# ==========================================
# 5. دوال جديدة - Registry Cleanup
# ==========================================
Function Backup-RegistryKeys {
    param([string[]]$KeyPaths, [string]$Label = "RegistryBackup")

    if (!(Test-Path "C:\backup")) { New-Item -Path "C:\backup" -ItemType Directory -Force | Out-Null }
    $timestamp  = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupFile = "C:\backup\${Label}_$timestamp.reg"
    $savedAny   = $false

    foreach ($keyPath in $KeyPaths) {
        if (Test-Path $keyPath) {
            # تحويل PS path (HKLM:\...) لصيغة reg.exe (HKLM\...)
            $regExePath = $keyPath -replace ":", "" -replace "^HKLM", "HKLM" -replace "^HKCU", "HKCU"
            try {
                & reg export $regExePath $backupFile /y 2>&1 | Out-Null
                $savedAny = $true
            } catch {}
        }
    }

    if ($savedAny) {
        Add-ReportEntry "Registry" "Registry Backup" "SUCCESS" "Backed up keys to $backupFile before changes"
        Write-Host "  [OK] Registry backup saved: $backupFile" -ForegroundColor Green
    } else {
        Add-ReportEntry "Registry" "Registry Backup" "WARNING" "No keys found to back up"
    }
    return $backupFile
}

Function Invoke-RegistryCleanup {
    Write-Host "  Backing up affected registry keys before cleanup..." -ForegroundColor Yellow
    Backup-RegistryKeys -Label "PreRegistryCleanup" -KeyPaths @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    ) | Out-Null

    Write-Host "  Cleaning orphaned Registry entries..." -ForegroundColor Yellow
    $cleaned = 0

    # تنظيف Uninstall keys للبرامج المحذوفة (DisplayIcon لمسارات غير موجودة)
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    foreach ($regPath in $uninstallPaths) {
        if (Test-Path $regPath) {
            Get-ChildItem $regPath -ErrorAction SilentlyContinue | ForEach-Object {
                $icon = (Get-ItemProperty $_.PSPath -Name DisplayIcon -ErrorAction SilentlyContinue).DisplayIcon
                if ($icon) {
                    # استخراج المسار بدون arguments
                    $iconPath = ($icon -split ",")[0].Trim('"')
                    if ($iconPath -and -not (Test-Path $iconPath) -and $iconPath -match "\\") {
                        Remove-Item $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                        $cleaned++
                    }
                }
            }
        }
    }

    # تنظيف Startup entries الميتة
    $startupKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    )
    $deadStartup = 0
    foreach ($key in $startupKeys) {
        if (Test-Path $key) {
            $values = Get-ItemProperty $key -ErrorAction SilentlyContinue
            $values.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
                $exePath = ($_.Value -split '"')[1]
                if (-not $exePath) { $exePath = ($_.Value -split " ")[0] }
                if ($exePath -and -not (Test-Path $exePath) -and $exePath -match "\\") {
                    Remove-ItemProperty -Path $key -Name $_.Name -ErrorAction SilentlyContinue
                    $deadStartup++
                }
            }
        }
    }

    Write-Host "  [OK] Removed $cleaned orphaned uninstall entries, $deadStartup dead startup entries." -ForegroundColor Green
    Add-ReportEntry "Registry" "Registry Cleanup" "SUCCESS" "Removed $cleaned orphaned entries, $deadStartup dead startup entries"
}

# ==========================================
# 6. دوال جديدة - Startup Manager
# ==========================================
Function Invoke-StartupManager {
    Write-Host "  Analyzing Startup programs..." -ForegroundColor Yellow
    $startupItems = @()

    # من الريجستري
    $regPaths = @(
        @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; Scope = "HKLM" },
        @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"; Scope = "HKCU" }
    )
    foreach ($reg in $regPaths) {
        if (Test-Path $reg.Path) {
            $props = Get-ItemProperty $reg.Path -ErrorAction SilentlyContinue
            $props.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
                $rawVal = $_.Value
                $parsedPath = ""
                if ($rawVal -match '"([^"]+)"') { $parsedPath = $matches[1] }
                else { $parsedPath = ($rawVal -split " ")[0] }

                $startupItems += [PSCustomObject]@{
                    Name   = $_.Name
                    Path   = $rawVal
                    Source = $reg.Scope
                    Exists = (Test-Path $parsedPath -ErrorAction SilentlyContinue)
                }
            }
        }
    }

    # من Startup folders
    $startupFolders = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
        "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
    )
    foreach ($folder in $startupFolders) {
        if (Test-Path $folder) {
            Get-ChildItem $folder -ErrorAction SilentlyContinue | ForEach-Object {
                $startupItems += [PSCustomObject]@{
                    Name   = $_.Name
                    Path   = $_.FullName
                    Source = "StartupFolder"
                    Exists = $true
                }
            }
        }
    }

    $count = $startupItems.Count
    Write-Host "  [OK] Found $count startup items." -ForegroundColor Green
    Add-ReportEntry "Performance" "Startup Items Analysis" "INFO" "Found $count startup programs"

    # تقليل التأثير: disable للـ items اللي مسارها مش موجود
    $disabled = 0
    $deadItems = $startupItems | Where-Object { $_.Exists -eq $false }
    foreach ($item in $deadItems) {
        foreach ($reg in $regPaths) {
            Remove-ItemProperty -Path $reg.Path -Name $item.Name -ErrorAction SilentlyContinue
        }
        $disabled++
    }
    if ($disabled -gt 0) {
        Write-Host "  [OK] Removed $disabled dead startup entries." -ForegroundColor Green
        Add-ReportEntry "Performance" "Dead Startup Cleanup" "SUCCESS" "Removed $disabled dead entries"
    }
}

# ==========================================
# 7. دوال جديدة - Services Repair
# ==========================================
Function Invoke-ServicesRepair {
    Write-Host "  Repairing critical Windows services..." -ForegroundColor Yellow

    # الـ services المهمة مع الـ startup type الصح بتاعها
    $criticalServices = @(
        @{ Name = "Spooler";       StartType = "Automatic"; Display = "Print Spooler" },
        @{ Name = "WSearch";       StartType = "Automatic"; Display = "Windows Search" },
        @{ Name = "AudioSrv";      StartType = "Automatic"; Display = "Windows Audio" },
        @{ Name = "Themes";        StartType = "Automatic"; Display = "Themes" },
        @{ Name = "wuauserv";      StartType = "Manual";    Display = "Windows Update" },
        @{ Name = "bits";          StartType = "Manual";    Display = "BITS" },
        @{ Name = "EventLog";      StartType = "Automatic"; Display = "Windows Event Log" },
        @{ Name = "Schedule";      StartType = "Automatic"; Display = "Task Scheduler" },
        @{ Name = "SysMain";       StartType = "Automatic"; Display = "Superfetch/SysMain" },
        @{ Name = "WinDefend";     StartType = "Automatic"; Display = "Windows Defender" }
    )

    $fixed = 0
    foreach ($svc in $criticalServices) {
        try {
            $service = Get-Service -Name $svc.Name -ErrorAction SilentlyContinue
            if ($service) {
                Set-Service -Name $svc.Name -StartupType $svc.StartType -ErrorAction SilentlyContinue
                if ($svc.StartType -eq "Automatic" -and $service.Status -ne "Running") {
                    Start-Service -Name $svc.Name -ErrorAction SilentlyContinue
                    $fixed++
                }
            }
        } catch { }
    }

    Write-Host "  [OK] Services checked. $fixed services were restarted." -ForegroundColor Green
    Add-ReportEntry "Performance" "Services Repair" "SUCCESS" "$fixed services restarted/fixed"
}

# ==========================================
# 8. دوال جديدة - Performance Optimization
# ==========================================
Function Invoke-PerformanceOptimization {
    Write-Host "  Optimizing system performance..." -ForegroundColor Yellow

    # Power Plan -> High Performance
    try {
        $highPerf = powercfg /list | Select-String "High performance"
        if ($highPerf) {
            $guid = ($highPerf -split "\s+")[3]
            powercfg /setactive $guid 2>&1 | Out-Null
            Write-Host "  [OK] Power plan set to High Performance." -ForegroundColor Green
            Add-ReportEntry "Performance" "Power Plan" "SUCCESS" "Set to High Performance"
        }
    } catch {
        Add-ReportEntry "Performance" "Power Plan" "WARNING" $_.Exception.Message
    }

    # Visual Effects -> Adjust for best performance (مستخدم عادي)
    try {
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        if (!(Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
        Set-ItemProperty -Path $regPath -Name "VisualFXSetting" -Value 2  # Best performance
        Add-ReportEntry "Performance" "Visual Effects" "SUCCESS" "Set to best performance"
        Write-Host "  [OK] Visual effects optimized." -ForegroundColor Green
    } catch {
        Add-ReportEntry "Performance" "Visual Effects" "WARNING" $_.Exception.Message
    }

    # Page File -> System managed
    try {
        $cs = Get-CimInstance Win32_ComputerSystem
        if (-not $cs.AutomaticManagedPagefile) {
            $cs | Set-CimInstance -Property @{AutomaticManagedPagefile = $true} -ErrorAction SilentlyContinue
        }
        Write-Host "  [OK] Page file set to system-managed." -ForegroundColor Green
        Add-ReportEntry "Performance" "Page File" "SUCCESS" "Set to system-managed"
    } catch {
        Add-ReportEntry "Performance" "Page File" "WARNING" $_.Exception.Message
    }

    # Superfetch / SysMain - تفعيل
    try {
        Set-Service -Name SysMain -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name SysMain -ErrorAction SilentlyContinue
        Write-Host "  [OK] Superfetch (SysMain) enabled." -ForegroundColor Green
        Add-ReportEntry "Performance" "Superfetch/SysMain" "SUCCESS" "Enabled and started"
    } catch {
        Add-ReportEntry "Performance" "Superfetch/SysMain" "WARNING" $_.Exception.Message
    }

    # Prefetch - تفعيل عبر الريجستري
    try {
        $prefetchKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
        Set-ItemProperty -Path $prefetchKey -Name "EnablePrefetcher" -Value 3 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $prefetchKey -Name "EnableSuperfetch"  -Value 3 -ErrorAction SilentlyContinue
        Write-Host "  [OK] Prefetch enabled (mode 3 = App+Boot)." -ForegroundColor Green
        Add-ReportEntry "Performance" "Prefetch" "SUCCESS" "Enabled (mode 3)"
    } catch {
        Add-ReportEntry "Performance" "Prefetch" "WARNING" $_.Exception.Message
    }
}

# ==========================================
# 9. دوال جديدة - App Startup Speed Fix
# ==========================================
Function Invoke-AppStartupFix {
    Write-Host "  Fixing slow application startup..." -ForegroundColor Yellow

    # .NET NGEN - إعادة compile الـ assemblies
    Write-Host "  Re-compiling .NET assemblies (ngen)..." -ForegroundColor Gray
    try {
        $ngenPaths = @(
            "$env:windir\Microsoft.NET\Framework64\v4.0.30319\ngen.exe",
            "$env:windir\Microsoft.NET\Framework\v4.0.30319\ngen.exe"
        )
        foreach ($ngen in $ngenPaths) {
            if (Test-Path $ngen) {
                Start-Process $ngen -ArgumentList "update /force /queue" -NoNewWindow -Wait -ErrorAction SilentlyContinue
                Start-Process $ngen -ArgumentList "executeQueuedItems" -NoNewWindow -Wait -ErrorAction SilentlyContinue
            }
        }
        Write-Host "  [OK] .NET assemblies recompiled." -ForegroundColor Green
        Add-ReportEntry "Performance" ".NET NGEN Recompile" "SUCCESS"
    } catch {
        Add-ReportEntry "Performance" ".NET NGEN Recompile" "WARNING" $_.Exception.Message
    }

    # تعطيل الـ apps اللي بتأخر الـ startup بشكل فعلي عبر Task Scheduler
    Write-Host "  Checking startup impact via Task Manager data..." -ForegroundColor Gray
    try {
        # جمع startup impact من الريجستري (HKCU StartupApproved)
        $approvedPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run"
        if (Test-Path $approvedPath) {
            $values = Get-ItemProperty $approvedPath -ErrorAction SilentlyContinue
            $values.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | ForEach-Object {
                # القيمة: أول byte هو الـ enabled/disabled flag
                # 02 = enabled, 03 = disabled
                $bytes = $_.Value
                if ($bytes -and $bytes[0] -eq 2) {
                    # enabled - نسجل بس مش نعطل تلقائياً لأننا للمستخدم العادي
                    Add-ReportEntry "Performance" "Startup Item: $($_.Name)" "INFO" "Enabled at startup"
                }
            }
        }
        Write-Host "  [OK] Startup items analyzed." -ForegroundColor Green
    } catch { }

    # تحسين الـ I/O Priority للعمليات الجديدة
    try {
        $ioKey = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
        Set-ItemProperty -Path $ioKey -Name "Win32PrioritySeparation" -Value 38 -ErrorAction SilentlyContinue
        Write-Host "  [OK] I/O priority optimized for foreground apps." -ForegroundColor Green
        Add-ReportEntry "Performance" "I/O Priority" "SUCCESS" "Foreground apps prioritized"
    } catch {
        Add-ReportEntry "Performance" "I/O Priority" "WARNING" $_.Exception.Message
    }

    # تسريع بدء الويندوز عبر Fast Startup
    try {
        $powerKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
        Set-ItemProperty -Path $powerKey -Name "HiberbootEnabled" -Value 1 -ErrorAction SilentlyContinue
        Write-Host "  [OK] Fast Startup enabled." -ForegroundColor Green
        Add-ReportEntry "Performance" "Fast Startup" "SUCCESS" "Enabled"
    } catch {
        Add-ReportEntry "Performance" "Fast Startup" "WARNING" $_.Exception.Message
    }

    # تنظيف Recent files وجمله الـ shell cache
    Write-Host "  Clearing shell cache and recent files..." -ForegroundColor Gray
    try {
        Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
        Add-ReportEntry "Performance" "Shell Cache Cleanup" "SUCCESS"
        Write-Host "  [OK] Shell cache cleared." -ForegroundColor Green
    } catch {
        Add-ReportEntry "Performance" "Shell Cache Cleanup" "WARNING" $_.Exception.Message
    }
}

# ==========================================
# 10. إصلاح بيئة .NET Framework
# ==========================================
Function Invoke-DotNetRepair {
    Write-Host "  Repairing .NET Framework environment..." -ForegroundColor Yellow

    # اكتشاف كل إصدارات .NET المثبتة
    $netVersions = @()
    $ndpKey = "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP"
    if (Test-Path $ndpKey) {
        Get-ChildItem $ndpKey -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $ver = (Get-ItemProperty $_.PSPath -Name Version -ErrorAction SilentlyContinue).Version
            if ($ver) { $netVersions += $ver }
        }
    }
    $netVersions = $netVersions | Sort-Object -Unique
    Write-Host "  Detected .NET versions: $($netVersions -join ', ')" -ForegroundColor Gray

    # NGEN على كل الإصدارات المتاحة (x64 + x86)
    $ngenPaths = @()
    Get-ChildItem "$env:windir\Microsoft.NET\Framework64" -ErrorAction SilentlyContinue | ForEach-Object {
        $p = Join-Path $_.FullName "ngen.exe"
        if (Test-Path $p) { $ngenPaths += @{ Path=$p; Arch="x64"; Ver=$_.Name } }
    }
    Get-ChildItem "$env:windir\Microsoft.NET\Framework" -ErrorAction SilentlyContinue | ForEach-Object {
        $p = Join-Path $_.FullName "ngen.exe"
        if (Test-Path $p) { $ngenPaths += @{ Path=$p; Arch="x86"; Ver=$_.Name } }
    }

    $ngenDone = 0
    foreach ($ngen in $ngenPaths) {
        Write-Host "  Recompiling $($ngen.Arch) $($ngen.Ver)..." -ForegroundColor Gray
        try {
            Start-Process $ngen.Path -ArgumentList "update /force /queue" -NoNewWindow -Wait -ErrorAction SilentlyContinue
            Start-Process $ngen.Path -ArgumentList "executeQueuedItems"    -NoNewWindow -Wait -ErrorAction SilentlyContinue
            $ngenDone++
        } catch { }
    }
    Write-Host "  [OK] NGEN recompiled $ngenDone runtime(s)." -ForegroundColor Green
    Add-ReportEntry ".NET Repair" "NGEN Recompile (all versions)" "SUCCESS" "$ngenDone runtimes recompiled"

    # إعادة تسجيل ASP.NET (لو موجود)
    $aspnetPaths = @(
        "$env:windir\Microsoft.NET\Framework64\v4.0.30319\aspnet_regiis.exe",
        "$env:windir\Microsoft.NET\Framework\v4.0.30319\aspnet_regiis.exe"
    )
    foreach ($asp in $aspnetPaths) {
        if (Test-Path $asp) {
            try {
                Start-Process $asp -ArgumentList "-iru" -NoNewWindow -Wait -ErrorAction SilentlyContinue
                Write-Host "  [OK] ASP.NET re-registered: $asp" -ForegroundColor Green
                Add-ReportEntry ".NET Repair" "ASP.NET Registration" "SUCCESS" $asp
            } catch {
                Add-ReportEntry ".NET Repair" "ASP.NET Registration" "WARNING" $_.Exception.Message
            }
        }
    }

    # إصلاح GAC (Global Assembly Cache) - فحص سلامة الـ assemblies
    Write-Host "  Verifying GAC integrity..." -ForegroundColor Gray
    try {
        $gacPaths = @(
            "$env:windir\assembly",
            "$env:windir\Microsoft.NET\assembly"
        )
        $gacIssues = 0
        foreach ($gacPath in $gacPaths) {
            if (Test-Path $gacPath) {
                $broken = Get-ChildItem $gacPath -Recurse -Filter "*.dll" -ErrorAction SilentlyContinue |
                    Where-Object { $_.Length -eq 0 }
                $gacIssues += $broken.Count
                $broken | Remove-Item -Force -ErrorAction SilentlyContinue
            }
        }
        if ($gacIssues -gt 0) {
            Write-Host "  [WARN] Removed $gacIssues empty/corrupt DLL(s) from GAC." -ForegroundColor Yellow
            Add-ReportEntry ".NET Repair" "GAC Integrity Check" "WARNING" "Removed $gacIssues broken assemblies"
        } else {
            Write-Host "  [OK] GAC integrity OK." -ForegroundColor Green
            Add-ReportEntry ".NET Repair" "GAC Integrity Check" "SUCCESS" "No broken assemblies found"
        }
    } catch {
        Add-ReportEntry ".NET Repair" "GAC Integrity Check" "WARNING" $_.Exception.Message
    }

    # تفعيل .NET 3.5 لو معلط (كتير من البرامج القديمة محتاجاه)
    Write-Host "  Checking .NET 3.5 status..." -ForegroundColor Gray
    try {
        $net35 = Get-WindowsOptionalFeature -Online -FeatureName "NetFx3" -ErrorAction SilentlyContinue
        if ($net35 -and $net35.State -ne "Enabled") {
            Write-Host "  Enabling .NET Framework 3.5..." -ForegroundColor Yellow
            Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3" -All -NoRestart -ErrorAction SilentlyContinue | Out-Null
            Write-Host "  [OK] .NET 3.5 enabled." -ForegroundColor Green
            Add-ReportEntry ".NET Repair" ".NET 3.5 Enable" "SUCCESS"
        } else {
            Write-Host "  [OK] .NET 3.5 already enabled." -ForegroundColor Green
            Add-ReportEntry ".NET Repair" ".NET 3.5 Status" "SUCCESS" "Already enabled"
        }
    } catch {
        Add-ReportEntry ".NET Repair" ".NET 3.5 Enable" "WARNING" $_.Exception.Message
    }

    # إعادة ضبط Environment Variables الخاصة بـ .NET
    try {
        $dotnetRoot64 = "$env:windir\Microsoft.NET\Framework64\v4.0.30319"
        $dotnetRoot86 = "$env:windir\Microsoft.NET\Framework\v4.0.30319"
        $currentPath  = [System.Environment]::GetEnvironmentVariable("PATH","Machine")
        $changed = $false
        foreach ($dp in @($dotnetRoot64, $dotnetRoot86)) {
            if ((Test-Path $dp) -and $currentPath -notlike "*$dp*") {
                $currentPath += ";$dp"
                $changed = $true
            }
        }
        if ($changed) {
            [System.Environment]::SetEnvironmentVariable("PATH", $currentPath, "Machine")
            Write-Host "  [OK] .NET paths added to system PATH." -ForegroundColor Green
            Add-ReportEntry ".NET Repair" "PATH Environment Fix" "SUCCESS" "Added .NET dirs to PATH"
        } else {
            Add-ReportEntry ".NET Repair" "PATH Environment Fix" "INFO" "Already in PATH"
        }
    } catch {
        Add-ReportEntry ".NET Repair" "PATH Environment Fix" "WARNING" $_.Exception.Message
    }
}

# ==========================================
# 11. إصلاح متجر ويندوز وتطبيقات UWP (آمن افتراضيًا)
# ==========================================
Function Invoke-UWPStoreRepair {
    [CmdletBinding()]
    param(
        [switch]$ForceReRegisterAllApps
    )

    Write-Host "  Starting safe Windows Store + UWP repair..." -ForegroundColor Yellow

    # 1. إيقاف خدمات المتجر
    Write-Host "  Stopping Store services..." -ForegroundColor Gray
    $storeServices = @("wsappx","InstallService","wlidsvc","ClipSVC")
    foreach ($svc in $storeServices) {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2

    # 2. مسح cache المتجر بشكل محدود لتجنب تعطيل التطبيقات المثبتة من المتجر
    Write-Host "  Clearing Store cache..." -ForegroundColor Gray
    $cachePaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalCache",
        "$env:TEMP\WinStore"
    )
    foreach ($cp in $cachePaths) {
        if (Test-Path $cp) {
            Get-ChildItem $cp -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }
    }

    # 3. wsreset
    Write-Host "  Running wsreset..." -ForegroundColor Gray
    try {
        Start-Process "wsreset.exe" -NoNewWindow -Wait -ErrorAction SilentlyContinue
        Write-Host "  [OK] wsreset done." -ForegroundColor Green
    } catch { }

    # 4. إعادة تسجيل المتجر فقط بشكل افتراضي، مع إمكانية إعادة تسجيل كل UWP عند الطلب
    if ($ForceReRegisterAllApps) {
        Write-Host "  Force mode enabled: re-registering all installed UWP apps..." -ForegroundColor Yellow
        $targetPackages = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.InstallLocation })
        $targetDescription = "all installed UWP apps"
    } else {
        Write-Host "  Safe mode enabled: re-registering Microsoft Store only..." -ForegroundColor Yellow
        $targetPackages = @(Get-AppxPackage -Name "Microsoft.WindowsStore" -AllUsers -ErrorAction SilentlyContinue)
        $targetDescription = "Microsoft Store package"
    }

    $uwpCount = 0
    $uwpFailed = 0
    foreach ($pkg in $targetPackages) {
        $manifest = Join-Path $pkg.InstallLocation "AppxManifest.xml"
        if (Test-Path $manifest) {
            try {
                Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction SilentlyContinue
                $uwpCount++
            } catch { $uwpFailed++ }
        }
    }
    Write-Host "  [OK] Re-registered $uwpCount $targetDescription item(s) ($uwpFailed failed)." -ForegroundColor Green
    Add-ReportEntry "Store/UWP" "UWP Re-registration" "SUCCESS" "$uwpCount re-registered ($targetDescription), $uwpFailed failed"

    # 5. إصلاح تطبيقات UWP التالفة (Provisioned)
    Write-Host "  Checking for missing provisioned packages..." -ForegroundColor Gray
    try {
        $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
        Add-ReportEntry "Store/UWP" "Provisioned Packages Check" "INFO" "Found $($provisioned.Count) provisioned packages"
    } catch {
        Add-ReportEntry "Store/UWP" "Provisioned Packages Check" "WARNING" $_.Exception.Message
    }

    # 6. إعادة تسجيل متجر ويندوز نفسه بشكل خاص
    Write-Host "  Re-registering Windows Store specifically..." -ForegroundColor Gray
    try {
        $storePkg = Get-AppxPackage -Name "Microsoft.WindowsStore" -ErrorAction SilentlyContinue
        if ($storePkg) {
            $storeManifest = Join-Path $storePkg.InstallLocation "AppxManifest.xml"
            if (Test-Path $storeManifest) {
                Add-AppxPackage -DisableDevelopmentMode -Register $storeManifest -ErrorAction SilentlyContinue
                Write-Host "  [OK] Windows Store re-registered." -ForegroundColor Green
                Add-ReportEntry "Store/UWP" "Windows Store Re-register" "SUCCESS"
            }
        } else {
            Write-Host "  [WARN] Windows Store package not found." -ForegroundColor Yellow
            Add-ReportEntry "Store/UWP" "Windows Store Re-register" "WARNING" "Package not found"
        }
    } catch {
        Add-ReportEntry "Store/UWP" "Windows Store Re-register" "WARNING" $_.Exception.Message
    }

    # 7. إعادة تشغيل خدمات المتجر
    Write-Host "  Restarting Store services..." -ForegroundColor Gray
    foreach ($svc in $storeServices) {
        Start-Service -Name $svc -ErrorAction SilentlyContinue
    }

    # 8. إصلاح AppX Deployment Service
    try {
        Set-Service -Name "AppXSvc" -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name "AppXSvc" -ErrorAction SilentlyContinue
        Write-Host "  [OK] AppX Deployment Service restarted." -ForegroundColor Green
        Add-ReportEntry "Store/UWP" "AppX Deployment Service" "SUCCESS"
    } catch {
        Add-ReportEntry "Store/UWP" "AppX Deployment Service" "WARNING" $_.Exception.Message
    }

    Write-Host "  [OK] Store/UWP repair complete." -ForegroundColor Green
}

# ==========================================
# 11.b Repair Installed Microsoft Apps (menu option)
# ==========================================
Function Invoke-RepairInstalledApps {
    Write-Host "  Repairing installed Microsoft Store apps..." -ForegroundColor Yellow

    if ($global:AnalysisOnly) {
        Add-ReportEntry "Apps" "Installed Apps Repair" "INFO" "Analysis-only mode: would repair Microsoft Store apps"
        return
    }

    # Target Microsoft-published Appx packages only to reduce risk
    try {
        $packages = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Where-Object { $_.Publisher -match 'CN=Microsoft' -or $_.Name -match 'Microsoft' }
    } catch {
        Add-ReportEntry "Apps" "Installed Apps Repair" "FAILED" "Failed to enumerate Appx packages: $($_.Exception.Message)"
        return
    }

    $repaired = 0
    $failed   = 0
    foreach ($pkg in $packages) {
        $manifest = Join-Path $pkg.InstallLocation "AppxManifest.xml"
        if ($pkg.InstallLocation -and (Test-Path $manifest)) {
            try {
                Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction Stop
                $repaired++
                Write-Host "    [OK] Re-registered: $($pkg.Name)" -ForegroundColor Green
            } catch {
                $failed++
                Write-Host "    [FAIL] $($pkg.Name): $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
            # If no manifest path, skip; many system packages cannot be re-registered safely
            Write-Host "    [SKIP] $($pkg.Name) (no manifest)" -ForegroundColor DarkGray
        }
    }

    Write-Host "  [OK] Repaired $repaired apps, $failed failed/skipped." -ForegroundColor Green
    Add-ReportEntry "Apps" "Installed Apps Repair" "SUCCESS" "Repaired $repaired apps, $failed failed/skipped"
}

# ==========================================
# 12. إصلاح WMI Repository
# ==========================================
Function Invoke-WMIRepair {
    Write-Host "  Repairing WMI Repository..." -ForegroundColor Yellow

    # 1. فحص سلامة الـ WMI أولاً
    Write-Host "  Verifying WMI consistency..." -ForegroundColor Gray
    $verifyOut = & winmgmt /verifyrepository 2>&1 | Out-String
    Write-Host "  WMI status: $($verifyOut.Trim())" -ForegroundColor Gray

    if ($verifyOut -match "inconsistent" -or $verifyOut -match "not consistent") {
        Write-Host "  [WARN] WMI repository is inconsistent. Attempting repair..." -ForegroundColor Yellow

        # 2. إيقاف خدمة WMI
        Write-Host "  Stopping WMI service..." -ForegroundColor Gray
        Stop-Service -Name winmgmt -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3

        # 3. إعادة بناء الـ Repository
        Write-Host "  Rebuilding WMI repository (salvagerepository)..." -ForegroundColor Yellow
        $salvageOut = & winmgmt /salvagerepository 2>&1 | Out-String
        Write-Host "  Salvage result: $($salvageOut.Trim())" -ForegroundColor Gray

        # 4. لو فشل salvage -> resetrepository (أقوى لكن بيمسح كل حاجة)
        $verifyAfter = & winmgmt /verifyrepository 2>&1 | Out-String
        if ($verifyAfter -match "inconsistent") {
            Write-Host "  Salvage failed. Trying full reset (resetrepository)..." -ForegroundColor Red
            & winmgmt /resetrepository 2>&1 | Out-Null
            Add-ReportEntry "WMI" "WMI Repository Reset (Full)" "WARNING" "Salvage failed, full reset performed"
        } else {
            Add-ReportEntry "WMI" "WMI Repository Salvage" "SUCCESS" "Repository salvaged successfully"
        }

        # 5. إعادة تشغيل الخدمة
        Start-Service -Name winmgmt -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2

    } else {
        Write-Host "  [OK] WMI repository is consistent." -ForegroundColor Green
        Add-ReportEntry "WMI" "WMI Consistency Check" "SUCCESS" "Repository consistent"
    }

    # 6. إعادة تسجيل MOF files (إعادة بناء Schema)
    Write-Host "  Re-registering WMI MOF/MFL files..." -ForegroundColor Yellow
    $mofCount  = 0
    $mofFailed = 0
    $mofPaths  = @(
        "$env:windir\System32\wbem",
        "$env:windir\SysWOW64\wbem"
    )
    foreach ($mofPath in $mofPaths) {
        if (Test-Path $mofPath) {
            Get-ChildItem $mofPath -Filter "*.mof" -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    & mofcomp $_.FullName 2>&1 | Out-Null
                    $mofCount++
                } catch { $mofFailed++ }
            }
            Get-ChildItem $mofPath -Filter "*.mfl" -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    & mofcomp $_.FullName 2>&1 | Out-Null
                    $mofCount++
                } catch { $mofFailed++ }
            }
        }
    }
    Write-Host "  [OK] MOF/MFL re-registered: $mofCount files ($mofFailed failed)." -ForegroundColor Green
    Add-ReportEntry "WMI" "MOF/MFL Re-registration" "SUCCESS" "$mofCount files recompiled, $mofFailed failed"

    # 7. إعادة تسجيل WMI DLLs
    Write-Host "  Re-registering WMI DLLs..." -ForegroundColor Gray
    try {
        $wmiDlls = @("wbemcore.dll","wbemess.dll","wmisvc.dll","fastprox.dll","wbemsvc.dll")
        foreach ($dll in $wmiDlls) {
            $dllPath = "$env:windir\System32\wbem\$dll"
            if (Test-Path $dllPath) {
                & regsvr32 /s $dllPath 2>&1 | Out-Null
            }
        }
        Write-Host "  [OK] WMI DLLs re-registered." -ForegroundColor Green
        Add-ReportEntry "WMI" "WMI DLL Registration" "SUCCESS"
    } catch {
        Add-ReportEntry "WMI" "WMI DLL Registration" "WARNING" $_.Exception.Message
    }

    # 8. فحص أخير
    $finalVerify = & winmgmt /verifyrepository 2>&1 | Out-String
    if ($finalVerify -match "consistent") {
        Write-Host "  [OK] WMI repair complete. Repository is consistent." -ForegroundColor Green
        Add-ReportEntry "WMI" "Final WMI Verification" "SUCCESS" $finalVerify.Trim()
    } else {
        Write-Host "  [WARN] WMI may still have issues. A reboot is recommended." -ForegroundColor Yellow
        Add-ReportEntry "WMI" "Final WMI Verification" "WARNING" "Reboot recommended"
    }
}

# ==========================================
# 13. تحديث وتثبيت التعريفات (Drivers)
# ==========================================
Function Invoke-DriverUpdate {
    Write-Host "  Scanning and updating drivers..." -ForegroundColor Yellow

    # 0. باك أب لكل الدرايفرات الحالية قبل أي تحديث (يسمح بعمل Rollback لو حصلت مشكلة)
    Write-Host "  Backing up current drivers before update..." -ForegroundColor Yellow
    try {
        if (!(Test-Path "C:\backup")) { New-Item -Path "C:\backup" -ItemType Directory -Force | Out-Null }
        $driverBackupPath = "C:\backup\DriverBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -Path $driverBackupPath -ItemType Directory -Force | Out-Null
        Export-WindowsDriver -Online -Destination $driverBackupPath -ErrorAction Stop | Out-Null
        Write-Host "  [OK] Driver backup saved: $driverBackupPath" -ForegroundColor Green
        Add-ReportEntry "Drivers" "Driver Backup" "SUCCESS" "Backed up to $driverBackupPath"
        # نخزن آخر مسار باك أب في ملف مرجعي عشان خيار الـ Rollback يلاقيه
        Set-Content -Path "C:\backup\LastDriverBackup.txt" -Value $driverBackupPath -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {
        Write-Host "  [WARN] Driver backup failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Add-ReportEntry "Drivers" "Driver Backup" "WARNING" $_.Exception.Message
    }

    # 1. جمع معلومات الـ drivers الحالية
    Write-Host "  Collecting installed driver information..." -ForegroundColor Gray
    try {
        $allDrivers = Get-WmiObject Win32_PnPSignedDriver -ErrorAction SilentlyContinue |
            Where-Object { $null -ne $_.DeviceName } |
            Select-Object DeviceName, DriverVersion, DriverDate, Manufacturer
        Write-Host "  Found $($allDrivers.Count) installed drivers." -ForegroundColor Gray
        Add-ReportEntry "Drivers" "Driver Inventory" "INFO" "Found $($allDrivers.Count) drivers"
    } catch {
        Add-ReportEntry "Drivers" "Driver Inventory" "WARNING" $_.Exception.Message
    }

    # 2. فحص الأجهزة اللي عندها مشاكل (Problem Devices)
    Write-Host "  Checking for problem devices..." -ForegroundColor Yellow
    try {
        $problemDevices = Get-WmiObject Win32_PnPEntity -ErrorAction SilentlyContinue |
            Where-Object { $_.ConfigManagerErrorCode -ne 0 } |
            Select-Object Name, ConfigManagerErrorCode, DeviceID
        if ($problemDevices -and $problemDevices.Count -gt 0) {
            Write-Host "  [WARN] Found $($problemDevices.Count) problem device(s):" -ForegroundColor Yellow
            foreach ($dev in $problemDevices) {
                Write-Host "    - $($dev.Name) (Error: $($dev.ConfigManagerErrorCode))" -ForegroundColor Red
                Add-ReportEntry "Drivers" "Problem Device: $($dev.Name)" "WARNING" "Error code: $($dev.ConfigManagerErrorCode)"
            }
        } else {
            Write-Host "  [OK] No problem devices found." -ForegroundColor Green
            Add-ReportEntry "Drivers" "Problem Devices Check" "SUCCESS" "No issues found"
        }
    } catch {
        Add-ReportEntry "Drivers" "Problem Devices Check" "WARNING" $_.Exception.Message
    }

    # 3. تحديث التعريفات عبر Windows Update (pnputil + wuauclt)
    Write-Host "  Triggering Windows Update driver scan..." -ForegroundColor Yellow
    try {
        # إجبار Windows Update على البحث عن driver updates
        & wuauclt /detectnow 2>&1 | Out-Null
        Start-Sleep -Seconds 3
        & wuauclt /updatenow 2>&1 | Out-Null
        Write-Host "  [OK] Windows Update driver scan triggered." -ForegroundColor Green
        Add-ReportEntry "Drivers" "Windows Update Driver Scan" "SUCCESS" "Scan triggered via wuauclt"
    } catch {
        Add-ReportEntry "Drivers" "Windows Update Driver Scan" "WARNING" $_.Exception.Message
    }

    # 4. استخدام UsoClient (Windows 10/11 الحديثة)
    try {
        & UsoClient StartScan 2>&1 | Out-Null
        Start-Sleep -Seconds 5
        & UsoClient StartDownload 2>&1 | Out-Null
        & UsoClient StartInstall  2>&1 | Out-Null
        Write-Host "  [OK] UsoClient update cycle started." -ForegroundColor Green
        Add-ReportEntry "Drivers" "UsoClient Driver Update" "SUCCESS" "Scan+Download+Install triggered"
    } catch {
        Add-ReportEntry "Drivers" "UsoClient Driver Update" "WARNING" "UsoClient not available or failed"
    }

    # 5. تثبيت التعريفات المتاحة محلياً عبر pnputil (من driver store)
    Write-Host "  Installing cached drivers from DriverStore..." -ForegroundColor Yellow
    try {
        $driverStore = "$env:windir\System32\DriverStore\FileRepository"
        if (Test-Path $driverStore) {
            $infFiles = Get-ChildItem $driverStore -Filter "*.inf" -Recurse -ErrorAction SilentlyContinue
            $installed = 0
            $failed    = 0
            foreach ($inf in $infFiles) {
                $result = & pnputil /add-driver $inf.FullName /install 2>&1 | Out-String
                if ($result -match "Successfully" -or $result -match "The operation completed") {
                    $installed++
                } else {
                    $failed++
                }
            }
            Write-Host "  [OK] DriverStore: $installed installed, $failed skipped/failed." -ForegroundColor Green
            Add-ReportEntry "Drivers" "DriverStore Install (pnputil)" "SUCCESS" "$installed installed, $failed failed"
        }
    } catch {
        Add-ReportEntry "Drivers" "DriverStore Install" "WARNING" $_.Exception.Message
    }

    # 6. إعادة تشغيل خدمة الـ Plug and Play
    try {
        Restart-Service -Name PlugPlay -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Plug and Play service restarted." -ForegroundColor Green
        Add-ReportEntry "Drivers" "Plug and Play Restart" "SUCCESS"
    } catch {
        Add-ReportEntry "Drivers" "Plug and Play Restart" "WARNING" $_.Exception.Message
    }

    Write-Host "  [OK] Driver update process complete." -ForegroundColor Green
    Write-Host "  NOTE: Some driver updates may require a reboot to take effect." -ForegroundColor Yellow
}

Function Invoke-DriverRollback {
    Write-Host "  Driver Rollback" -ForegroundColor Yellow

    $lastBackupRef = "C:\backup\LastDriverBackup.txt"
    $backupPath = $null

    if (Test-Path $lastBackupRef) {
        $suggested = (Get-Content $lastBackupRef -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($suggested -and (Test-Path $suggested)) {
            Write-Host "  Found last driver backup: $suggested" -ForegroundColor Cyan
            $useIt = Read-Host "  Restore from this backup? (y/n)"
            if ($useIt -eq 'y') { $backupPath = $suggested }
        }
    }

    if (-not $backupPath) {
        $backupPath = Read-Host "  Enter the full path of the driver backup folder"
    }

    if (-not (Test-Path $backupPath)) {
        Write-Host "  [FAIL] Backup path not found: $backupPath" -ForegroundColor Red
        Add-ReportEntry "Drivers" "Driver Rollback" "FAILED" "Backup path not found: $backupPath"
        return
    }

    try {
        $infFiles = Get-ChildItem $backupPath -Filter "*.inf" -Recurse -ErrorAction SilentlyContinue
        if (-not $infFiles -or $infFiles.Count -eq 0) {
            Write-Host "  [WARN] No .inf driver files found in backup." -ForegroundColor Yellow
            Add-ReportEntry "Drivers" "Driver Rollback" "WARNING" "No .inf files found in $backupPath"
            return
        }

        $restored = 0
        $failed   = 0
        foreach ($inf in $infFiles) {
            $result = & pnputil /add-driver $inf.FullName /install 2>&1 | Out-String
            if ($result -match "Successfully" -or $result -match "The operation completed") { $restored++ }
            else { $failed++ }
        }

        Write-Host "  [OK] Driver rollback: $restored restored, $failed failed/skipped." -ForegroundColor Green
        Add-ReportEntry "Drivers" "Driver Rollback" "SUCCESS" "Restored $restored drivers from $backupPath ($failed failed/skipped)"
        Write-Host "  NOTE: A reboot may be required for restored drivers to take effect." -ForegroundColor Yellow
    } catch {
        Write-Host "  [FAIL] Rollback failed: $($_.Exception.Message)" -ForegroundColor Red
        Add-ReportEntry "Drivers" "Driver Rollback" "FAILED" $_.Exception.Message
    }
}

# ==========================================
# 14. توليد التقرير HTML
# ==========================================
Function Export-HtmlReport {
    $endTime   = Get-Date
    $duration  = [math]::Round(($endTime - $global:ReportStartTime).TotalMinutes, 1)
    $reportPath = "$env:USERPROFILE\Desktop\RepairReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"

$successCount = @($global:ReportData | Where-Object { $_.Status -eq "SUCCESS" }).Count
$warnCount    = @($global:ReportData | Where-Object { $_.Status -eq "WARNING" }).Count
$failCount    = @($global:ReportData | Where-Object { $_.Status -eq "FAILED"  }).Count
$infoCount    = @($global:ReportData | Where-Object { $_.Status -eq "INFO"    }).Count

    $sysInfo = $global:SystemInfo

    $rowsHtml = ""
    foreach ($entry in $global:ReportData) {
        $color = switch ($entry.Status) {
            "SUCCESS" { "#d4edda" }
            "WARNING" { "#fff3cd" }
            "FAILED"  { "#f8d7da" }
            default   { "#e2e3e5" }
        }
        $badge = switch ($entry.Status) {
            "SUCCESS" { "<span style='background:#28a745;color:#fff;padding:2px 8px;border-radius:12px;font-size:12px'>✔ SUCCESS</span>" }
            "WARNING" { "<span style='background:#ffc107;color:#212529;padding:2px 10px;border-radius:14px;font-size:12px'>⚠ WARNING</span>" }
            "FAILED"  { "<span style='background:#dc3545;color:#fff;padding:2px 8px;border-radius:12px;font-size:12px'>✘ FAILED</span>"  }
            default   { "<span style='background:#6c757d;color:#fff;padding:2px 8px;border-radius:12px;font-size:12px'>ℹ INFO</span>"    }
        }
       $rowsHtml += "<tr style='background:$color; color: #1a1a2e; font-weight: 500;'><td>$($entry.Time)</td><td>$($entry.Section)</td><td>$($entry.Task)</td><td>$badge</td><td>$($entry.Detail)</td></tr>`n"
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Windows Repair Report</title>
<style>
  body { font-family: Segoe UI, sans-serif; background: #1a1a2e; color: #e0e0e0; margin: 0; padding: 20px; }
  h1   { text-align:center; color:#00d4ff; letter-spacing:2px; margin-bottom:5px; }
  .subtitle { text-align:center; color:#888; margin-bottom:30px; font-size:14px; }
  .cards { display:flex; gap:15px; justify-content:center; flex-wrap:wrap; margin-bottom:30px; }
  .card { background:#16213e; border-radius:12px; padding:20px 30px; text-align:center; min-width:130px; box-shadow:0 4px 15px rgba(0,0,0,0.3); }
  .card .num { font-size:36px; font-weight:bold; }
  .card .lbl { font-size:13px; color:#aaa; margin-top:5px; }
  .green  { color:#28a745; }
  .yellow { color:#ffc107; }
  .red    { color:#dc3545; }
  .blue   { color:#17a2b8; }
  .sysbox { background:#16213e; border-radius:12px; padding:20px; margin-bottom:25px; display:grid; grid-template-columns:repeat(auto-fit,minmax(200px,1fr)); gap:10px; }
  .sysitem { background:#0f3460; border-radius:8px; padding:10px 15px; }
  .sysitem .key { font-size:11px; color:#aaa; text-transform:uppercase; }
  .sysitem .val { font-size:15px; font-weight:600; color:#00d4ff; margin-top:3px; }
  table  { width:100%; border-collapse:collapse; background:#16213e; border-radius:12px; overflow:hidden; box-shadow:0 4px 15px rgba(0,0,0,0.3); }
  th     { background:#0f3460; color:#00d4ff; padding:12px 15px; text-align:left; font-size:13px; letter-spacing:1px; }
  td     { padding:10px 15px; font-size:13px; border-bottom:1px solid #1a1a2e; }
  tr:last-child td { border-bottom:none; }
  .footer { text-align:center; margin-top:20px; color:#555; font-size:12px; }
</style>
</head>
<body>
<h1>🛠 Windows Repair Report</h1>
<div class="subtitle">Generated: $(Get-Date -Format "dddd, MMMM dd yyyy — HH:mm:ss") &nbsp;|&nbsp; Duration: ${duration} min</div>

<div class="cards">
  <div class="card"><div class="num green">$successCount</div><div class="lbl">Success</div></div>
  <div class="card"><div class="num yellow">$warnCount</div><div class="lbl">Warnings</div></div>
  <div class="card"><div class="num red">$failCount</div><div class="lbl">Failed</div></div>
  <div class="card"><div class="num blue">$infoCount</div><div class="lbl">Info</div></div>
</div>

<div class="sysbox">
  <div class="sysitem"><div class="key">Hostname</div><div class="val">$($sysInfo.Hostname)</div></div>
  <div class="sysitem"><div class="key">User</div><div class="val">$($sysInfo.User)</div></div>
  <div class="sysitem"><div class="key">OS</div><div class="val">$($sysInfo.OS)</div></div>
  <div class="sysitem"><div class="key">Build</div><div class="val">$($sysInfo.Build)</div></div>
  <div class="sysitem"><div class="key">CPU</div><div class="val">$($sysInfo.CPU)</div></div>
  <div class="sysitem"><div class="key">RAM</div><div class="val">$($sysInfo.RAM_GB) GB</div></div>
  <div class="sysitem"><div class="key">Drive Type</div><div class="val">$($sysInfo.DriveType)</div></div>
  <div class="sysitem"><div class="key">Disk Free</div><div class="val">$($sysInfo.DiskFree) / $($sysInfo.DiskTotal) GB</div></div>
</div>

<table>
<tr><th>Time</th><th>Section</th><th>Task</th><th>Status</th><th>Details</th></tr>
$rowsHtml
</table>
<div class="footer">Windows Repair & Optimization Tool v13.0 — PANDA</div>
</body>
</html>
"@

    $html | Set-Content -Path $reportPath -Encoding UTF8
    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Cyan
    Write-Host "  Report saved to: $reportPath" -ForegroundColor Green
    Write-Host "  ============================================" -ForegroundColor Cyan
    Start-Process $reportPath
}

# ==========================================
# 15. القائمة الرئيسية
# ==========================================

Get-SystemInfo

do {
    Clear-Host
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "  Windows Repair & Optimization Tool v13.0 " -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host " 1. Full Auto Repair (Recommended)         " -ForegroundColor White
    Write-Host " 2. Advanced System Repair (Manual)        " -ForegroundColor White
    Write-Host " 3. Update Apps via Winget                 " -ForegroundColor White
    Write-Host " 4. Export HTML Report                     " -ForegroundColor White
    Write-Host " 5. Check my PC                            " -ForegroundColor Cyan
    Write-Host " 0. Exit                                   " -ForegroundColor White
    Write-Host "============================================" -ForegroundColor Cyan

    $selection = if ($AutoSelect -gt 0) { [string]$AutoSelect } else { Read-Host "Choice" }
    $autoMode = $AutoSelect -gt 0

    switch ($selection) {

        # ==========================================
        # خيار 1: Full Auto Repair - تم دمج الدوال المفقودة هنا بالترتيب
        # ==========================================
        '1' {
            Clear-Host
            Write-Host "============================================" -ForegroundColor Green
            Write-Host "   Starting Full Auto Repair...            " -ForegroundColor Green
            Write-Host "   Please wait. This may take 15-60 min.  " -ForegroundColor Yellow
            Write-Host "============================================" -ForegroundColor Green
            Start-Sleep -Seconds 2

            Invoke-AdvancedHealthScan -Mode 'Expert'

            $steps = @(
                @{ Name="Restore Point";             Fn={ Invoke-RestorePoint } },
                @{ Name="Windows Update Repair";     Fn={ Invoke-WindowsUpdateRepair } },
                @{ Name="SFC + DISM";                Fn={ Invoke-SystemRepair } },
                @{ Name="WMI Repository Repair";     Fn={ Invoke-WMIRepair } },             # تم إضافتها
                @{ Name="Disk Check (scheduled)";    Fn={ Invoke-DiskRepair } },
                @{ Name="Disk Cleanup + Optimize";   Fn={ Invoke-DiskCleanup } },
                @{ Name="Network Reset + DNS";       Fn={ Invoke-NetworkRepair } },
                @{ Name="Boot Repair";               Fn={ Invoke-BootRepair } },
                @{ Name="Store Cache Reset";         Fn={ Invoke-AppStoreReset } },
                @{ Name="Safe Store Repair";         Fn={ Invoke-UWPStoreRepair } },        # تم إضافتها
                @{ Name="Permissions Repair";        Fn={ Invoke-PermissionsRepair } },
                @{ Name="Registry Cleanup";          Fn={ Invoke-RegistryCleanup } },
                @{ Name="Startup Manager";           Fn={ Invoke-StartupManager } },
                @{ Name="Services Repair";           Fn={ Invoke-ServicesRepair } },
                @{ Name="Driver Updates Scan";       Fn={ Invoke-DriverUpdate } },          # تم إضافتها
                @{ Name="Performance Optimization";  Fn={ Invoke-PerformanceOptimization } },
                @{ Name="App Startup Fix";           Fn={ Invoke-AppStartupFix } },
                @{ Name=".NET Framework Repair";     Fn={ Invoke-DotNetRepair } }           # تم إضافتها
            )

            $total = $steps.Count
            $i = 0
            foreach ($step in $steps) {
                $i++
                Write-Host ""
                Write-Host "[$i/$total] $($step.Name)" -ForegroundColor Cyan
                Write-Host "--------------------------------------------" -ForegroundColor DarkGray
                & $step.Fn
            }

            Write-Host ""
            Write-Host "============================================" -ForegroundColor Green
            Write-Host "   ALL REPAIRS COMPLETED!                  " -ForegroundColor Green
            Write-Host "   Generating HTML Report...               " -ForegroundColor Cyan
            Write-Host "============================================" -ForegroundColor Green
            Export-HtmlReport
            Write-Host "   A SYSTEM RESTART IS RECOMMENDED.        " -ForegroundColor Yellow
            if (-not $autoMode) { Pause }
        }

        # ==========================================
        # خيار 2: Manual - تم إضافة الدوال المفقودة كخيارات من 17 لـ 20
        # ==========================================
        '2' {
            do {
                Clear-Host
                Write-Host "============================================" -ForegroundColor Cyan
                Write-Host "       Advanced System Repair              " -ForegroundColor Cyan
                Write-Host "============================================" -ForegroundColor Cyan
                Write-Host " 1.  Restore Point                         " -ForegroundColor White
                Write-Host " 2.  Windows Update Repair                 " -ForegroundColor White
                Write-Host " 3.  SFC + DISM                            " -ForegroundColor White
                Write-Host " 4.  Disk Check (/f /r - needs reboot)     " -ForegroundColor White
                Write-Host " 5.  Disk Cleanup + Optimize               " -ForegroundColor White
                Write-Host " 6.  Network Reset + DNS Benchmark         " -ForegroundColor White
                Write-Host " 7.  Boot Repair (BCD)                     " -ForegroundColor White
                Write-Host " 8.  Windows Store Reset                   " -ForegroundColor White
                Write-Host " 9.  Full Network Reset (Reboot!)          " -ForegroundColor Red
                Write-Host "10.  Permissions Repair (icacls)           " -ForegroundColor White
                Write-Host "11.  Malware Scan (Defender)               " -ForegroundColor White
                Write-Host "12.  Registry Cleanup                      " -ForegroundColor White
                Write-Host "13.  Startup Manager                       " -ForegroundColor White
                Write-Host "14.  Services Repair                       " -ForegroundColor White
                Write-Host "15.  Performance Optimization              " -ForegroundColor White
                Write-Host "16.  App Startup Fix (.NET/IO/Prefetch)    " -ForegroundColor White
                Write-Host "17.  Safe Windows Store Repair            " -ForegroundColor Yellow   # خيار جديد
                Write-Host "18.  WMI Repository Repair                 " -ForegroundColor Yellow   # خيار جديد
                Write-Host "19.  Scan & Update Drivers                 " -ForegroundColor Yellow   # خيار جديد
                Write-Host "20.  .NET Framework Environment Repair     " -ForegroundColor Yellow   # خيار جديد
                Write-Host "21.  Restore Drivers from Backup           " -ForegroundColor Yellow   # خيار جديد
                Write-Host "22.  Remove Bloatware / PUP Programs       " -ForegroundColor Yellow   # خيار جديد
                Write-Host "23.  Repair Installed Microsoft Apps       " -ForegroundColor Yellow   # خيار جديد
                Write-Host " 0.  Back                                  " -ForegroundColor White
                Write-Host "============================================" -ForegroundColor Cyan

                $repairChoice = Read-Host "Choice"
                Clear-Host

                switch ($repairChoice) {
                    '1'  { Invoke-RestorePoint }
                    '2'  { Invoke-WindowsUpdateRepair }
                    '3'  { Invoke-SystemRepair }
                    '4'  { Invoke-DiskRepair }
                    '5'  { Invoke-DiskCleanup }
                    '6'  { Invoke-NetworkRepair }
                    '7'  { Invoke-BootRepair }
                    '8'  { Invoke-AppStoreReset }
                    '9'  { Invoke-FullNetworkReset }
                    '10' { Invoke-PermissionsRepair }
                    '11' { Invoke-MalwareScan }
                    '12' { Invoke-RegistryCleanup }
                    '13' { Invoke-StartupManager }
                    '14' { Invoke-ServicesRepair }
                    '15' { Invoke-PerformanceOptimization }
                    '16' { Invoke-AppStartupFix }
                    '17' { Invoke-UWPStoreRepair }         # استدعاء الدالة هنا
                    '18' { Invoke-WMIRepair }               # استدعاء الدالة هنا
                    '19' { Invoke-DriverUpdate }            # استدعاء الدالة هنا
                    '20' { Invoke-DotNetRepair }            # استدعاء الدالة هنا
                    '21' { Invoke-DriverRollback }          # خيار جديد
                    '22' { Invoke-BloatwareRemoval }        # خيار جديد
                    '23' { Invoke-RepairInstalledApps }     # خيار جديد: Repair Microsoft apps
                    '0'  { break }
                    Default { Write-Host "Invalid choice." -ForegroundColor Red; Start-Sleep -Seconds 1 }
                }
                if ($repairChoice -ne '0' -and $repairChoice -match "^\d+$" -and [int]$repairChoice -le 22) { Pause }
            } until ($repairChoice -eq '0')
        }

        # ==========================================
        # خيار 3: Winget
        # ==========================================
        '3' {
            if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                Clear-Host
                Write-Host "Winget is not installed." -ForegroundColor Red
                Start-Process "ms-windows-store://pdp/?productid=9NBLGGH4NNS1"
                Pause; continue
            }

            try { winget upgrade --id Microsoft.AppInstaller --accept-source-agreements --accept-package-agreements -h 2>&1 | Out-Null } catch {}

            do {
                Clear-Host
                Write-Host "============================================" -ForegroundColor Cyan
                Write-Host "    App Updates via Winget                 " -ForegroundColor Cyan
                Write-Host "============================================" -ForegroundColor Cyan
                Write-Host "Fetching available upgrades..." -ForegroundColor White
                Write-Host ""

                $rawOutput  = winget upgrade --include-unknown
                $lines      = $rawOutput -split "`r`n"
                $packageLines = @()
                $currentIndex = 1

                foreach ($line in $lines) {
                    $trimmed = $line.Trim()
                    if ($trimmed -eq "" -or $trimmed -match "^Name" -or $trimmed -match "^-{5,}" -or $trimmed -match "^[\\|/-]$") { continue }
                    $parts = [regex]::Split($trimmed, "\s{2,}")
                    if ($parts.Count -lt 3) { continue }
                    Write-Host "[$currentIndex] $line"
                    $packageLines += [PSCustomObject]@{ Index = $currentIndex; Line = $line }
                    $currentIndex++
                }

                if ($packageLines.Count -eq 0) {
                    Write-Host "No upgrades available." -ForegroundColor Green
                    Pause; break
                }

                Write-Host ""
                Write-Host "[1] Upgrade ALL  [2] Select by Index  [0] Cancel" -ForegroundColor Cyan
                $upopt = (Read-Host "Choice").Trim()

                switch ($upopt) {
                    "0" { break }
                    "1" {
                        winget upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements -h
                        Add-ReportEntry "Winget" "Upgrade All Packages" "SUCCESS"
                        Pause
                    }
                    "2" {
                        $selectedIndices = (Read-Host "Enter indices (e.g. 1,3,5)") -replace ' ',''
                        if ([string]::IsNullOrWhiteSpace($selectedIndices)) { Pause; continue }
                        $indicesArray = $selectedIndices.Split(",")
                        $validIndices = @()
                        foreach ($idxStr in $indicesArray) {
                            if ($idxStr -match "^\d+$") {
                                $idx = [int]$idxStr
                                if ($idx -ge 1 -and $idx -le $packageLines.Count) { $validIndices += $idx }
                                else { Write-Host "Index $idx out of range." -ForegroundColor Red }
                            }
                        }
                        foreach ($idx in $validIndices) {
                            $parts = [regex]::Split($packageLines[$idx-1].Line.Trim(), "\s{2,}")
                            if ($parts.Count -ge 2) {
                                $id = $parts[1].Trim()
                                if (-not [string]::IsNullOrWhiteSpace($id)) {
                                    Write-Host "Updating $id..." -ForegroundColor Cyan
                                    winget upgrade --id $id --include-unknown --accept-source-agreements --accept-package-agreements -h
                                    Add-ReportEntry "Winget" "Upgrade $id" "SUCCESS"
                                }
                            }
                        }
                        Pause
                    }
                    default { Write-Host "Invalid." -ForegroundColor Red; Start-Sleep -Seconds 1 }
                }
            } until ($upopt -eq '0')
        }

        # ==========================================
        # خيار 4: Export Report
        # ==========================================
        '4' {
            if ($global:ReportData.Count -eq 0) {
                Write-Host "No repair data yet. Run repairs first." -ForegroundColor Yellow
            } else {
                Export-HtmlReport
            }
            if (-not $autoMode) { Pause }
        }

        '5' {
            Invoke-CheckMyPC
            if (-not $autoMode) { Pause }
        }

        '0' {
            Write-Host "Goodbye!" -ForegroundColor Yellow
            Stop-Process -Id $PID
        }
        Default {
            Write-Host "Invalid choice." -ForegroundColor Red
            Stop-Process -Id $PID
        }
    }
} until ($selection -eq '0' -or $autoMode)