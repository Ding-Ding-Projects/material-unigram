@echo off
rem Build the Material Unigram appliance image (boots straight into the server).
rem   build-appliance.bat          Telegram proxy appliance
rem   build-appliance.bat --full   full Telegram-compatible server appliance
setlocal
set "VARIANT=proxy"
if /I "%~1"=="--full" set "VARIANT=full"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0appliance\build.ps1" -Variant %VARIANT%
exit /b %ERRORLEVEL%
