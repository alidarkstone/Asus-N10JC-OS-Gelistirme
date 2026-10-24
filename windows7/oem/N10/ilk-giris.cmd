@echo off
rem N10JC Windows 7: ilk oturum acilisinda kullanici olarak bir kez calisir.
setlocal
set U=C:\N10\uygulamalar
set LOG=C:\N10\kurulum.log
echo [%date% %time%] Ilk giris basladi >> "%LOG%"
if exist "%U%\supermium_setup_32.exe" (
  "%U%\supermium_setup_32.exe" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /ALLUSERS --system-level --do-not-launch-chrome
  echo Supermium: %errorlevel% >> "%LOG%"
)
rem Duvar kagidini hemen uygula
RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters 1, True
rem Kurulum dosyalarini sil (SSD'de yer acilir), gunluk ve rapor kalir
rd /s /q "%U%" >nul 2>&1
echo [%date% %time%] Ilk giris bitti >> "%LOG%"
endlocal
