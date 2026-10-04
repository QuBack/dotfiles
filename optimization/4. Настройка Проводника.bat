@echo off
:: Compact Mode
mode con: cols=45 lines=20
setlocal EnableDelayedExpansion

:: ====================================================================================
:: Script Name: EXPLORER CONFIG (v2.8 - Logic Swap)
:: Fix: Desktop Recycle Bin: Visible = Red, Hidden = Green.
:: Apply All now HIDES the Desktop Recycle Bin icon.
:: ====================================================================================

:: 1. Auto-Elevation
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    echo Requesting Admin...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
    pushd "%CD%"
    CD /D "%~dp0"

:: 2. Colors
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do (set "ESC=%%b")
set "Reset=%ESC%[0m"
set "Bold=%ESC%[1m"
set "Red=%ESC%[31m"
set "Green=%ESC%[32m"
set "Yellow=%ESC%[33m"
set "Cyan=%ESC%[36m"
set "Gray=%ESC%[90m"

:: 3. Paths & GUIDs
set "RegAdv=HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
set "RegExp=HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer"
set "RegDeskIcons=HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel"
set "ClsidHome={f874310e-b6b7-47dc-bc84-b9e6b38f5903}"
set "ClsidGallery={e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" 
set "ClsidNetwork={F02C1A0D-BE21-4350-88B0-7367FC96EF3C}"
set "ClsidRecycle={645FF040-5081-101B-9F08-00AA002F954E}"
set "ClsidMenu={86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"

:MenuLoop
cls
call :CheckStatus
echo.
echo  %Bold%%Cyan%EXPLORER CONFIG%Reset%
echo  %Gray%-------------------------------------------%Reset%

:: --- NAVIGATION ---
if "!_OpenLoc!"=="1" (set "s=%Green%This PC%Reset%") else (set "s=%Red%Home%Reset%")
echo  %Bold%[1]%Reset%  Open Explorer to      : !s!

if "!_HideHome!"=="0" (set "s=%Green%Hidden%Reset%") else (set "s=%Red%Visible%Reset%")
echo  %Bold%[2]%Reset%  Home Button           : !s!

if "!_HideGallery!"=="0" (set "s=%Green%Hidden%Reset%") else (set "s=%Red%Visible%Reset%")
echo  %Bold%[3]%Reset%  Gallery Button        : !s!

if "!_HideNetwork!"=="0" (set "s=%Green%Hidden%Reset%") else (set "s=%Red%Visible%Reset%")
echo  %Bold%[4]%Reset%  Network Button        : !s!

:: --- INTERFACE ---
if "!_ShowRecycle!"=="1" (set "s=%Green%Visible%Reset%") else (set "s=%Red%Hidden%Reset%")
echo  %Bold%[5]%Reset%  Recycle Bin (Nav)     : !s!

if "!_DeskRecycle!"=="0" (set "s=%Red%Visible%Reset%") else (set "s=%Green%Hidden%Reset%")
echo  %Bold%[6]%Reset%  Desktop Recycle Bin   : !s!

if "!_Compact!"=="1" (set "s=%Green%Enabled%Reset%") else (set "s=%Red%Disabled%Reset%")
echo  %Bold%[7]%Reset%  Compact View          : !s!

if "!_Privacy!"=="0" (set "s=%Green%Disabled%Reset%") else (set "s=%Red%Enabled%Reset%")
echo  %Bold%[8]%Reset%  Privacy (Recent)      : !s!

if "!_CtxMenu!"=="1" (set "s=%Green%Classic%Reset%") else (set "s=%Red%Modern%Reset%")
echo  %Bold%[9]%Reset%  Context Menu          : !s!

echo  %Gray%-------------------------------------------%Reset%

:: --- ACTIONS ---
echo  %Bold%[R]%Reset%  %Yellow%Restart Explorer%Reset%

echo  %Gray%-------------------------------------------%Reset%

echo  %Bold%[A]%Reset%  %Green%Apply All%Reset%
echo  %Bold%[D]%Reset%  %Red%Restore Defaults%Reset%
echo.

set /p "c=Select: "

:: Navigation
if /i "%c%"=="A" goto ApplyAllGreen
if /i "%c%"=="D" goto RestoreDefaults
if /i "%c%"=="R" goto RestartExp

:: Toggles
if "%c%"=="1" goto ToggleOpen
if "%c%"=="2" goto ToggleHome
if "%c%"=="3" goto ToggleGallery
if "%c%"=="4" goto ToggleNetwork
if "%c%"=="5" goto ToggleRecycle
if "%c%"=="6" goto ToggleDeskRecycle
if "%c%"=="7" goto ToggleCompact
if "%c%"=="8" goto TogglePrivacy
if "%c%"=="9" goto ToggleCtxMenu

goto MenuLoop

:: ====================================================================================
:: LOGIC
:: ====================================================================================

:ToggleOpen
if "!_OpenLoc!"=="1" (reg add "%RegAdv%" /v LaunchTo /t REG_DWORD /d 2 /f >nul) else (reg add "%RegAdv%" /v LaunchTo /t REG_DWORD /d 1 /f >nul)
goto MenuLoop

:ToggleHome
if "!_HideHome!"=="0" (reg add "HKCU\Software\Classes\CLSID\%ClsidHome%" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 1 /f >nul) else (reg add "HKCU\Software\Classes\CLSID\%ClsidHome%" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 0 /f >nul)
goto MenuLoop

:ToggleGallery
if "!_HideGallery!"=="0" (reg add "HKCU\Software\Classes\CLSID\%ClsidGallery%" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 1 /f >nul) else (reg add "HKCU\Software\Classes\CLSID\%ClsidGallery%" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 0 /f >nul)
goto MenuLoop

:ToggleNetwork
if "!_HideNetwork!"=="0" (reg add "HKCU\Software\Classes\CLSID\%ClsidNetwork%" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 1 /f >nul) else (reg add "HKCU\Software\Classes\CLSID\%ClsidNetwork%" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 0 /f >nul)
goto MenuLoop

:ToggleRecycle
:: Toggles Navigation Pane Pin Only
if "!_ShowRecycle!"=="1" (
    reg add "HKCU\Software\Classes\CLSID\%ClsidRecycle%" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 0 /f >nul
) else (
    reg add "HKCU\Software\Classes\CLSID\%ClsidRecycle%" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 1 /f >nul
)
goto MenuLoop

:ToggleDeskRecycle
:: Toggles Desktop Icon Only (0 = Visible/Red, 1 = Hidden/Green)
if "!_DeskRecycle!"=="0" (
    reg add "%RegDeskIcons%" /v "%ClsidRecycle%" /t REG_DWORD /d 1 /f >nul
) else (
    reg delete "%RegDeskIcons%" /v "%ClsidRecycle%" /f >nul
)
goto MenuLoop

:ToggleCompact
if "!_Compact!"=="1" (reg add "%RegAdv%" /v UseCompactMode /t REG_DWORD /d 0 /f >nul) else (reg add "%RegAdv%" /v UseCompactMode /t REG_DWORD /d 1 /f >nul)
goto MenuLoop

:TogglePrivacy
if "!_Privacy!"=="0" (
    reg add "%RegExp%" /v ShowRecent /t REG_DWORD /d 1 /f >nul
    reg add "%RegExp%" /v ShowFrequent /t REG_DWORD /d 1 /f >nul
    reg add "%RegExp%" /v ShowCloudFilesInQuickAccess /t REG_DWORD /d 1 /f >nul
    reg add "%RegAdv%" /v Start_TrackDocs /t REG_DWORD /d 1 /f >nul
) else (
    reg add "%RegExp%" /v ShowRecent /t REG_DWORD /d 0 /f >nul
    reg add "%RegExp%" /v ShowFrequent /t REG_DWORD /d 0 /f >nul
    reg add "%RegExp%" /v ShowCloudFilesInQuickAccess /t REG_DWORD /d 0 /f >nul
    reg add "%RegAdv%" /v Start_TrackDocs /t REG_DWORD /d 0 /f >nul
)
goto MenuLoop

:ToggleCtxMenu
if "!_CtxMenu!"=="1" (reg delete "HKCU\Software\Classes\CLSID\%ClsidMenu%" /f >nul 2>&1) else (reg add "HKCU\Software\Classes\CLSID\%ClsidMenu%\InprocServer32" /ve /f >nul)
goto MenuLoop

:ApplyAllGreen
reg add "%RegAdv%" /v LaunchTo /t REG_DWORD /d 1 /f >nul
reg add "HKCU\Software\Classes\CLSID\%ClsidHome%" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Software\Classes\CLSID\%ClsidGallery%" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Software\Classes\CLSID\%ClsidNetwork%" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Software\Classes\CLSID\%ClsidRecycle%" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 1 /f >nul
:: HIDE Desktop Recycle Bin (Green)
reg add "%RegDeskIcons%" /v "%ClsidRecycle%" /t REG_DWORD /d 1 /f >nul
reg add "%RegAdv%" /v UseCompactMode /t REG_DWORD /d 1 /f >nul
reg add "%RegExp%" /v ShowRecent /t REG_DWORD /d 0 /f >nul
reg add "%RegExp%" /v ShowFrequent /t REG_DWORD /d 0 /f >nul
reg add "%RegExp%" /v ShowCloudFilesInQuickAccess /t REG_DWORD /d 0 /f >nul
reg add "%RegAdv%" /v Start_TrackDocs /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Software\Classes\CLSID\%ClsidMenu%\InprocServer32" /ve /f >nul
goto RestartExp

:RestoreDefaults
reg add "%RegAdv%" /v LaunchTo /t REG_DWORD /d 2 /f >nul
reg add "HKCU\Software\Classes\CLSID\%ClsidHome%" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 1 /f >nul
reg add "HKCU\Software\Classes\CLSID\%ClsidGallery%" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 1 /f >nul
reg add "HKCU\Software\Classes\CLSID\%ClsidNetwork%" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 1 /f >nul
reg add "HKCU\Software\Classes\CLSID\%ClsidRecycle%" /v System.IsPinnedToNameSpaceTree /t REG_DWORD /d 0 /f >nul
:: SHOW Desktop Recycle Bin (Red/Default)
reg delete "%RegDeskIcons%" /v "%ClsidRecycle%" /f >nul 2>&1
reg add "%RegAdv%" /v UseCompactMode /t REG_DWORD /d 0 /f >nul
reg add "%RegExp%" /v ShowRecent /t REG_DWORD /d 1 /f >nul
reg add "%RegExp%" /v ShowFrequent /t REG_DWORD /d 1 /f >nul
reg add "%RegExp%" /v ShowCloudFilesInQuickAccess /t REG_DWORD /d 1 /f >nul
reg add "%RegAdv%" /v Start_TrackDocs /t REG_DWORD /d 1 /f >nul
reg delete "HKCU\Software\Classes\CLSID\%ClsidMenu%" /f >nul 2>&1
goto RestartExp

:RestartExp
taskkill /f /im explorer.exe >nul 2>&1
start explorer.exe
timeout /t 2 /nobreak >nul
goto MenuLoop

:: ====================================================================================
:: STATUS HELPER
:: ====================================================================================

:CheckStatus
call :GetRegValue "%RegAdv%" "LaunchTo" 2 _OpenLoc
call :GetRegValue "HKCU\Software\Classes\CLSID\%ClsidHome%" "System.IsPinnedToNameSpaceTree" 1 _HideHome
call :GetRegValue "HKCU\Software\Classes\CLSID\%ClsidGallery%" "System.IsPinnedToNameSpaceTree" 1 _HideGallery
call :GetRegValue "HKCU\Software\Classes\CLSID\%ClsidNetwork%" "System.IsPinnedToNameSpaceTree" 1 _HideNetwork
call :GetRegValue "HKCU\Software\Classes\CLSID\%ClsidRecycle%" "System.IsPinnedToNameSpaceTree" 0 _ShowRecycle
call :GetRegValue "%RegDeskIcons%" "%ClsidRecycle%" 0 _DeskRecycle
call :GetRegValue "%RegAdv%" "UseCompactMode" 0 _Compact
call :GetRegValue "%RegExp%" "ShowRecent" 1 _Privacy
reg query "HKCU\Software\Classes\CLSID\%ClsidMenu%\InprocServer32" >nul 2>&1
if %errorlevel% EQU 0 (set "_CtxMenu=1") else (set "_CtxMenu=0")
exit /b

:GetRegValue
set "%4=%3"
for /f "tokens=3" %%a in ('reg query "%~1" /v "%~2" 2^>nul') do (set /a "%4=%%a")
exit /b