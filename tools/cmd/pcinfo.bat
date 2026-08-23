@echo off
setlocal enabledelayedexpansion
color 0B

:: تكبير حجم النافذة والخط
powershell -Command "&{$Host.UI.RawUI.WindowTitle='Modern System Info Tool v3.0 - Enhanced Display'}"

:: ==============================================
:: MODERN SYSTEM INFORMATION TOOL
:: Updated for Windows 10/11 (No WMIC dependency)
:: Version: 3.0 PowerShell Enhanced
:: ==============================================

title Modern System Info Tool v3.0

cls
echo.
echo =====================================================================================
echo                         MODERN SYSTEM INFORMATION TOOL v3.0
echo =====================================================================================
echo.

:: Check if PowerShell is available
powershell -Command "Write-Host 'PowerShell Available'" >nul 2>&1
if !errorlevel! neq 0 (
    echo ERROR: PowerShell is required but not available.
    pause
    exit /b 1
)

:: Welcome message
echo.
echo Welcome %username%!
echo.
timeout /t 2 >nul

:MAIN_MENU
cls
echo.
echo =====================================================================================
echo                                    MAIN MENU
echo =====================================================================================
echo.
echo    AVAILABLE OPTIONS:
echo.
echo    [1]  Complete System Overview
echo    [2]  Hardware Details
echo    [3]  Performance Analysis
echo    [4]  Network Diagnostics
echo    [5]  System Health Check
echo    [6]  Display Full Report
echo    [7]  Gaming Performance Info
echo    [0]  Exit
echo.
set /p choice="Select option (0-7): "

if "%choice%"=="1" goto OVERVIEW
if "%choice%"=="2" goto HARDWARE
if "%choice%"=="3" goto PERFORMANCE
if "%choice%"=="4" goto NETWORK
if "%choice%"=="5" goto HEALTH
if "%choice%"=="6" goto EXPORT
if "%choice%"=="7" goto GAMING
if "%choice%"=="0" goto EXIT
goto MAIN_MENU

:OVERVIEW
cls
echo.
echo ======================================================================================
echo                                   SYSTEM OVERVIEW
echo ======================================================================================
echo.

echo         BASIC SYSTEM INFO:
echo.
for /f "delims=" %%i in ('powershell -Command "(Get-CimInstance Win32_OperatingSystem).Caption"') do echo          OS: %%i
for /f "delims=" %%i in ('powershell -Command "(Get-CimInstance Win32_OperatingSystem).Version"') do echo          Version: %%i
for /f "delims=" %%i in ('powershell -Command "(Get-CimInstance Win32_ComputerSystem).Manufacturer"') do echo          Manufacturer: %%i
for /f "delims=" %%i in ('powershell -Command "(Get-CimInstance Win32_ComputerSystem).Model"') do echo          Model: %%i
echo          User: %username%
echo          Computer: %computername%
echo.
echo         QUICK HARDWARE SUMMARY:
echo.
for /f "delims=" %%i in ('powershell -Command "(Get-CimInstance Win32_Processor).Name"') do echo          CPU: %%i
for /f "delims=" %%i in ('powershell -Command "[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB)"') do echo          RAM: %%i GB
for /f "delims=" %%i in ('powershell -Command "(Get-CimInstance Win32_VideoController | Where-Object {$_.Name -notlike '*Basic*'}).Name"') do (
    echo          GPU: %%i
)

echo.
for /f "delims=" %%i in ('powershell -Command "(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString('dd/MM/yyyy HH:mm')"') do echo          Last Boot: %%i
echo.
echo ======================================================================================
pause
goto MAIN_MENU

:HARDWARE
cls
echo.
echo ======================================================================================
echo                                      HARDWARE DETAILS
echo ======================================================================================
echo.

echo         PROCESSOR INFORMATION:
echo.
for /f "delims=" %%i in ('powershell -Command "(Get-CimInstance Win32_Processor).Name"') do echo          Name: %%i
for /f "delims=" %%i in ('powershell -Command "(Get-CimInstance Win32_Processor).NumberOfCores"') do echo          Cores: %%i
for /f "delims=" %%i in ('powershell -Command "(Get-CimInstance Win32_Processor).NumberOfLogicalProcessors"') do echo          Threads: %%i
for /f "delims=" %%i in ('powershell -Command "[math]::Round((Get-CimInstance Win32_Processor).MaxClockSpeed/1000, 1)"') do echo          Max Speed: %%i GHz
for /f "delims=" %%i in ('powershell -Command "(Get-CimInstance Win32_Processor).Architecture"') do (
    if "%%i"=="9" echo          Architecture: x64
    if "%%i"=="0" echo          Architecture: x86
)
echo.
echo         MEMORY INFORMATION:
echo.
powershell -Command "$sticks = Get-CimInstance Win32_PhysicalMemory; $total = 0; foreach($stick in $sticks) { $gb = [math]::Round($stick.Capacity/1GB); Write-Host \"          RAM Stick: $gb GB\"; $total += $gb }; Write-Host \"          Total RAM: $total GB\""
echo.
echo         STORAGE INFORMATION:
echo.
powershell -Command "Get-CimInstance Win32_DiskDrive | ForEach-Object { Write-Host \"          Drive: $($_.Model)\"; Write-Host \"          Size: $([math]::Round($_.Size/1GB)) GB\"; Write-Host \"          ────────────────────\" }"
echo.
echo         GRAPHICS INFORMATION:
echo.
powershell -Command "Get-CimInstance Win32_VideoController | Where-Object {$_.Name -notlike '*Basic*'} | ForEach-Object { Write-Host \"          GPU: $($_.Name)\" }"

echo.
echo ======================================================================================
pause
goto MAIN_MENU

:PERFORMANCE
cls
echo.
echo ======================================================================================
echo                                    PERFORMANCE ANALYSIS
echo ======================================================================================
echo.

echo         CURRENT SYSTEM PERFORMANCE:
echo.
echo          Collecting performance data...
echo.

:: CPU Usage using PowerShell
for /f "delims=" %%i in ('powershell -Command "$cpu = Get-Counter '\Processor(_Total)\%% Processor Time' -SampleInterval 1 -MaxSamples 2 | Select-Object -ExpandProperty CounterSamples | Select-Object -Last 1; [math]::Round(100 - $cpu.CookedValue)"') do (
    set cpu_usage=%%i
    if !cpu_usage! LSS 30 (
        echo          CPU Usage: !cpu_usage!%% ^(Good^)
    ) else if !cpu_usage! LSS 70 (
        echo          CPU Usage: !cpu_usage!%% ^(Moderate^)
    ) else (
        echo          CPU Usage: !cpu_usage!%% ^(High^)
    )
)

:: Memory Usage using PowerShell
for /f "delims=" %%i in ('powershell -Command "$os = Get-CimInstance Win32_OperatingSystem; $used = ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) * 1024; $total = $os.TotalVisibleMemorySize * 1024; [math]::Round(($used / $total) * 100)"') do (
    set mem_percent=%%i
    if !mem_percent! LSS 60 (
        echo          RAM Usage: !mem_percent!%% ^(Good^)
    ) else if !mem_percent! LSS 85 (
        echo          RAM Usage: !mem_percent!%% ^(Moderate^)
    ) else (
        echo          RAM Usage: !mem_percent!%% ^(High^)
    )
)

echo.
echo         TEMPERATURE MONITOR:
echo.
powershell -Command "Get-CimInstance -Namespace root/WMI -ClassName MSAcpi_ThermalZoneTemperature 2>$null" | find "CurrentTemperature" >nul
if !errorlevel! equ 0 (
    echo          System Temperature: Available ^(use HWiNFO for details^)
) else (
    echo          System Temperature: Not available via WMI
)

echo.
echo         POWER INFORMATION:
echo.
for /f "delims=" %%i in ('powershell -Command "try { $battery = Get-CimInstance Win32_Battery -ErrorAction Stop; if($battery.BatteryStatus -eq 1) { Write-Host 'Battery: Discharging' } elseif($battery.BatteryStatus -eq 2) { Write-Host 'Battery: Charging' } elseif($battery.BatteryStatus -eq 3) { Write-Host 'Battery: Critical' } else { Write-Host 'Battery: Unknown status' } } catch { Write-Host 'No battery detected (Desktop)' }"') do echo          %%i
for /f "delims=" %%i in ('powershell -Command "try { (Get-CimInstance Win32_Battery -ErrorAction Stop).EstimatedChargeRemaining } catch { Write-Host 'N/A' }"') do (
    if not "%%i"=="N/A" echo          Battery Level: %%i%%
)

echo.
echo         PROCESS COUNT:
for /f "delims=" %%i in ('powershell -Command "(Get-Process).Count"') do echo          Running Processes: %%i

echo.
echo ======================================================================================
pause
goto MAIN_MENU

:NETWORK
cls
echo.
echo ======================================================================================
echo                                     NETWORK DIAGNOSTICS
echo ======================================================================================
echo.

echo         NETWORK ADAPTERS:
echo.
powershell -Command "Get-CimInstance Win32_NetworkAdapter | Where-Object {$_.NetEnabled -eq $true} | ForEach-Object { Write-Host \"          $($_.Name)\" }"

echo.
echo         IP CONFIGURATION:
echo.
for /f "tokens=2 delims=:" %%i in ('ipconfig ^| find "IPv4"') do echo          IPv4:%%i
for /f "tokens=2 delims=:" %%i in ('ipconfig ^| find "Default Gateway"') do (
    if not "%%i"==" " echo          Gateway:%%i
)

echo.
echo         CONNECTIVITY TEST:
echo          Testing internet connection...

ping google.com -n 2 >nul
if errorlevel 1 (
    echo          Internet: Disconnected
) else (
    echo          Internet: Connected
)

ping 8.8.8.8 -n 2 >nul
if errorlevel 1 (
    echo          DNS: Issues detected
) else (
    echo          DNS: Working
)

echo.
echo         NETWORK STATISTICS:
for /f "tokens=3,4" %%i in ('netstat -e ^| find "Bytes"') do (
    echo          Bytes Sent: %%i
    echo          Bytes Received: %%j
)

echo.
echo ======================================================================================
pause
goto MAIN_MENU


:HEALTH
cls
echo.
@echo off
setlocal enabledelayedexpansion

echo ======================================================================================
echo                                     SYSTEM HEALTH CHECK
echo ======================================================================================
echo.

echo         HEALTH DIAGNOSTICS:
echo          Running system health checks...
echo.

set health_score=100

:: Check disk space using PowerShell (returns OK or Low only)
for /f "delims=" %%i in ('powershell -Command "$disk = Get-CimInstance Win32_LogicalDisk -Filter \"DeviceID=''C:''\"; $freeGB = [math]::Round($disk.FreeSpace/1GB); if($freeGB -lt 10) { 'Low' } else { 'OK' }"') do (
    if "%%i"=="Low" (
        echo          Low disk space on C: drive
        set /a health_score-=15
    ) else (
        echo          Disk space: OK
    )
)

:: Check system file integrity
echo          Checking system files...
sfc /verifyonly >nul 2>&1
if %errorlevel% equ 0 (
    echo          System files: Intact
) else (
    echo          System files: May need repair
    set /a health_score-=20
)

:: Check for Windows updates (pending restart key)
echo          Checking update status...
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" >nul 2>&1
if %errorlevel% equ 0 (
    echo          Pending restart required
    set /a health_score-=10
) else (
    echo          No pending restarts
)

:: Check running services
sc query "wuauserv" | find "RUNNING" >nul
if %errorlevel% equ 0 (
    echo          Windows Update service: Running
) else (
    echo          Windows Update service: Not running
    set /a health_score-=5
)

echo.
echo         SYSTEM HEALTH SCORE:
if !health_score! GEQ 90 (
    echo          Health Score: !health_score!/100 ^(Excellent^)
) else if !health_score! GEQ 70 (
    echo          Health Score: !health_score!/100 ^(Good^)
) else (
    echo          Health Score: !health_score!/100 ^(Needs Attention^)
)

echo.
echo         RECOMMENDATIONS:
if !health_score! LSS 90 (
    echo          • Run disk cleanup
    echo          • Check for Windows updates
    echo          • Consider system maintenance
) else (
    echo          • System is running optimally
    echo          • Continue regular maintenance
)

echo.
echo ======================================================================================
pause
goto MAIN_MENU


:GAMING
cls
echo.
echo ======================================================================================
echo                                     GAMING PERFORMANCE INFO
echo ======================================================================================
echo.

echo         GAMING READINESS CHECK:
echo.

:: DirectX Version
reg query "HKLM\SOFTWARE\Microsoft\DirectX" /v Version >nul 2>&1
if !errorlevel! equ 0 (
    echo          DirectX: Installed
) else (
    echo          DirectX: Not found
)

:: Check for gaming-related software
tasklist | find "Steam.exe" >nul
if !errorlevel! equ 0 (
    echo          Steam: Running
) else (
    echo          Steam: Not running
)

tasklist | find "Discord.exe" >nul
if !errorlevel! equ 0 (
    echo          Discord: Running
) else (
    echo          Discord: Not running
)

echo.
echo         GRAPHICS PERFORMANCE:
echo.
for /f "delims=" %%i in ('powershell -Command "$gpu = Get-CimInstance Win32_VideoController | Where-Object {$_.Name -notlike '*Basic*'} | Select-Object -First 1; $gpu.Name"') do (
    echo          GPU: %%i
    echo %%i | find "RTX" >nul && echo          Ray Tracing: Supported
    echo %%i | find "GTX" >nul && echo          Gaming: Optimized
    echo %%i | find "Intel" >nul && echo          Integrated: Basic gaming
)

echo.
echo         GAMING RECOMMENDATIONS:
echo.
for /f "delims=" %%i in ('powershell -Command "[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB)"') do (
    set total_ram=%%i
    if !total_ram! GEQ 16 (
        echo          RAM: Excellent for gaming ^(!total_ram!GB^)
    ) else if !total_ram! GEQ 8 (
        echo          RAM: Good for gaming ^(!total_ram!GB^)
    ) else (
        echo          RAM: Consider upgrade ^(!total_ram!GB^)
    )
)

if defined cpu_usage (
    if !cpu_usage! LSS 50 (
        echo          CPU: Ready for gaming
    ) else (
        echo          CPU: High usage, close background apps
    )
)

echo.
echo         GAMING OPTIMIZATION TIPS:
echo          • Close unnecessary background applications
echo          • Update graphics drivers regularly
echo          • Enable Game Mode in Windows settings
echo          • Consider SSD for faster loading times

echo.
echo ======================================================================================
pause
goto MAIN_MENU

:EXPORT
cls

echo.
echo =================================================================================
echo                            COMPLETE SYSTEM REPORT
echo =================================================================================
echo.

echo  Displaying Full Report...
echo  Generated: %date% %time%
echo  User: %username%
echo.
echo Press any key to continue...
pause >nul

echo =================================================================================
echo                                SYSTEM OVERVIEW
echo =================================================================================
systeminfo
echo.

echo =================================================================================
echo                               CPU INFORMATION
echo =================================================================================
powershell -Command "Get-CimInstance Win32_Processor | Format-Table Name,NumberOfCores,NumberOfLogicalProcessors,MaxClockSpeed -AutoSize"
echo.

echo =================================================================================
echo                              MEMORY INFORMATION
echo =================================================================================
powershell -Command "Get-CimInstance Win32_PhysicalMemory | Format-Table BankLabel,@{Name='Capacity(GB)';Expression={[math]::Round($_.Capacity/1GB)}},Speed -AutoSize"
echo.

echo =================================================================================
echo                              STORAGE INFORMATION
echo =================================================================================
powershell -Command "Get-CimInstance Win32_DiskDrive | Format-Table Model,@{Name='Size(GB)';Expression={[math]::Round($_.Size/1GB)}},Caption -AutoSize"
echo.

echo =================================================================================
echo                              GRAPHICS INFORMATION
echo =================================================================================
powershell -Command "Get-CimInstance Win32_VideoController | Where-Object {$_.Name -notlike '*Basic*'} | Format-Table Name -AutoSize"
echo.

echo =================================================================================
echo                             NETWORK CONFIGURATION
echo =================================================================================
ipconfig /all
echo.

echo =================================================================================
echo                                REPORT COMPLETED
echo =================================================================================
echo.
echo   Report Completed
echo   Press any key to return to main menu
pause >nul
goto MAIN_MENU

:EXIT
cls
echo.
echo =================================================================================
echo                                   GOODBYE!
echo =================================================================================
echo.
echo     Thank you for using System Info Tool v3.0
echo.
echo    Goodbye!
echo.
timeout /t 2 > nul
exit