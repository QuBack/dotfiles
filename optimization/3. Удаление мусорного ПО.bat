@echo off
mode con: cols=45 lines=24
setlocal EnableDelayedExpansion

:: 1. Check for Administrator Privileges
openfiles >nul 2>&1
if %errorlevel% NEQ 0 (
    mode con: cols=80 lines=10
    echo.
    echo  ERROR: Administrator privileges required.
    echo  Right-click -^> Run as administrator.
    pause
    exit /b
)

:: 2. Setup ANSI Colors
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do (
  set "ESC=%%b"
)
set "Reset=%ESC%[0m"
set "Bold=%ESC%[1m"
set "Red=%ESC%[31m"
set "Green=%ESC%[32m"
set "Yellow=%ESC%[33m"
set "Cyan=%ESC%[36m"
set "White=%ESC%[37m"
set "Gray=%ESC%[90m"

:MenuLoop
cls
echo.
echo  %Yellow%Scanning installed apps...%Reset%
call :CheckStatus
cls

echo.
echo  %Bold%%Cyan%BLOATWARE REMOVER%Reset%
echo  %Gray%-------------------------------------------%Reset%

:: --- Menu Display ---

if "!_Cam!"=="1" (set "s1=%Red%Installed%Reset%") else (set "s1=%Green%Removed%Reset%")
echo  %Bold%[1]%Reset%  Camera                  : !s1!

if "!_Dev!"=="1" (set "s2=%Red%Installed%Reset%") else (set "s2=%Green%Removed%Reset%")
echo  %Bold%[2]%Reset%  Dev Home                : !s2!

if "!_Hub!"=="1" (set "s3=%Red%Installed%Reset%") else (set "s3=%Green%Removed%Reset%")
echo  %Bold%[3]%Reset%  Feedback Hub            : !s3!

if "!_Copilot!"=="1" (set "s4=%Red%Installed%Reset%") else (set "s4=%Green%Removed%Reset%")
echo  %Bold%[4]%Reset%  Microsoft 365 Copilot   : !s4!

if "!_Bing!"=="1" (set "s5=%Red%Installed%Reset%") else (set "s5=%Green%Removed%Reset%")
echo  %Bold%[5]%Reset%  Microsoft Bing Search   : !s5!

if "!_Clip!"=="1" (set "s6=%Red%Installed%Reset%") else (set "s6=%Green%Removed%Reset%")
echo  %Bold%[6]%Reset%  Microsoft Clipchamp     : !s6!

if "!_News!"=="1" (set "s7=%Red%Installed%Reset%") else (set "s7=%Green%Removed%Reset%")
echo  %Bold%[7]%Reset%  Microsoft News          : !s7!

if "!_Teams!"=="1" (set "s8=%Red%Installed%Reset%") else (set "s8=%Green%Removed%Reset%")
echo  %Bold%[8]%Reset%  Microsoft Teams         : !s8!

if "!_ToDo!"=="1" (set "s9=%Red%Installed%Reset%") else (set "s9=%Green%Removed%Reset%")
echo  %Bold%[9]%Reset%  Microsoft To Do         : !s9!

if "!_Outlook!"=="1" (set "s10=%Red%Installed%Reset%") else (set "s10=%Green%Removed%Reset%")
echo  %Bold%[10]%Reset% Outlook                 : !s10!

if "!_Power!"=="1" (set "s11=%Red%Installed%Reset%") else (set "s11=%Green%Removed%Reset%")
echo  %Bold%[11]%Reset% Power Automate          : !s11!

if "!_Quick!"=="1" (set "s12=%Red%Installed%Reset%") else (set "s12=%Green%Removed%Reset%")
echo  %Bold%[12]%Reset% Quick Assist            : !s12!

if "!_Sol!"=="1" (set "s13=%Red%Installed%Reset%") else (set "s13=%Green%Removed%Reset%")
echo  %Bold%[13]%Reset% Solitaire               : !s13!

if "!_Sound!"=="1" (set "s14=%Red%Installed%Reset%") else (set "s14=%Green%Removed%Reset%")
echo  %Bold%[14]%Reset% Sound Recorder          : !s14!

if "!_Sticky!"=="1" (set "s15=%Red%Installed%Reset%") else (set "s15=%Green%Removed%Reset%")
echo  %Bold%[15]%Reset% Sticky Notes            : !s15!

echo  %Gray%-------------------------------------------%Reset%
echo  %Bold%[A]%Reset% %Green%Remove all%Reset%
echo.

:: Input Handler
set /p "choice=Select: "

if "%choice%"=="1" goto ToggleCam
if "%choice%"=="2" goto ToggleDev
if "%choice%"=="3" goto ToggleHub
if "%choice%"=="4" goto ToggleCopilot
if "%choice%"=="5" goto ToggleBing
if "%choice%"=="6" goto ToggleClip
if "%choice%"=="7" goto ToggleNews
if "%choice%"=="8" goto ToggleTeams
if "%choice%"=="9" goto ToggleToDo
if "%choice%"=="10" goto ToggleOutlook
if "%choice%"=="11" goto TogglePower
if "%choice%"=="12" goto ToggleQuick
if "%choice%"=="13" goto ToggleSol
if "%choice%"=="14" goto ToggleSound
if "%choice%"=="15" goto ToggleSticky
if /i "%choice%"=="a" goto ApplyAllGreen
goto MenuLoop

:: ====================================================================================

:ToggleCam
call :RemoveApp "Microsoft.WindowsCamera"
goto MenuLoop

:ToggleDev
call :RemoveApp "Microsoft.Windows.DevHome"
goto MenuLoop

:ToggleHub
call :RemoveApp "Microsoft.WindowsFeedbackHub"
goto MenuLoop

:ToggleCopilot
echo. & echo %Red%Removing Microsoft 365 Copilot...%Reset%
:: 0. Убиваем процессы, на которых может висеть интерфейс
taskkill /f /im msedgewebview2.exe >nul 2>&1
taskkill /f /im msedge.exe >nul 2>&1

:: 1. 
reg add "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v "TurnOffWindowsCopilot" /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v "TurnOffWindowsCopilot" /t REG_DWORD /d 1 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowCopilotButton /t REG_DWORD /d 0 /f >nul

:: 2. 
winget uninstall --name "Microsoft 365 Copilot" --silent --accept-source-agreements >nul 2>&1
winget uninstall --name "Copilot" --silent --accept-source-agreements >nul 2>&1

:: 3. 
powershell -NoProfile -Command "Get-AppxPackage -AllUsers | Where-Object { $_.Name -match 'Copilot|Windows.Ai' } | ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue }" >nul 2>&1
powershell -NoProfile -Command "Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -match 'Copilot|Windows.Ai' } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue" >nul 2>&1

timeout /t 2 >nul
goto MenuLoop

:ToggleBing
echo. & echo %Red%Removing Microsoft Bing...%Reset%
powershell -NoProfile -Command "Get-AppxPackage *BingSearch* -AllUsers | Remove-AppxPackage -AllUsers" >nul 2>&1
powershell -NoProfile -Command "Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like '*BingSearch*' } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue" >nul 2>&1
reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f >nul
timeout /t 1 >nul
goto MenuLoop

:ToggleClip
call :RemoveApp "Clipchamp.Clipchamp"
goto MenuLoop

:ToggleNews
call :RemoveApp "Microsoft.BingNews"
goto MenuLoop

:ToggleTeams
echo. & echo %Red%Killing Teams processes...%Reset%
taskkill /f /im msteams.exe >nul 2>&1
call :RemoveApp "MSTeams"
goto MenuLoop

:ToggleToDo
echo. & echo %Red%Killing To Do processes...%Reset%
taskkill /f /im Todo.exe >nul 2>&1
call :RemoveApp "Microsoft.Todos"
goto MenuLoop

:ToggleOutlook
echo. & echo %Red%Killing Outlook processes...%Reset%
taskkill /f /im olk.exe >nul 2>&1
call :RemoveApp "Microsoft.OutlookForWindows"
goto MenuLoop

:TogglePower
echo. & echo %Red%Killing Power Automate processes...%Reset%
taskkill /f /im PowerAutomate.exe >nul 2>&1
taskkill /f /im PAD.Console.Host.exe >nul 2>&1
taskkill /f /im PAD.DesktopBehavior.exe >nul 2>&1
call :RemoveApp "Microsoft.PowerAutomateDesktop"
goto MenuLoop

:ToggleQuick
call :RemoveApp "MicrosoftCorporationII.QuickAssist"
goto MenuLoop

:ToggleSol
call :RemoveApp "Microsoft.MicrosoftSolitaireCollection"
goto MenuLoop

:ToggleSound
call :RemoveApp "Microsoft.WindowsSoundRecorder"
goto MenuLoop

:ToggleSticky
call :RemoveApp "Microsoft.MicrosoftStickyNotes"
goto MenuLoop

:: ====================================================================================

:ApplyAllGreen
echo.
echo %Green%REMOVING ALL LISTED APPS...%Reset%
echo %Yellow%Please wait, this will take about a minute.%Reset%

:: 1.
taskkill /f /im PowerAutomate.exe >nul 2>&1
taskkill /f /im PAD.Console.Host.exe >nul 2>&1
taskkill /f /im PAD.DesktopBehavior.exe >nul 2>&1
taskkill /f /im Todo.exe >nul 2>&1
taskkill /f /im msteams.exe >nul 2>&1
taskkill /f /im olk.exe >nul 2>&1
taskkill /f /im msedgewebview2.exe >nul 2>&1
taskkill /f /im msedge.exe >nul 2>&1

:: 2.
winget uninstall --name "Microsoft 365 Copilot" --silent --accept-source-agreements >nul 2>&1
winget uninstall --name "Copilot" --silent --accept-source-agreements >nul 2>&1

:: 3. 
reg add "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v "TurnOffWindowsCopilot" /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v "TurnOffWindowsCopilot" /t REG_DWORD /d 1 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowCopilotButton /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions /t REG_DWORD /d 1 /f >nul

:: 4.
powershell -NoProfile -Command "$apps = '*WindowsCamera*,*DevHome*,*WindowsFeedbackHub*,*Clipchamp*,*BingNews*,*MSTeams*,*Todos*,*OutlookForWindows*,*PowerAutomateDesktop*,*QuickAssist*,*SolitaireCollection*,*WindowsSoundRecorder*,*StickyNotes*,*Copilot*,*Windows.Ai*,*BingSearch*'.Split(','); $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue; foreach($a in $apps){ Write-Host 'Removing' $a; Get-AppxPackage -Name $a -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue; if ($prov) { $prov | Where-Object {$_.DisplayName -like $a} | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue } }" >nul 2>&1

echo.
echo %Green%Done!%Reset%
timeout /t 3 >nul
goto MenuLoop

:: ====================================================================================
:: HELPERS
:: ====================================================================================

:RemoveApp
echo. & echo %Red%Removing %~1...%Reset%
powershell -NoProfile -Command "Get-AppxPackage -Name '*%~1*' -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue; $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue; if ($prov) { $prov | Where-Object { $_.DisplayName -like '*%~1*' } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue }" >nul 2>&1
exit /b

:CheckStatus
set "_Cam=0" & set "_Dev=0" & set "_Hub=0" & set "_Copilot=0"
set "_Bing=0" & set "_Clip=0" & set "_News=0" & set "_Teams=0"
set "_ToDo=0" & set "_Outlook=0" & set "_Power=0" & set "_Quick=0"
set "_Sol=0" & set "_Sound=0" & set "_Sticky=0"

powershell -NoProfile -Command "Get-AppxPackage -AllUsers | Select-Object -ExpandProperty Name" > "%temp%\apps.txt"

findstr /i "WindowsCamera" "%temp%\apps.txt" >nul && set "_Cam=1"
findstr /i "DevHome" "%temp%\apps.txt" >nul && set "_Dev=1"
findstr /i "WindowsFeedbackHub" "%temp%\apps.txt" >nul && set "_Hub=1"
findstr /i "Clipchamp" "%temp%\apps.txt" >nul && set "_Clip=1"
findstr /i "BingNews" "%temp%\apps.txt" >nul && set "_News=1"
findstr /i "MSTeams" "%temp%\apps.txt" >nul && set "_Teams=1"
findstr /i "Todos" "%temp%\apps.txt" >nul && set "_ToDo=1"
findstr /i "OutlookForWindows" "%temp%\apps.txt" >nul && set "_Outlook=1"
findstr /i "PowerAutomateDesktop" "%temp%\apps.txt" >nul && set "_Power=1"
findstr /i "QuickAssist" "%temp%\apps.txt" >nul && set "_Quick=1"
findstr /i "SolitaireCollection" "%temp%\apps.txt" >nul && set "_Sol=1"
findstr /i "WindowsSoundRecorder" "%temp%\apps.txt" >nul && set "_Sound=1"
findstr /i "StickyNotes" "%temp%\apps.txt" >nul && set "_Sticky=1"

:: 
findstr /i "Copilot Windows.Ai" "%temp%\apps.txt" >nul && set "_Copilot=1"

reg query "HKCU\Software\Policies\Microsoft\Windows\Explorer" /v DisableSearchBoxSuggestions >nul 2>&1
if %errorlevel% EQU 0 (set "_Bing=0") else (set "_Bing=1")

del "%temp%\apps.txt" >nul
exit /b