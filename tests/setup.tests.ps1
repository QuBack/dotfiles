param([string]$SetupPath = (Join-Path $PSScriptRoot '..\setup.ps1'))
$ErrorActionPreference = 'Stop'
. $SetupPath
$originalDownload = (Get-Command Download-App).ScriptBlock
$originalInstall = (Get-Command Install-App).ScriptBlock
$originalRuntimeReady = (Get-Command Test-NpmRuntimeReady).ScriptBlock
$originalHardware = (Get-Command Get-NvidiaHardware).ScriptBlock
$originalTestInstalled = (Get-Command Test-AppInstalled).ScriptBlock
$originalUpdatePath = (Get-Command Update-SessionPath).ScriptBlock
$originalLocalAppData = $env:LOCALAPPDATA
$script:passed = 0
function Assert($Condition, $Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:passed++
    Write-Host "PASS: $Message"
}
$testRoot = Join-Path $PSScriptRoot ('tmp-' + [guid]::NewGuid().ToString('N'))
try {
    $script:DataRoot = $testRoot
    $script:installed = @{}
    function Get-NvidiaHardware { return [pscustomobject]@{Detected=$false; Names=@(); Versions=@()} }
    function Test-AppInstalled($App) { return $script:installed.ContainsKey($App.Key) }

    # Menu input returns an explicit action without running installers.
    $selected = @{}
    $inputResult = Get-MenuKeyResult 'Enter' 1 $selected
    Assert ($inputResult.Action -eq 'None' -and $inputResult.Keys.Count -eq 0 -and $inputResult.Notice) 'empty selection cannot start an installation'
    $inputResult = Get-MenuKeyResult 'Enter' 2 $selected
    Assert ($selected.ContainsKey('git') -and $inputResult.Action -eq 'None') 'Enter on a program selects it without installing'
    Get-MenuKeyResult 'Spacebar' 2 $selected | Out-Null
    Assert ($selected.Count -eq 0) 'Space toggles a selected program off'
    $claudeRow = 2 + [array]::IndexOf(@($script:Catalog.Key), 'claude')
    Get-MenuKeyResult 'Spacebar' $claudeRow $selected | Out-Null
    Get-MenuKeyResult 'Enter' 2 $selected | Out-Null
    $inputResult = Get-MenuKeyResult 'Enter' 1 $selected
    Assert ($inputResult.Action -eq 'Install' -and ($inputResult.Keys -join ',') -eq 'git,claude') 'selected action includes only checked programs in catalog order'
    $inputResult = Get-MenuKeyResult 'Enter' 0 @{}
    Assert ($inputResult.Action -eq 'Install' -and ($inputResult.Keys -join ',') -eq ($script:Catalog.Key -join ',')) 'install all ignores checkbox selection'
    $inputResult = Get-MenuKeyResult 'Spacebar' 0 $selected
    Assert ($inputResult.Action -eq 'None' -and $selected.Count -eq 2) 'Space on an action cannot trigger installation'
    $exitRow = $script:Catalog.Count + 2
    Assert ((Get-MenuKeyResult 'UpArrow' 0 $selected).Cursor -eq $exitRow) 'Up wraps from first action to Exit'
    Assert ((Get-MenuKeyResult 'DownArrow' $exitRow $selected).Cursor -eq 0) 'Down wraps from Exit to first action'
    Assert ((Get-MenuKeyResult 'DownArrow' 1 $selected).Cursor -eq 2) 'navigation moves from actions to programs'
    Assert ((Get-MenuKeyResult 'Enter' $exitRow $selected).Action -eq 'Exit') 'Exit row exits on Enter'
    Assert ((Get-MenuKeyResult 'Escape' $claudeRow $selected).Action -eq 'Exit') 'Escape exits from the program list'
    $unsafeInputs = @('D','I','A','P','R','O','S','Q','LeftArrow','RightArrow')
    $unexpectedActions = @($unsafeInputs | ForEach-Object { Get-MenuKeyResult $_ 0 $selected } | Where-Object Action -ne 'None')
    Assert ($unexpectedActions.Count -eq 0 -and $selected.Count -eq 2) 'removed shortcuts cannot trigger actions or change selection'

    $plan = @(Get-InstallPlan @('codex'))
    Assert (($plan.Key -join ',') -eq 'node,codex') 'dependency precedes Codex'
    $plan = @(Get-InstallPlan @('claude'))
    Assert (($plan.Key -join ',') -eq 'node,claude') 'dependency precedes Claude'
    $plan = @(Get-InstallPlan @('codex','claude'))
    Assert (($plan.Key -join ',') -eq 'node,codex,claude') 'both CLIs share one Node dependency'
    $plan = @(Get-InstallPlan @('codex-desktop','claude-desktop','steam','chrome'))
    Assert (($plan.Key -join ',') -eq 'codex-desktop,claude-desktop,steam,chrome') 'desktop apps, Steam and Chrome need no npm runtime'
    $selectedVariants = @{}
    foreach ($key in @('codex-desktop','claude-desktop')) {
        $row = 2 + [array]::IndexOf(@($script:Catalog.Key), $key)
        Get-MenuKeyResult 'Enter' $row $selectedVariants | Out-Null
    }
    $inputResult = Get-MenuKeyResult 'Enter' 1 $selectedVariants
    Assert (($inputResult.Keys -join ',') -eq 'codex-desktop,claude-desktop') 'desktop variants can be checked without selecting CLI'
    foreach ($key in @('codex','claude')) {
        $row = 2 + [array]::IndexOf(@($script:Catalog.Key), $key)
        Get-MenuKeyResult 'Spacebar' $row $selectedVariants | Out-Null
    }
    $inputResult = Get-MenuKeyResult 'Enter' 1 $selectedVariants
    Assert ($inputResult.Keys.Count -eq 4 -and @($inputResult.Keys | Where-Object { $_ -in @('codex','codex-desktop','claude','claude-desktop') }).Count -eq 4) 'desktop and CLI variants can be selected together'
    $plan = @(Get-InstallPlan @('codex','node','git'))
    Assert (($plan.Key -join ',') -eq 'node,codex,git') 'dependencies are deduplicated'
    $script:installed['codex'] = $true
    Assert (@(Get-InstallPlan @('codex')).Count -eq 1) 'installed Codex needs no new dependency'
    $script:installed.Clear()
    $thrown = $false
    try { Get-App 'nonexistent' | Out-Null } catch { $thrown = $true }
    Assert $thrown 'unknown app rejected'

    function Install-App($App) { throw 'must not execute during DryRun' }
    function Download-App($App) { throw 'must not execute during DryRun' }
    $result = @(Invoke-SetupAction @('codex') 'Install' -Preview)
    Assert ($result.Count -eq 2 -and @($result | Where-Object Status -ne 'Plan').Count -eq 0) 'DryRun returns plan'
    Assert (-not (Test-Path -LiteralPath $testRoot)) 'DryRun creates no directories'

    $script:calls = @()
    function Install-App($App) {
        $script:calls += $App.Key
        if ($App.Key -eq 'node') { throw 'simulated dependency error' }
    }
    $result = @(Invoke-SetupAction @('codex','git') 'Install')
    Assert (($script:calls -join ',') -eq 'node,git') 'dependent install blocked; independent install continues'
    Assert (($result.Status -join ',') -eq 'Error,Blocked,OK') 'failures remain in report'
    $script:calls = @()
    $result = @(Invoke-SetupAction @('codex','claude','codex-desktop','claude-desktop','steam') 'Install')
    Assert (($script:calls -join ',') -eq 'node,codex-desktop,claude-desktop,steam' -and ($result.Status -join ',') -eq 'Error,Blocked,Blocked,OK,OK,OK') 'npm dependency failure does not block desktop apps or Steam'
    $script:installed['git'] = $true
    $script:calls = @()
    $result = @(Invoke-SetupAction @('git') 'Install')
    Assert ($result[0].Status -eq 'Skipped' -and $script:calls.Count -eq 0) 'installed app skipped'

    New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
    $payloadDir = Join-Path $testRoot 'downloads\payload'
    New-Item -ItemType Directory -Path $payloadDir -Force | Out-Null
    $payload = Join-Path $payloadDir 'installer.exe'
    [IO.File]::WriteAllText($payload, 'test payload')
    Save-DownloadReceipt (Get-App 'git') $payloadDir @($payload)
    Assert ($null -ne (Get-CachedDownload (Get-App 'git'))) 'receipt survives reload'
    function Ensure-WinGet { throw 'must not execute when download is cached' }
    & $originalDownload (Get-App 'git')
    Assert ($null -ne (Get-CachedDownload (Get-App 'git'))) 'repeat download reuses valid cache without network'
    [IO.File]::WriteAllText($payload, 'modified payload')
    Assert ($null -eq (Get-CachedDownload (Get-App 'git'))) 'modified payload invalidates cache'
    Save-DownloadReceipt (Get-App 'git') $payloadDir @($payload)
    Remove-Item -LiteralPath $payload
    Assert ($null -eq (Get-CachedDownload (Get-App 'git'))) 'deleted payload invalidates cache'
    function Download-App($App) { throw 'simulated network failure' }
    $result = @(Invoke-SetupAction @('obsidian') 'Download')
    Assert ($result[0].Status -eq 'Error') 'download failure reported'
    Assert ($null -eq (Get-CachedDownload (Get-App 'obsidian'))) 'failed download not marked cached'
    $script:downloadCalls = @()
    function Download-App($App) { $script:downloadCalls += $App.Key }
    $result = @(Invoke-SetupAction @('codex-desktop','steam') 'Download')
    Assert ($result[0].Status -eq 'Manual' -and $result[0].Message -match 'Microsoft Store' -and $result[1].Status -eq 'OK' -and ($script:downloadCalls -join ',') -eq 'steam') 'Store download explains manual step while other downloads continue'
    Assert ($null -eq (Get-CachedDownload (Get-App 'codex-desktop'))) 'Store manual download creates no cached receipt'
    $script:downloadCalls = @()
    $result = @(Invoke-SetupAction @('codex-desktop') 'Download' -Preview)
    Assert ($result[0].Status -eq 'Plan' -and $result[0].Message -match 'Microsoft Store' -and $script:downloadCalls.Count -eq 0) 'Store download preview reports limitation without downloading'
    $script:Apps = @('codex-desktop')
    $script:Download = $true
    Assert ((Invoke-SetupMain) -eq 2) 'Store download returns action-required exit code'
    function Download-App($App) { throw 'simulated network failure' }
    $thrown = $false
    try { & $originalDownload (Get-App 'codex-desktop') } catch { $thrown = $_.Exception.Message -match 'Microsoft Store' }
    Assert $thrown 'direct Store download rejects unsupported operation before WinGet or network'

    $receipt = Get-ReceiptPath (Get-App 'git')
    [IO.File]::WriteAllText($receipt, '{bad json')
    Assert ($null -eq (Get-CachedDownload (Get-App 'git'))) 'corrupt receipt handled'
    $thrown = $false
    try { Invoke-InstallerCommand 'cmd.exe' @('/c','exit','19') } catch { $thrown = $true }
    Assert $thrown 'nonzero native installer exit throws'
    $script:installed.Clear()
    $plan = @(Get-InstallPlan @($script:Catalog.Key))
    Assert ($plan.Count -eq $script:Catalog.Count) 'all includes every app exactly once'
    $script:All = $true
    $script:Apps = @('git')
    $thrown = $false
    try { Invoke-SetupMain | Out-Null } catch { $thrown = $true }
    Assert $thrown 'incompatible All and Apps rejected'
    $script:All = $false
    $script:Apps = @('obsidian')
    $script:Download = $true
    Assert ((Invoke-SetupMain) -eq 1) 'automatic mode returns failure exit code'

    # Test the real npm installation branch with an executable boundary mock.
    $script:LogFile = $null
    function Update-SessionPath { }
    function Test-NpmRuntimeReady { return $true }
    function Find-SetupCommand($Name) { return [pscustomobject]@{Source=$Name} }
    $script:nativeCalls = @()
    function Invoke-InstallerCommand($FilePath, $ArgumentList) {
        $script:nativeCalls += [pscustomobject]@{File=$FilePath; Arguments=@($ArgumentList)}
    }
    foreach ($key in @('codex','claude')) {
        $script:nativeCalls = @()
        $app = Get-App $key
        & $originalInstall $app
        Assert ($script:nativeCalls[0].File -eq 'npm.cmd' -and $script:nativeCalls[0].Arguments[2] -eq ($app.Id + '@latest')) "$key uses its own npm package"
        Assert ($script:nativeCalls[0].Arguments -contains '--include=optional') "$key installs platform dependency"
        Assert ($script:nativeCalls[1].File -eq ($key + '.cmd') -and $script:nativeCalls[1].Arguments[0] -eq '--version') "$key command verified"
    }
    $legacyPayload = Join-Path $payloadDir 'claude.exe'
    [IO.File]::WriteAllText($legacyPayload, 'legacy winget installer')
    $legacyApp = [pscustomobject]@{Key='claude'; Id='Anthropic.ClaudeCode'; Kind='winget'}
    Save-DownloadReceipt $legacyApp $payloadDir @($legacyPayload)
    Assert ($null -eq (Get-CachedDownload (Get-App 'claude'))) 'legacy Claude executable not reused as npm package'
    $archive = Join-Path $payloadDir 'claude.tgz'
    [IO.File]::WriteAllText($archive, 'mock npm archive')
    Save-DownloadReceipt (Get-App 'claude') $payloadDir @($archive)
    $script:nativeCalls = @()
    & $originalInstall (Get-App 'claude')
    Assert ($script:nativeCalls[0].Arguments[2] -eq $archive) 'Claude install reuses downloaded npm archive'
    $script:nodeMajor = 20
    function Get-NodeMajor { return $script:nodeMajor }
    Assert (-not (& $originalRuntimeReady)) 'old Node requires preparation'
    $script:nodeMajor = 22
    Assert (& $originalRuntimeReady) 'Node 22 with npm accepted'
    function Find-SetupCommand($Name) { return $null }
    Assert (-not (& $originalRuntimeReady)) 'Node without npm requires preparation'

    # Driver handoff must not masquerade as an installed driver or open in DryRun.
    $script:browserCalls = 0
    function Open-NvidiaDriverPage { $script:browserCalls++ }
    $result = @(Invoke-SetupAction @('nvidia') 'Install')
    Assert ($result[0].Status -eq 'Skipped' -and $script:browserCalls -eq 0) 'NVIDIA skipped when absent'
    function Get-NvidiaHardware { return [pscustomobject]@{Detected=$true; Names=@('NVIDIA GeForce GTX 1660 Ti'); Versions=@('32.0.16.1692')} }
    $result = @(Invoke-SetupAction @('nvidia') 'Install' -Preview)
    Assert ($result[0].Status -eq 'Plan' -and $script:browserCalls -eq 0) 'NVIDIA preview does not open browser'
    $result = @(Invoke-SetupAction @('nvidia') 'Download')
    Assert ($result[0].Status -eq 'Manual' -and $script:browserCalls -eq 1) 'NVIDIA download hands off to official site'
    function Get-NvidiaHardware { return [pscustomobject]@{Detected=$null; Names=@(); Versions=@()} }
    $result = @(Invoke-SetupAction @('nvidia') 'Install')
    Assert ($result[0].Status -eq 'Manual') 'unknown GPU still allows manual selection'
    $script:Apps = @('nvidia')
    $script:Download = $false
    Assert ((Invoke-SetupMain) -eq 2) 'driver handoff returns action-required exit code'
    $script:NvidiaHardware = $null
    function Get-CimInstance { throw 'simulated hardware access denied' }
    Assert ($null -eq (& $originalHardware).Detected) 'hardware detection failure is unknown rather than absent'
    $script:NvidiaHardware = $null
    function Get-CimInstance { return [pscustomobject]@{Name='Microsoft Basic Display Adapter'; PNPDeviceID='PCI\VEN_10DE&DEV_2182'; DriverVersion='0'} }
    Assert ((& $originalHardware).Detected -eq $true) 'NVIDIA detected by PCI vendor without its driver'
    function Ensure-WinGet { }
    $script:nativeCalls = @()
    & $originalInstall (Get-App 'vlc')
    Assert ($script:nativeCalls[0].Arguments[0] -eq 'install' -and $script:nativeCalls[0].Arguments[2] -eq 'VideoLAN.VLC') 'VLC installed through official winget package'

    Assert ((Get-App 'terminal').Id -eq 'Microsoft.WindowsTerminal') 'Terminal uses stable official package'
    Assert ((Get-App 'powershell-preview').Id -eq 'Microsoft.PowerShell.Preview') 'PowerShell uses official Preview channel'
    foreach ($key in @('terminal','powershell-preview')) {
        $script:nativeCalls = @()
        & $originalInstall (Get-App $key)
        $call = $script:nativeCalls[0]
        Assert ($call.File -eq 'winget.exe' -and $call.Arguments[0] -eq 'install' -and $call.Arguments[2] -eq (Get-App $key).Id -and $call.Arguments -contains '--exact' -and $call.Arguments -contains '--no-upgrade' -and $call.Arguments -notcontains '--version') "$key installation uses exact package without pinning a version"
    }

    # Test actual detection: pwsh alone must not mark Preview as installed.
    $script:mockRegistryNames = @('PowerShell 7.6.0.0-x64')
    function Get-InstalledAppNames { return $script:mockRegistryNames }
    function Find-SetupCommand($Name) { return [pscustomobject]@{Source=$Name} }
    $script:appxCalls = 0
    $script:appxError = $false
    $script:mockAppxNames = @('Microsoft.WindowsTerminal','Microsoft.PowerShell')
    function Get-AppxPackage {
        $script:appxCalls++
        if ($script:appxError) { throw 'simulated Appx unavailable' }
        foreach ($name in $script:mockAppxNames) { [pscustomobject]@{Name=$name} }
    }
    $script:InstalledAppxNames = $null
    Assert (& $originalTestInstalled (Get-App 'terminal')) 'Store Terminal detected by exact MSIX identity'
    Assert (-not (& $originalTestInstalled (Get-App 'powershell-preview'))) 'stable PowerShell and pwsh command do not satisfy Preview'
    Assert ($script:appxCalls -eq 1) 'MSIX inventory reused between app status checks'
    $script:mockRegistryNames = @()
    $script:mockAppxNames = @('Microsoft.WindowsTerminalPreview','Microsoft.PowerShellPreview')
    $script:InstalledAppxNames = $null
    Assert (-not (& $originalTestInstalled (Get-App 'terminal'))) 'Terminal Preview does not satisfy stable Terminal'
    Assert (& $originalTestInstalled (Get-App 'powershell-preview')) 'PowerShell Preview detected by exact MSIX identity'
    $script:appxError = $true
    $script:InstalledAppxNames = $null
    $script:mockRegistryNames = @('PowerShell 7.7.0-preview.3-x64')
    Assert (& $originalTestInstalled (Get-App 'powershell-preview')) 'Preview MSI detected when Appx inventory unavailable'
    $script:mockRegistryNames = @('PowerShell 7-preview-x64')
    Assert (& $originalTestInstalled (Get-App 'powershell-preview')) 'Preview MSI display name without version detected'
    & $originalUpdatePath
    Assert ($null -eq $script:InstalledAppxNames) 'PATH refresh invalidates MSIX status cache after installation'
    $script:Apps = @('terminal,powershell-preview')
    $script:DryRun = $true
    $script:nativeCalls = @()
    Assert ((Invoke-SetupMain) -eq 0 -and $script:nativeCalls.Count -eq 0) 'File launcher accepts comma-separated app selection without running installers in DryRun'

    $script:nativeCalls = @()
    & $originalInstall (Get-App 'chrome')
    Assert ($script:nativeCalls[0].Arguments[2] -eq 'Google.Chrome') 'Chrome uses official stable winget package'
    $script:mockRegistryNames = @('Google Chrome Beta')
    function Find-SetupCommand($Name) { return $null }
    Assert (-not (& $originalTestInstalled (Get-App 'chrome'))) 'Chrome Beta does not satisfy stable Chrome'
    $script:mockRegistryNames = @('Google Chrome')
    Assert (& $originalTestInstalled (Get-App 'chrome')) 'Chrome detected through Windows installed applications'

    # Desktop and CLI identities must stay independent.
    function Find-SetupCommand($Name) { return $null }
    $script:appxError = $false
    $script:mockRegistryNames = @()
    $script:mockAppxNames = @('OpenAI.Codex','Claude')
    $script:InstalledAppxNames = $null
    Assert ((& $originalTestInstalled (Get-App 'codex-desktop')) -and (& $originalTestInstalled (Get-App 'claude-desktop'))) 'desktop apps detected by exact MSIX identities'
    Assert (-not (& $originalTestInstalled (Get-App 'codex')) -and -not (& $originalTestInstalled (Get-App 'claude'))) 'desktop packages do not mark CLI installed'
    $script:mockAppxNames = @()
    $script:InstalledAppxNames = $null
    function Find-SetupCommand($Name) { return [pscustomobject]@{Source=$Name} }
    Assert ((& $originalTestInstalled (Get-App 'codex')) -and (& $originalTestInstalled (Get-App 'claude'))) 'CLI detected through its own commands'
    Assert (-not (& $originalTestInstalled (Get-App 'codex-desktop')) -and -not (& $originalTestInstalled (Get-App 'claude-desktop'))) 'CLI commands do not mark desktop apps installed'
    function Find-SetupCommand($Name) { return $null }
    $script:mockRegistryNames = @('Claude Code','SteamVR','Steam Game')
    Assert (-not (& $originalTestInstalled (Get-App 'claude-desktop')) -and -not (& $originalTestInstalled (Get-App 'steam'))) 'CLI registry name and Steam-related apps do not satisfy desktop packages'
    $script:mockRegistryNames = @('Claude','Steam')
    Assert ((& $originalTestInstalled (Get-App 'claude-desktop')) -and (& $originalTestInstalled (Get-App 'steam'))) 'legacy Claude desktop and Steam detected through registry'
    foreach ($entry in @(
        @{Key='codex-desktop'; Id='9PLM9XGG6VKS'; Source='msstore'},
        @{Key='claude-desktop'; Id='Anthropic.Claude'; Source='winget'},
        @{Key='steam'; Id='Valve.Steam'; Source='winget'}
    )) {
        $script:nativeCalls = @()
        & $originalInstall (Get-App $entry.Key)
        $call = $script:nativeCalls[0]
        $sourceIndex = [array]::IndexOf($call.Arguments, '--source')
        Assert ($script:nativeCalls.Count -eq 1 -and $call.File -eq 'winget.exe' -and $call.Arguments[0] -eq 'install' -and $call.Arguments[2] -eq $entry.Id -and $sourceIndex -ge 0 -and $call.Arguments[$sourceIndex + 1] -eq $entry.Source -and $call.Arguments -contains '--exact' -and $call.Arguments -contains '--no-upgrade') "$($entry.Key) installs exact package from correct source without npm"
    }

    # JSONC edits preserve all text outside the requested root startup fields.
    $jsonc = @'
{
    // Keep this comment and the URL below.
    "defaultProfile": "old",
    "profiles": {"list": [{"name": "User", "guid": "custom", "defaultProfile": "nested"}]},
    "theme": "light",
    "url": "https://example.com/a//b/*c*/",
    "startupActions": "new-tab -p cmd",
    "firstWindowPreference": "persistedWindowLayout",
}
'@
    $updated = Set-JsoncStringProperty $jsonc 'defaultProfile' 'new'
    $parsed = (ConvertFrom-SetupJsonc $updated).Settings
    Assert ($parsed.defaultProfile -eq 'new' -and $parsed.profiles.list[0].defaultProfile -eq 'nested') 'only root defaultProfile changes'
    Assert ($updated.Contains('// Keep this comment') -and $parsed.url -eq 'https://example.com/a//b/*c*/' -and $parsed.theme -eq 'light') 'JSONC comments, URL strings and unrelated settings preserved'
    Assert ((Set-JsoncStringProperty $updated 'defaultProfile' 'new') -ceq $updated) 'JSONC update is idempotent'
    Assert ((ConvertFrom-SetupJsonc (Set-JsoncStringProperty '{/*empty*/}' 'defaultProfile' 'new')).Settings.defaultProfile -eq 'new') 'property inserted into empty commented settings'
    Assert ((ConvertFrom-SetupJsonc (Set-JsoncStringProperty '{"theme":"dark",}' 'defaultProfile' 'new')).Settings.theme -eq 'dark') 'property inserted into settings with trailing comma'
    $thrown = $false
    try { Set-JsoncStringProperty '{bad json}' 'defaultProfile' 'new' | Out-Null } catch { $thrown = $true }
    Assert $thrown 'invalid Terminal settings rejected before writing'
    $thrown = $false
    try { Set-JsoncStringProperty '{"defaultProfile":"a","defaultProfile":"b"}' 'defaultProfile' 'new' | Out-Null } catch { $thrown = $true }
    Assert $thrown 'duplicate startup properties rejected'
    Assert (Test-TerminalDefaultSupported 22000 0) 'Windows 11 supports terminal delegation'
    Assert (-not (Test-TerminalDefaultSupported 19045 3030) -and (Test-TerminalDefaultSupported 19045 3031)) 'Windows 10 delegation requires the supported update'

    # Run file configuration against a fake user profile, never real settings.
    $env:LOCALAPPDATA = Join-Path $testRoot 'user-profile'
    $shell = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\Microsoft.PowerShellPreview_8wekyb3d8bbwe\pwsh.exe'
    New-Item -ItemType Directory -Path (Split-Path -Parent $shell) -Force | Out-Null
    [IO.File]::WriteAllText($shell, 'fake executable, never run')
    Assert ((Get-PowerShellPreviewPath) -eq $shell) 'Preview profile resolves package-specific alias'
    $settingsPath = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
    New-Item -ItemType Directory -Path (Split-Path -Parent $settingsPath) -Force | Out-Null
    [IO.File]::WriteAllText($settingsPath, $jsonc)
    $script:LogFile = $null
    Set-TerminalPowerShellProfile
    $configuredText = [IO.File]::ReadAllText($settingsPath)
    $configured = (ConvertFrom-SetupJsonc $configuredText).Settings
    $fragmentPath = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\DotfilesSetup\powershell-preview.json'
    $fragment = Get-Content -LiteralPath $fragmentPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert ($configured.defaultProfile -eq $fragment.profiles[0].guid -and $fragment.profiles[0].commandline -eq ('"' + $shell + '"')) 'default profile references an explicit Preview fragment'
    Assert ($configured.firstWindowPreference -eq 'defaultProfile' -and $configured.startupActions -eq '') 'startup opens default profile instead of previous layout or actions'
    Assert ($configured.profiles.list[0].name -eq 'User' -and $configuredText.Contains('// Keep this comment')) 'existing Terminal profiles and comments survive file configuration'
    $backups = @(Get-ChildItem -LiteralPath (Join-Path $testRoot 'backups') -Filter '*.bak')
    Assert ($backups.Count -eq 1 -and [IO.File]::ReadAllText($backups[0].FullName) -ceq $jsonc) 'original Terminal settings backed up before changes'
    Set-TerminalPowerShellProfile
    Assert (@(Get-ChildItem -LiteralPath (Join-Path $testRoot 'backups') -Filter '*.bak').Count -eq 1) 'unchanged rerun creates no additional file backups'
    [IO.File]::WriteAllText($settingsPath, '{broken}')
    $thrown = $false
    try { Set-TerminalPowerShellProfile } catch { $thrown = $true }
    Assert ($thrown -and [IO.File]::ReadAllText($settingsPath) -ceq '{broken}') 'invalid settings left untouched'
    Remove-Item -LiteralPath $settingsPath
    Set-TerminalPowerShellProfile
    Assert ((ConvertFrom-SetupJsonc ([IO.File]::ReadAllText($settingsPath))).Settings.defaultProfile -eq $fragment.profiles[0].guid) 'profile configuration works before first Terminal launch'
    [IO.File]::WriteAllText($settingsPath, '{"disabledProfileSources":["DotfilesSetup"]}')
    $thrown = $false
    try { Set-TerminalPowerShellProfile } catch { $thrown = $true }
    Assert $thrown 'disabled fragment source reported instead of false success'
    [IO.File]::WriteAllText($settingsPath, $configuredText)

    # Registry writes are replaced with an in-memory boundary mock.
    $script:delegation = @{DelegationConsole='old-console'; DelegationTerminal=$null}
    $script:registryWrites = @()
    $script:failDelegationWrite = $false
    function Get-TerminalDelegation {
        return [pscustomobject]@{Path='HKCU:\Console\%%Startup'; DelegationConsole=$script:delegation.DelegationConsole; DelegationTerminal=$script:delegation.DelegationTerminal}
    }
    function Set-TerminalDelegationValue($Name, $Value) {
        $script:registryWrites += $Name
        if ($Name -eq 'DelegationTerminal' -and $script:failDelegationWrite) {
            $script:failDelegationWrite = $false
            throw 'simulated registry write failure'
        }
        $script:delegation[$Name] = $Value
    }
    Set-WindowsTerminalDefault
    Assert ($script:delegation.DelegationConsole -eq '{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}' -and $script:delegation.DelegationTerminal -eq '{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}') 'both stable Terminal delegation values written'
    $delegationBackup = Get-ChildItem -LiteralPath (Join-Path $testRoot 'backups') -Filter 'terminal-delegation-*.json' | Select-Object -First 1
    $saved = Get-Content -LiteralPath $delegationBackup.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert ($saved.DelegationConsole -eq 'old-console' -and $null -eq $saved.DelegationTerminal) 'previous delegation values including absence backed up'
    $script:registryWrites = @()
    Set-WindowsTerminalDefault
    Assert ($script:registryWrites.Count -eq 0) 'correct terminal default not rewritten on rerun'
    $script:delegation = @{DelegationConsole='restore-console'; DelegationTerminal='restore-terminal'}
    $script:failDelegationWrite = $true
    $thrown = $false
    try { Set-WindowsTerminalDefault } catch { $thrown = $true }
    Assert ($thrown -and $script:delegation.DelegationConsole -eq 'restore-console' -and $script:delegation.DelegationTerminal -eq 'restore-terminal') 'partial registry failure restores both previous values'

    function Get-TerminalDefaultSupport { return $true }
    $script:installed = @{terminal=$true; 'powershell-preview'=$true}
    $script:DryRun = $false
    function Install-App($App) { throw 'already installed apps must be skipped' }
    $result = @(Invoke-SetupAction @('terminal','powershell-preview') 'Install')
    Assert (($result.Status -join ',') -eq 'Skipped,Skipped,OK,OK') 'defaults configured even when both apps already installed'
    function Get-TerminalDefaultSupport { return $false }
    $script:registryWrites = @()
    $result = @(Invoke-TerminalDefaults @('terminal'))
    Assert ($result[0].Status -eq 'Manual' -and $result[1].Status -eq 'OK' -and $script:registryWrites.Count -eq 0) 'unsupported Windows reports manual delegation while profile setup remains available'
    $script:installed.Remove('powershell-preview')
    $result = @(Invoke-TerminalDefaults @('powershell-preview'))
    Assert ($result[0].Status -eq 'Error') 'missing Preview cannot report successful profile configuration'
    function Set-WindowsTerminalDefault { throw 'must not mutate during preview or download' }
    function Set-TerminalPowerShellProfile { throw 'must not mutate during preview or download' }
    $result = @(Invoke-SetupAction @('terminal','powershell-preview') 'Install' -Preview)
    Assert ($result.Count -eq 4 -and @($result | Where-Object Status -ne 'Plan').Count -eq 0) 'DryRun describes terminal defaults without mutations'
    function Download-App($App) { }
    $result = @(Invoke-SetupAction @('terminal','powershell-preview') 'Download')
    Assert ($result.Count -eq 2 -and @($result | Where-Object Status -ne 'OK').Count -eq 0) 'download does not configure terminal defaults'
    Assert (@(Invoke-TerminalDefaults @('chrome')).Count -eq 0) 'Chrome-only selection does not change terminal defaults'
    $script:installed['powershell-preview'] = $true
    $script:Apps = @('powershell-preview')
    Assert ((Invoke-SetupMain) -eq 1) 'configuration failure returns error exit code even when installation is skipped'
    Write-Host "Passed: $script:passed"
} finally {
    $env:LOCALAPPDATA = $originalLocalAppData
    $resolvedRoot = [IO.Path]::GetFullPath($testRoot)
    $testsDirectory = [IO.Path]::GetFullPath($PSScriptRoot) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedRoot.StartsWith($testsDirectory, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Test cleanup path outside tests directory'
    }
    if (Test-Path -LiteralPath $resolvedRoot) { Remove-Item -LiteralPath $resolvedRoot -Recurse -Force }
}
