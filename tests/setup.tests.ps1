param([string]$SetupPath = (Join-Path $PSScriptRoot '..\setup.ps1'))
$ErrorActionPreference = 'Stop'
. $SetupPath
$originalDownload = (Get-Command Download-App).ScriptBlock
$originalInstall = (Get-Command Install-App).ScriptBlock
$originalRuntimeReady = (Get-Command Test-NpmRuntimeReady).ScriptBlock
$originalHardware = (Get-Command Get-NvidiaHardware).ScriptBlock
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
    $plan = @(Get-InstallPlan @('codex'))
    Assert (($plan.Key -join ',') -eq 'node,codex') 'dependency precedes Codex'
    $plan = @(Get-InstallPlan @('claude'))
    Assert (($plan.Key -join ',') -eq 'node,claude') 'dependency precedes Claude'
    $plan = @(Get-InstallPlan @('codex','claude'))
    Assert (($plan.Key -join ',') -eq 'node,codex,claude') 'both CLIs share one Node dependency'
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
    Write-Host "Passed: $script:passed"
} finally {
    $resolvedRoot = [IO.Path]::GetFullPath($testRoot)
    $testsDirectory = [IO.Path]::GetFullPath($PSScriptRoot) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedRoot.StartsWith($testsDirectory, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Test cleanup path outside tests directory'
    }
    if (Test-Path -LiteralPath $resolvedRoot) { Remove-Item -LiteralPath $resolvedRoot -Recurse -Force }
}
