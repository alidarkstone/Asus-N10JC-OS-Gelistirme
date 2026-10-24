@echo off
rem N10JC Windows 7 kiti - cift tiklayin. Yonetici izni ister, sonra her seyi kendisi yapar.
net session >nul 2>&1
if %errorlevel% neq 0 (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
title N10JC Windows 7 hazirlaniyor - pencereyi kapatmayin
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\hazirla.ps1"
echo.
echo Bitti. Bu pencereyi kapatabilirsiniz.
pause >nul
