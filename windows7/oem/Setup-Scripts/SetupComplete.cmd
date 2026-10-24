@echo off
rem N10JC Windows 7: kurulumun sonunda (ilk giristen once) SYSTEM olarak calisir.
rem Gunluk: C:\N10\kurulum.log
setlocal EnableDelayedExpansion
set N10=C:\N10
set U=%N10%\uygulamalar
set LOG=%N10%\kurulum.log
echo [%date% %time%] SetupComplete basladi >> "%LOG%"

rem ---- Guc ve disk (SSD) ----
powercfg -h off >> "%LOG%" 2>&1
rem Dengeli plan: prizde ekran 15 dk, pilde 5 dk; kapak kapaninca uyku
powercfg -change -monitor-timeout-ac 15
powercfg -change -monitor-timeout-dc 5
powercfg -change -standby-timeout-ac 0
powercfg -change -standby-timeout-dc 20
fsutil behavior set DisableDeleteNotify 0 >> "%LOG%" 2>&1
rem Sayfa dosyasi sabit 1-3 GB (2 GB RAM ile oyunlar icin yeterli, SSD'yi parcalamaz)
wmic computersystem where name="%computername%" set AutomaticManagedPagefile=False >> "%LOG%" 2>&1
wmic pagefileset create name="C:\pagefile.sys" >> "%LOG%" 2>&1
wmic pagefileset where name="C:\\pagefile.sys" set InitialSize=1024,MaximumSize=3072 >> "%LOG%" 2>&1

rem ---- Gereksiz arka plan hizmetleri ----
for %%S in (SysMain WSearch DiagTrack dmwappushservice WMPNetworkSvc TabletInputService Fax WerSvc WinDefend) do (
  sc config %%S start= disabled >> "%LOG%" 2>&1
  sc stop %%S >nul 2>&1
)
sc config wuauserv start= demand >> "%LOG%" 2>&1

rem ---- Gereksiz zamanlanmis gorevler (SSD yazmasi ve islemci yuku) ----
call :gorev "\Microsoft\Windows\Defrag\ScheduledDefrag"
call :gorev "\Microsoft\Windows\Application Experience\AitAgent"
call :gorev "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
call :gorev "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
call :gorev "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
call :gorev "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask"
call :gorev "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
call :gorev "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
call :gorev "\Microsoft\Windows\Maintenance\WinSAT"
call :gorev "\Microsoft\Windows\Autochk\Proxy"
call :gorev "\Microsoft\Windows\Windows Defender\MP Scheduled Scan"
call :gorev "\Microsoft\Windows\Media Center\mcupdate"
call :gorev "\Microsoft\Windows\RAC\RacTask"

rem ---- Oyun bilesenleri ----
if exist "%U%\directx_Jun2010_redist.exe" (
  "%U%\directx_Jun2010_redist.exe" /Q /T:"%TEMP%\n10dx"
  "%TEMP%\n10dx\DXSETUP.exe" /silent
  echo DirectX: !errorlevel! >> "%LOG%"
)
if exist "%U%\vcredist2005_x86.exe" "%U%\vcredist2005_x86.exe" /q
if exist "%U%\vcredist2008_x86.exe" "%U%\vcredist2008_x86.exe" /q
if exist "%U%\vcredist2010_x86.exe" "%U%\vcredist2010_x86.exe" /q /norestart
for %%V in (2012 2013 2019 2022) do (
  if exist "%U%\vcredist%%V_x86.exe" (
    "%U%\vcredist%%V_x86.exe" /install /quiet /norestart
    echo VC++ %%V: !errorlevel! >> "%LOG%"
  )
)
if exist "%U%\PhysX.msi" msiexec /i "%U%\PhysX.msi" /qn /norestart >> "%LOG%" 2>&1
if exist "%U%\oalinst.exe" "%U%\oalinst.exe" /s
if exist "%U%\ndp48-x86-x64-allos-enu.exe" "%U%\ndp48-x86-x64-allos-enu.exe" /q /norestart

rem ---- Uygulamalar ----
if exist "%U%\7zip_x86.exe" "%U%\7zip_x86.exe" /S
if exist "%U%\mpc-hc_x86.exe" "%U%\mpc-hc_x86.exe" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-

rem ---- Her acilista USB'ye rapor (Output klasoru) ve etkinlestirme denemesi ----
schtasks /Create /F /RU SYSTEM /SC ONSTART /DELAY 0002:00 /TN "N10\Rapor" /TR "powershell -NoProfile -ExecutionPolicy Bypass -File C:\N10\n10-rapor.ps1" >> "%LOG%" 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File C:\N10\n10-rapor.ps1 >> "%LOG%" 2>&1

echo [%date% %time%] SetupComplete bitti >> "%LOG%"
endlocal
exit /b 0

:gorev
schtasks /Change /TN %1 /Disable >> "%LOG%" 2>&1
exit /b 0
