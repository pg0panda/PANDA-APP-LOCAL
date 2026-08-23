# Reset Windows Firewall - PowerShell Version
# Created by Panda
# Improved: safer prompts, backup/restore, validation, stronger netsh handling

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Confirm-Action {
    param(
        [string]$Message,
        [string]$DefaultChoice = 'n'
    )

    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
    $answer = Read-Host "Type 'Y' to confirm or 'N' to cancel"
    return ($answer.Trim().ToLower() -eq 'y' -or ($answer.Trim().Length -eq 0 -and $DefaultChoice.ToLower() -eq 'y'))
}

function Invoke-NetshCommand {
    param(
        [string]$Arguments,
        [switch]$Silent
    )

    try {
        $output = & netsh $Arguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            if (-not $Silent) {
                Write-Host "[!] netsh command failed: $Arguments" -ForegroundColor Red
                $output | ForEach-Object { Write-Host $_ -ForegroundColor Red }
            }
            return $false
        }

        if (-not $Silent) {
            $output | ForEach-Object { Write-Host $_ }
        }
        return $true
    }
    catch {
        Write-Host "[!] Unable to execute netsh command: $Arguments" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

function Backup-FirewallSettings {
    $backupDir = Join-Path $env:TEMP 'PandaFirewallBackup'
    if (-not (Test-Path $backupDir)) {
        New-Item -Path $backupDir -ItemType Directory -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupFile = Join-Path $backupDir "firewall-backup-$timestamp.wfw"

    Write-Host "[*] Creating firewall backup..." -ForegroundColor Yellow
    $result = & netsh advfirewall export $backupFile 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[!] Backup failed. Firewall export command returned an error." -ForegroundColor Red
        $result | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        return $null
    }

    Write-Host "[+] Backup created: $backupFile" -ForegroundColor Green
    return $backupFile
}

function Restore-FirewallBackup {
    param(
        [string]$BackupPath
    )

    if (-not $BackupPath -or -not (Test-Path $BackupPath)) {
        Write-Host "[!] No valid firewall backup was found." -ForegroundColor Red
        return $false
    }

    Write-Host "[*] Restoring firewall settings from backup..." -ForegroundColor Yellow
    $result = & netsh advfirewall import $BackupPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[!] Restore failed." -ForegroundColor Red
        $result | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        return $false
    }

    Write-Host "[+] Firewall restored successfully." -ForegroundColor Green
    return $true
}

function Show-FirewallStatus {
    Write-Host ""
    Write-Host "[*] Current firewall status (all profiles):" -ForegroundColor Yellow
    & netsh advfirewall show allprofiles

    Write-Host ""
    Write-Host "[*] Current rules count:" -ForegroundColor Yellow
    $ruleLines = & netsh advfirewall firewall show rule name=all 2>&1
    if ($LASTEXITCODE -eq 0) {
        $ruleCount = ($ruleLines | Select-String 'Rule Name:' | Measure-Object).Count
        Write-Host "Rules found: $ruleCount" -ForegroundColor Cyan
    }
    else {
        Write-Host "[!] Unable to enumerate rules." -ForegroundColor Red
    }
}

function Show-MainMenu {
    Clear-Host
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                     Firewall Reset Tool                    ║" -ForegroundColor Cyan
    Write-Host "║                      Created by Panda                      ║" -ForegroundColor Cyan
    Write-Host "╠════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "║  [1] Full firewall reset                                   ║" -ForegroundColor White
    Write-Host "║  [2] Backup firewall settings                              ║" -ForegroundColor White
    Write-Host "║  [3] Restore firewall backup                               ║" -ForegroundColor White
    Write-Host "║  [4] Restore default settings                              ║" -ForegroundColor White
    Write-Host "║  [5] Enable firewall for all profiles                      ║" -ForegroundColor White
    Write-Host "║  [6] Disable firewall for all profiles                     ║" -ForegroundColor White
    Write-Host "║  [7] Show current firewall status                          ║" -ForegroundColor White
    Write-Host "║  [0] Exit                                                  ║" -ForegroundColor White
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    $choice = Read-Host "Choose option number (0-7)"

    switch ($choice) {
        '1' { Reset-Firewall }
        '2' { Backup-MenuAction }
        '3' { Restore-MenuAction }
        '4' { Restore-Defaults }
        '5' { Enable-Firewall }
        '6' { Disable-Firewall }
        '7' { Show-Status }
        '0' { Exit-Script }
        default {
            Write-Host "[!] Invalid choice / خيار غير صحيح" -ForegroundColor Red
            Start-Sleep -Seconds 1.5
            Show-MainMenu
        }
    }
}

function Backup-MenuAction {
    $backupFile = Backup-FirewallSettings
    if ($backupFile) {
        Write-Host ""
        Write-Host "Press Enter to continue..." -ForegroundColor Gray
        $null = Read-Host
    }
    Show-MainMenu
}

function Restore-MenuAction {
    $backupDir = Join-Path $env:TEMP 'PandaFirewallBackup'
    $backupFiles = @(Get-ChildItem -Path $backupDir -Filter 'firewall-backup-*.wfw' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)

    if (-not $backupFiles -or $backupFiles.Count -eq 0) {
        Write-Host "[!] No firewall backups were found in $backupDir" -ForegroundColor Red
        Write-Host "Press Enter to continue..." -ForegroundColor Gray
        $null = Read-Host
        Show-MainMenu
        return
    }

    Write-Host ""
    Write-Host "Available backups:" -ForegroundColor Cyan
    for ($i = 0; $i -lt $backupFiles.Count; $i++) {
        Write-Host "[$($i + 1)] $($backupFiles[$i].FullName)"
    }

    $selected = Read-Host "Select backup number to restore"
    if (-not ($selected -match '^[0-9]+$') -or [int]$selected -lt 1 -or [int]$selected -gt $backupFiles.Count) {
        Write-Host "[!] Invalid selection." -ForegroundColor Red
        Write-Host "Press Enter to continue..." -ForegroundColor Gray
        $null = Read-Host
        Show-MainMenu
        return
    }

    $targetBackup = $backupFiles[[int]$selected - 1].FullName
    if (-not (Confirm-Action "This will restore the selected firewall backup. Continue?")) {
        Show-MainMenu
        return
    }

    Restore-FirewallBackup -BackupPath $targetBackup
    Write-Host "Press Enter to continue..." -ForegroundColor Gray
    $null = Read-Host
    Show-MainMenu
}

function Reset-Firewall {
    Clear-Host
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    Resetting Firewall...                   ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Confirm-Action "This action will reset firewall rules and may block some apps until you reconfigure them. Continue?")) {
        Show-MainMenu
        return
    }

    $backupFile = Backup-FirewallSettings
    Write-Host ""
    Write-Host "[*] Step 1/5: Resetting firewall configuration..." -ForegroundColor Yellow
    & netsh advfirewall reset
    
    Write-Host "[*] Step 2/5: Deleting all custom firewall rules..." -ForegroundColor Yellow
    & netsh advfirewall firewall delete rule name=all

    Write-Host "[*] Step 3/5: Restoring default block/allow policies..." -ForegroundColor Yellow
    & netsh advfirewall set allprofiles firewallpolicy blockinbound,allowoutbound

    Write-Host "[*] Step 4/5: Enabling firewall on all profiles..." -ForegroundColor Yellow
    & netsh advfirewall set allprofiles state on

    Write-Host "[*] Step 5/5: Restoring default remote management settings..." -ForegroundColor Yellow
    & netsh advfirewall set allprofiles settings remotemanagement disable
    & netsh advfirewall set allprofiles settings unicastresponsetomulticast enable

    Write-Host ""
    Write-Host "[+] Firewall reset completed successfully." -ForegroundColor Green
    if ($backupFile) {
        Write-Host "[+] Backup saved: $backupFile" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "Press Enter to continue..." -ForegroundColor Gray
    $null = Read-Host
    Show-MainMenu
}

function Restore-Defaults {
    Clear-Host
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                  Restoring Default Settings                ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Confirm-Action "Restore default Windows Firewall settings?")) {
        Show-MainMenu
        return
    }

    Write-Host "[*] Restoring default settings..." -ForegroundColor Yellow
    & netsh advfirewall set allprofiles firewallpolicy blockinbound,allowoutbound
    & netsh advfirewall set allprofiles settings remotemanagement disable
    & netsh advfirewall set allprofiles settings unicastresponsetomulticast enable

    Write-Host ""
    Write-Host "[+] Default settings restored successfully." -ForegroundColor Green
    Write-Host ""
    Write-Host "Press Enter to continue..." -ForegroundColor Gray
    $null = Read-Host
    Show-MainMenu
}

function Enable-Firewall {
    Clear-Host
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    Enabling Firewall...                    ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Confirm-Action "Enable firewall for all profiles?")) {
        Show-MainMenu
        return
    }

    Write-Host "[*] Enabling firewall for all profiles..." -ForegroundColor Yellow
    & netsh advfirewall set allprofiles state on

    Write-Host ""
    Write-Host "[+] Firewall enabled successfully." -ForegroundColor Green
    Write-Host ""
    Write-Host "Press Enter to continue..." -ForegroundColor Gray
    $null = Read-Host
    Show-MainMenu
}

function Disable-Firewall {
    Clear-Host
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    Disabling Firewall...                   ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "[!] Warning: disabling the firewall may expose the machine to network risk." -ForegroundColor Red

    if (-not (Confirm-Action "Are you absolutely sure you want to disable the firewall?")) {
        Show-MainMenu
        return
    }

    Write-Host "[*] Disabling firewall for all profiles..." -ForegroundColor Yellow
    & netsh advfirewall set allprofiles state off

    Write-Host ""
    Write-Host "[+] Firewall disabled." -ForegroundColor Green
    Write-Host ""
    Write-Host "Press Enter to continue..." -ForegroundColor Gray
    $null = Read-Host
    Show-MainMenu
}

function Show-Status {
    Clear-Host
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    Current Firewall Status                 ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    Show-FirewallStatus
    Write-Host ""
    Write-Host "Press Enter to continue..." -ForegroundColor Gray
    $null = Read-Host
    Show-MainMenu
}

function Exit-Script {
    Clear-Host
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                      Goodbye!                              ║" -ForegroundColor Cyan
    Write-Host "║                   Created by Panda                         ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Thanks for using the firewall tool." -ForegroundColor Green
    Write-Host ""
    Start-Sleep -Seconds 1
    exit
}

if (-not (Test-Administrator)) {
    Write-Host ""
    Write-Host "[!] This script must be run as Administrator." -ForegroundColor Red
    Write-Host "[!] Restarting with elevated privileges..." -ForegroundColor Yellow
    $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)
    Start-Process -FilePath 'powershell.exe' -ArgumentList $args -Verb RunAs
    exit
}

$Host.UI.RawUI.WindowTitle = 'Reset Windows Firewall - Created by Panda'
$Host.UI.RawUI.ForegroundColor = 'Cyan'

# Start the script
Show-MainMenu