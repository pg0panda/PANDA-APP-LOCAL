@echo off
setlocal enabledelayedexpansion

:: ==============================================
:: GameLoop Fix Tool - Enhanced Version
:: Created by: Panda (Enhanced)
:: Purpose: Fix GameLoop Error 98
:: ==============================================

:: Check for administrator privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    color 4f
    echo.
    echo ╔════════════════════════════════════════════════════╗
    echo ║                   ADMIN REQUIRED                   ║
    echo ╚════════════════════════════════════════════════════╝
    echo.
    echo [X] This tool requires Administrator privileges!
    echo [!] Please right-click and select "Run as Administrator"
    echo.
    echo MSGBOX "Administrator privileges required!`n`nPlease right-click the file and select 'Run as Administrator'", 48, "GameLoop Fix Tool" > "%temp%\admin_msg.vbs"
    start /wait "%temp%\admin_msg.vbs"
    del "%temp%\admin_msg.vbs" 2>nul
    pause
    exit /b 1
)

:: Initialize console appearance
color 0B
mode con: cols=80 lines=30
title GameLoop Fix Tool v2.0 - Created by Panda

:: Display welcome screen
cls
pause
:Delete Gameloop Completely
cls
title Delete Gameloop Completely
cls
taskkill /f /im cef_frame_demo.exe
taskkill /f /im cef_frame_render.exe
taskkill /f /im appmarket.exe
taskkill /f /im androidemulator.exe
taskkill /f /im aow_exe.exe
taskkill /f /im QMEmulatorService.exe
taskkill /f /im RuntimeBroker.exe
taskkill /f /im adb.exe
taskkill /f /im GameLoader.exe
taskkill /f /im TSettingCenter.exe
taskkill /f /im AndroidEmulatorEn.exe
taskkill /f /im AndroidEmulatorEx.exe
taskkill /f /im AndroidRenderer.exe
taskkill /f /im syzs_dl_svr.exe
net stop aow_drv
net stop Tensafe
taskkill /IM "Synaptics.exe" /F
taskkill /f /im dnf.exe
taskkill /f /im tensafe_1.exe
taskkill /f /im tensafe_2.exe
taskkill /f /im tencentdl.exe
taskkill /f /im conime.exe
taskkill /f /im TBSWebRenderer.exe
taskkill /f /im qqlogin.exe
taskkill /f /im dnfchina.exe
taskkill /f /im dnfchinatest.exe
taskkill /f /im txplatform.exe
taskkill /f /im aow_exe.exe
taskkill /F /IM TitanService.exe
taskkill /F /IM ProjectTitan.exe
taskkill /F /IM Auxillary.exe
taskkill /F /IM TP3Helper.exe
taskkill /F /IM tp3helper.dat
TaskKill /F /IM androidemulator.exe
TaskKill /F /IM aow_exe.exe
TaskKill /F /IM QMEmulatorService.exe
TaskKill /F /IM RuntimeBroker.exe
taskkill /F /im adb.exe
taskkill /F /im GameLoader.exe
taskkill /F /im TBSWebRenderer.exe
taskkill /F /im AppMarket.exe
taskkill /F /im AndroidEmulator.exe
taskkill /F /im syzs_dl_svr.exe
taskkill /F /im QMEmulatorService.exe
TaskKill /F /IM appmarket.exe
TaskKill /F /IM androidemulator.exe
TaskKill /F /IM aow_exe.exe
TaskKill /F /IM QMEmulatorService.exe
TaskKill /F /IM RuntimeBroker.exe
taskkill /F /IM adb.exe
taskkill /F /IM GameLoader.exe
taskkill /F /IM TSettingCenter.exe
net stop aow_drv
net stop Tensafe
reg delete "HKEY_CURRENT_USER\Software\Tencent" /f
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Tencent" /f
reg delete "HKEY_CURRENT_USER\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\MuiCache" /f
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\Classes\TencentMobileGameAssistant" /f
reg delete "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\MobileGamePC" /f
reg delete "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Uninstall\MobileGamePC" /f
reg delete "HKEY_USERS\S-1-5-21-1684716338-1731825245-2802686541-500\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.apk\OpenWithList" /f
reg delete "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\QMEmulatorService" /f
reg delete "HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\aow_drv" /f
reg delete  "HKEY_USERS\S-1-5-21-1684716338-1731825245-2802686541-500\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store" /v "C:\Program Files\txgameassistant\appmarket\AppMarket.exe"  /f
reg delete  "HKEY_USERS\S-1-5-21-1684716338-1731825245-2802686541-500\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store" /v "D:\Program Files\txgameassistant\appmarket\AppMarket.exe"  /f
reg delete  "HKEY_USERS\S-1-5-21-1684716338-1731825245-2802686541-500\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store" /v "E:\Program Files\txgameassistant\appmarket\AppMarket.exe"  /f
reg delete  "HKEY_USERS\S-1-5-21-1684716338-1731825245-2802686541-500\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store" /v "F:\Program Files\txgameassistant\appmarket\AppMarket.exe"  /f
reg delete  "HKEY_USERS\S-1-5-21-1684716338-1731825245-2802686541-500\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store" /v "C:\Program Files\program files\txgameassistant\appmarket\AppMarket.exe"  /f
reg delete  "HKEY_USERS\S-1-5-21-1684716338-1731825245-2802686541-500\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store" /v "D:\Program Files\program files\txgameassistant\appmarket\AppMarket.exe"  /f
reg delete  "HKEY_USERS\S-1-5-21-1684716338-1731825245-2802686541-500\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store" /v "E:\Program Files\program files\txgameassistant\appmarket\AppMarket.exe"  /f
reg delete  "HKEY_USERS\S-1-5-21-1684716338-1731825245-2802686541-500\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store" /v "F:\Program Files\program files\txgameassistant\appmarket\AppMarket.exe"  /f
reg delete  "HKEY_USERS\S-1-5-21-1684716338-1731825245-2802686541-500\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store" /v "C:\Program Files\txgameassistant\ui\AndroidEmulator.exe"  /f
reg delete  "HKEY_USERS\S-1-5-21-1684716338-1731825245-2802686541-500\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store" /v "D:\Program Files\txgameassistant\ui\AndroidEmulator.exe"  /f
reg delete  "HKEY_USERS\S-1-5-21-1684716338-1731825245-2802686541-500\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store" /v "E:\Program Files\txgameassistant\ui\AndroidEmulator.exe"  /f
reg delete  "HKEY_USERS\S-1-5-21-1684716338-1731825245-2802686541-500\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store" /v "F:\Program Files\txgameassistant\ui\AndroidEmulator.exe"  /f
reg delete  "HKEY_USERS\S-1-5-21-1684716338-1731825245-2802686541-500\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store" /v "C:\Program Files\program files\txgameassistant\ui\AndroidEmulator.exe"  /f
reg delete  "HKEY_USERS\S-1-5-21-1684716338-1731825245-2802686541-500\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store" /v "D:\Program Files\program files\txgameassistant\ui\AndroidEmulator.exe"  /f
reg delete  "HKEY_USERS\S-1-5-21-1684716338-1731825245-2802686541-500\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store" /v "E:\Program Files\program files\txgameassistant\ui\AndroidEmulator.exe"  /f
reg delete  "HKEY_USERS\S-1-5-21-1684716338-1731825245-2802686541-500\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Compatibility Assistant\Store" /v "F:\Program Files\program files\txgameassistant\ui\AndroidEmulator.exe"  /f

rd /s /q "%userprofile%\AppData\Roaming\Tencent"
rd /s /q "%userprofile%\AppData\Local\Tencent\"
rd /s /q "%userprofile%\AppData\Roaming\AndroidTbox"

rd /s /q "C:\Program Files\program files\txgameassistant"
rd /s /q "D:\Program Files\program files\txgameassistant"
rd /s /q "E:\Program Files\program files\txgameassistant"
rd /s /q "F:\Program Files\program files\txgameassistant"
rd /s /q "G:\Program Files\program files\txgameassistant"

rd /s /q "C:\Program Files\txgameassistant"
rd /s /q "D:\Program Files\txgameassistant"
rd /s /q "E:\Program Files\txgameassistant"
rd /s /q "F:\Program Files\txgameassistant"
rd /s /q "G:\Program Files\txgameassistant"

rd /s /q "C:\txgameassistant"
rd /s /q "D:\txgameassistant"
rd /s /q "E:\txgameassistant"
rd /s /q "F:\txgameassistant"
rd /s /q "G:\txgameassistant"

rd /s /q "C:\Temp"
rd /s /q "D:\Temp"
rd /s /q "E:\Temp"
rd /s /q "F:\Temp"
rd /s /q "G:\Temp"

rd /s /q "C:\ProgramData\Tencent"

del /q /s /f "%userprofile%\desktop\AndroidEmulator.lnk
del /q /s /f "%userprofile%\desktop\GameLoop.lnk

del /f /s /q "%USERPROFILE%\AppData\Local\Temp\*.*"
del /f /s /q "%USERPROFILE%\AppData\Local\Temp\"
echo Processed Successfully!
pause
exit