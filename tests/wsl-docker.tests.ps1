param([string]$SetupPath = (Join-Path $PSScriptRoot '..\setup.ps1'))
$ErrorActionPreference = 'Stop'
. $SetupPath
$originalInstall = (Get-Command Install-App).ScriptBlock
$originalDownload = (Get-Command Download-App).ScriptBlock
$originalInstalled = (Get-Command Test-AppInstalled).ScriptBlock
$originalWslVersion = (Get-Command Get-WslVersion).ScriptBlock
$originalWslReady = (Get-Command Test-WslReady).ScriptBlock
$originalWslInstaller = (Get-Command Invoke-WslInstaller).ScriptBlock
$originalInstallWsl = (Get-Command Install-Wsl).ScriptBlock
$originalUpdatePath = (Get-Command Update-SessionPath).ScriptBlock
$script:passed = 0
function Assert($Condition, $Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:passed++
    Write-Host "PASS: $Message"
}

# Every installer and system query is mocked; never install WSL or Docker here.
$script:DataRoot = Join-Path $PSScriptRoot ('unused-' + [guid]::NewGuid().ToString('N'))
$script:installed = @{}
function Test-AppInstalled($App) { return $script:installed.ContainsKey($App.Key) }
function Get-NvidiaHardware { return [pscustomobject]@{Detected=$false; Names=@(); Versions=@()} }
function Install-App($App) { throw 'installer must not run during preview' }
function Download-App($App) { throw 'downloader must not run during preview' }
function Initialize-OperationLog { }
function Update-SessionPath { }

Assert ((Get-App 'wsl').Kind -eq 'wsl' -and (Get-App 'wsl').Id -eq 'Microsoft.WSL') 'WSL has its own Windows component installer and official download package'
Assert ((Get-App 'docker').Id -eq 'Docker.DockerDesktop') 'Docker uses the Desktop package'
Assert ((@(Get-InstallPlan @('docker')).Key -join ',') -eq 'wsl,docker') 'Docker automatically includes WSL before itself'
Assert ((@(Get-InstallPlan @('docker','wsl','gh')).Key -join ',') -eq 'wsl,docker,gh') 'WSL dependency is deduplicated'
$script:installed['docker'] = $true
Assert ((@(Get-InstallPlan @('docker')).Key -join ',') -eq 'docker') 'installed Docker does not reinstall WSL'
$script:installed.Clear()
$result = @(Invoke-SetupAction @('docker') 'Install' -Preview)
Assert (($result.Status -join ',') -eq 'Plan,Plan' -and $result[0].Message -match 'без дистрибутива.*UAC.*перезагрузка') 'preview explains WSL elevation and restart without running installers'
Assert (-not (Test-Path -LiteralPath $script:DataRoot)) 'preview creates no files or folders'
$selection = @{}
foreach ($key in @('wsl','docker')) {
    Get-MenuKeyResult 'Enter' (2 + [array]::IndexOf(@($script:Catalog.Key), $key)) $selection | Out-Null
}
Assert (((Get-MenuKeyResult 'Enter' 1 $selection).Keys -join ',') -eq 'wsl,docker') 'WSL and Docker can be selected from the menu'

$script:installCalls = @()
$script:wslOutcome = 'Manual'
function Install-App($App) {
    $script:installCalls += $App.Key
    if ($App.Key -eq 'wsl') {
        if ($script:wslOutcome -eq 'Error') { throw 'simulated WSL failure' }
        if ($script:wslOutcome -eq 'Manual') { return [pscustomobject]@{Status='Manual'; Message='Перезагрузите Windows'} }
    }
}
$result = @(Invoke-SetupAction @('docker','gh') 'Install')
Assert (($result.Status -join ',') -eq 'Manual,Manual,OK' -and ($script:installCalls -join ',') -eq 'wsl,gh') 'WSL restart defers Docker while independent installs continue'
$script:Apps = @('docker')
Assert ((Invoke-SetupMain) -eq 2) 'restart returns action-required exit code instead of an installation error'
$script:wslOutcome = 'Error'
$script:installCalls = @()
$result = @(Invoke-SetupAction @('docker','gh') 'Install')
Assert (($result.Status -join ',') -eq 'Error,Blocked,OK' -and ($script:installCalls -join ',') -eq 'wsl,gh') 'WSL error blocks Docker while independent installs continue'
Assert ((Invoke-SetupMain) -eq 1) 'failed WSL installation returns error exit code'
$script:wslOutcome = 'OK'
$script:installed['wsl'] = $true
$script:installCalls = @()
$result = @(Invoke-SetupAction @('docker') 'Install')
Assert (($result.Status -join ',') -eq 'Skipped,OK' -and ($script:installCalls -join ',') -eq 'docker') 'ready WSL is reused on a later run'
$script:installed['docker'] = $true
$script:installCalls = @()
$result = @(Invoke-SetupAction @('wsl','docker') 'Install')
Assert (($result.Status -join ',') -eq 'Skipped,Skipped' -and $script:installCalls.Count -eq 0) 'installed WSL and Docker are skipped on rerun'
$script:installed.Clear()
$script:downloadCalls = @()
function Download-App($App) { $script:downloadCalls += $App.Key }
$result = @(Invoke-SetupAction @('docker') 'Download')
Assert ($result.Count -eq 1 -and ($script:downloadCalls -join ',') -eq 'docker') 'Docker download does not install or download WSL dependencies'

# WSL readiness uses the package, its version and the active Windows hypervisor.
$script:registryNames = @()
$script:appxNames = @()
$script:queryCalls = @()
$script:queryVersion = 'Версия WSL: 2.6.1.0'
$script:queryExit = 0
function Get-InstalledAppNames { return $script:registryNames }
function Get-InstalledAppxNames { return $script:appxNames }
function Find-SetupCommand($Name) { return [pscustomobject]@{Source=$Name} }
function Invoke-WslQuery($ArgumentList) {
    $script:queryCalls += ($ArgumentList -join ' ')
    return [pscustomobject]@{ExitCode=$script:queryExit; Output=$script:queryVersion}
}
$script:WslVersion = $null
Assert ((& $originalWslVersion) -eq [version]'0.0.0' -and $script:queryCalls.Count -eq 0) 'Windows wsl.exe stub is not queried or mistaken for an installed package'
$script:registryNames = @('Windows Subsystem for Linux')
$script:WslVersion = $null
Assert ((& $originalWslVersion) -eq [version]'2.6.1.0') 'WSL MSI version is read from localized version output'
$script:registryNames = @()
$script:appxNames = @('MicrosoftCorporationII.WindowsSubsystemForLinux')
$script:queryVersion = "WSL version: 2.6.1.0`nKernel version: 6.6.87.2"
$script:WslVersion = $null
Assert ((& $originalWslVersion) -eq [version]'2.6.1.0') 'Store WSL detection reads the WSL version instead of the kernel version'
$script:queryVersion = 'Kernel version: 6.6.87.2'
$script:queryExit = 1
$script:WslVersion = $null
Assert ((& $originalWslVersion) -eq [version]'0.0.0') 'failed version query cannot satisfy WSL detection'
$script:queryVersion = 'WSL version: 2.6.1.0'
$script:queryExit = 0
$script:readyVersion = [version]'2.1.4'
$script:hypervisor = $true
$script:serviceMissing = $false
function Get-WslVersion { return $script:readyVersion }
function Get-Service {
    if ($script:serviceMissing) { throw 'vmcompute not installed' }
    return [pscustomobject]@{Name='vmcompute'}
}
function Get-CimInstance { return [pscustomobject]@{HypervisorPresent=$script:hypervisor} }
Assert (-not (& $originalWslReady)) 'WSL older than Docker minimum needs an update'
$script:readyVersion = [version]'2.1.5'
Assert (& $originalWslReady) 'supported WSL and active virtualization satisfy readiness'
$script:serviceMissing = $true
Assert (-not (& $originalWslReady)) 'WSL package without Virtual Machine Platform is not ready'
$script:serviceMissing = $false
$script:hypervisor = $false
Assert (-not (& $originalWslReady)) 'disabled virtualization or pending Windows feature restart is not ready'
$script:hypervisor = $true
$script:queryExit = 1
Assert (-not (& $originalWslReady)) 'failed WSL status cannot satisfy readiness'
$script:queryExit = 0
function Test-WslReady { return $true }
Assert (& $originalInstalled (Get-App 'wsl')) 'installed status delegates to WSL readiness'
Assert (-not (& $originalInstalled (Get-App 'docker'))) 'docker.exe alone does not mark Docker Desktop installed'
$script:registryNames = @('Docker CLI','Docker Compose')
Assert (-not (& $originalInstalled (Get-App 'docker'))) 'CLI and Compose registry entries do not satisfy Docker Desktop'
$script:registryNames = @('Docker Desktop')
Assert (& $originalInstalled (Get-App 'docker')) 'Docker Desktop is detected by its own registry identity'

# Check real WSL orchestration through mocked elevation and command boundaries.
$script:processCode = 3010
$script:processCall = $null
function Start-Process($FilePath, $ArgumentList, $Verb, $WindowStyle, [switch]$Wait, [switch]$PassThru, $ErrorAction) {
    $script:processCall = [pscustomobject]@{File=$FilePath; Arguments=@($ArgumentList); Verb=$Verb; Window=$WindowStyle; Wait=$Wait; PassThru=$PassThru}
    return [pscustomobject]@{ExitCode=$script:processCode}
}
Assert ((& $originalWslInstaller @('--install','--no-distribution','--web-download')) -eq 3010) 'WSL reboot code is accepted as a completed installer step'
Assert ($script:processCall.Verb -eq 'RunAs' -and $script:processCall.Window -eq 'Hidden' -and $script:processCall.Wait -and $script:processCall.PassThru) 'only WSL command is elevated and its completion is awaited'
$script:processCode = 5
$thrown = $false
try { & $originalWslInstaller @('--install','--no-distribution') | Out-Null } catch { $thrown = $true }
Assert $thrown 'WSL installer failures remain errors'
$script:wslCalls = @()
$script:wslCode = 0
$script:wslReady = $true
$script:readyVersion = [version]'2.6.1'
$script:nativeCalls = @()
function Invoke-WslInstaller($ArgumentList) {
    $script:wslCalls += ($ArgumentList -join ' ')
    if ($ArgumentList -contains '--update') { $script:readyVersion = [version]'2.6.1' }
    return $script:wslCode
}
function Test-WslReady { return $script:wslReady }
function Invoke-InstallerCommand($FilePath, $ArgumentList) {
    $script:nativeCalls += [pscustomobject]@{File=$FilePath; Arguments=@($ArgumentList)}
}
& $originalInstallWsl
Assert (($script:wslCalls -join ',') -eq '--install --no-distribution --web-download' -and ($script:nativeCalls[0].Arguments -join ' ') -eq '--set-default-version 2') 'WSL installs without a distribution and defaults new distributions to version 2'
$script:readyVersion = [version]'2.1.4'
$script:wslCalls = @()
& $originalInstallWsl
Assert (($script:wslCalls -join ',') -eq '--install --no-distribution --web-download,--update --web-download') 'old WSL is updated before Docker can proceed'
$script:wslCode = 3010
$script:wslCalls = @()
$script:nativeCalls = @()
$result = & $originalInstallWsl
Assert ($result.Status -eq 'Manual' -and $script:nativeCalls.Count -eq 0 -and $script:wslCalls.Count -eq 1) 'restart defers readiness commands and preserves a manual result'
$script:wslCode = 0
$script:wslReady = $false
$result = & $originalInstallWsl
Assert ($result.Status -eq 'Manual' -and $result.Message -match 'BIOS/UEFI' -and $script:nativeCalls.Count -eq 0) 'unready WSL after a zero exit code still asks for setup completion'
function Install-Wsl { return [pscustomobject]@{Status='Manual'; Message='test restart'} }
Assert ((& $originalInstall (Get-App 'wsl')).Status -eq 'Manual') 'generic installation retains WSL restart status'
function Ensure-WinGet { }
$script:nativeCalls = @()
& $originalInstall (Get-App 'docker')
Assert ($script:nativeCalls.Count -eq 1 -and $script:nativeCalls[0].File -eq 'winget.exe' -and $script:nativeCalls[0].Arguments[2] -eq 'Docker.DockerDesktop' -and $script:nativeCalls[0].Arguments -contains '--exact' -and $script:nativeCalls[0].Arguments -contains '--no-upgrade' -and $script:nativeCalls[0].Arguments -contains '--custom' -and $script:nativeCalls[0].Arguments -contains '--backend=wsl-2') 'Docker installs its exact Desktop package with WSL 2 backend'
# Verify the special WSL kind still uses the standard WinGet download/cache path.
$script:nativeCalls = @()
$script:receipt = $null
function Get-CachedDownload { return $null }
function New-Item { }
function Get-ChildItem { return [pscustomobject]@{Extension='.msi'; FullName=(Join-Path $script:DataRoot 'fake-wsl.msi')} }
function Save-DownloadReceipt($App, $Directory, $Files) { $script:receipt = [pscustomobject]@{App=$App.Key; Kind=$App.Kind; Files=@($Files)} }
& $originalDownload (Get-App 'wsl')
Assert ($script:nativeCalls.Count -eq 1 -and $script:nativeCalls[0].File -eq 'winget.exe' -and $script:nativeCalls[0].Arguments[0] -eq 'download' -and $script:nativeCalls[0].Arguments[2] -eq 'Microsoft.WSL') 'WSL download gets the official WinGet package without elevating or enabling Windows components'
Assert ($script:receipt.App -eq 'wsl' -and $script:receipt.Kind -eq 'wsl' -and $script:receipt.Files.Count -eq 1) 'WSL download saves a receipt for its own kind'
$script:WslVersion = [version]'2.1.4'
& $originalUpdatePath
Assert ($null -eq $script:WslVersion) 'session refresh clears cached WSL version after installation'
Assert (-not (Test-Path -LiteralPath $script:DataRoot)) 'mocked WSL and Docker tests leave no installation data'
Write-Host "Passed: $script:passed"
