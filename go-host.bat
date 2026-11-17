@echo off
rem Run the Material Unigram Telegram proxy as plain processes in WSL (no Docker).
rem   go-host.bat           install if needed, start, print the address
rem   go-host.bat --stop    stop it
rem   go-host.bat --status  is it running?
setlocal
set "MODE=start"
if /I "%~1"=="--stop" set "MODE=stop"
if /I "%~1"=="--status" set "MODE=status"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\go-host.ps1" -Mode %MODE%
exit /b %ERRORLEVEL%
