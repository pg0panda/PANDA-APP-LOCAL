@shift
@echo off 
color 0B
title WELCOME %username%

cls
:loop
echo MSGBOX "Welcome to the ultimate cleaning tool created by Panda!" ,48,"CREATED BY Panda" > %temp%\TEMPmessage.vbs
call %temp%\TEMPmessage.vbs
echo Start cleaning...
cls


title Clean Tool- created by PANDA
@echo off
netsh interface ip show config
ipconfig /all
ipconfig /registerdns
ipconfig /displaydns
ipconfig /release
ipconfig /renew
ipconfig /flushdns
netsh int ip reset
netsh winsock reset
netsh interface ipv4 reset
netsh interface ipv6 reset
netsh advfirewall reset
nbtstat -r
taskkill /F /IM Auxillary.exe
taskkill /F /IM TP3Helper.exe
taskkill /F /IM tp3helper.dat
TaskKill /F /IM androidemulator.exe
TaskKill /F /IM aow_exe.exe
TaskKill /F /IM QMEmulatorService.exe
TaskKill /F /IM RuntimeBroker.exe
taskkill /f /im adb.exe
taskkill /f /im GameLoader.exe
taskkill /f /im TBSWebRenderer.exe
taskkill /f /im AppMarket.exe
taskkill /f /im AndroidEmulator.exe
taskkill /f /im ninja.vmp.exe
net stop QMEmulatorService
net stop aow_drv
net stop aow_exe
net stop aow_drv_x64_ev
net stop AndroidEmulator
net stop aow_drv_x64
net stop Tensafe
taskkill /F /IM Auxillary.exe
taskkill /F /IM TP3Helper.exe
taskkill /F /IM tp3helper.dat
TaskKill /F /IM androidemulator.exe
TaskKill /F /IM aow_exe.exe
TaskKill /F /IM QMEmulatorService.exe
TaskKill /F /IM RuntimeBroker.exe
taskkill /f /im adb.exe
taskkill /f /im GameLoader.exe
taskkill /f /im TBSWebRenderer.exe
taskkill /f /im AppMarket.exe
taskkill /f /im AndroidEmulator.exe
taskkill /f /im ninja.vmp.exe
net stop QMEmulatorService
net stop aow_drv
net stop aow_exe
net stop aow_drv_x64_ev
net stop AndroidEmulator
net stop aow_drv_x64
net stop Tensafe
taskkill /F /IM Auxillary.exe
taskkill /F /IM TP3Helper.exe
taskkill /F /IM tp3helper.dat
TaskKill /F /IM androidemulator.exe
TaskKill /F /IM aow_exe.exe
TaskKill /F /IM QMEmulatorService.exe
TaskKill /F /IM RuntimeBroker.exe
taskkill /f /im adb.exe
taskkill /f /im GameLoader.exe
taskkill /f /im TBSWebRenderer.exe
taskkill /f /im AppMarket.exe
taskkill /f /im AndroidEmulator.exe
taskkill /f /im ninja.vmp.exe
net stop QMEmulatorService
net stop aow_drv
net stop aow_exe
net stop aow_drv_x64_ev
net stop AndroidEmulator
net stop aow_drv_x64
net stop Tensafe
taskkill /f /im syzs_dl_svr.exe
taskkill /f /im TUpdate.exe
nbtstat -rr
del C:\Windows\Temp /q & del /q/f/s %TEMP%\* /q
del /s /f /q C:\Users\%username%\AppData\Local\Temp\
del /s /f /q C:\Users\%username%\AppData\Roaming\Tencent\*.*
del /s /f /q C:\ProgramData\Tencent*.*
del /s /f /q C:\Users\%username%\AppData\Local\Temp\
del /s /f /q C:\Users\%username%\AppData\Local\Tencent\
del /s /f /q C:\Users\%username%\AppData\Roaming\Tencent\
cls
del /f /s /q %systemdrive%\*.tmp
del /f /s /q %systemdrive%\*._mp
del /f /s /q %systemdrive%\*.log
del /f /s /q %systemdrive%\*.gid
del /f /s /q %systemdrive%\*.chk
del /f /s /q %systemdrive%\*.old
del /f /s /q %systemdrive%\recycled\*.*
del /f /s /q %windir%\*.bak
del /f /s /q %windir%\prefetch\*.*
rd /s /q %windir%\temp & md %windir%\temp
del /f /q %userprofile%\cookies\*.*
del /f /s /q "%userprofile%\Local Settings\Temporary Internet Files\*.*"
del /f /s /q  "%userprofile%\Local Settings\Temp\*.*"
del /q /f /s "%USERPROFILE%\AppData\Local\Microsoft\Windows\Temporary Internet Files\*.*"
del /f /s /q  "%userprofile%\recent\*.*"
del /q /f /s "%USERPROFILE%\AppData\Local\Temp\Excel8.0\*.exd??
del /q /f /s "%USERPROFILE%\AppData\Roaming\Microsoft\Office\*.tmp"
del /f /s /q "%userprofile%\Local Settings\Temp\*.*"
del /s /q C:\Windows\temp\*
del /f /s /q "%userprofile%\recent\*.*"
rd /s /q %windir%\temp & md %windir%\temp
del /q/f/s %TEMP%\*
rd /s /q %windir%\temp & md %windir%\temp
del /f /q %userprofile%\cookies\*.*
del /f /q %userprofile%\recent\*.*
del /f /s /q "%userprofile%\Local Settings\Temporary Internet Files\*.*"
del /f /s /q "%userprofile%\Local Settings\Temp\*.*"
del /f /s /q "%userprofile%\recent\*.*"
del /s /f /q c:\windows\temp\*.*
rd /s /q c:\windows\temp
md c:\windows\temp
del /s /f /q C:\WINDOWS\Prefetch
del /s /f /q %temp%\*.*
md %temp%
deltree /y c:\windows\tempor~1
deltree /y c:\windows\temp
deltree /y c:\windows\tmp
deltree /y c:\windows\ff*.tmp
deltree /y c:\windows\history
deltree /y c:\windows\cookies
deltree /y c:\windows\recent
deltree /y c:\windows\spool\printers
del c:\WIN386.SWP
Del /S /F /Q %Windir%\Temp
Del /S /F /Q %temp%
echo of |clip
rd /q /s c:\$Recycle.Bin
rd /q /s d:\$Recycle.Bin
%SystemRoot%System32Cmd.exe /c Cleanmgr /sageset:16 & Cleanmgr /sagerun:16
del *.log /a /s /q /f
del /s /f /q C:\ProgramData\Tencent
del /s /f /q c:\Windows\Prefetch
del /s /f /q C:\aow_drv.log
echo Done 
call %temp%\TEMPmessage.vbs
TaskKill /F /IM chrome.exe
TaskKill /F /IM opera.exe
TaskKill /F /IM firefox.exe
TaskKill /F /IM service.exe

echo. [+] Cleaning Autorun.inf from all local drives...
for %%V in (C D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    :: Check if the drive letter exists
    if exist "%%V:\" (
        echo.     Checking drive %%V:
        if exist "%%V:\autorun.inf" (
            cd "%%V:\"
            attrib -s -h -r "autorun.inf" >nul 2>&1
            del "autorun.inf" >nul 2>&1
            echo.         --> Found and removed autorun.inf from drive %%V:
        ) else (
            echo.         --> autorun.inf not found on drive %%V:
        )
    )
)
echo. [+] Autorun.inf cleanup complete!

net start uxsms

del /f /s /q "%systemdrive%\*.tmp"
del /f /s /q "%systemdrive%\*._mp"
del /f /s /q "%systemdrive%\*.log"
del /f /s /q "%systemdrive%\*.gid"
del /f /s /q "%systemdrive%\*.chk"
del /f /s /q "%systemdrive%\*.old"
del /f /s /q "%systemdrive%\*.SWP"

del /f /s /q "C:\*.tmp
del /f /s /q "C:\*._mp"
del /f /s /q "C:\*.log"
del /f /s /q "C:\*.gid"
del /f /s /q "C:\*.chk"
del /f /s /q "C:\*.old"
del /f /s /q "C:\*.SWP"

del /f /s /q "E:\*.tmp
del /f /s /q "E:\*._mp"
del /f /s /q "E:\*.log"
del /f /s /q "E:\*.gid"
del /f /s /q "E:\*.chk"
del /f /s /q "E:\*.old"
del /f /s /q "E:\*.SWP"

del /f /s /q "D:\*.tmp
del /f /s /q "D:\*._mp"
del /f /s /q "D:\*.log"
del /f /s /q "D:\*.gid"
del /f /s /q "D:\*.chk"
del /f /s /q "D:\*.old"
del /f /s /q "D:\*.SWP"

del /f /s /q "F:\*.tmp
del /f /s /q "F:\*._mp"
del /f /s /q "F:\*.log"
del /f /s /q "F:\*.gid"
del /f /s /q "F:\*.chk"
del /f /s /q "F:\*.old"
del /f /s /q "F:\*.SWP"

del /f /s /q "%windir%\*.bak"
del /f /s /q "%SystemRoot%\MEMORY.DMP"
del /f /s /q "%SystemRoot%\Minidump.dmp"
del /f /s /q "%SystemRoot%\Minidump\*.*"
del /f /s /q "%SystemRoot%\Minidump\"
rd /s /q "%SystemRoot%\Minidump\"
md "%SystemRoot%\Minidump\"

reg delete "HKEY_USERS\S-1-5-21-1684716338-1731825245-2802686541-500\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" /f
del /f /s /q "%userprofile%\AppData\Roaming\Microsoft\Windows\Recent\*.*"
rd /s /q "%userprofile%\AppData\Roaming\Microsoft\Windows\Recent\*.*"
md "%userprofile%\AppData\Roaming\Microsoft\Windows\Recent\"
del /f /s /q "%userprofile%\AppData\Local\Microsoft\Windows\History\*.*"
rd /s /q "%userprofile%\AppData\Local\Microsoft\Windows\History\"
md "%userprofile%\AppData\Local\Microsoft\Windows\History\"
del /f /s /q "%userprofile%\AppData\Roaming\Microsoft\Windows\Cookies\*.*"
rd /s /q "%userprofile%\AppData\Roaming\Microsoft\Windows\Cookies\*.*"
md "%userprofile%\AppData\Roaming\Microsoft\Windows\Cookies\*.*"
del /f /s /q "%windir%\temp\*.*"
del /f /s /q "%windir%\temp\"
del /f /s /q "%windir%\prefetch\*.*"
del /f /s /q "%windir%\prefetch\"
rd /s /q "%windir%\prefetch\"
md "%windir%\prefetch\"
del /f /s /q "%USERPROFILE%\AppData\Local\Temp\*.*"
del /f /s /q "%USERPROFILE%\AppData\Local\Temp\"
del /f /q "%userprofile%\cookies\*.*"
del /f /q "%userprofile%\cookies\"
rd /s /q "%userprofile%\cookies\"
del /f /s /q "%userprofile%\Local Settings\Temporary Internet Files\*.*"
del /f /s /q "%USERPROFILE%\AppData\Local\Microsoft\Windows\Temporary Internet Files\*.*"
del /f /s /q "%USERPROFILE%\AppData\Local\Microsoft\Windows\Temporary Internet Files\"
rd /s /q "%USERPROFILE%\AppData\Local\Microsoft\Windows\Temporary Internet Files\"
del /f /s /q "%USERPROFILE%\AppData\Local\Microsoft\Windows\Caches\"
del /f /s /q "%USERPROFILE%\AppData\Local\Microsoft\Windows\Caches\*.*"
del /f /s /q "%systemdrive%\ProgramData\Microsoft\Windows\Caches\*.*"
rd /s /q "%systemdrive%\ProgramData\Microsoft\Windows\Caches\"
del /f /s /q "%USERPROFILE%\AppData\Local\Microsoft\Windows\WER\*.*"
rd /s /q "%USERPROFILE%\AppData\Local\Microsoft\Windows\WER\"
del /f /s /q "%USERPROFILE%\AppData\Local\Microsoft\Windows\WER\ReportArchive\*.*"
rd /s /q "%USERPROFILE%\AppData\Local\Microsoft\Windows\WER\ReportArchive\"
del /f /s /q "%USERPROFILE%\AppData\Local\Microsoft\Windows\WER\ReportQueue\*.*"
rd /s /q "%USERPROFILE%\AppData\Local\Microsoft\Windows\WER\ReportQueue\"
del /f /s /q "%USERPROFILE%\AppData\Local\Microsoft\Windows\WER\ERC\*.*"
rd /s /q "%USERPROFILE%\AppData\Local\Microsoft\Windows\WER\ERC\"
del /f /s /q "%systemdrive%\ProgramData\Microsoft\Windows\WER\ReportQueue\*.*"
rd /s /q "%systemdrive%\ProgramData\Microsoft\Windows\WER\ReportQueue\"
del /f /s /q "%systemdrive%\ProgramData\Microsoft\Windows\WER\ReportArchive\*.*"
rd /s /q "%systemdrive%\ProgramData\Microsoft\Windows\WER\ReportArchive\"
del /f /s /q "%userprofile%\AppData\Local\Microsoft\Windows\Explorer\*.db"
del /f /s /q "%userprofile%\AppData\Local\Microsoft\Windows\Explorer\*.etl"
del /f /s /q "%userprofile%\AppData\Local\Microsoft\Windows\Explorer\ThumbCacheToDelete\*.tmp"
rd /s /q "%userprofile%\AppData\Local\Microsoft\Windows\Explorer\ThumbCacheToDelete\"
del /f /s /q "\$Recycle.Bin\"
del /f /s /q "\$Recycle.Bin\*"
del /f /s "/q \$Recycle.Bin\*.*"
rd /s /q "\$Recycle.Bin\"
rd /s /q "\$Recycle.Bin\*"
rd /s /q "\$Recycle.Bin\*.*"
%SystemRoot%\System32\Cmd.exe /c Cleanmgr /sageset:16 & Cleanmgr /sagerun:16
c:\windows\SYSTEM32\cleanmgr.exe /dDrive
chkdsk C:
echo. Now Termine Scan Local Disk [C] !Now Scan [D]
chkdsk D:
echo. Now Termine Scan Local Disk [D] !Now Scan [E]
chkdsk E:
echo. Now Termine Scan Local Disk [E] !Now Scan [F]
chkdsk F:
echo. Now Termine Scan Local Disk [C/D/E/F]
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 255
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 1
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 2
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 8
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 16
RunDll32.exe InetCpl.cpl,ClearMyTracksByProcess 16
cls
del /f /s /q %systemdrive%\*.tmp
del /f /s /q %systemdrive%\*._mp
del /f /s /q %systemdrive%\*.log
del /f /s /q %systemdrive%\*.gid
del /f /s /q %systemdrive%\*.chk
del /f /s /q %systemdrive%\*.old
del /f /s /q %systemdrive%\recycled\*.*
del /f /s /q %windir%\*.bak
del /f /s /q %windir%\prefetch\*.*
del /f /q %userprofile%\cookies\*.*
del /f /q %userprofile%\recent\*.*
del /f /s /q "%userprofile%\Local Settings\Temporary Internet Files\*.*"
del /f /q "%userprofile%\AppData\Local\Microsoft\Windows\Temporary Internet Files\*.*"
del /f /s /q "%userprofile%\Local Settings\Temp\*.*"
del /f /s /q "%userprofile%\recent\*.*"
rd /s /q %windir%\temp & md %windir%\tempdel /f /s /q %systemdrive%\*.tmp
del /q /f /s "%USERPROFILE%\AppData\Local\Temp\Excel8.0\*.exd?
del /q /f /s "%USERPROFILE%\AppData\Roaming\Microsoft\Office\*.tmp"
del /s /q C:\Windows\temp\*
del /f /s /q "%userprofile%\recent\*.*"
del /q /f /s "%USERPROFILE%\AppData\Local\Temp\*.*"
rd /s /q %windir%\temp & md %windir%\temp
del /q/f/s %TEMP%\*
rd /s /q c:\windows\temp
md c:\windows\temp
del /s /f /q C:\WINDOWS\Prefetch
del /s /f /q %temp%\*.*
md %temp%
del c:\WIN386.SWP
Del /S /F /Q %Windir%\Temp
Del /S /F /Q %temp%
echo of |clip
rd /q /s c:\$Recycle.Bin
rd /q /s d:\$Recycle.Bin
del *.log /a /s /q /f
del /s /f /q C:\ProgramData\Tencent
del /s /f /q c:\Windows\Prefetch
del /s /f /q C:\aow_drv.log
deltree /y c:\windows\tempor~1
deltree /y c:\windows\temp
deltree /y c:\windows\tmp
deltree /y c:\windows\ff*.tmp
deltree /y c:\windows\history
deltree /y c:\windows\cookies
deltree /y c:\windows\recent
deltree /y c:\windows\spool\printers
CLEANMGR /sagerun:
sfc /scannow
DISM.exe /Online /Cleanup-image /Restorehealth
echo Processed Completed! Restart your PC
:loop

echo MSGBOX "Ultimate Cleanup processed successfully! Restart your PC for best results." ,48,"CREATED BY Panda" > %temp%\TEMPmessage.vbs
call %temp%\TEMPmessage.vbs