@echo off
rem Host the Material Unigram Telegram proxy in Docker.
rem   host.bat             choose a mode
rem   host.bat --detached  start in the background and print the address
rem   host.bat --logs      live log view (leaving it keeps the proxy running)
rem   host.bat --stop      stop the proxy
setlocal
set "MODE=ask"
if /I "%~1"=="--detached" set "MODE=detached"
if /I "%~1"=="--logs" set "MODE=logs"
if /I "%~1"=="--stop" set "MODE=stop"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\host.ps1" -Mode %MODE%
exit /b %ERRORLEVEL%
