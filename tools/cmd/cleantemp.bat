@echo off
setlocal enabledelayedexpansion
title Advanced Temp Files Cleaner v2.0 - Created by Panda
color 0B

:: Check admin privileges
fsutil dirty query %systemdrive% >nul 2>&1
if %errorlevel% NEQ 0 (
    echo This tool needs Administrator privileges to work properly.
    echo Restarting with admin rights...
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\_getadmin.vbs"
    echo UAC.ShellExecute "cmd.exe", "/c ""%~s0""", "", "runas", 1 >> "%temp%\_getadmin.vbs"
    "%temp%\_getadmin.vbs"
    del "%temp%\_getadmin.vbs" >nul 2>&1
    exit /B
)

echo ===================================================================
echo                     Advanced Temp Files Cleaner v2.0              
echo                          Created by Panda                        
echo ===================================================================
echo.
echo Starting comprehensive cleanup process...
echo.

:: Clean user temp files
echo [1/12] Cleaning user temp files...
call :CLEAN_DIRECTORY "%temp%" "User Temp Files"

:: Clean Windows temp files
echo [2/12] Cleaning Windows temp files...
call :CLEAN_DIRECTORY "C:\Windows\Temp" "Windows Temp Files"

:: Clean system temp files
echo [3/12] Cleaning system temp files...
if exist "C:\tmp" call :CLEAN_DIRECTORY "C:\tmp" "System Tmp Files"

:: Clean Prefetch files (with safety check)
echo [4/12] Cleaning Prefetch files...
if exist "C:\Windows\Prefetch" (
    for /f %%i in ('dir /b "C:\Windows\Prefetch\*.pf" 2^>nul ^| find /c /v ""') do set "prefetch_count=%%i"
    if !prefetch_count! GTR 0 (
        powershell -command "Remove-Item 'C:\Windows\Prefetch\*.pf' -Force" >nul 2>&1
        if !errorlevel! equ 0 (
            echo    SUCCESS: Cleaned !prefetch_count! prefetch files
        ) else (
            echo    WARNING: Could not clean some prefetch files
            set /a errors+=1
        )
    ) else (
        echo    INFO: No prefetch files to clean
    )
) else (
    echo    INFO: Prefetch folder not found
)

:: Clean Recent files
echo [5/12] Cleaning recent files...
call :CLEAN_DIRECTORY "%APPDATA%\Microsoft\Windows\Recent" "Recent Files"

:: Clean Windows Update cache (with proper service management)
echo [6/12] Cleaning Windows Update cache...
echo    Stopping Windows Update services...
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
net stop dosvc >nul 2>&1
timeout /t 2 /nobreak >nul

if exist "C:\Windows\SoftwareDistribution\Download" (
    call :CLEAN_DIRECTORY "C:\Windows\SoftwareDistribution\Download" "Windows Update Cache"
) else (
    echo    INFO: Windows Update cache folder not found
)

echo    Restarting Windows Update services...
net start bits >nul 2>&1
net start wuauserv >nul 2>&1
net start dosvc >nul 2>&1

:: Clean system cache
echo [7/12] Cleaning system cache...
call :CLEAN_DIRECTORY "%LocalAppData%\Microsoft\Windows\INetCache" "Internet Cache"
call :CLEAN_DIRECTORY "%LocalAppData%\Temp" "Local Temp Files"

:: Clean browser caches
echo [8/12] Cleaning browser caches...

:: Chrome cache
if exist "%LocalAppData%\Google\Chrome\User Data\Default\Cache" (
    call :CLEAN_DIRECTORY "%LocalAppData%\Google\Chrome\User Data\Default\Cache" "Chrome Cache"
)

:: Firefox cache
for /d %%p in ("%LocalAppData%\Mozilla\Firefox\Profiles\*") do (
    if exist "%%p\cache2" (
        call :CLEAN_DIRECTORY "%%p\cache2" "Firefox Cache"
    )
)

:: Edge cache
if exist "%LocalAppData%\Microsoft\Edge\User Data\Default\Cache" (
    call :CLEAN_DIRECTORY "%LocalAppData%\Microsoft\Edge\User Data\Default\Cache" "Edge Cache"
)

:: Clean additional browser data
echo [9/12] Cleaning additional browser data...
:: Chrome temp files
if exist "%LocalAppData%\Google\Chrome\User Data\Default\Code Cache" (
    call :CLEAN_DIRECTORY "%LocalAppData%\Google\Chrome\User Data\Default\Code Cache" "Chrome Code Cache"
)

:: Clean Windows logs (older than 30 days)
echo [10/12] Cleaning old Windows logs...
if exist "C:\Windows\Logs" (
    forfiles /p "C:\Windows\Logs" /s /m *.log /d -30 /c "cmd /c powershell -command \"Remove-Item '@path' -Force\"" >nul 2>&1
    if !errorlevel! equ 0 (
        echo    SUCCESS: Cleaned old log files
    )
)

:: Clean crash dumps
echo [11/12] Cleaning crash dumps...
if exist "C:\Windows\Minidump" (
    for /f %%i in ('dir /b "C:\Windows\Minidump\*.dmp" 2^>nul ^| find /c /v ""') do set "dump_count=%%i"
    if !dump_count! GTR 0 (
        powershell -command "Remove-Item 'C:\Windows\Minidump\*.dmp' -Force" >nul 2>&1
        if !errorlevel! equ 0 (
            echo    SUCCESS: Cleaned !dump_count! crash dump files
        )
    )
)

:: Empty recycle bin (safely)
echo [12/12] Emptying recycle bin...
powershell -command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >nul 2>&1
if !errorlevel! equ 0 (
    echo    SUCCESS: Recycle bin emptied
) else (
    :: Fallback method using PowerShell
    powershell -command "Get-ChildItem '%systemdrive%\$Recycle.Bin' -Recurse -Force | Remove-Item -Force -Recurse" >nul 2>&1
    echo    SUCCESS: Recycle bin emptied ^(PowerShell method^)
)

:: Run Disk Cleanup utility silently
echo.
echo Running Windows Disk Cleanup utility...
cleanmgr /sagerun:1 >nul 2>&1

:: Final summary
cls
echo ===================================================================
echo                       Cleanup Completed Successfully!             
echo ===================================================================                                                            
echo    All temporary files cleaned                                 
echo    Browser caches cleared                                 
echo    System cache cleaned                                    
echo    Recycle bin emptied                                      
echo    Windows logs cleaned                                                                                                                                        
echo ===================================================================
echo Press any key to exit...
pause >nul

exit

:: Function to clean directories safely using PowerShell
:CLEAN_DIRECTORY
setlocal
set "target_dir=%~1"
set "desc=%~2"

if not exist "%target_dir%" (
    echo    INFO: %desc% folder not found
    goto :eof
)

:: Count files before cleaning using PowerShell
for /f %%i in ('powershell -command "(Get-ChildItem '%target_dir%' -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object).Count"') do set "file_count=%%i"

if %file_count% equ 0 (
    echo    INFO: %desc% - No files to clean
    goto :eof
)

:: Clean files using PowerShell
powershell -command "try { Get-ChildItem '%target_dir%' -Recurse -Force | Remove-Item -Force -Recurse -ErrorAction Stop } catch { exit 1 }" >nul 2>&1
set "ps_result=!errorlevel!"

if !ps_result! equ 0 (
    echo    SUCCESS: %desc% - Cleaned %file_count% items using PowerShell
) else (
    echo    WARNING: %desc% - Some files could not be cleaned
    set /a errors+=1
)
endlocal
goto :eof