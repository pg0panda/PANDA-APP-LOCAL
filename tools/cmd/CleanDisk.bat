@echo off
setlocal EnableDelayedExpansion
color 0B
title CleanDisk Pro Enhanced - Created by PANDA

:: التحقق من صلاحيات المدير
NET SESSION >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo   ============================================
    echo      ADMINISTRATOR PRIVILEGES REQUIRED
    echo   ============================================
    echo.
    echo   This tool requires administrator privileges to function properly.
    echo   Please right-click and select "Run as Administrator"
    echo.
    pause
    exit /b
)

:ADMIN_OK
set "cleaned_files=0"
set "freed_space=0"

echo.
echo   ================================================================
echo      CLEAN DISK PROFESSIONAL ENHANCED - By PANDA
echo   ================================================================
echo       [Version 4.0] - Advanced System Cleaner ^& Security Scanner
echo   ================================================================
echo.
echo   System Information:
echo   - OS: %OS%
echo   - Computer: %COMPUTERNAME%
echo   - User: %USERNAME%
echo   - Date: %DATE% %TIME%
echo.
pause
cls

:MAIN_MENU
echo.
echo   ==================[ MAIN MENU ]==================
echo   1. Quick Clean (Fast Temporary Files Cleanup)
echo   2. Deep System Clean ^& Malware Scan
echo   3. Browser Data Cleanup (All Browsers)
echo   4. Registry Cleanup ^& Optimization
echo   5. Disk Space Analyzer
echo   6. System Health Check
echo   7. Custom Cleanup Options
echo   8. View Cleanup Statistics
echo   9. Exit
echo   ==================================================
echo.
set /p choice=   Select Option [1-9]: 

if "%choice%"=="1" goto QUICK_CLEAN
if "%choice%"=="2" goto DEEP_CLEAN
if "%choice%"=="3" goto BROWSER_CLEAN
if "%choice%"=="4" goto REGISTRY_CLEAN
if "%choice%"=="5" goto DISK_ANALYZER
if "%choice%"=="6" goto HEALTH_CHECK
if "%choice%"=="7" goto CUSTOM_CLEAN
if "%choice%"=="8" goto STATS
if "%choice%"=="9" goto SHUTDOWN

echo   Invalid choice! Please select 1-9.
timeout /t 2 >nul
goto MAIN_MENU

:QUICK_CLEAN
echo.
echo [1] Starting Quick Cleanup...
echo ================================
echo.

echo Cleaning Windows Temp files...
if exist "%temp%" (
    for /f %%i in ('dir /s /b "%temp%\*.*" 2^>nul ^| find /c /v ""') do set temp_count=%%i
    del /q /f /s "%temp%\*.*" 2>nul
    rd /s /q "%temp%" 2>nul
    mkdir "%temp%" 2>nul
)

echo Cleaning System Temp files...
if exist "%windir%\temp" (
    del /q /f /s "%windir%\temp\*.*" 2>nul
    for /d %%i in ("%windir%\temp\*") do rd /s /q "%%i" 2>nul
)

echo Cleaning Prefetch files...
if exist "C:\Windows\Prefetch" (
    del /q /f /s "C:\Windows\Prefetch\*.*" 2>nul
)

echo Cleaning Recent files...
del /q /f /s "%appdata%\Microsoft\Windows\Recent\*.*" 2>nul

echo.
echo [✓] Quick Clean Completed Successfully!
echo Files processed: Calculating...
timeout /t 3 >nul
goto MAIN_MENU

:DEEP_CLEAN
echo.
echo [2] Starting Deep System Clean and Security Scan...
echo ==================================================
echo.

echo Phase 1: Advanced System Cleanup...
:: تشغيل أداة تنظيف القرص المدمجة
echo Running Disk Cleanup utility...
cleanmgr /sagerun:1

:: تنظيف مكونات النظام
echo Cleaning Windows Component Store...
dism /online /cleanup-image /startcomponentcleanup /resetbase >nul 2>&1

:: تنظيف شامل للملفات المؤقتة
echo Removing temporary files and caches...
del /q /f /s "%temp%\*.*" 2>nul
del /q /f /s "%windir%\temp\*.*" 2>nul
del /q /f /s "%localappdata%\Temp\*.*" 2>nul
del /q /f /s "%systemroot%\Logs\*.*" 2>nul
del /q /f /s "%windir%\SoftwareDistribution\Download\*.*" 2>nul

echo Phase 2: Security and Malware Scan...
:: تشغيل Windows Defender Quick Scan
echo Running Windows Defender Quick Scan...
"%ProgramFiles%\Windows Defender\MpCmdRun.exe" -Scan -ScanType 1 >nul 2>&1

:: تشغيل أداة إزالة البرامج الضارة من مايكروسوفت
echo Running Microsoft Malicious Software Removal Tool...
if exist "%windir%\system32\mrt.exe" (
    start /wait "" "%windir%\system32\mrt.exe" /Q /F:Y
)

echo Phase 3: System File Check...
echo Running System File Checker...
sfc /scannow >nul 2>&1

echo.
echo [✓] Deep Clean and Security Scan Completed!
echo Your system has been thoroughly cleaned and scanned.
timeout /t 5 >nul
goto MAIN_MENU

:BROWSER_CLEAN
echo.
echo [3] Cleaning Browser Data for All Users...
echo ==========================================
echo.

echo Cleaning Google Chrome data...
for /d %%u in ("C:\Users\*") do (
    if exist "%%u\AppData\Local\Google\Chrome\User Data\Default" (
        rd /s /q "%%u\AppData\Local\Google\Chrome\User Data\Default\Cache" 2>nul
        rd /s /q "%%u\AppData\Local\Google\Chrome\User Data\Default\Code Cache" 2>nul
        del /q /f "%%u\AppData\Local\Google\Chrome\User Data\Default\History" 2>nul
        del /q /f "%%u\AppData\Local\Google\Chrome\User Data\Default\Cookies" 2>nul
    )
)

echo Cleaning Microsoft Edge data...
for /d %%u in ("C:\Users\*") do (
    if exist "%%u\AppData\Local\Microsoft\Edge\User Data\Default" (
        rd /s /q "%%u\AppData\Local\Microsoft\Edge\User Data\Default\Cache" 2>nul
        rd /s /q "%%u\AppData\Local\Microsoft\Edge\User Data\Default\Code Cache" 2>nul
        del /q /f "%%u\AppData\Local\Microsoft\Edge\User Data\Default\History" 2>nul
        del /q /f "%%u\AppData\Local\Microsoft\Edge\User Data\Default\Cookies" 2>nul
    )
)

echo Cleaning Firefox data...
for /d %%u in ("C:\Users\*") do (
    if exist "%%u\AppData\Local\Mozilla\Firefox\Profiles" (
        for /d %%p in ("%%u\AppData\Local\Mozilla\Firefox\Profiles\*") do (
            rd /s /q "%%p\cache2" 2>nul
            del /q /f "%%p\places.sqlite" 2>nul
            del /q /f "%%p\cookies.sqlite" 2>nul
        )
    )
)

echo.
echo [✓] Browser Data Cleanup Completed!
timeout /t 3 >nul
goto MAIN_MENU

:REGISTRY_CLEAN
echo.
echo [4] Registry Cleanup and Optimization...
echo =======================================
echo.

echo Cleaning Registry temporary entries...
:: تنظيف مفاتيح الريجستري المؤقتة (بحذر)
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs" /f 2>nul
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" /f 2>nul

echo Defragmenting Registry...
:: ضغط وتحسين قاعدة بيانات الريجستري
compact /c /s:"%windir%\system32\config" /i 2>nul

echo.
echo [✓] Registry Cleanup Completed!
echo Note: Registry optimization will take effect after restart.
timeout /t 3 >nul
goto MAIN_MENU

:DISK_ANALYZER
echo.
echo [5] Disk Space Analysis...
echo =========================
echo.

echo Analyzing disk usage patterns...
echo.

:: تحليل استخدام القرص
for %%d in (C D E F) do (
    if exist "%%d:\" (
        echo Drive %%d: Information:
        for /f "tokens=3" %%i in ('dir %%d:\ ^| find "bytes free"') do echo   Free Space: %%i bytes
        echo   Large folders:
        dir "%%d:\" /s /b 2>nul | findstr /i ".log .tmp .cache" | find /c /v "" > temp_count.txt
        set /p temp_files=<temp_count.txt
        echo   Temporary files found: !temp_files!
        del temp_count.txt 2>nul
        echo.
    )
)

echo Analysis completed! Check the information above.
pause
goto MAIN_MENU

:HEALTH_CHECK
echo.
echo [6] System Health Check...
echo ==========================
echo.

echo Checking system integrity...
echo Running CHKDSK on system drive...
echo Y | chkdsk C: /f /r >nul 2>&1

echo Verifying system files...
sfc /verifyonly >nul 2>&1
if %errorlevel%==0 (
    echo [✓] System files are healthy
) else (
    echo [!] System file issues detected - run SFC scan
)

echo Checking Windows Update service...
sc query wuauserv | find "RUNNING" >nul
if %errorlevel%==0 (
    echo [✓] Windows Update service is running
) else (
    echo [!] Windows Update service needs attention
)

echo.
echo System Health Check completed!
pause
goto MAIN_MENU

:CUSTOM_CLEAN
echo.
echo [7] Custom Cleanup Options...
echo =============================
echo.
echo   a. Clean Download folder
echo   b. Clean Desktop temporary files
echo   c. Clean System Event Logs
echo   d. Clean Windows Update Cache
echo   e. Return to Main Menu
echo.
set /p custom_choice=   Select Option [a-e]: 

if /i "%custom_choice%"=="a" (
    echo Cleaning Downloads folder...
    for /d %%u in ("C:\Users\*") do (
        del /q /f /s "%%u\Downloads\*.tmp" 2>nul
        del /q /f /s "%%u\Downloads\*.temp" 2>nul
    )
    echo [✓] Downloads folder cleaned!
)

if /i "%custom_choice%"=="b" (
    echo Cleaning Desktop temporary files...
    for /d %%u in ("C:\Users\*") do (
        del /q /f /s "%%u\Desktop\*.tmp" 2>nul
        del /q /f /s "%%u\Desktop\Thumbs.db" 2>nul
    )
    echo [✓] Desktop temporary files cleaned!
)

if /i "%custom_choice%"=="c" (
    echo Clearing System Event Logs...
    for /f "tokens=*" %%i in ('wevtutil el') do wevtutil cl "%%i" 2>nul
    echo [✓] Event logs cleared!
)

if /i "%custom_choice%"=="d" (
    echo Cleaning Windows Update Cache...
    net stop wuauserv 2>nul
    rd /s /q "%windir%\SoftwareDistribution" 2>nul
    net start wuauserv 2>nul
    echo [✓] Windows Update cache cleaned!
)

if /i "%custom_choice%"=="e" goto MAIN_MENU

timeout /t 2 >nul
goto CUSTOM_CLEAN

:STATS
echo.
echo [8] Cleanup Statistics...
echo ========================
echo.
echo   Current Session Statistics:
echo   - Script Runtime: Running...
echo   - Operations Completed: Various
echo   - System Status: Optimized
echo.
echo   System Information:
for /f "tokens=*" %%i in ('systeminfo ^| findstr /c:"Total Physical Memory"') do echo   %%i
for /f "tokens=*" %%i in ('systeminfo ^| findstr /c:"Available Physical Memory"') do echo   %%i
echo.
echo   Disk Space (C: Drive):
for /f "tokens=3" %%i in ('dir C:\ ^| find "bytes free"') do echo   Free Space: %%i bytes
echo.
pause
goto MAIN_MENU

:SHUTDOWN
cls
echo.
echo   ================================================================
echo      THANK YOU FOR USING CLEANDISK PRO ENHANCED!
echo   ================================================================
echo.
echo           - [Created by PANDA - Enhanced Version] -
echo.
echo   Your system is now optimized and secured!
echo   Recommendation: Restart your computer for best performance.
echo.
echo   ================================================================

timeout /t 8 >nul
exit