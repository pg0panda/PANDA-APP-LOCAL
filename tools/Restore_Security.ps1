<#
    .SYNOPSIS
        Automated Windows Security Recovery & Hardening Script
    .DESCRIPTION
        Automatically relaunches itself as Administrator if needed,
        restores Windows Defender policies, firewall settings,
        and updates security signatures.
#>

$ErrorActionPreference = "Continue"

# Self-elevate if not running as Administrator
$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {

    $scriptPath = $MyInvocation.MyCommand.Path

    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        Write-Host "Unable to determine script path." -ForegroundColor Red
        Pause
        exit
    }

    Start-Process `
        -FilePath "powershell.exe" `
        -Verb RunAs `
        -ArgumentList "-NoExit -ExecutionPolicy Bypass -NoProfile -File `"$scriptPath`""

    exit
}

try {
    Start-Transcript -Path "$env:TEMP\SecurityRecovery.log" -Force | Out-Null

    Clear-Host

    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "     AUTOMATED WINDOWS SECURITY RESTORE & RECOVERY      " -ForegroundColor Green
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host ""

    # 1. Remove Defender policies from Registry
    Write-Host "[1/4] Removing restrictive Defender policies..." -ForegroundColor Yellow

    $policyPaths = @(
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender",
        "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
    )

    foreach ($path in $policyPaths) {
        if (Test-Path $path) {
            try {
                # إزالة أي قيم بداخل المجلدات أولاً للتأكد من عدم ترك مخلفات قفل
                Get-Item -Path $path | Get-ItemProperty | ForEach-Object {
                    if ($_.PSChildName -ne "") {
                        Remove-ItemProperty -Path $path -Name $_.PSChildName -Force -ErrorAction SilentlyContinue
                    }
                }
                Remove-Item $path -Recurse -Force -ErrorAction Stop
                Write-Host "    Removed policy path: $path" -ForegroundColor Green
            }
            catch {
                Write-Host "    Failed to remove: $path" -ForegroundColor Red
            }
        }
    }

    # 2. Enable Firewall
    Write-Host ""
    Write-Host "[2/4] Enabling Windows Firewall (All Profiles)..." -ForegroundColor Yellow

    # تشغيل الخدمة أولاً للتأكد من قدرة الأمر على العمل
    sc.exe config mpssvc start= auto | Out-Null
    Start-Service mpssvc -ErrorAction SilentlyContinue

    netsh advfirewall set allprofiles state on | Out-Null
    Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled True -ErrorAction SilentlyContinue
    Write-Host "    Windows Advanced Firewall enabled on all profiles." -ForegroundColor Green

    # 3. Configure Defender Service
    Write-Host ""
    Write-Host "[3/4] Configuring Defender background services..." -ForegroundColor Yellow

    sc.exe config WinDefend start= auto | Out-Null
    Start-Service WinDefend -ErrorAction SilentlyContinue
    
    # تشغيل الخدمات المساعدة للحماية والبرمجيات الخبيثة
    sc.exe config WdNisSvc start= auto | Out-Null
    Start-Service WdNisSvc -ErrorAction SilentlyContinue

    # 4. Restore Defender preferences and real-time monitoring
    Write-Host ""
    Write-Host "[4/4] Restoring Defender preferences and file monitoring..." -ForegroundColor Yellow

    Import-Module Defender -ErrorAction SilentlyContinue

    if (Get-Command Set-MpPreference -ErrorAction SilentlyContinue) {

        try {
            # إعادة تفعيل مراقبة فتح الملفات، الحماية اللحظية، ومراقبة السلوك
            Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisableBehaviorMonitoring $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisableIOAVProtection $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisablePrivacyMode $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisableArchiveScanning $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisableIntrusionPreventionSystem $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisableScriptScanning $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisableScanningNetworkFiles $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisableScanningMappedNetworkDrivesForFullScan $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisableCatchupFullScan $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisableCatchupQuickScan $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisableRemovableDriveScanning $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisableEmailScanning $false -ErrorAction SilentlyContinue
            Set-MpPreference -DisableBlockAtFirstSeen $false -ErrorAction SilentlyContinue
            
            # تفعيل الحماية السحابية وإرسال العينات التلقائي لتحليل التهديدات
            Set-MpPreference -MAPSReporting 2 -ErrorAction SilentlyContinue
            Set-MpPreference -SubmitSamplesConsent 1 -ErrorAction SilentlyContinue

            Write-Host "    All Defender preferences and user monitoring systems restored." -ForegroundColor Green
        }
        catch {
            Write-Host "    Some preferences could not be automatically restored." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "    Defender module unavailable." -ForegroundColor Yellow
    }

    # تحديث تواقيع الفيروسات لضمان الفحص المباشر لأي ملفات جديدة
    Write-Host ""
    Write-Host "[*] Triggering security signatures update..." -ForegroundColor Yellow
    if (Get-Command Update-MpSignature -ErrorAction SilentlyContinue) {
        Update-MpSignature -ErrorAction SilentlyContinue
        Write-Host "    Signatures updated successfully." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Cyan
    Write-Host "                    PROCESS COMPLETED                    " -ForegroundColor Green
    Write-Host "========================================================" -ForegroundColor Cyan
}
catch {
    Write-Host "`n[!] A fatal error occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

# الانتظار حتى تضغط Enter
Write-Host "`n[i] Script execution complete." -ForegroundColor Gray
Read-Host "Press ENTER to close this window"

# قفل فوري للحظة وبدون أي تأخير نهائياً
Stop-Process -Id $PID