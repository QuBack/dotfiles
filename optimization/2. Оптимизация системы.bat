@echo off
mode con: cols=52 lines=32
setlocal EnableDelayedExpansion

:: 1. Check Admin
openfiles >nul 2>&1
if %errorlevel% NEQ 0 (
  mode con: cols=60 lines=5
  echo.
  echo  RUN AS ADMINISTRATOR REQUIRED!
  pause
  exit /b
)

:: 2. Colors
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do (set "ESC=%%b")
set "Reset=%ESC%[0m"
set "Bold=%ESC%[1m"
set "Red=%ESC%[31m"
set "Green=%ESC%[32m"
set "Yellow=%ESC%[33m"
set "Cyan=%ESC%[36m"
set "Gray=%ESC%[90m"

:MenuLoop
cls
call :CheckStatus

:: Map Status to Strings
set "s1=%Red%Balanced%Reset%"
if "!_Power!"=="1" set "s1=%Green%High Perf%Reset%"
if "!_Power!"=="2" set "s1=%Cyan%Ultimate%Reset%"

if "!_BackApps!"=="1" (set "s2=%Red%Enabled%Reset%") else (set "s2=%Green%Disabled%Reset%")
if "!_DelOpt!"=="1" (set "s3=%Red%Enabled%Reset%") else (set "s3=%Green%Disabled%Reset%")
if "!_Edge!"=="1" (set "s4=%Red%Enabled%Reset%") else (set "s4=%Green%Disabled%Reset%")
if "!_Hiber!"=="1" (set "s5=%Red%Enabled%Reset%") else (set "s5=%Green%Disabled%Reset%")
if "!_FastBoot!"=="1" (set "s6=%Red%Enabled%Reset%") else (set "s6=%Green%Disabled%Reset%")

if "!_Tele!"=="1" (set "s7=%Red%Enabled%Reset%") else (set "s7=%Green%Disabled%Reset%")
if "!_Copilot!"=="1" (set "s8=%Red%Enabled%Reset%") else (set "s8=%Green%Disabled%Reset%")
if "!_UAC!"=="1" (set "s9=%Red%Enabled%Reset%") else (set "s9=%Green%Disabled%Reset%")

if "!_MenuDelay!"=="1" (set "s10=%Red%400 ms%Reset%") else (set "s10=%Green%20 ms%Reset%")
if "!_WallComp!"=="1" (set "s11=%Red%Enabled%Reset%") else (set "s11=%Green%Disabled%Reset%")
if "!_RecSec!"=="1" (set "s12=%Red%Show%Reset%") else (set "s12=%Green%Hidden%Reset%")
if "!_Mouse!"=="1" (set "s13=%Red%Enabled%Reset%") else (set "s13=%Green%Disabled%Reset%")
if "!_Sticky!"=="1" (set "s14=%Red%Enabled%Reset%") else (set "s14=%Green%Disabled%Reset%")

echo.
echo  %Bold%%Cyan%SYSTEM TWEAKER%Reset%
echo  %Gray%================================================%Reset%
echo.
echo  %Bold%%Yellow%--- PERFORMANCE ---%Reset%
echo  %Bold% [1]%Reset% Power Plan Mode          : !s1!
echo  %Bold% [2]%Reset% Background UWP Apps      : !s2!
echo  %Bold% [3]%Reset% Delivery Optimization    : !s3!
echo  %Bold% [4]%Reset% Edge Startup Boost       : !s4!
echo  %Bold% [5]%Reset% Hibernation              : !s5!
echo  %Bold% [6]%Reset% Fast Startup (SSD)       : !s6!
echo.
echo  %Bold%%Yellow%--- PRIVACY ^& SECURITY ---%Reset%
echo  %Bold% [7]%Reset% Telemetry ^& Ads          : !s7!
echo  %Bold% [8]%Reset% Windows Copilot AI       : !s8!
echo  %Bold% [9]%Reset% User Account Control     : !s9!
echo.
echo  %Bold%%Yellow%--- INTERFACE ^& UX ---%Reset%
echo  %Bold%[10]%Reset% Menu Show Delay          : !s10!
echo  %Bold%[11]%Reset% Wallpaper Compression    : !s11!
echo  %Bold%[12]%Reset% Recommended Section      : !s12!
echo  %Bold%[13]%Reset% Mouse Acceleration       : !s13!
echo  %Bold%[14]%Reset% Sticky Keys (Logoff)     : !s14!
echo.
echo  %Gray%================================================%Reset%
echo  %Bold%[T]%Reset% %Yellow%Clear Taskbar%Reset%          %Bold%[X]%Reset% %Yellow%System Cleanup%Reset%
echo  %Gray%------------------------------------------------%Reset%
echo  %Bold%[A]%Reset% %Green%APPLY ALL TWEAKS%Reset%       %Bold%[D]%Reset% %Red%RESTORE DEFAULTS%Reset%
echo.

set /p "c=Select: "

:: Navigation
if /i "%c%"=="A" goto ApplyAll
if /i "%c%"=="D" goto RestoreAll
if /i "%c%"=="T" goto Action_Taskbar
if /i "%c%"=="X" goto Action_Cleanup

:: Toggles
if "%c%"=="1" goto TogglePower
if "%c%"=="2" goto ToggleBackApps
if "%c%"=="3" goto ToggleDelOpt
if "%c%"=="4" goto ToggleEdge
if "%c%"=="5" goto ToggleHiber
if "%c%"=="6" goto ToggleFastBoot
if "%c%"=="7" goto ToggleTele
if "%c%"=="8" goto ToggleCopilot
if "%c%"=="9" goto ToggleUAC
if "%c%"=="10" goto ToggleMenuDelay
if "%c%"=="11" goto ToggleWall
if "%c%"=="12" goto ToggleRec
if "%c%"=="13" goto ToggleMouse
if "%c%"=="14" goto ToggleSticky

goto MenuLoop

:: ====================================================================================
:: LOGIC
:: ====================================================================================

:TogglePower
if "!_Power!"=="0" goto Power_High
if "!_Power!"=="1" goto Power_Ult
goto Power_Bal

:Power_High
powershell -NoProfile -Command "$schemes = powercfg /l | Where-Object { $_ -match '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c|High|\u0412\u044b\u0441\u043e\u043a\u0430\u044f' }; if (-not $schemes) { $new = powercfg -duplicatescheme 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c; $guid = $new -replace '.*([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}).*', '$1'; powercfg /setactive $guid } else { $keep = $schemes | Select-Object -First 1; $guid = $keep -replace '.*([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}).*', '$1'; powercfg /setactive $guid; $remove = $schemes | Select-Object -Skip 1; if ($remove) { foreach ($s in $remove) { $delGuid = $s -replace '.*([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}).*', '$1'; powercfg /delete $delGuid } } }" >nul 2>&1
goto MenuLoop

:Power_Ult
powershell -NoProfile -Command "$schemes = powercfg /l | Where-Object { $_ -match 'e9a42b02-d5df-448d-aa00-03f14749eb61|Ultimate|\u041c\u0430\u043a\u0441\u0438\u043c\u0430\u043b\u044c\u043d\u0430\u044f' }; if (-not $schemes) { $new = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61; $guid = $new -replace '.*([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}).*', '$1'; powercfg /setactive $guid } else { $keep = $schemes | Select-Object -First 1; $guid = $keep -replace '.*([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}).*', '$1'; powercfg /setactive $guid; $remove = $schemes | Select-Object -Skip 1; if ($remove) { foreach ($s in $remove) { $delGuid = $s -replace '.*([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}).*', '$1'; powercfg /delete $delGuid } } }" >nul 2>&1
goto MenuLoop

:Power_Bal
powershell -NoProfile -Command "$schemes = powercfg /l | Where-Object { $_ -match '381b4222-f694-41f0-9685-ff5bb260df2e|Balanced|\u0421\u0431\u0430\u043b\u0430\u043d\u0441\u0438\u0440\u043e\u0432\u0430\u043d\u043d\u0430\u044f' }; if (-not $schemes) { $new = powercfg -duplicatescheme 381b4222-f694-41f0-9685-ff5bb260df2e; $guid = $new -replace '.*([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}).*', '$1'; powercfg /setactive $guid } else { $keep = $schemes | Select-Object -First 1; $guid = $keep -replace '.*([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}).*', '$1'; powercfg /setactive $guid; $remove = $schemes | Select-Object -Skip 1; if ($remove) { foreach ($s in $remove) { $delGuid = $s -replace '.*([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}).*', '$1'; powercfg /delete $delGuid } } }" >nul 2>&1
goto MenuLoop

:ToggleBackApps
if "!_BackApps!"=="0" goto BackApps_Enable
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 1 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v BackgroundAppGlobalToggle /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\embeddedmode" /v Start /t REG_DWORD /d 4 /f >nul
goto MenuLoop
:BackApps_Enable
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v BackgroundAppGlobalToggle /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\embeddedmode" /v Start /t REG_DWORD /d 3 /f >nul
goto MenuLoop

:ToggleDelOpt
if "!_DelOpt!"=="0" goto DelOpt_Enable
cmd /c "reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /t REG_DWORD /d 0 /f" >nul 2>&1
cmd /c "sc config DoSvc start= disabled" >nul 2>&1
cmd /c "net stop DoSvc" >nul 2>&1
goto MenuLoop
:DelOpt_Enable
cmd /c "reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /f" >nul 2>&1
cmd /c "sc config DoSvc start= demand" >nul 2>&1
cmd /c "net start DoSvc" >nul 2>&1
goto MenuLoop

:ToggleEdge
if "!_Edge!"=="0" goto Edge_Enable
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v StartupBoostEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v BackgroundModeEnabled /t REG_DWORD /d 0 /f >nul 2>&1
goto MenuLoop
:Edge_Enable
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v StartupBoostEnabled /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v BackgroundModeEnabled /f >nul 2>&1
goto MenuLoop

:ToggleTele
if "!_Tele!"=="0" goto Tele_Enable
sc config DiagTrack start= disabled >nul 2>&1
sc stop DiagTrack >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" /v ScoobeSystemSettingEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\SQMClient\Windows" /v CEIPEnable /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338387Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338393Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353694Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353696Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-310093Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SilentInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat" /v AITEnable /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy" /v TailoredExperiencesWithDiagnosticDataEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Input\TIPC" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\TabletPC" /v PreventHandwritingDataSharing /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports" /v PreventHandwritingErrorReports /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Siuf\Rules" /v NumberOfSIUFInPeriod /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d "Deny" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreenCamera /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v Disabled /t REG_DWORD /d 1 /f >nul 2>&1
goto MenuLoop
:Tele_Enable
sc config DiagTrack start= auto >nul 2>&1
sc start DiagTrack >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" /v ScoobeSystemSettingEnabled /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\SQMClient\Windows" /v CEIPEnable /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338389Enabled /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338387Enabled /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338393Enabled /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353694Enabled /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353696Enabled /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-310093Enabled /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SilentInstalledAppsEnabled /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat" /v AITEnable /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy" /v TailoredExperiencesWithDiagnosticDataEnabled /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Input\TIPC" /v Enabled /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\TabletPC" /v PreventHandwritingDataSharing /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports" /v PreventHandwritingErrorReports /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Siuf\Rules" /v NumberOfSIUFInPeriod /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreenCamera /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v Disabled /f >nul 2>&1
goto MenuLoop

:ToggleCopilot
if "!_Copilot!"=="0" goto Copilot_Enable
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /t REG_DWORD /d 1 /f >nul 2>&1
goto MenuLoop
:Copilot_Enable
reg delete "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /f >nul 2>&1
goto MenuLoop

:ToggleUAC
if "!_UAC!"=="0" goto UAC_Enable
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v PromptOnSecureDesktop /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 1 /f >nul 2>&1
goto MenuLoop
:UAC_Enable
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v PromptOnSecureDesktop /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 5 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 1 /f >nul 2>&1
goto MenuLoop

:ToggleMouse
if "!_Mouse!"=="0" goto Mouse_Enable
reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f >nul
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f >nul
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f >nul
powershell -NoProfile -Command "$code='using System.Runtime.InteropServices; public class W32 { [DllImport(\"user32.dll\")] public static extern bool SystemParametersInfo(uint a, uint b, int[] c, uint d); }'; Add-Type -TypeDefinition $code; $p=[int[]]@(0,0,0); [W32]::SystemParametersInfo(4,0,$p,3)" >nul 2>&1
goto MenuLoop
:Mouse_Enable
reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 1 /f >nul
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 6 /f >nul
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 10 /f >nul
powershell -NoProfile -Command "$code='using System.Runtime.InteropServices; public class W32 { [DllImport(\"user32.dll\")] public static extern bool SystemParametersInfo(uint a, uint b, int[] c, uint d); }'; Add-Type -TypeDefinition $code; $p=[int[]]@(6,10,1); [W32]::SystemParametersInfo(4,0,$p,3)" >nul 2>&1
goto MenuLoop

:ToggleSticky
if "!_Sticky!"=="0" goto Sticky_Enable
reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 506 /f >nul 2>&1
reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v Flags /t REG_SZ /d 122 /f >nul 2>&1
reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v Flags /t REG_SZ /d 58 /f >nul 2>&1
goto MenuLoop
:Sticky_Enable
reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 510 /f >nul 2>&1
reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v Flags /t REG_SZ /d 126 /f >nul 2>&1
reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v Flags /t REG_SZ /d 62 /f >nul 2>&1
goto MenuLoop

:ToggleMenuDelay
if "!_MenuDelay!"=="0" goto MenuDelay_Enable
reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 20 /f >nul 2>&1
goto RestartExplorer
:MenuDelay_Enable
reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 400 /f >nul 2>&1
goto RestartExplorer

:ToggleWall
if "!_WallComp!"=="0" goto Wall_Enable
reg add "HKCU\Control Panel\Desktop" /v JPEGImportQuality /t REG_DWORD /d 100 /f >nul 2>&1
goto RestartExplorer
:Wall_Enable
reg delete "HKCU\Control Panel\Desktop" /v JPEGImportQuality /f >nul 2>&1
goto RestartExplorer

:ToggleRec
if "!_RecSec!"=="0" goto Rec_Enable
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v HideRecommendedSection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Start" /v HideRecommendedSection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Education" /v IsEducationEnvironment /t REG_DWORD /d 1 /f >nul 2>&1
goto RestartExplorer
:Rec_Enable
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v HideRecommendedSection /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Start" /v HideRecommendedSection /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Education" /v IsEducationEnvironment /f >nul 2>&1
goto RestartExplorer

:ToggleHiber
if "!_Hiber!"=="0" goto Hiber_Enable
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f >nul 2>&1
powercfg /h off >nul 2>&1
goto MenuLoop
:Hiber_Enable
powercfg /h on >nul 2>&1
goto MenuLoop

:ToggleFastBoot
if "!_FastBoot!"=="0" goto FastBoot_Enable
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f >nul 2>&1
goto MenuLoop
:FastBoot_Enable
powercfg /h on >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 1 /f >nul 2>&1
goto MenuLoop

:Action_Taskbar
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" /v Favorites /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband" /v FavoritesResolve /f >nul 2>&1
goto RestartExplorer

:Action_Cleanup
cls
echo.
echo  %Bold%%Yellow%  System Cleanup...%Reset%
echo  %Gray%  ----------------------------------------------%Reset%
call :CleanStep "%temp%" "User Temp Files"
call :CleanStep "%windir%\Temp" "Windows Temp Files"
call :CleanStep "%windir%\Prefetch" "Windows Prefetch"

echo.
echo  %Bold%  Windows Update Cache:%Reset%
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
call :CalcAndClean "%windir%\SoftwareDistribution\Download"
net start wuauserv >nul 2>&1
net start bits >nul 2>&1

call :CleanStep "%localappdata%\D3DSCache" "DirectX Shader Cache"

echo.
echo  %Bold%  Recycle Bin:%Reset%
powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >nul 2>&1
echo  Cleared.

echo.
echo  %Bold%  Event Logs:%Reset%
for /F "tokens=*" %%1 in ('wevtutil.exe el') do (
    wevtutil.exe cl "%%1" >nul 2>&1
)
echo  Cleared.

echo.
echo  %Green%  Cleanup Complete!%Reset%
timeout /t 3 >nul
goto MenuLoop

:CleanStep
echo.
echo  %Bold%  %~2:%Reset%
if exist "%~1" (
    call :CalcAndClean "%~1"
) else (
    echo  Not found/Already clean.
)
exit /b

:CalcAndClean
if not exist "%~1" exit /b
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "try { $x = Get-ChildItem -Path '%~1' -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum; '{0} files ({1:N2} MB)' -f $x.Count, ($x.Sum / 1MB) } catch { '0 files (0.00 MB)' }"`) do set "info=%%a"
del /f /s /q "%~1\*" >nul 2>&1
for /d %%x in ("%~1\*") do rd /s /q "%%x" >nul 2>&1
echo  Deleted: !info!
exit /b

:RestartExplorer
taskkill /f /im explorer.exe >nul 2>&1
start explorer.exe
timeout /t 1 >nul
goto MenuLoop

:ApplyAll
powershell -NoProfile -Command "$schemes = powercfg /l | Where-Object { $_ -match 'e9a42b02-d5df-448d-aa00-03f14749eb61|Ultimate|\u041c\u0430\u043a\u0441\u0438\u043c\u0430\u043b\u044c\u043d\u0430\u044f' }; if (-not $schemes) { $new = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61; $guid = $new -replace '.*([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}).*', '$1'; powercfg /setactive $guid } else { $keep = $schemes | Select-Object -First 1; $guid = $keep -replace '.*([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}).*', '$1'; powercfg /setactive $guid; $remove = $schemes | Select-Object -Skip 1; if ($remove) { foreach ($s in $remove) { $delGuid = $s -replace '.*([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}).*', '$1'; powercfg /delete $delGuid } } }" >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 1 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v BackgroundAppGlobalToggle /t REG_DWORD /d 0 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\embeddedmode" /v Start /t REG_DWORD /d 4 /f >nul
cmd /c "reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /t REG_DWORD /d 0 /f" >nul 2>&1
cmd /c "sc config DoSvc start= disabled" >nul 2>&1
cmd /c "net stop DoSvc" >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v StartupBoostEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v BackgroundModeEnabled /t REG_DWORD /d 0 /f >nul 2>&1
sc config DiagTrack start= disabled >nul 2>&1
sc stop DiagTrack >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" /v ScoobeSystemSettingEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\SQMClient\Windows" /v CEIPEnable /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338387Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338393Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353694Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353696Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-310093Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SilentInstalledAppsEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat" /v AITEnable /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy" /v TailoredExperiencesWithDiagnosticDataEnabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Input\TIPC" /v Enabled /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\TabletPC" /v PreventHandwritingDataSharing /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports" /v PreventHandwritingErrorReports /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Siuf\Rules" /v NumberOfSIUFInPeriod /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /t REG_SZ /d "Deny" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreenCamera /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v Disabled /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v PromptOnSecureDesktop /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f >nul
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f >nul
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f >nul
powershell -NoProfile -Command "$code='using System.Runtime.InteropServices; public class W32 { [DllImport(\"user32.dll\")] public static extern bool SystemParametersInfo(uint a, uint b, int[] c, uint d); }'; Add-Type -TypeDefinition $code; $p=[int[]]@(0,0,0); [W32]::SystemParametersInfo(4,0,$p,3)" >nul 2>&1
reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 506 /f >nul 2>&1
reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v Flags /t REG_SZ /d 122 /f >nul 2>&1
reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v Flags /t REG_SZ /d 58 /f >nul 2>&1
reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 20 /f >nul 2>&1
reg add "HKCU\Control Panel\Desktop" /v JPEGImportQuality /t REG_DWORD /d 100 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v HideRecommendedSection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Start" /v HideRecommendedSection /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Education" /v IsEducationEnvironment /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f >nul 2>&1
powercfg /h off >nul 2>&1
goto RestartExplorer

:RestoreAll
powershell -NoProfile -Command "$schemes = powercfg /l | Where-Object { $_ -match '381b4222-f694-41f0-9685-ff5bb260df2e|Balanced|\u0421\u0431\u0430\u043b\u0430\u043d\u0441\u0438\u0440\u043e\u0432\u0430\u043d\u043d\u0430\u044f' }; if (-not $schemes) { $new = powercfg -duplicatescheme 381b4222-f694-41f0-9685-ff5bb260df2e; $guid = $new -replace '.*([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}).*', '$1'; powercfg /setactive $guid } else { $keep = $schemes | Select-Object -First 1; $guid = $keep -replace '.*([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}).*', '$1'; powercfg /setactive $guid }" >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v BackgroundAppGlobalToggle /t REG_DWORD /d 1 /f >nul
reg add "HKLM\SYSTEM\CurrentControlSet\Services\embeddedmode" /v Start /t REG_DWORD /d 3 /f >nul
cmd /c "reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode /f" >nul 2>&1
cmd /c "sc config DoSvc start= demand" >nul 2>&1
cmd /c "net start DoSvc" >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v StartupBoostEnabled /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v BackgroundModeEnabled /f >nul 2>&1
sc config DiagTrack start= auto >nul 2>&1
sc start DiagTrack >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement" /v ScoobeSystemSettingEnabled /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\SQMClient\Windows" /v CEIPEnable /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338389Enabled /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338387Enabled /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338393Enabled /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353694Enabled /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-353696Enabled /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-310093Enabled /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SilentInstalledAppsEnabled /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat" /v AITEnable /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy" /v TailoredExperiencesWithDiagnosticDataEnabled /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Input\TIPC" /v Enabled /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\TabletPC" /v PreventHandwritingDataSharing /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports" /v PreventHandwritingErrorReports /f >nul 2>&1
reg delete "HKCU\Software\Microsoft\Siuf\Rules" /v NumberOfSIUFInPeriod /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" /v Value /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization" /v NoLockScreenCamera /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v Disabled /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /f >nul 2>&1
reg delete "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v DisableAIDataAnalysis /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v PromptOnSecureDesktop /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 5 /f >nul 2>&1
reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 1 /f >nul
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 6 /f >nul
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 10 /f >nul
powershell -NoProfile -Command "$code='using System.Runtime.InteropServices; public class W32 { [DllImport(\"user32.dll\")] public static extern bool SystemParametersInfo(uint a, uint b, int[] c, uint d); }'; Add-Type -TypeDefinition $code; $p=[int[]]@(6,10,1); [W32]::SystemParametersInfo(4,0,$p,3)" >nul 2>&1
reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 510 /f >nul 2>&1
reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v Flags /t REG_SZ /d 126 /f >nul 2>&1
reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v Flags /t REG_SZ /d 62 /f >nul 2>&1
reg add "HKCU\Control Panel\Desktop" /v MenuShowDelay /t REG_SZ /d 400 /f >nul 2>&1
reg delete "HKCU\Control Panel\Desktop" /v JPEGImportQuality /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\Explorer" /v HideRecommendedSection /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Start" /v HideRecommendedSection /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Education" /v IsEducationEnvironment /f >nul 2>&1
powercfg /h on >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 1 /f >nul 2>&1
goto RestartExplorer

:CheckStatus
set "_Power=0"
for /f "usebackq tokens=*" %%a in (`powershell -NoProfile -Command "$a = powercfg /getactivescheme; if ($a -match '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c|High|\u0412\u044b\u0441\u043e\u043a\u0430\u044f') { Write-Output '1' } elseif ($a -match 'e9a42b02-d5df-448d-aa00-03f14749eb61|Ultimate|\u041c\u0430\u043a\u0441\u0438\u043c\u0430\u043b\u044c\u043d\u0430\u044f') { Write-Output '2' } else { Write-Output '0' }"`) do set "_Power=%%a"

set "_BackApps=1"
for /f "tokens=3" %%b in ('reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled 2^>nul') do (if "%%b"=="0x1" set "_BackApps=0")
set "_DelOpt=1"
for /f "tokens=3" %%c in ('reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" /v DODownloadMode 2^>nul') do (if "%%c"=="0x0" set "_DelOpt=0")
set "_Edge=1"
for /f "tokens=3" %%d in ('reg query "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v StartupBoostEnabled 2^>nul') do (if "%%d"=="0x0" set "_Edge=0")
set "_Tele=1"
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry 2>nul | find "0x0" >nul
if %errorlevel% EQU 0 set "_Tele=0"
set "_Copilot=1"
for /f "tokens=3" %%i in ('reg query "HKCU\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot 2^>nul') do (if "%%i"=="0x1" set "_Copilot=0")
set "_UAC=1"
for /f "tokens=3" %%e in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ConsentPromptBehaviorAdmin 2^>nul') do (if "%%e"=="0x0" set "_UAC=0")
set "_Mouse=0"
for /f "tokens=3" %%a in ('reg query "HKCU\Control Panel\Mouse" /v MouseSpeed 2^>nul') do (if "%%a"=="1" set "_Mouse=1")
set "_Sticky=1"
reg query "HKCU\Control Panel\Accessibility\StickyKeys" /v Flags 2>nul | find "506" >nul
if %errorlevel% EQU 0 set "_Sticky=0"
set "_MenuDelay=1"
for /f "tokens=3" %%h in ('reg query "HKCU\Control Panel\Desktop" /v MenuShowDelay 2^>nul') do (if "%%h"=="20" set "_MenuDelay=0")
set "_WallComp=1"
for /f "tokens=3" %%g in ('reg query "HKCU\Control Panel\Desktop" /v JPEGImportQuality 2^>nul') do (if "%%g"=="0x64" set "_WallComp=0")
set "_RecSec=1"
reg query "HKLM\SOFTWARE\Microsoft\PolicyManager\current\device\Education" /v IsEducationEnvironment 2>nul | find "0x1" >nul
if %errorlevel% EQU 0 set "_RecSec=0"

set "_Hiber=0"
for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Power" /v HibernateEnabled 2^>nul') do (if "%%a"=="0x1" set "_Hiber=1")
set "_FastBoot=0"
for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled 2^>nul') do (if "%%a"=="0x1" set "_FastBoot=1")
exit /b