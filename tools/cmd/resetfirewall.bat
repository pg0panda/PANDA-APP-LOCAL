@echo off
chcp 65001 > nul
title Reset Windows Firewall - Created by Panda
color 0b

:: Check for administrator privileges
fsutil dirty query %systemdrive% >nul 2>&1
if %errorlevel% NEQ 0 (
    echo.
    echo [!] This script must be run as Administrator.
    echo [!] Restarting with admin rights...
    
    :: Create temporary VBS script to request admin
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\_getadmin.vbs"
    echo UAC.ShellExecute "cmd.exe", "/c ""%~s0""", "", "runas", 1 >> "%temp%\_getadmin.vbs"
    "%temp%\_getadmin.vbs"
    del "%temp%\_getadmin.vbs"
    exit /B
)

:main_menu
cls
echo ╔════════════════════════════════════════════════════════════╗
echo ║                     Firewall Reset Tool                    ║
echo ║                      Created by Panda                      ║
echo ╠════════════════════════════════════════════════════════════╣
echo ║                                                            ║
echo ║[1] Reset Windows Firewall Completely                       ║
echo ║                                                            ║
echo ║[2] Restore Default Settings                                ║
echo ║                                                            ║
echo ║[3] Enable Firewall for All Profiles                        ║
echo ║                                                            ║
echo ║[4] Disable Firewall for All Profiles                       ║
echo ║                                                            ║
echo ║[5] Show Current Firewall Status                            ║
echo ║                                                            ║
echo ║[0] Exit                                                    ║
echo ║                                                            ║
echo ╚════════════════════════════════════════════════════════════╝
echo.
set /p choice="Choose option number (0-5): "

if "%choice%"=="1" goto reset_firewall
if "%choice%"=="2" goto restore_defaults
if "%choice%"=="3" goto enable_firewall
if "%choice%"=="4" goto disable_firewall
if "%choice%"=="5" goto show_status
if "%choice%"=="0" goto exit_script
echo خيار غير صحيح / Invalid choice!
timeout /t 2 > nul
goto main_menu

:reset_firewall
cls
echo ╔════════════════════════════════════════════════════════════╗
echo ║                    Resetting Firewall...                   ║
echo ╚════════════════════════════════════════════════════════════╝
echo.
echo [*] Starting reset process...
echo.

:: Reset firewall completely
echo [1/4] Resetting firewall settings...
netsh advfirewall reset

echo [2/4] Deleting all custom rules...
netsh advfirewall firewall delete rule name=all

echo [3/4] Restoring default policies...
netsh advfirewall set allprofiles firewallpolicy blockinbound,allowoutbound

echo [4/4] Enabling firewall for all profiles...
netsh advfirewall set allprofiles state on

echo.
echo  Firewall has been successfully reset!
echo.
pause
goto main_menu

:restore_defaults
cls
echo ╔════════════════════════════════════════════════════════════╗
echo ║                  Restoring Default Settings                ║
echo ╚════════════════════════════════════════════════════════════╝
echo.

echo [*] Restoring default settings...
netsh advfirewall set allprofiles firewallpolicy blockinbound,allowoutbound
netsh advfirewall set allprofiles settings remotemanagement disable
netsh advfirewall set allprofiles settings unicastresponsetomulticast enable

echo.
echo  Default settings restored successfully!
echo.
pause
goto main_menu

:enable_firewall
cls
echo ╔════════════════════════════════════════════════════════════╗
echo ║                        Enabling Firewall...                ║
echo ╚════════════════════════════════════════════════════════════╝
echo.

echo [*] Enabling firewall for all profiles...
netsh advfirewall set allprofiles state on

echo.
echo  Firewall enabled successfully!
echo.
pause
goto main_menu

:disable_firewall
cls
echo ╔════════════════════════════════════════════════════════════╗
echo ║                        Disabling Firewall...               ║
echo ╚════════════════════════════════════════════════════════════╝
echo.
echo  Warning: Disabling firewall may expose your system to risks!
echo.
set /p confirm="Are you sure? (y/n): "
if /i not "%confirm%"=="y" goto main_menu

echo [*] Disabling firewall for all profiles...
netsh advfirewall set allprofiles state off

echo.
echo  Firewall disabled!
echo.
pause
goto main_menu

:show_status
cls
echo ╔════════════════════════════════════════════════════════════╗
echo ║                    Current Firewall Status                 ║
echo ╚════════════════════════════════════════════════════════════╝
echo.

echo [*] Displaying firewall status...
echo.
netsh advfirewall show allprofiles

echo.
echo [*] Displaying active rules...
echo.
netsh advfirewall firewall show rule name=all | findstr /i "rule name"

echo.
pause
goto main_menu

:exit_script
cls
echo ╔════════════════════════════════════════════════════════════╗
echo ║                      Goodbye!                              ║
echo ║                   Created by Panda                         ║
echo ╚════════════════════════════════════════════════════════════╝
echo.
echo شكراً لاستخدام الأداة!
echo Thanks for using the tool!
timeout /t 3 > nul
exit