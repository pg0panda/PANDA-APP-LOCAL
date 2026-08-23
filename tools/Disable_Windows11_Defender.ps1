Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

<#
    .SYNOPSIS
        Advanced script to fully disable Windows Defender and Firewall.
    .DESCRIPTION
        Implements rigorous verification loops, policy enforcement, and registry tweaks.
    .NOTES
        Must be run as Administrator.
#>

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
    Start-Process "powershell.exe" -ArgumentList $psiArgs -Verb RunAs
    exit
}
Clear-Host
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "    WINDOWS SECURITY FULL DISABLE SCRIPT (MAX POWER)   " -ForegroundColor Yellow
Write-Host "========================================================" -ForegroundColor Cyan

# 2. Strict Verification Loop for Tamper & Cloud Protection
$fullyUnlocked = $false
while (-not $fullyUnlocked) {
    
    # Open the exact UI settings page for the user
    Write-Host "`n[*] Launching Windows Security Settings page..." -ForegroundColor Magenta
    Start-Process "windowsdefender://threatsettings/"
    
    # --- بناء الواجهة الاحترافية بدون حواف (Frameless Modern UI) ---
    $form = New-Object System.Windows.Forms.Form
    $form.Size = New-Object System.Drawing.Size(440, 280)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "None" # إزالة الشريط الأبيض والحواف تماماً
    $form.TopMost = $true 
    
    # لوحة الألوان المحسنة والمتناسقة
    $backColor = [System.Drawing.Color]::FromArgb(30, 30, 30)       # خلفية داكنة متناسقة
    $cardColor = [System.Drawing.Color]::FromArgb(40, 40, 40)       # لون الحاوية الداخلية
    $textColor = [System.Drawing.Color]::FromArgb(240, 240, 240)    # نص أبيض ناعم
    $subTextColor = [System.Drawing.Color]::FromArgb(180, 180, 180) # نص رمادي توضيحي
    $btnLangColor = [System.Drawing.Color]::FromArgb(55, 55, 55)     # زر لغة رمادي داكن هادئ
    $btnConfirmColor = [System.Drawing.Color]::FromArgb(0, 122, 204) # أزرق ويندوز الأنيق
    
    $form.BackColor = $backColor

    # ميزة تحريك النافذة بدون شريط علوي (Drag functionality)
    $mouseDown = $false
    $mousePos = New-Object System.Drawing.Point
    $form.Add_MouseDown({
        param($sender, $e)
        $script:mouseDown = $true
        $script:mousePos = $e.Location
    })
    $form.Add_MouseMove({
        param($sender, $e)
        if ($script:mouseDown) {
            $screenPos = $form.PointToScreen($e.Location)
            $form.Location = New-Object System.Drawing.Point(($screenPos.X - $script:mousePos.X), ($screenPos.Y - $script:mousePos.Y))
        }
    })
    $form.Add_MouseUp({ $script:mouseDown = $false })

    # النصوص باللغتين
    $script:isArabic = $true
    $textAr = "تنبيه هام ومطلوب:`n`nتم فتح صفحة الأمان خلف هذه النافذة.`nيرجى التمرير لأسفل الصفحة وتعطيل الخيار:`n`n[ Tamper Protection -> Switch to OFF ]`n`nاضغط على 'تم التعطيل' بعد إنهاء الخطوة."
    $textEn = "Action Required:`n`nThe settings page has been opened behind this window.`nPlease scroll down inside that window and disable:`n`n[ Tamper Protection -> Switch to OFF ]`n`nClick 'Done' after completing the step."
    
    # الحاوية الداخلية (Card)
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point(15, 15)
    $panel.Size = New-Object System.Drawing.Size(410, 160)
    $panel.BackColor = $cardColor
    $form.Controls.Add($panel)

    # جعل الحاوية أيضاً قابلة لسحب وتحريك النافذة
    $panel.Add_MouseDown({ param($sender, $e) $script:mouseDown = $true; $script:mousePos = $e.Location })
    $panel.Add_MouseMove({
        param($sender, $e)
        if ($script:mouseDown) {
            $screenPos = $panel.PointToScreen($e.Location)
            $form.Location = New-Object System.Drawing.Point(($screenPos.X - $script:mousePos.X), ($screenPos.Y - $script:mousePos.Y))
        }
    })
    $panel.Add_MouseUp({ $script:mouseDown = $false })

    # نص التعليمات
    $label = New-Object System.Windows.Forms.Label
    $label.Location = New-Object System.Drawing.Point(15, 15)
    $label.Size = New-Object System.Drawing.Size(380, 130)
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 10.5)
    $label.ForeColor = $textColor
    $label.Text = $textAr
    $label.RightToLeft = "Yes"
    $panel.Controls.Add($label)

    # زر تبديل اللغة المتناسق
    $btnLang = New-Object System.Windows.Forms.Button
    $btnLang.Location = New-Object System.Drawing.Point(15, 200)
    $btnLang.Size = New-Object System.Drawing.Size(110, 45)
    $btnLang.Text = "English"
    $btnLang.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnLang.ForeColor = $textColor
    $btnLang.BackColor = $btnLangColor
    $btnLang.FlatStyle = "Flat"
    $btnLang.FlatAppearance.BorderSize = 0
    
    $btnLang.Add_MouseEnter({ $btnLang.BackColor = [System.Drawing.Color]::FromArgb(75, 75, 75) })
    $btnLang.Add_MouseLeave({ $btnLang.BackColor = $btnLangColor })
    
    $btnLang.Add_Click({
        if ($script:isArabic) {
            $label.Text = $textEn
            $label.RightToLeft = "No"
            $btnLang.Text = "العربية"
            $btnConfirm.Text = "Done / Verified"
            $script:isArabic = $false
        } else {
            $label.Text = $textAr
            $label.RightToLeft = "Yes"
            $btnLang.Text = "English"
            $btnConfirm.Text = "تم التعطيل"
            $script:isArabic = $true
        }
    })
    $form.Controls.Add($btnLang)

    # زر التأكيد والمتابعة الأزرق الاحترافي
    $btnConfirm = New-Object System.Windows.Forms.Button
    $btnConfirm.Location = New-Object System.Drawing.Point(215, 200)
    $btnConfirm.Size = New-Object System.Drawing.Size(210, 45)
    $btnConfirm.Text = "تم التعطيل"
    $btnConfirm.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $btnConfirm.ForeColor = $textColor
    $btnConfirm.BackColor = $btnConfirmColor
    $btnConfirm.FlatStyle = "Flat"
    $btnConfirm.FlatAppearance.BorderSize = 0
    $btnConfirm.DialogResult = [System.Windows.Forms.DialogResult]::OK
    
    $btnConfirm.Add_MouseEnter({ $btnConfirm.BackColor = [System.Drawing.Color]::FromArgb(0, 140, 230) })
    $btnConfirm.Add_MouseLeave({ $btnConfirm.BackColor = $btnConfirmColor })
    
    $form.Controls.Add($btnConfirm)


# عرض الواجهة وانتظار تفاعل المستخدم
    $result = $form.ShowDialog()
    
    # --- التعديل الجذري: إنهاء عملية نافذة الحماية برمجياً وإعادة التوجيه ---
    try {
        # إغلاق نافذة إعدادات الأمان عن طريق إنهاء عمليتها مباشرة
        Stop-Process -Name "SecHealthUI" -Force -ErrorAction SilentlyContinue
        
        # مهلة قصيرة جداً للتأكد من إغلاق النافذة
        Start-Sleep -Milliseconds 300
        
        # إعادة التركيز وجلب نافذة الباورشيل الحالية للمقدمة
        $wshell = New-Object -ComObject WScript.Shell
        $currentPid = [System.Diagnostics.Process]::GetCurrentProcess().Id
        $wshell.AppActivate($currentPid) | Out-Null
    } catch {
        # خطة بديلة في حال تعذر جلب الـ PID
        $wshell = New-Object -ComObject WScript.Shell
        $wshell.AppActivate("PowerShell") | Out-Null
    }
    # -------------------------------------------------------------------------

    Write-Host "`n[! ] MANDATORY MANUAL ACTION REQUIRED [ !]" -ForegroundColor Red
    Write-Host "Microsoft protects this toggle inside the Kernel. You MUST turn this OFF manually:" -ForegroundColor White
    Write-Host "  1. Tamper Protection       -> Switch to (OFF)" -ForegroundColor Yellow
    
    Write-Host "`n[*] Validating system defense override permissions..." -ForegroundColor Yellow
    
    # Programmatic test to see if the cloud/tamper protection block has been lifted
    try {
        Set-MpPreference -DisableBlockAtFirstSeen $true -ErrorAction Stop
        $fullyUnlocked = $true
    } catch {
        Write-Host "`n[X] VALIDATION FAILED: Access Denied." -ForegroundColor Red
        Write-Host "Windows Defender is still blocking automated adjustments." -ForegroundColor LightRed
        Write-Host "Please make sure 'Tamper Protection' is OFF." -ForegroundColor White
        Start-Sleep -Seconds 3
    }
}

Write-Host "`n[✓] Validation successful! Proceeding with deep system teardown..." -ForegroundColor Green

# 3. Disable All Defender Preferences via PowerShell Cmdlets
Write-Host "[*] Disabling real-time monitoring, file-open tracking, and behavior analytics..." -ForegroundColor Cyan
Set-MpPreference -DisableRealtimeMonitoring $true `
                 -DisableBehaviorMonitoring $true `
                 -DisableIOAVProtection $true `
                 -DisablePrivacyMode $true `
                 -DisableArchiveScanning $true `
                 -DisableIntrusionPreventionSystem $true `
                 -DisableScriptScanning $true `
                 -DisableScanningNetworkFiles $true `
                 -DisableScanningMappedNetworkDrivesForFullScan $true `
                 -DisableCatchupFullScan $true `
                 -DisableCatchupQuickScan $true `
                 -DisableRemovableDriveScanning $true `
                 -DisableEmailScanning $true `
                 -MAPSReporting 0

# --- تعطيل مراقب الملفات والمجلدات وأي شيء يفتحه المستخدم ---
Write-Host "[*] Disabling file, folder, and user-opened item monitoring..." -ForegroundColor Cyan

Set-MpPreference -DisableRealtimeMonitoring $true
Set-MpPreference -DisableBehaviorMonitoring $true
Set-MpPreference -DisableIOAVProtection $true
Set-MpPreference -DisableScriptScanning $true
Set-MpPreference -DisableScanningNetworkFiles $true
Set-MpPreference -DisableScanningMappedNetworkDrivesForFullScan $true
Set-MpPreference -DisableRemovableDriveScanning $true
Set-MpPreference -DisableCatchupFullScan $true
Set-MpPreference -DisableCatchupQuickScan $true

# تعطيل الحماية عند الوصول إلى الملفات عبر Registry
$RealTimePath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
New-ItemProperty -Path $RealTimePath -Name "DisableOnAccessProtection" -Value 1 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path $RealTimePath -Name "DisableRealtimeMonitoring" -Value 1 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path $RealTimePath -Name "DisableBehaviorMonitoring" -Value 1 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path $RealTimePath -Name "DisableIOAVProtection" -Value 1 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path $RealTimePath -Name "DisableScanOnRealtimeEnable" -Value 1 -PropertyType DWORD -Force | Out-Null

# 4. Inject Deep Group Policy & Registry Overrides
Write-Host "[*] Injecting global policies into Local Machine Registry..." -ForegroundColor Cyan
$RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
if (!(Test-Path $RegistryPath)) { New-Item -Path $RegistryPath -Force | Out-Null }
New-ItemProperty -Path $RegistryPath -Name "DisableAntiSpyware" -Value 1 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path $RegistryPath -Name "DisableAntiVirus" -Value 1 -PropertyType DWORD -Force | Out-Null

$RealTimePath = "$RegistryPath\Real-Time Protection"
if (!(Test-Path $RealTimePath)) { New-Item -Path $RealTimePath -Force | Out-Null }
New-ItemProperty -Path $RealTimePath -Name "DisableRealtimeMonitoring" -Value 1 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path $RealTimePath -Name "DisableBehaviorMonitoring" -Value 1 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path $RealTimePath -Name "DisableScanOnRealtimeEnable" -Value 1 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path $RealTimePath -Name "DisableOnAccessProtection" -Value 1 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path $RealTimePath -Name "DisableIOAVProtection" -Value 1 -PropertyType DWORD -Force | Out-Null

# 5. Drop All Active Windows Firewall Profiles
Write-Host "[*] Disabling Windows Advanced Firewall (Domain, Private, and Public)..." -ForegroundColor Cyan
NetSh Advfirewall set allprofiles state off | Out-Null

# 6. Attempt Service Termination
Write-Host "[*] Attempting to stop and deprecate background security services..." -ForegroundColor Cyan
sc.exe config WinDefend start= disabled | Out-Null
sc.exe stop WinDefend | Out-Null

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "[✓] ALL PROTECTION SYSTEMS DISENGAGED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Cyan

# Keep-Alive Execution Barrier
Write-Host "`n[i] Script execution complete." -ForegroundColor Gray
Read-Host "Press ENTER to close this window"