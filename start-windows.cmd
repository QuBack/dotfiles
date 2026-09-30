@echo off
setlocal
if not exist "%~dp0setup.ps1" (
    echo setup.ps1 was not found next to this launcher.
    pause
    exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1" %*
set "setup_result=%errorlevel%"
if not "%setup_result%"=="0" pause
exit /b %setup_result%
