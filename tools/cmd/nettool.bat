@echo off
setlocal enabledelayedexpansion

:: ===== Script Settings =====
title Advanced Network Reset Tool v2.1 - Created by PANDA
color 0b
chcp 65001 >nul

:: Check for Administrator privileges
NET SESSION >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo WARNING: This script must be run as Administrator
    echo.
    mshta "javascript:alert('Administrator privileges required!\n\nPlease right-click and select Run as Administrator');close()"
    pause
    exit /b
)

:: ===== Variables =====
set "logfile=%temp%\network_reset_log.txt"
set "statefile=%temp%\network_tool_state.ini"
set "lastdns=Unknown"

if exist "%statefile%" (
    for /f "usebackq delims=" %%a in ("%statefile%") do set "lastdns=%%a"
)

:MAIN_MENU
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                 Advanced Network Reset Tool v2.1                 ║
echo ║                        Created by PANDA                          ║
echo ╠══════════════════════════════════════════════════════════════════╣
echo ║                                                                  ║
echo ║  [1] Complete Network Reset (Recommended)                        ║
echo ║  [2] DNS Cache Flush Only                                        ║
echo ║  [3] Reset TCP/IP                                                ║
echo ║  [4] Restart Network Adapters                                    ║
echo ║  [5] Renew IP Addresses                                          ║
echo ║  [6] Network Diagnosis                                           ║
echo ║  [7] Connection Test                                             ║
echo ║  [8] Advanced Settings                                           ║
echo ║  [0] Exit                                                        ║
echo ║                                                                  ║
echo ╠══════════════════════════════════════════════════════════════════╣
echo ║  Last selected DNS: %lastdns%                                      ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
set /p "choice=Select option number: "

if "%choice%"=="1" goto FULL_RESET
if "%choice%"=="2" goto DNS_FLUSH
if "%choice%"=="3" goto WINSOCK_RESET
if "%choice%"=="4" goto ADAPTER_RESTART
if "%choice%"=="5" goto IP_RENEW
if "%choice%"=="6" goto NETWORK_DIAGNOSIS
if "%choice%"=="7" goto CONNECTION_TEST
if "%choice%"=="8" goto ADVANCED_SETTINGS
if "%choice%"=="0" goto EXIT
goto MAIN_MENU

:FULL_RESET
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                      Complete Network Reset                      ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo Executing complete network reset...
echo.

:: 1. DNS Cache Flush
echo [1/8] Flushing DNS cache...
ipconfig /flushdns >nul 2>&1
call :CHECK_SUCCESS "DNS Cache Flush"

:: 2. Reset Winsock
echo [2/8] Resetting Winsock...
netsh winsock reset >nul 2>&1
call :CHECK_SUCCESS "Winsock Reset"

:: 3. Reset TCP/IP
echo [3/8] Resetting TCP/IP...
netsh int ip reset "%temp%\resetlog.txt" >nul 2>&1
call :CHECK_SUCCESS "TCP/IP Reset"

:: 4. Reset HTTP Proxy
echo [4/8] Resetting HTTP Proxy...
netsh winhttp reset proxy >nul 2>&1
call :CHECK_SUCCESS "HTTP Proxy Reset"

:: 5. Clear ARP table
echo [5/8] Clearing ARP table...
arp -d * >nul 2>&1
call :CHECK_SUCCESS "ARP Table Clear"

:: 6. Clear neighbor cache (IPv6)
echo [6/8] Clearing neighbor cache...
netsh interface ipv6 delete neighbors >nul 2>&1
if %errorlevel% neq 0 (
    echo WARNING: Could not clear IPv6 neighbors ^(may not be supported^)
) else (
    echo SUCCESS: IPv6 neighbor cache cleared
)

:: 7. Restart network adapters
echo [7/8] Restarting network adapters...
call :RESTART_ADAPTERS

:: 8. Renew IP addresses and register DNS
echo [8/8] Renewing IP addresses...
ipconfig /release >nul 2>&1
timeout /t 3 /nobreak >nul
ipconfig /renew >nul 2>&1
call :CHECK_SUCCESS "IP Address Renewal"

echo [8/8] Registering DNS...
ipconfig /registerdns >nul 2>&1
call :CHECK_SUCCESS "DNS Registration"

echo.
echo SUCCESS: Complete network reset completed successfully!
echo NOTE: Some changes may require a system restart to take full effect.
echo.
pause
goto MAIN_MENU

:DNS_FLUSH
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                         DNS Cache Flush                          ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo Flushing DNS cache...
ipconfig /flushdns
call :CHECK_SUCCESS "DNS Cache Flush"
echo.
pause
goto MAIN_MENU

:WINSOCK_RESET
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                     Reset TCP/IP ^& Winsock                       ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo Resetting Winsock...
netsh winsock reset
echo.
echo Resetting TCP/IP...
netsh int ip reset "%temp%\resetlog.txt"
echo.
echo WARNING: You may need to restart your computer to activate changes
echo.
pause
goto MAIN_MENU

:ADAPTER_RESTART
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                     Restart Network Adapters                     ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
call :RESTART_ADAPTERS
echo.
pause
goto MAIN_MENU

:IP_RENEW
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                        Renew IP Addresses                        ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo Releasing IP addresses...
ipconfig /release
echo.
echo Renewing IP addresses...
ipconfig /renew
echo.
pause
goto MAIN_MENU

:NETWORK_DIAGNOSIS
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                        Network Diagnosis                         ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.

echo Active Network Adapters:
echo ================================
for /f "skip=3 tokens=1,2,3,*" %%A in ('netsh interface show interface 2^>nul') do (
    if /I "%%B"=="Connected" echo - %%D
)
echo.

echo Current IP Configuration:
echo =========================
ipconfig | findstr /i "IPv4.*Address.*Subnet.*Mask.*Default.*Gateway"
echo.

echo DNS Servers:
echo =================================
ipconfig /all | findstr /r /i "DNS.*Servers"
echo.

echo Basic Network Statistics:
echo =============================
netstat -e
echo.

pause
goto MAIN_MENU

:CONNECTION_TEST
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                         Connection Test                          ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.

echo Testing connection to Google DNS ^(8.8.8.8^)...
ping -n 2 8.8.8.8
echo.

echo Testing connection to Cloudflare DNS ^(1.1.1.1^)...
ping -n 2 1.1.1.1
echo.

echo Testing connection to google.com...
ping -n 2 google.com
echo.

pause
goto MAIN_MENU

:ADVANCED_SETTINGS
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                        Advanced Settings                         ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo  [1] Reset Firewall Settings
echo  [2] Clear Operation Log
echo  [3] Restart Network Services
echo  [4] Change DNS Servers
echo  [5] View Operation Log
echo  [6] Back to Main Menu
echo.
echo  Current last selected DNS: %lastdns%
echo.
set /p "adv_choice=Select option number: "

if "%adv_choice%"=="1" goto FIREWALL_RESET
if "%adv_choice%"=="2" goto CLEAR_LOG
if "%adv_choice%"=="3" goto RESTART_SERVICES
if "%adv_choice%"=="4" goto CHANGE_DNS
if "%adv_choice%"=="5" goto SHOW_LOG
if "%adv_choice%"=="6" goto MAIN_MENU
goto ADVANCED_SETTINGS

:FIREWALL_RESET
echo.
echo Resetting firewall settings...
netsh advfirewall reset >nul 2>&1
call :CHECK_SUCCESS "Firewall Reset"
pause
goto ADVANCED_SETTINGS

:CLEAR_LOG
echo.
echo Clearing operation log...
if exist "%logfile%" del "%logfile%" >nul 2>&1
echo SUCCESS: Operation log cleared
pause
goto ADVANCED_SETTINGS

:RESTART_SERVICES
echo.
echo Restarting network-related services...
echo Stopping services...
net stop "DHCP Client" >nul 2>&1
net stop "DNS Client" >nul 2>&1
timeout /t 2 /nobreak >nul
echo Starting services...
net start "DNS Client" >nul 2>&1
net start "DHCP Client" >nul 2>&1
call :CHECK_SUCCESS "Network Services Restart"
pause
goto ADVANCED_SETTINGS

:CHANGE_DNS
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                           Change DNS                             ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo Available network interfaces:
set "interface_count=0"
for /f "skip=3 tokens=1,2,3,*" %%A in ('netsh interface show interface 2^>nul') do (
    if /I "%%B"=="Connected" (
        set /a interface_count+=1
        echo [!interface_count!] %%D
    )
)

if %interface_count% equ 0 (
    echo ERROR: No connected network interfaces found
    pause
    goto ADVANCED_SETTINGS
)

echo.
set /p "netif=Enter network interface name exactly as shown above: "

echo.
echo  [1] Google DNS ^(8.8.8.8, 8.8.4.4^)
echo  [2] Cloudflare DNS ^(1.1.1.1, 1.0.0.1^)
echo  [3] OpenDNS ^(208.67.222.222, 208.67.220.220^)
echo  [4] Automatic ^(DHCP^)
echo.
set /p "dns_choice=Choose DNS server: "

if "%dns_choice%"=="1" (
    netsh interface ip set dns "%netif%" static 8.8.8.8 primary >nul 2>&1
    if !errorlevel! equ 0 (
        netsh interface ip add dns "%netif%" 8.8.4.4 index=2 >nul 2>&1
        set "lastdns=Google ^(8.8.8.8 / 8.8.4.4^)"
        >"%statefile%" echo !lastdns!
        echo SUCCESS: Google DNS configured
    ) else (
        echo ERROR: Failed to configure Google DNS
    )
)
if "%dns_choice%"=="2" (
    netsh interface ip set dns "%netif%" static 1.1.1.1 primary >nul 2>&1
    if !errorlevel! equ 0 (
        netsh interface ip add dns "%netif%" 1.0.0.1 index=2 >nul 2>&1
        set "lastdns=Cloudflare ^(1.1.1.1 / 1.0.0.1^)"
        >"%statefile%" echo !lastdns!
        echo SUCCESS: Cloudflare DNS configured
    ) else (
        echo ERROR: Failed to configure Cloudflare DNS
    )
)
if "%dns_choice%"=="3" (
    netsh interface ip set dns "%netif%" static 208.67.222.222 primary >nul 2>&1
    if !errorlevel! equ 0 (
        netsh interface ip add dns "%netif%" 208.67.220.220 index=2 >nul 2>&1
        set "lastdns=OpenDNS ^(208.67.222.222 / 208.67.220.220^)"
        >"%statefile%" echo !lastdns!
        echo SUCCESS: OpenDNS configured
    ) else (
        echo ERROR: Failed to configure OpenDNS
    )
)
if "%dns_choice%"=="4" (
    netsh interface ip set dns "%netif%" dhcp >nul 2>&1
    if !errorlevel! equ 0 (
        set "lastdns=Automatic ^(DHCP^)"
        >"%statefile%" echo !lastdns!
        echo SUCCESS: Automatic DNS configured
    ) else (
        echo ERROR: Failed to configure automatic DNS
    )
)

echo.
echo Flushing DNS cache to apply changes...
ipconfig /flushdns >nul 2>&1

echo.
echo Current DNS settings for %netif%:
netsh interface ip show dns "%netif%" 2>nul
echo.

pause
goto ADVANCED_SETTINGS

:SHOW_LOG
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                         Operation Log                            ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
if exist "%logfile%" (
    type "%logfile%"
) else (
    echo No operations logged yet.
)
echo.
pause
goto ADVANCED_SETTINGS

:: ===== Helper Functions =====

:CHECK_SUCCESS
setlocal
set "task_name=%~1"
set "error_code=%errorlevel%"

if "%error_code%" equ "0" (
    echo SUCCESS: %task_name%
) else (
    echo FAILED: %task_name% ^(ErrorLevel=%error_code%^)
)

:: Write result to log file
echo [%date% %time%] %task_name% - ErrorLevel: %error_code% >> "%logfile%"

endlocal
goto :eof

:RESTART_ADAPTERS
setlocal
set "adapter_count=0"
set "success_count=0"

echo [+] Discovering connected network adapters...

for /f "skip=3 tokens=3*" %%A in ('netsh interface show interface ^| findstr /i "Connected"') do (
    set /a adapter_count+=1
    echo [!adapter_count!] Restarting: %%B
    netsh interface set interface "%%B" admin=disable >nul 2>&1
    if !errorlevel! equ 0 (
        timeout /t 3 /nobreak >nul
        netsh interface set interface "%%B" admin=enable >nul 2>&1
        if !errorlevel! equ 0 (
            set /a success_count+=1
            echo SUCCESS: Adapter "%%B" restarted
        ) else (
            echo WARNING: Could not enable adapter "%%B"
        )
    ) else (
        echo WARNING: Could not disable adapter "%%B"
    )
    timeout /t 2 /nobreak >nul
)

if !adapter_count! equ 0 (
    echo INFO: No connected adapters found
) else (
    echo SUMMARY: !success_count! out of !adapter_count! adapters restarted successfully
)

endlocal
goto :eof

:EXIT
cls
echo.
echo ╔══════════════════════════════════════════════════════════════════╗
echo ║                   Thank you for using the tool!                   ║
echo ║                        Created by PANDA                          ║
echo ╚══════════════════════════════════════════════════════════════════╝
echo.
echo Exiting...
timeout /t 2 /nobreak >nul
endlocal
exit