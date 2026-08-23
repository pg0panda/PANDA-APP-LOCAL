@echo off
setlocal enabledelayedexpansion

:: ==============================================
:: COMPLETE EMULATOR KILLER TOOL
:: Created by: Panda
:: Purpose: Stop ALL Android Emulators
:: ==============================================

:: Check for administrator privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    color 4f
    echo.
    echo ╔═══════════════════════════════════════════════════╗
    echo ║               ADMIN REQUIRED                      ║
    echo ╚═══════════════════════════════════════════════════╝
    echo.
    echo [X] Please run this tool as Administrator!
    echo.
    echo MSGBOX "You must run this tool as Administrator!" ,48,"Emulator Killer" > %temp%\TEMPmessage.vbs
    start /wait %temp%\TEMPmessage.vbs
    del %temp%\TEMPmessage.vbs
    pause
    exit /b
)

:PROCEED
:: Initialize console
color 0B
mode con: cols=85 lines=35
title Complete Emulator Killer - Created by Panda

cls
echo.
echo ╔═══════════════════════════════════════════════════════════════════════════════╗
echo ║                        COMPLETE EMULATOR KILLER                               ║
echo ║                            Created by: Panda                                  ║
echo ╚═══════════════════════════════════════════════════════════════════════════════╝
echo.
echo ┌─ Purpose: Terminate ALL Android Emulators and related processes
echo ├─ Targets: GameLoop, MEmu, BlueStacks, LDPlayer, Nox, and more
echo └─ Status: Ready to terminate all emulator processes
echo.

:: Display welcome message
echo MSGBOX "Complete Emulator Killer Tool!`n`nThis will forcefully stop ALL Android emulators and related processes.`n`nClick OK to proceed...", 48, "Emulator Killer" > %temp%\TEMPmessage.vbs
start /wait %temp%\TEMPmessage.vbs
del %temp%\TEMPmessage.vbs

echo.
echo [INFO] Starting complete emulator termination...
echo.

set "total_killed=0"

:: ==============================================
:: GAMELOOP / TENCENT GAMING BUDDY
:: ==============================================
echo ┌─ [1/8] GameLoop / Tencent Gaming Buddy
set "gameloop_processes=AndroidEmulator.exe AndroidEmulatorEx.exe GameLoader.exe appmarket.exe androidemulator.exe androidemulatoren.exe AndroidProcess.exe aow_exe.exe QMEmulatorService.exe adb.exe adb2.exe TBSWebRenderer.exe GameAssistant.exe TxGameAssistant.exe"

for %%p in (%gameloop_processes%) do (
    tasklist /FI "IMAGENAME eq %%p" 2>nul | find /I "%%p" >nul
    if !errorlevel! equ 0 (
        echo │  [KILL] %%p
        taskkill /F /T /IM "%%p" >nul 2>&1
        set /a total_killed+=1
    )
)

:: ==============================================
:: MEMU EMULATOR
:: ==============================================
echo ├─ [2/8] MEmu Emulator
set "memu_processes=MEmu.exe MEmuConsole.exe MEmuHeadless.exe MEmuSVC.exe MemuService.exe MEmuManage.exe MEmuTray.exe MEmuUpdater.exe Memuc.exe"

for %%p in (%memu_processes%) do (
    tasklist /FI "IMAGENAME eq %%p" 2>nul | find /I "%%p" >nul
    if !errorlevel! equ 0 (
        echo │  [KILL] %%p
        taskkill /F /T /IM "%%p" >nul 2>&1
        set /a total_killed+=1
    )
)

:: ==============================================
:: BLUESTACKS
:: ==============================================
echo ├─ [3/8] BlueStacks Emulator
set "bluestacks_processes=BlueStacks.exe Bluestacks.exe HD-Agent.exe HD-LogRotatorService.exe HD-UpdaterService.exe HD-Player.exe BstkSVC.exe BlueStacksServices.exe HD-Frontend.exe HD-BlockDevice.exe"

for %%p in (%bluestacks_processes%) do (
    tasklist /FI "IMAGENAME eq %%p" 2>nul | find /I "%%p" >nul
    if !errorlevel! equ 0 (
        echo │  [KILL] %%p
        taskkill /F /T /IM "%%p" >nul 2>&1
        set /a total_killed+=1
    )
)

:: ==============================================
:: LDPLAYER
:: ==============================================
echo ├─ [4/8] LDPlayer Emulator
set "ldplayer_processes=LdVBoxHeadless.exe Ld9BoxHeadless.exe LdPlayer.exe dnplayer.exe ldconsole.exe ldnews.exe ldlog.exe LdVirtualBoxLauncher.exe VirtualBox.exe VBoxHeadless.exe"

for %%p in (%ldplayer_processes%) do (
    tasklist /FI "IMAGENAME eq %%p" 2>nul | find /I "%%p" >nul
    if !errorlevel! equ 0 (
        echo │  [KILL] %%p
        taskkill /F /T /IM "%%p" >nul 2>&1
        set /a total_killed+=1
    )
)

:: ==============================================
:: NOX PLAYER
:: ==============================================
echo ├─ [5/8] Nox Player
set "nox_processes=Nox.exe NoxVMHandle.exe MultiPlayerManager.exe NoxConsole.exe RuntimeBroker.exe BigNoxVMHandle.exe"

for %%p in (%nox_processes%) do (
    tasklist /FI "IMAGENAME eq %%p" 2>nul | find /I "%%p" >nul
    if !errorlevel! equ 0 (
        echo │  [KILL] %%p
        taskkill /F /T /IM "%%p" >nul 2>&1
        set /a total_killed+=1
    )
)

:: ==============================================
:: GENYMOTION
:: ==============================================
echo ├─ [6/8] Genymotion Emulator
set "genymotion_processes=genymotion.exe player.exe gmtool.exe VirtualBox.exe VBoxSVC.exe VBoxNetDHCP.exe VBoxNetNAT.exe"

for %%p in (%genymotion_processes%) do (
    tasklist /FI "IMAGENAME eq %%p" 2>nul | find /I "%%p" >nul
    if !errorlevel! equ 0 (
        echo │  [KILL] %%p
        taskkill /F /T /IM "%%p" >nul 2>&1
        set /a total_killed+=1
    )
)

:: ==============================================
:: ANDROID STUDIO EMULATOR
:: ==============================================
echo ├─ [7/8] Android Studio Emulator
set "studio_processes=emulator.exe emulator64.exe qemu-system-x86_64.exe qemu-system-i386.exe emulator-x86.exe emulator-arm.exe"

for %%p in (%studio_processes%) do (
    tasklist /FI "IMAGENAME eq %%p" 2>nul | find /I "%%p" >nul
    if !errorlevel! equ 0 (
        echo │  [KILL] %%p
        taskkill /F /T /IM "%%p" >nul 2>&1
        set /a total_killed+=1
    )
)

:: ==============================================
:: ADDITIONAL PROCESSES
:: ==============================================
echo └─ [8/8] Additional Emulator Processes
set "additional_processes=ProjectTitan.exe TitanService.exe Auxillary.exe TP3Helper.exe tp3helper.dat Synaptics.exe dnf.exe syzs_dl_svr.exe TUpdate.exe ninja.vmp.exe"

for %%p in (%additional_processes%) do (
    tasklist /FI "IMAGENAME eq %%p" 2>nul | find /I "%%p" >nul
    if !errorlevel! equ 0 (
        echo    [KILL] %%p
        taskkill /F /T /IM "%%p" >nul 2>&1
        set /a total_killed+=1
    )
)

:: ==============================================
:: SERVICE MANAGEMENT
:: ==============================================
echo.
echo ┌─ Stopping Emulator Services...

set "services=CEDRIVER60 aow_drv QMEmulatorService MEmuSVC BstHdAndroidSvc BstHdLogRotatorSvc BstHdUpdaterSvc LdBoxService VBoxService"
set "stopped_services=0"

for %%s in (%services%) do (
    sc query "%%s" >nul 2>&1
    if !errorlevel! equ 0 (
        echo │  [STOP] %%s
        sc stop "%%s" >nul 2>&1
        set /a stopped_services+=1
        timeout /t 1 >nul
    )
)

:: Delete problematic services
sc query "CEDRIVER60" >nul 2>&1
if !errorlevel! equ 0 (
    echo │  [DELETE] CEDRIVER60
    sc delete "CEDRIVER60" >nul 2>&1
)

echo └─ Services processed: !stopped_services!

:: ==============================================
:: FILE CLEANUP
:: ==============================================
echo.
echo ┌─ Cleaning Emulator Files...

set "deleted_files=0"

:: Clean common log files
for %%D in (C D E F G H) do (
    for %%f in (aow_drv.log emulator.log memu.log nox.log bluestacks.log) do (
        if exist "%%D:\%%f" (
            echo │  [DELETE] %%D:\%%f
            del /f /q "%%D:\%%f" >nul 2>&1
            set /a deleted_files+=1
        )
    )
)

:: Clean temp emulator files
if exist "%TEMP%\AndroidEmulator" (
    echo │  [DELETE] %TEMP%\AndroidEmulator
    rd /s /q "%TEMP%\AndroidEmulator" >nul 2>&1
    set /a deleted_files+=1
)

if exist "%TEMP%\MEmu" (
    echo │  [DELETE] %TEMP%\MEmu
    rd /s /q "%TEMP%\MEmu" >nul 2>&1
    set /a deleted_files+=1
)

echo └─ Files cleaned: !deleted_files!

:: ==============================================
:: FINAL CLEANUP
:: ==============================================
echo.
echo ┌─ Final System Cleanup...

:: Kill any remaining adb processes
for /f "tokens=2" %%i in ('tasklist /FI "IMAGENAME eq adb*" ^| find "adb"') do (
    taskkill /F /PID %%i >nul 2>&1
)

:: Clear clipboard
echo.|clip >nul 2>&1

echo └─ System cleanup completed

:: ==============================================
:: COMPLETION REPORT
:: ==============================================
cls
echo.
echo ╔═══════════════════════════════════════════════════════════════════════════════╗
echo ║                           TERMINATION COMPLETED                               ║
echo ╚═══════════════════════════════════════════════════════════════════════════════╝
echo.
echo ┌─ SUMMARY REPORT:
echo ├─ Total processes killed: !total_killed!
echo ├─ Services stopped: !stopped_services!
echo ├─ Files cleaned: !deleted_files!
echo └─ Status: ALL EMULATORS TERMINATED ✓
echo.
echo ┌─ EMULATORS AFFECTED:
echo ├─ ✓ GameLoop / Tencent Gaming Buddy
echo ├─ ✓ MEmu Emulator
echo ├─ ✓ BlueStacks
echo ├─ ✓ LDPlayer
echo ├─ ✓ Nox Player
echo ├─ ✓ Genymotion
echo ├─ ✓ Android Studio Emulator
echo └─ ✓ All related processes and services
echo.
echo ┌─ SYSTEM STATUS:
echo ├─ Memory freed from emulator processes
echo ├─ Background services stopped
echo ├─ Temporary files cleaned
echo └─ System ready for fresh emulator start
echo.

:: Success message
echo MSGBOX "Complete Emulator Termination Successful!`n`nSUMMARY:`n- Processes killed: !total_killed!`n- Services stopped: !stopped_services!`n- Files cleaned: !deleted_files!`n`nALL ANDROID EMULATORS HAVE BEEN TERMINATED!", 64, "Mission Accomplished - Emulator Killer" > %temp%\TEMPmessage.vbs
start /wait %temp%\TEMPmessage.vbs
del %temp%\TEMPmessage.vbs

echo.
echo Press any key to exit...
pause >nul

:: Final cleanup
del "%temp%\*.vbs" 2>nul

endlocal
exit 