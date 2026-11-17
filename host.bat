@echo off
rem Host the Material Unigram Telegram proxy in Docker.
rem   host.bat             choose a mode
rem   host.bat --detached  start in the background and print the address
rem   host.bat --logs      live log view (leaving it keeps the proxy running)
rem   host.bat --stop      stop the proxy
rem   add --full to any of these for the full Telegram-compatible server instead of the proxy
setlocal
set "MODE=ask"
set "SERVER=proxy"
for %%A in (%*) do (
    if /I "%%~A"=="--detached" set "MODE=detached"
    if /I "%%~A"=="--logs" set "MODE=logs"
    if /I "%%~A"=="--stop" set "MODE=stop"
    if /I "%%~A"=="--full" set "SERVER=full"
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\host.ps1" -Mode %MODE% -Server %SERVER%
exit /b %ERRORLEVEL%
