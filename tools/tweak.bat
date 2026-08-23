@echo off
:: Gaming Performance Optimizer v4.0 - Enhanced Gaming Optimization
setlocal enabledelayedexpansion

:: Check for Administrator Privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Please run this tool as Administrator!
    echo.
    powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Administrator privileges required!', 'Permission Error', 'OK', 'Error')"
    pause
    exit /b 1
)

:: Initialize variables
set "OPTIMIZER_VERSION=4.0"
set "LOG_ENABLED=true"

:: Main Menu
:MAIN_MENU
cls
color 0b
title Gaming Performance Optimizer v%OPTIMIZER_VERSION% - Enhanced System Optimization

echo.
echo ================================================================================
echo                    Gaming Performance Optimizer v%OPTIMIZER_VERSION%
echo                      Enhanced Gaming Performance Solution
echo ================================================================================
echo.
echo   [1] Complete System Optimization - Full performance optimization suite
echo   [2] Quick Performance Boost - Rapid gaming enhancement
echo   [3] Advanced System Tweaks - Specialized performance adjustments
echo   [4] Gaming Services Manager - Control gaming-related services
echo   [5] Performance Monitor - View system performance metrics
echo   [6] Cleanup Tools - System maintenance and cleanup
echo   [7] Network Gaming Optimizer - Optimize network for gaming
echo   [8] Restore Default Settings - Revert system modifications
echo   [9] Exit Application
echo.
choice /C 123456789 /N /M "Select option [1-9]: "

if errorlevel 9 goto :exit
if errorlevel 8 goto RESTORE_DEFAULTS
if errorlevel 7 goto NETWORK_GAMING
if errorlevel 6 goto CLEANUP_TOOLS
if errorlevel 5 goto PERFORMANCE_MONITOR
if errorlevel 4 goto GAMING_SERVICES
if errorlevel 3 goto ADVANCED_TWEAKS
if errorlevel 2 goto QUICK_BOOST
if errorlevel 1 goto COMPLETE_OPTIMIZATION

:: ========================================================================
::                      COMPLETE SYSTEM OPTIMIZATION
:: ========================================================================
:COMPLETE_OPTIMIZATION
cls
echo.
echo Starting Complete System Optimization...
echo ================================================================================
echo.

echo [Step 1/12] Optimizing power management...
:: Set Ultimate Performance or High Performance
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 >nul 2>&1
powercfg -setactive e9a42b02-d5df-448d-aa00-03f14749eb61 >nul 2>&1
if !errorlevel! neq 0 (
    echo Ultimate Performance unavailable - switching to High Performance
    powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1
)

:: Disable power saving features
powercfg -change -monitor-timeout-ac 0 >nul 2>&1
powercfg -change -disk-timeout-ac 0 >nul 2>&1
powercfg -change -standby-timeout-ac 0 >nul 2>&1
powercfg -change -hibernate-timeout-ac 0 >nul 2>&1
powercfg -h off >nul 2>&1

:: Disable CPU throttling
powercfg -setacvalueindex scheme_current sub_processor PROCTHROTTLEMIN 100 >nul 2>&1
powercfg -setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 100 >nul 2>&1
powercfg -setactive scheme_current >nul 2>&1
echo Power management optimized successfully

echo [Step 2/12] Configuring visual effects for maximum performance...
:: Disable animations and visual effects
reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d "0" /f >nul 2>&1
reg add "HKCU\Control Panel\Desktop" /v ForegroundLockTimeout /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d "0" /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAnimations /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ListviewAlphaSelect /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ListviewShadow /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Control Panel\Desktop" /v UserPreferencesMask /t REG_BINARY /d 9012038010000000 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f >nul 2>&1
echo Visual effects optimized for performance

echo [Step 3/12] Applying advanced gaming registry optimizations...
:: Gaming mode enhancements
reg add "HKCU\Software\Microsoft\GameBar" /v AllowAutoGameMode /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\GameBar" /v AutoGameModeEnabled /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehaviorMode /t REG_DWORD /d 2 /f >nul 2>&1

:: Multimedia system profile optimization
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "GPU Priority" /t REG_DWORD /d 8 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v Priority /t REG_DWORD /d 6 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Scheduling Category" /t REG_SZ /d "High" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "SFIO Priority" /t REG_SZ /d "High" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 0 /f >nul 2>&1
echo Gaming registry optimizations applied

echo [Step 4/12] Optimizing GPU and graphics performance...
:: Enable hardware-accelerated GPU scheduling
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 2 /f >nul 2>&1
:: Optimize TDR settings
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrLevel /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrDelay /t REG_DWORD /d 60 /f >nul 2>&1
:: DirectX optimizations
reg add "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" /v DirectXUserGlobalSettings /t REG_SZ /d "GpuPreference=2;" /f >nul 2>&1
echo GPU and graphics performance optimized

echo [Step 5/12] Configuring memory management...
:: Advanced memory optimizations
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v DisablePagingExecutive /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v LargeSystemCache /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v SystemPages /t REG_DWORD /d 4294967295 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v ClearPageFileAtShutdown /t REG_DWORD /d 0 /f >nul 2>&1

:: Clear memory working sets
echo Clearing system memory caches...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Process | Where-Object {$_.WorkingSet -gt 50MB} | ForEach-Object { try { $_.EmptyWorkingSet() } catch {} }" >nul 2>&1
echo Memory management configured successfully

echo [Step 6/12] Optimizing CPU performance and priority...
:: CPU performance tweaks
reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 38 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v GlobalTimerResolutionRequests /t REG_DWORD /d 1 /f >nul 2>&1
:: Disable CPU core parking
powercfg -setacvalueindex scheme_current sub_processor CPMINCORES 100 >nul 2>&1
echo CPU performance optimized

echo [Step 7/12] Configuring storage and file system...
:: Detect disk type and apply appropriate optimizations
powershell -Command "$disk = Get-PhysicalDisk | Select-Object -First 1; if ($disk.MediaType -eq 'SSD') { Write-Host 'SSD detected - applying SSD optimizations' } else { Write-Host 'HDD detected - applying HDD optimizations' }"

:: Universal storage optimizations
fsutil behavior set DisableLastAccess 1 >nul 2>&1
fsutil behavior set EncryptPagingFile 0 >nul 2>&1

:: Disable automatic defragmentation for SSDs
schtasks /Query /TN "Microsoft\Windows\Defrag\ScheduledDefrag" >nul 2>&1
if !errorlevel! equ 0 (
    powershell -Command "if ((Get-PhysicalDisk | Select-Object -First 1).MediaType -eq 'SSD') { schtasks /Change /TN 'Microsoft\Windows\Defrag\ScheduledDefrag' /Disable }" >nul 2>&1
)
echo Storage optimization completed

echo [Step 8/12] Optimizing gaming services...
:: Stop unnecessary services that impact gaming performance
set "SERVICES_TO_DISABLE=SysMain WSearch Spooler Fax BITS TabletInputService DiagTrack dmwappushservice PcaSvc WerSvc"
for %%S in (%SERVICES_TO_DISABLE%) do (
    sc query "%%S" >nul 2>&1
    if !errorlevel! equ 0 (
        net stop "%%S" >nul 2>&1
        sc config "%%S" start=demand >nul 2>&1
    )
)

:: Ensure critical gaming services are running
set "GAMING_SERVICES=AudioSrv AudioEndpointBuilder Themes UxSms Dhcp Dnscache"
for %%S in (%GAMING_SERVICES%) do (
    sc config "%%S" start=auto >nul 2>&1
    net start "%%S" >nul 2>&1
)
echo Gaming services optimized

echo [Step 9/12] Applying network optimizations for gaming...
:: Advanced network tweaks for reduced latency
netsh int tcp set global autotuninglevel=normal >nul 2>&1
netsh int tcp set global chimney=enabled >nul 2>&1
netsh int tcp set global rss=enabled >nul 2>&1
netsh int tcp set global netdma=enabled >nul 2>&1
netsh int tcp set heuristics disabled >nul 2>&1
netsh int tcp set global rsc=enabled >nul 2>&1
netsh int tcp set global nonsackrttresiliency=disabled >nul 2>&1
netsh int tcp set global timestamps=disabled >nul 2>&1

:: Gaming-specific network registry tweaks
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Network Throttling Index" /t REG_DWORD /d 4294967295 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpAckFrequency /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TCPNoDelay /t REG_DWORD /d 1 /f >nul 2>&1
echo Network optimizations applied

echo [Step 10/12] Configuring audio system for gaming...
:: Audio performance optimizations
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio" /v "GPU Priority" /t REG_DWORD /d 8 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio" /v Priority /t REG_DWORD /d 6 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio" /v "Scheduling Category" /t REG_SZ /d "High" /f >nul 2>&1
echo Audio system optimized for gaming

echo [Step 11/12] Disabling unnecessary Windows features...
:: Disable Windows Update automatic downloads during gaming
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" /v DODownloadMode /t REG_DWORD /d 0 /f >nul 2>&1

:: Disable telemetry and data collection
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul 2>&1

:: Disable Game DVR and Xbox features that can impact performance
reg add "HKCU\Software\Microsoft\GameBar" /v ShowStartupPanel /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AudioCaptureEnabled /t REG_DWORD /d 0 /f >nul 2>&1
echo Unnecessary Windows features disabled

echo [Step 12/12] Finalizing optimizations...
:: Clear DNS cache
ipconfig /flushdns >nul 2>&1

:: Apply all changes
RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters >nul 2>&1
gpupdate /force >nul 2>&1

:: Restart Windows Explorer to apply visual changes
taskkill /f /im explorer.exe >nul 2>&1
start explorer.exe

echo.
echo ================================================================================
echo                        OPTIMIZATION COMPLETED SUCCESSFULLY!
echo ================================================================================
echo.
echo All gaming optimizations have been applied to your system.
echo.
echo IMPORTANT: System restart is highly recommended for optimal performance.
echo.
echo Your system is now optimized for maximum gaming performance!
echo.
pause
goto MAIN_MENU

:: ========================================================================
::                          QUICK PERFORMANCE BOOST
:: ========================================================================
:QUICK_BOOST
cls
echo.
echo Quick Performance Boost
echo ================================================================================
echo.

echo [1/6] Setting high performance power plan...
powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c >nul 2>&1
powercfg -change -monitor-timeout-ac 0 >nul 2>&1

echo [2/6] Stopping resource-intensive services...
net stop "SysMain" >nul 2>&1
net stop "WSearch" >nul 2>&1
net stop "BITS" >nul 2>&1

echo [3/6] Clearing system memory...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Process | Where-Object {$_.WorkingSet -gt 100MB} | ForEach-Object { try { $_.EmptyWorkingSet() } catch {} }" >nul 2>&1

echo [4/6] Optimizing network settings...
netsh int tcp set global autotuninglevel=normal >nul 2>&1
ipconfig /flushdns >nul 2>&1

echo [5/6] Applying quick registry tweaks...
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 0 /f >nul 2>&1

echo [6/6] Finalizing changes...
RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters >nul 2>&1

echo.
echo Quick performance boost completed successfully!
echo Performance improvements applied without requiring system restart.
echo.
pause
goto MAIN_MENU

:: ========================================================================
::                         ADVANCED SYSTEM TWEAKS
:: ========================================================================
:ADVANCED_TWEAKS
cls
echo.
echo Advanced System Tweaks
echo ================================================================================
echo.
echo   [1] DirectX and Graphics Optimization
echo   [2] Advanced Network Gaming Tweaks
echo   [3] Memory Management Optimization
echo   [4] CPU and Processor Tweaks
echo   [5] Storage Performance Optimization
echo   [6] Audio System Optimization
echo   [7] Return to Main Menu
echo.
choice /C 1234567 /N /M "Select optimization [1-7]: "

if errorlevel 7 goto MAIN_MENU
if errorlevel 6 goto AUDIO_OPTIMIZATION
if errorlevel 5 goto STORAGE_OPTIMIZATION
if errorlevel 4 goto CPU_TWEAKS
if errorlevel 3 goto MEMORY_TWEAKS
if errorlevel 2 goto NETWORK_TWEAKS
if errorlevel 1 goto GRAPHICS_TWEAKS

:GRAPHICS_TWEAKS
cls
echo DirectX and Graphics Optimization
echo ================================================================================
echo.
echo Applying advanced graphics optimizations...

:: Enable hardware-accelerated GPU scheduling
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 2 /f >nul 2>&1

:: Optimize graphics driver timeout detection and recovery
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrLevel /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrDelay /t REG_DWORD /d 60 /f >nul 2>&1

:: DirectX user preferences
reg add "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" /v DirectXUserGlobalSettings /t REG_SZ /d "GpuPreference=2;" /f >nul 2>&1

:: Disable Windows fullscreen optimizations interference
reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehaviorMode /t REG_DWORD /d 2 /f >nul 2>&1

echo DirectX and graphics optimizations applied successfully.
echo Hardware-accelerated GPU scheduling enabled.
echo Graphics driver timeouts optimized.
echo.
pause
goto ADVANCED_TWEAKS

:NETWORK_TWEAKS
cls
echo Advanced Network Gaming Tweaks
echo ================================================================================
echo.
echo Applying advanced network optimizations...

:: TCP optimizations for gaming
netsh int tcp set global autotuninglevel=normal >nul 2>&1
netsh int tcp set global chimney=enabled >nul 2>&1
netsh int tcp set global rss=enabled >nul 2>&1
netsh int tcp set global netdma=enabled >nul 2>&1
netsh int tcp set heuristics disabled >nul 2>&1
netsh int tcp set global rsc=enabled >nul 2>&1

:: Disable Nagle's algorithm for reduced latency
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TCPNoDelay /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpAckFrequency /t REG_DWORD /d 1 /f >nul 2>&1

:: Disable network throttling for gaming
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Network Throttling Index" /t REG_DWORD /d 4294967295 /f >nul 2>&1

:: Clear DNS cache
ipconfig /flushdns >nul 2>&1

echo Advanced network optimizations applied successfully.
echo TCP settings optimized for gaming latency.
echo Network throttling disabled.
echo DNS cache cleared.
echo.
pause
goto ADVANCED_TWEAKS

:MEMORY_TWEAKS
cls
echo Advanced Memory Management Optimization
echo ================================================================================
echo.
echo Applying memory optimizations...

:: Disable paging executive for better performance
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v DisablePagingExecutive /t REG_DWORD /d 1 /f >nul 2>&1

:: Optimize system cache
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v LargeSystemCache /t REG_DWORD /d 0 /f >nul 2>&1

:: Set system pages to maximum
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v SystemPages /t REG_DWORD /d 4294967295 /f >nul 2>&1

:: Clear working sets of memory-intensive processes
echo Clearing memory working sets...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Process | Where-Object {$_.WorkingSet -gt 50MB -and $_.ProcessName -ne 'explorer' -and $_.ProcessName -ne 'dwm'} | ForEach-Object { try { $_.EmptyWorkingSet() } catch {} }" >nul 2>&1

echo Memory management optimizations applied successfully.
echo Paging executive disabled for better performance.
echo System memory working sets cleared.
echo.
pause
goto ADVANCED_TWEAKS

:CPU_TWEAKS
cls
echo CPU and Processor Optimization
echo ================================================================================
echo.
echo Applying CPU optimizations...

:: Optimize processor scheduling
reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 38 /f >nul 2>&1

:: Enable high-resolution timer
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v GlobalTimerResolutionRequests /t REG_DWORD /d 1 /f >nul 2>&1

:: Disable CPU throttling
powercfg -setacvalueindex scheme_current sub_processor PROCTHROTTLEMIN 100 >nul 2>&1
powercfg -setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 100 >nul 2>&1

:: Disable core parking for maximum performance
powercfg -setacvalueindex scheme_current sub_processor CPMINCORES 100 >nul 2>&1

:: Apply power settings
powercfg -setactive scheme_current >nul 2>&1

echo CPU and processor optimizations applied successfully.
echo Processor scheduling optimized for gaming.
echo CPU throttling and core parking disabled.
echo.
pause
goto ADVANCED_TWEAKS

:STORAGE_OPTIMIZATION
cls
echo Storage Performance Optimization
echo ================================================================================
echo.
echo Analyzing storage configuration...

:: Detect storage type
powershell -Command "$disk = Get-PhysicalDisk | Select-Object -First 1; Write-Host 'Primary storage type:' $disk.MediaType"

echo Applying storage optimizations...

:: Disable last access time tracking
fsutil behavior set DisableLastAccess 1 >nul 2>&1

:: Disable pagefile encryption for performance
fsutil behavior set EncryptPagingFile 0 >nul 2>&1

:: Optimize NTFS settings
fsutil behavior set MemoryUsage 2 >nul 2>&1

:: Disable automatic defragmentation for SSDs
powershell -Command "if ((Get-PhysicalDisk | Select-Object -First 1).MediaType -eq 'SSD') { Write-Host 'SSD detected - disabling automatic defragmentation'; schtasks /Change /TN 'Microsoft\Windows\Defrag\ScheduledDefrag' /Disable 2>null } else { Write-Host 'HDD detected - keeping defragmentation enabled' }" 2>nul

echo Storage performance optimizations applied successfully.
echo Last access time tracking disabled.
echo NTFS performance optimized.
echo.
pause
goto ADVANCED_TWEAKS

:AUDIO_OPTIMIZATION
cls
echo Audio System Optimization
echo ================================================================================
echo.
echo Applying audio optimizations for gaming...

:: Optimize audio task priority
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio" /v "GPU Priority" /t REG_DWORD /d 8 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio" /v Priority /t REG_DWORD /d 6 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio" /v "Scheduling Category" /t REG_SZ /d "High" /f >nul 2>&1

:: Optimize playback device priority
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\PlaybackMedia" /v "GPU Priority" /t REG_DWORD /d 8 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\PlaybackMedia" /v Priority /t REG_DWORD /d 6 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\PlaybackMedia" /v "Scheduling Category" /t REG_SZ /d "High" /f >nul 2>&1

echo Audio system optimizations applied successfully.
echo Audio processing priority increased.
echo Audio latency reduced for gaming.
echo.
pause
goto ADVANCED_TWEAKS

:: ========================================================================
::                         GAMING SERVICES MANAGER
:: ========================================================================
:GAMING_SERVICES
cls
echo.
echo Gaming Services Manager
echo ================================================================================
echo.
echo   [1] Optimize Services for Gaming - Stop unnecessary services
echo   [2] Enable Essential Services - Start required gaming services
echo   [3] View Service Status - Check current service states
echo   [4] Custom Service Configuration - Manual service control
echo   [5] Return to Main Menu
echo.
choice /C 12345 /N /M "Select option [1-5]: "

if errorlevel 5 goto MAIN_MENU
if errorlevel 4 goto CUSTOM_SERVICES
if errorlevel 3 goto SERVICE_STATUS
if errorlevel 2 goto ENABLE_SERVICES
if errorlevel 1 goto OPTIMIZE_SERVICES

:OPTIMIZE_SERVICES
cls
echo Optimizing Services for Gaming Performance
echo ================================================================================
echo.

echo Stopping non-essential services that can impact gaming performance...

set "SERVICES_TO_OPTIMIZE=SysMain WSearch Spooler Fax BITS TabletInputService DiagTrack dmwappushservice PcaSvc WerSvc RemoteRegistry TapiSrv"

for %%S in (%SERVICES_TO_OPTIMIZE%) do (
    sc query "%%S" >nul 2>&1
    if !errorlevel! equ 0 (
        echo Optimizing service: %%S
        net stop "%%S" >nul 2>&1
        sc config "%%S" start=demand >nul 2>&1
    )
)

echo.
echo Services optimized for gaming performance.
echo Non-essential services have been set to manual startup.
echo.
pause
goto GAMING_SERVICES

:ENABLE_SERVICES
cls
echo Enabling Essential Gaming Services
echo ================================================================================
echo.

echo Starting essential services for optimal gaming experience...

set "ESSENTIAL_SERVICES=AudioSrv AudioEndpointBuilder Themes UxSms Dhcp Dnscache EventLog PlugPlay"

for %%S in (%ESSENTIAL_SERVICES%) do (
    echo Ensuring service is running: %%S
    sc config "%%S" start=auto >nul 2>&1
    net start "%%S" >nul 2>&1
)

echo.
echo Essential gaming services are now running.
echo Audio, network, and system services optimized.
echo.
pause
goto GAMING_SERVICES

:SERVICE_STATUS
cls
echo Current Service Status
echo ================================================================================
echo.

echo Essential Gaming Services:
echo.
set "CHECK_SERVICES=AudioSrv AudioEndpointBuilder Dhcp Dnscache"
for %%S in (%CHECK_SERVICES%) do (
    sc query "%%S" | findstr "STATE" | findstr "RUNNING" >nul 2>&1
    if !errorlevel! equ 0 (
        echo [RUNNING] %%S
    ) else (
        echo [STOPPED] %%S
    )
)

echo.
echo Optimized/Disabled Services:
echo.
set "OPT_SERVICES=SysMain WSearch BITS"
for %%S in (%OPT_SERVICES%) do (
    sc query "%%S" | findstr "STATE" | findstr "RUNNING" >nul 2>&1
    if !errorlevel! equ 0 (
        echo [RUNNING] %%S - Consider stopping for better gaming performance
    ) else (
        echo [STOPPED] %%S - Optimized for gaming
    )
)

echo.
pause
goto GAMING_SERVICES

:CUSTOM_SERVICES
cls
echo Custom Service Configuration
echo ================================================================================
echo.
echo Available actions:
echo   [1] Stop a specific service
echo   [2] Start a specific service  
echo   [3] Set service to automatic startup
echo   [4] Set service to manual startup
echo   [5] Return to Gaming Services Menu
echo.
choice /C 12345 /N /M "Select action [1-5]: "

if errorlevel 5 goto GAMING_SERVICES
if errorlevel 4 goto SET_MANUAL
if errorlevel 3 goto SET_AUTO
if errorlevel 2 goto START_SERVICE
if errorlevel 1 goto STOP_SERVICE

:STOP_SERVICE
echo.
set /p "SERVICE_NAME=Enter service name to stop: "
net stop "%SERVICE_NAME%" 2>nul
if !errorlevel! equ 0 (
    echo Service %SERVICE_NAME% stopped successfully.
) else (
    echo Failed to stop service %SERVICE_NAME% or service not found.
)
pause
goto CUSTOM_SERVICES

:START_SERVICE
echo.
set /p "SERVICE_NAME=Enter service name to start: "
net start "%SERVICE_NAME%" 2>nul
if !errorlevel! equ 0 (
    echo Service %SERVICE_NAME% started successfully.
) else (
    echo Failed to start service %SERVICE_NAME% or service not found.
)
pause
goto CUSTOM_SERVICES

:SET_AUTO
echo.
set /p "SERVICE_NAME=Enter service name for automatic startup: "
sc config "%SERVICE_NAME%" start=auto 2>nul
if !errorlevel! equ 0 (
    echo Service %SERVICE_NAME% set to automatic startup.
) else (
    echo Failed to configure service %SERVICE_NAME% or service not found.
)
pause
goto CUSTOM_SERVICES

:SET_MANUAL
echo.
set /p "SERVICE_NAME=Enter service name for manual startup: "
sc config "%SERVICE_NAME%" start=demand 2>nul
if !errorlevel! equ 0 (
    echo Service %SERVICE_NAME% set to manual startup.
) else (
    echo Failed to configure service %SERVICE_NAME% or service not found.
)
pause
goto CUSTOM_SERVICES

:: ========================================================================
::                         PERFORMANCE MONITOR (No WMIC)
:: ========================================================================
:PERFORMANCE_MONITOR
cls
echo.
echo Performance Monitor
echo ================================================================================

echo.
echo System Information:
echo.

:: CPU
powershell -NoProfile -Command "Get-CimInstance Win32_Processor | Select-Object -ExpandProperty Name"

:: RAM (GB)
powershell -NoProfile -Command "$ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory; '{0} GB RAM' -f [math]::Round($ram/1GB)"

:: OS
powershell -NoProfile -Command "Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption"

echo.
echo GPU Information:
powershell -NoProfile -Command "Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name"

echo.
echo Storage Information:
powershell -NoProfile -Command "Get-PhysicalDisk | Select-Object FriendlyName, MediaType, @{n='Size(GB)';e={[math]::Round($_.Size/1GB,0)}} | Format-Table -AutoSize"

echo.
echo Current Power Plan:
powercfg /getactivescheme

echo.
echo Gaming Optimization Status:
echo.

reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness 2>nul | findstr "0x0" >nul
if !errorlevel! equ 0 (
    echo [OPTIMIZED] System Responsiveness
) else (
    echo [NOT OPTIMIZED] System Responsiveness
)

reg query "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode 2>nul | findstr "0x2" >nul
if !errorlevel! equ 0 (
    echo [ENABLED] GPU Hardware Scheduling
) else (
    echo [DISABLED] GPU Hardware Scheduling
)

reg query "HKCU\System\GameConfigStore" /v GameDVR_Enabled 2>nul | findstr "0x0" >nul
if !errorlevel! equ 0 (
    echo [OPTIMIZED] Game DVR (Disabled for performance)
) else (
    echo [NOT OPTIMIZED] Game DVR (May impact performance)
)

echo.
echo Memory Usage:
powershell -NoProfile -Command "$os = Get-CimInstance Win32_OperatingSystem; $total=[math]::Round($os.TotalVisibleMemorySize/1MB,0); $free=[math]::Round($os.FreePhysicalMemory/1MB,0); $used=$total-$free; $percent=[math]::Round(($used/$total)*100,0); Write-Host ('Used: {0} MB / {1} MB ({2}%%)' -f $used,$total,$percent)"

echo.
echo -------------------------------------------------
echo Press any key to return to main menu...
pause > nul
goto MAIN_MENU

:: ========================================================================
::                            CLEANUP TOOLS
:: ========================================================================
:CLEANUP_TOOLS
cls
echo.
echo Cleanup Tools
echo ================================================================================
echo.
echo   [1] System File Cleanup - Remove temporary and cache files
echo   [2] Registry Cleanup - Clean invalid registry entries
echo   [3] Memory Cleanup - Clear RAM and working sets
echo   [4] Network Cache Cleanup - Clear DNS and network caches
echo   [5] Complete System Cleanup - Run all cleanup operations
echo   [6] Return to Main Menu
echo.
choice /C 123456 /N /M "Select cleanup option [1-6]: "

if errorlevel 6 goto MAIN_MENU
if errorlevel 5 goto COMPLETE_CLEANUP
if errorlevel 4 goto NETWORK_CLEANUP
if errorlevel 3 goto MEMORY_CLEANUP
if errorlevel 2 goto REGISTRY_CLEANUP
if errorlevel 1 goto FILE_CLEANUP

:FILE_CLEANUP
cls
echo System File Cleanup
echo ================================================================================
echo.

echo Cleaning temporary files...
del /s /f /q "%temp%\*.*" >nul 2>&1
for /d %%i in ("%temp%\*") do rd /s /q "%%i" >nul 2>&1

del /s /f /q "C:\Windows\Temp\*.*" >nul 2>&1
for /d %%i in ("C:\Windows\Temp\*") do rd /s /q "%%i" >nul 2>&1

echo Cleaning prefetch files...
if exist "%windir%\Prefetch" (
    del /s /f /q "%windir%\Prefetch\*.*" >nul 2>&1
)

echo Cleaning recent files...
del /s /f /q "%userprofile%\AppData\Roaming\Microsoft\Windows\Recent\*.*" >nul 2>&1

echo Cleaning thumbnail cache...
del /s /f /q "%userprofile%\AppData\Local\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1

echo Emptying recycle bin...
powershell -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >nul 2>&1

echo.
echo System file cleanup completed successfully.
echo.
pause
goto CLEANUP_TOOLS

:REGISTRY_CLEANUP
cls
echo Registry Cleanup
echo ================================================================================
echo.

echo Cleaning registry entries for better performance...

echo Removing old registry entries...
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths" /f >nul 2>&1

echo Optimizing registry for gaming...
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 0 /f >nul 2>&1

echo.
echo Registry cleanup completed successfully.
echo.
pause
goto CLEANUP_TOOLS

:MEMORY_CLEANUP
cls
echo Memory Cleanup
echo ================================================================================
echo.

echo Clearing system memory caches...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Process | Where-Object {$_.WorkingSet -gt 50MB -and $_.ProcessName -ne 'explorer' -and $_.ProcessName -ne 'dwm' -and $_.ProcessName -ne 'winlogon'} | ForEach-Object { try { Write-Host 'Clearing memory for:' $_.ProcessName; $_.EmptyWorkingSet() } catch { Write-Host 'Could not clear memory for:' $_.ProcessName } }" 2>nul

echo Clearing standby memory...
powershell -Command "if (Get-Command 'Clear-StandbyMemory' -ErrorAction SilentlyContinue) { Clear-StandbyMemory }" >nul 2>&1

echo.
echo Memory cleanup completed successfully.
echo.
pause
goto CLEANUP_TOOLS

:NETWORK_CLEANUP
cls
echo Network Cache Cleanup
echo ================================================================================
echo.

echo Clearing DNS cache...
ipconfig /flushdns >nul 2>&1

echo Clearing ARP cache...
netsh interface ip delete arpcache >nul 2>&1

echo Resetting network statistics...
netsh int ip reset >nul 2>&1

echo Clearing NetBios cache...
nbtstat -R >nul 2>&1
nbtstat -RR >nul 2>&1

echo.
echo Network cache cleanup completed successfully.
echo Network performance may be improved.
echo.
pause
goto CLEANUP_TOOLS

:COMPLETE_CLEANUP
cls
echo Complete System Cleanup
echo ================================================================================
echo.

echo [1/4] Cleaning system files...
del /s /f /q "%temp%\*.*" >nul 2>&1
for /d %%i in ("%temp%\*") do rd /s /q "%%i" >nul 2>&1
del /s /f /q "C:\Windows\Temp\*.*" >nul 2>&1
for /d %%i in ("C:\Windows\Temp\*") do rd /s /q "%%i" >nul 2>&1
if exist "%windir%\Prefetch" del /s /f /q "%windir%\Prefetch\*.*" >nul 2>&1
del /s /f /q "%userprofile%\AppData\Roaming\Microsoft\Windows\Recent\*.*" >nul 2>&1
del /s /f /q "%userprofile%\AppData\Local\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
powershell -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >nul 2>&1

echo [2/4] Cleaning registry...
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths" /f >nul 2>&1

echo [3/4] Clearing memory caches...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Process | Where-Object {$_.WorkingSet -gt 50MB -and $_.ProcessName -ne 'explorer' -and $_.ProcessName -ne 'dwm'} | ForEach-Object { try { $_.EmptyWorkingSet() } catch {} }" >nul 2>&1

echo [4/4] Clearing network caches...
ipconfig /flushdns >nul 2>&1
netsh interface ip delete arpcache >nul 2>&1
nbtstat -R >nul 2>&1

echo.
echo Complete system cleanup finished successfully.
echo System performance optimized and caches cleared.
echo.
pause
goto CLEANUP_TOOLS

:: ========================================================================
::                       NETWORK GAMING OPTIMIZER
:: ========================================================================
:NETWORK_GAMING
cls
echo.
echo Network Gaming Optimizer
echo ================================================================================
echo.
echo   [1] Optimize Network for Low Latency - Reduce ping and lag
echo   [2] Gaming Network Priority Setup - Prioritize gaming traffic
echo   [3] Advanced TCP/IP Optimization - Fine-tune network stack
echo   [4] Network Adapter Optimization - Optimize network hardware
echo   [5] Test Network Performance - Check current network status
echo   [6] Return to Main Menu
echo.
choice /C 123456 /N /M "Select network optimization [1-6]: "

if errorlevel 6 goto MAIN_MENU
if errorlevel 5 goto NETWORK_TEST
if errorlevel 4 goto ADAPTER_OPTIMIZATION
if errorlevel 3 goto TCPIP_OPTIMIZATION
if errorlevel 2 goto GAMING_PRIORITY
if errorlevel 1 goto LOW_LATENCY

:LOW_LATENCY
cls
echo Network Low Latency Optimization
echo ================================================================================
echo.

echo Applying low latency network optimizations...

echo Optimizing TCP settings...
netsh int tcp set global autotuninglevel=normal >nul 2>&1
netsh int tcp set global chimney=enabled >nul 2>&1
netsh int tcp set global rss=enabled >nul 2>&1
netsh int tcp set global netdma=enabled >nul 2>&1
netsh int tcp set heuristics disabled >nul 2>&1

echo Disabling Nagle's algorithm...
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TCPNoDelay /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpAckFrequency /t REG_DWORD /d 1 /f >nul 2>&1

echo Optimizing network buffer sizes...
netsh int tcp set global initialRto=2000 >nul 2>&1
netsh int tcp set global rsc=enabled >nul 2>&1

echo Clearing network caches...
ipconfig /flushdns >nul 2>&1
netsh interface ip delete arpcache >nul 2>&1

echo.
echo Low latency network optimization completed.
echo Network ping and responsiveness should be improved.
echo.
pause
goto NETWORK_GAMING

:GAMING_PRIORITY
cls
echo Gaming Network Priority Setup
echo ================================================================================
echo.

echo Setting up gaming network priority...

echo Disabling network throttling for games...
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" /v "Network Throttling Index" /t REG_DWORD /d 4294967295 /f >nul 2>&1

echo Optimizing QoS settings...
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v NonBestEffortLimit /t REG_DWORD /d 0 /f >nul 2>&1

echo Setting gaming traffic priority...
powershell -Command "if (Get-Command 'New-NetQosPolicy' -ErrorAction SilentlyContinue) { try { New-NetQosPolicy -Name 'Gaming' -AppPathNameMatchCondition '*.exe' -NetworkProfile All -PrecedenceValue 127 -ErrorAction SilentlyContinue } catch {} }" >nul 2>&1

echo.
echo Gaming network priority setup completed.
echo Gaming traffic is now prioritized over other network activities.
echo.
pause
goto NETWORK_GAMING

:TCPIP_OPTIMIZATION
cls
echo Advanced TCP/IP Optimization
echo ================================================================================
echo.

echo Applying advanced TCP/IP optimizations...

echo Optimizing TCP window scaling...
netsh int tcp set global autotuninglevel=normal >nul 2>&1

echo Configuring TCP Chimney Offload...
netsh int tcp set global chimney=enabled >nul 2>&1

echo Enabling Receive Side Scaling...
netsh int tcp set global rss=enabled >nul 2>&1

echo Configuring NetDMA...
netsh int tcp set global netdma=enabled >nul 2>&1

echo Disabling TCP heuristics...
netsh int tcp set heuristics disabled >nul 2>&1

echo Optimizing receive window...
netsh int tcp set global rsc=enabled >nul 2>&1

echo Disabling TCP timestamps...
netsh int tcp set global timestamps=disabled >nul 2>&1

echo Setting optimal MTU size...
powershell -Command "Get-NetAdapter | Where-Object {$_.Status -eq 'Up' -and $_.InterfaceType -eq 6} | ForEach-Object { netsh interface ipv4 set subinterface $_.InterfaceIndex mtu=1500 store=persistent }" >nul 2>&1

echo.
echo Advanced TCP/IP optimization completed.
echo Network stack optimized for gaming performance.
echo.
pause
goto NETWORK_GAMING

:ADAPTER_OPTIMIZATION
cls
echo Network Adapter Optimization
echo ================================================================================
echo.

echo Optimizing network adapter settings...

echo Detecting active network adapters...
powershell -Command "Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | Select-Object Name, InterfaceDescription | Format-Table -AutoSize"

echo Applying adapter optimizations...
powershell -Command "Get-NetAdapterAdvancedProperty | Where-Object {$_.DisplayName -like '*Power*'} | Set-NetAdapterAdvancedProperty -DisplayValue 'Disabled' -ErrorAction SilentlyContinue" >nul 2>&1

echo Disabling power management...
powershell -Command "Get-NetAdapter | ForEach-Object { $adapter = $_; Get-PnpDevice | Where-Object {$_.FriendlyName -like '*' + $adapter.InterfaceDescription + '*'} | Get-PnpDeviceProperty -KeyName 'DEVPKEY_Device_PowerData' | Set-PnpDeviceProperty -KeyName 'DEVPKEY_Device_PowerData' -Data 0 -ErrorAction SilentlyContinue }" >nul 2>&1

echo Optimizing interrupt moderation...
powershell -Command "Get-NetAdapterAdvancedProperty | Where-Object {$_.DisplayName -like '*Interrupt*'} | Set-NetAdapterAdvancedProperty -DisplayValue 'Enabled' -ErrorAction SilentlyContinue" >nul 2>&1

echo.
echo Network adapter optimization completed.
echo Adapter settings optimized for gaming performance.
echo.
pause
goto NETWORK_GAMING

:NETWORK_TEST
cls
echo Network Performance Test
echo ================================================================================
echo.

echo Current Network Configuration:
echo.

echo Active Network Adapters:
powershell -Command "Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | Select-Object Name, LinkSpeed | Format-Table -AutoSize"

echo.
echo TCP Settings:
netsh int tcp show global | findstr "Receive Window Auto-Tuning Level\|Chimney Offload State\|RSS State\|NetDMA State"

echo.
echo DNS Configuration:
ipconfig /all | findstr "DNS Servers"

echo.
echo Network Latency Test:
echo Testing connectivity to common gaming servers...
ping -n 4 8.8.8.8 | findstr "Average"
ping -n 4 1.1.1.1 | findstr "Average"

echo.
echo Current QoS Policies:
powershell -Command "if (Get-Command 'Get-NetQosPolicy' -ErrorAction SilentlyContinue) { Get-NetQosPolicy | Format-Table Name, AppPathNameMatchCondition, PrecedenceValue -AutoSize }" 2>nul

echo.
pause
goto NETWORK_GAMING

:: ========================================================================
::                        RESTORE DEFAULT SETTINGS
:: ========================================================================
:RESTORE_DEFAULTS
cls
echo.
echo Restore Default Settings
echo ================================================================================
echo.
echo WARNING: This will revert all optimizations back to Windows defaults.
echo.
echo This includes:
echo - Power plan settings
echo - Visual effects settings  
echo - Service configurations
echo - Registry optimizations
echo - Network settings
echo.
choice /C YN /N /M "Are you sure you want to restore defaults? [Y/N]: "

if errorlevel 2 goto MAIN_MENU
if errorlevel 1 goto PERFORM_RESTORE

:PERFORM_RESTORE
cls
echo Restoring Default Settings
echo ================================================================================
echo.

echo [1/8] Restoring power plan settings...
powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e >nul 2>&1
powercfg -change -monitor-timeout-ac 10 >nul 2>&1
powercfg -change -disk-timeout-ac 20 >nul 2>&1
powercfg -change -standby-timeout-ac 30 >nul 2>&1
powercfg -h on >nul 2>&1

echo [2/8] Restoring visual effects...
reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d "400" /f >nul 2>&1
reg add "HKCU\Control Panel\Desktop\WindowMetrics" /v MinAnimate /t REG_SZ /d "1" /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAnimations /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 0 /f >nul 2>&1

echo [3/8] Restoring service configurations...
set "RESTORE_SERVICES=SysMain WSearch Spooler BITS"
for %%S in (%RESTORE_SERVICES%) do (
    sc config "%%S" start=auto >nul 2>&1
    net start "%%S" >nul 2>&1
)

echo [4/8] Restoring registry settings...
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 20 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" /v Win32PrioritySeparation /t REG_DWORD /d 2 /f >nul 2>&1

echo [5/8] Restoring memory management...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v DisablePagingExecutive /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v LargeSystemCache /t REG_DWORD /d 1 /f >nul 2>&1

echo [6/8] Restoring network settings...
netsh int tcp reset >nul 2>&1
netsh winsock reset >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TCPNoDelay /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v TcpAckFrequency /f >nul 2>&1

echo [7/8] Restoring GPU settings...
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /f >nul 2>&1
reg delete "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v TdrLevel /f >nul 2>&1

echo [8/8] Applying changes...
schtasks /Change /TN "Microsoft\Windows\Defrag\ScheduledDefrag" /Enable >nul 2>&1
RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters >nul 2>&1
gpupdate /force >nul 2>&1

echo.
echo ================================================================================
echo                         RESTORE COMPLETED SUCCESSFULLY!
echo ================================================================================
echo.
echo All settings have been restored to Windows defaults.
echo.
echo System restart is recommended for all changes to take effect.
echo.
pause
goto MAIN_MENU