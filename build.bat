@echo off
rem Material Unigram: one-click build on Windows.
rem   build.bat            install anything missing, build TDLib, then the unpackaged WinUI app
rem   build.bat /s         same, without pausing at the end (for scripts)
rem   build.bat /run       build, then start the app
rem Output: Telegram\bin\... (the path is printed at the end). Exit code is non-zero on failure.
setlocal EnableExtensions
set "ROOT=%~dp0"
set "SILENT="
set "RUN="
for %%A in (%*) do (
    if /I "%%~A"=="/s" set "SILENT=1"
    if /I "%%~A"=="/run" set "RUN=1"
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\bootstrap.ps1"
if errorlevel 1 goto :failed

set /p MATERIAL_UNIGRAM_VS=<"%ROOT%scripts\.toolchain"
set "VCPKG_ROOT=%ROOT%..\vcpkg"

echo ==^> Building TDLib for x64-windows
pushd "%ROOT%Libraries\tdjson"
powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1 -arch x64 -target windows
set "ERR=%ERRORLEVEL%"
popd
if not "%ERR%"=="0" goto :failed

echo ==^> Building the app (unpackaged WinUI, x64 Release)
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%Build.WinUI.ps1" -Unpackaged
if errorlevel 1 goto :failed

echo.
echo Build succeeded.
if defined RUN powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%scripts\run.ps1"
if not defined SILENT pause
exit /b 0

:failed
echo.
echo Build FAILED. Read the first error above; nothing was reported as successful.
if not defined SILENT pause
exit /b 1
