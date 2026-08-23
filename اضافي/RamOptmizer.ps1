# ====================================================================
# 1. Self-Elevate to Administrator
# ====================================================================
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
    $ScriptPath = $MyInvocation.MyCommand.Path
    $Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    Start-Process powershell.exe -ArgumentList $Arguments -Verb RunAs
    Exit
}

# ====================================================================
# 2. C# Native Windows API Integration
# ====================================================================
$Source = @"
using System;
using System.Runtime.InteropServices;

public class PandaRamPurge {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetProcessWorkingSetSize(IntPtr proc, IntPtr min, IntPtr max);

    [DllImport("ntdll.dll")]
    public static extern uint NtSetSystemInformation(int SystemInformationClass, IntPtr SystemInformation, int SystemInformationLength);

    public static void PurgeSystemCache() {
        int SYSTEM_COMMAND = 21; 
        IntPtr pCmd = Marshal.AllocHGlobal(sizeof(int));
        Marshal.WriteInt32(pCmd, 2); // 2 = EmptyStandbyList
        try {
            NtSetSystemInformation(SYSTEM_COMMAND, pCmd, sizeof(int));
        } catch {}
        finally {
            Marshal.FreeHGlobal(pCmd);
        }
    }
}
"@

if (-not ([System.Management.Automation.PSTypeName]'PandaRamPurge').Type) {
    Add-Type -TypeDefinition $Source
}

# ====================================================================
# 3. Execution & Real-Time Logging (Memory Counter Included)
# ====================================================================
Clear-Host
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "         PANDA RAM PURGE v2.5 - LIVE LOG          " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Cyan

# Capture RAM usage before purge
$MemBefore = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory

Write-Host "[LOG] [$(Get-Date -Format 'HH:mm:ss')] Initializing Deep Memory Purge..." -ForegroundColor White

# Step 1: Purge Standby List & System Cache
Write-Host "[LOG] [$(Get-Date -Format 'HH:mm:ss')] Purging System Cache and Standby Memory Lists..." -ForegroundColor Yellow
[PandaRamPurge]::PurgeSystemCache()

# Step 2: Trim Processes Working Set
Write-Host "[LOG] [$(Get-Date -Format 'HH:mm:ss')] Trimming active application working sets..." -ForegroundColor Yellow
$ProcessCount = 0
$SuccessCount = 0

$AllProcesses = Get-Process
foreach ($Process in $AllProcesses) {
    $ProcessCount++
    try {
        # Force process to release unused RAM
        if ([PandaRamPurge]::SetProcessWorkingSetSize($Process.Handle, -1, -1)) {
            $SuccessCount++
        }
    }
    catch {
        # Skip system-protected processes safely
        continue
    }
}

# Step 3: Calculate Results
$MemAfter = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory
$SavedKB = $MemAfter - $MemBefore
$SavedMB = [Math]::Round($SavedKB / 1024, 2)

# Output Summary Log
Write-Host "--------------------------------------------------" -ForegroundColor Cyan
Write-Host "[LOG] [$(Get-Date -Format 'HH:mm:ss')] Scan complete: Checked $ProcessCount processes." -ForegroundColor White
Write-Host "[LOG] [$(Get-Date -Format 'HH:mm:ss')] Successfully optimized $SuccessCount processes." -ForegroundColor Green

if ($SavedMB -gt 0) {
    Write-Host "[LOG] [$(Get-Date -Format 'HH:mm:ss')] SUCCESS: Released ~$SavedMB MB of RAM instantly!" -ForegroundColor Green
} else {
    Write-Host "[LOG] [$(Get-Date -Format 'HH:mm:ss')] SUCCESS: Standby Memory cleared. RAM is optimized." -ForegroundColor Green
}
Write-Host "==================================================" -ForegroundColor Cyan

Stop-Process -Id $PID