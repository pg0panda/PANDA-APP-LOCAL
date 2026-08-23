@echo off
:: ������ �� ������� ������
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [X] Please run this tool as Administrator!
    echo.
    echo MSGBOX "You must run this tool as Administrator!" ,48,"FIX 98" > %temp%\TEMPmessage.vbs
    start /wait %temp%\TEMPmessage.vbs
    del %temp%\TEMPmessage.vbs
    pause
    exit /b
)

:PROCEED
:: --- Script Initialization ---
:: Sets the console color and title.
color a
title WELCOME %username%
color 0B

:: Displays a welcome message using VBScript.
echo MSGBOX " WELCOME... this tool will fix gameloop 98 !" ,48,"CREATED BY Panda" > %temp%\TEMPmessage.vbs
start /wait %temp%\TEMPmessage.vbs
del %temp%\TEMPmessage.vbs

:: --- Process Termination (Taskkill) ---
:: Terminates various emulator-related processes forcefully.
:: /F: Specifies to forcefully terminate the process(es).
:: /IM: Specifies the image name of the process to be terminated.
:: /T: Terminates the specified process and any child processes which were started by it.

taskkill /F /IM AndroidEmulator.exe
taskkill /F /IM AndroidEmulatorEx.exe
taskkill /F /IM GameLoader.exe
taskkill /F /IM appmarket.exe
taskkill /F /IM androidemulator.exe
taskkill /F /IM androidemulatoren.exe
taskkill /F /IM AndroidProcess.exe
taskkill /F /IM aow_exe.exe
taskkill /F /IM QMEmulatorService.exe
taskkill /F /IM RuntimeBroker.exe
taskkill /F /IM adb.exe
taskkill /F /IM adb2.exe
taskkill /F /IM ProjectTitan.exe
taskkill /F /IM TitanService.exe
taskkill /F /IM MEmuHeadless.exe
taskkill /F /IM MEmuSVC.exe
taskkill /F /IM MEmu.exe
taskkill /F /IM MEmuConsole.exe
taskkill /F /IM ldnews.exe
taskkill /F /IM MemuService.exe
taskkill /F /IM "Synaptics.exe"
taskkill /F /IM dnf.exe
taskkill /F /IM Auxillary.exe
taskkill /F /IM TP3Helper.exe
taskkill /F /IM TBSWebRenderer.exe

:: --- Service Management ---
:: Stops and deletes specific services related to emulators.
sc stop CEDRIVER60 2>nul
sc delete CEDRIVER60 2>nul
net stop aow_drv 2>nul
net stop QMEmulatorService 2>nul
net stop MEmuSVC 2>nul

:: --- Cleanup ---
:: Deletes a specific log file.
del C:\aow_drv.log 2>nul

:: ��� ��� ���� ���� ����� ������...
title FIX 98 - Created by PANDA

:: ����� ����� ����� �� ����� �� ����� ������
echo looking: AOW_Rootfs_100\0 ...

set "foundAny=false"

for %%D in (C D E F G H) do (
    set "target=%%D:\TxGameAssistant\AOW_Rootfs_100\0"
    if exist "!target!" (
        echo [?] found: !target!
        set "foundAny=true"
        for %%F in (0 367 30 30.ini) do (
            if exist "!target!\%%F" (
                del /f /q "!target!\%%F"
                echo Deleted: !target!\%%F
            )
        )
    )
)

if "!foundAny!"=="false" (
    echo [X] Folder not found.
) else (
    echo [?] Done.
)

REM ����� �� ���� ui ���� aow_drv.log ���
for %%D in (C D E F G H) do (
    set "uiFolder=%%D:\TxGameAssistant\ui"
    if exist "!uiFolder!\aow_drv.log" (
        del /f /q "!uiFolder!\aow_drv.log"
        echo Deleted: !uiFolder!\aow_drv.log
    )
)

:: ����� ������ �� ����� ������
echo MSGBOX "Done" ,48,"CREATED BY Panda" > %temp%\TEMPmessage.vbs
start /wait %temp%\TEMPmessage.vbs
del %temp%\TEMPmessage.vbs
pause