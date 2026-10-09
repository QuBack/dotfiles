param([string]$SetupPath = (Join-Path $PSScriptRoot '..\setup.ps1'))
$ErrorActionPreference = 'Stop'
. $SetupPath
$originalInstall = (Get-Command Install-App).ScriptBlock
$originalDownload = (Get-Command Download-App).ScriptBlock
$originalInstalled = (Get-Command Test-AppInstalled).ScriptBlock
$script:passed = 0
function Assert($Condition, $Message) {
    if (-not $Condition) { throw "FAIL: $Message" }
    $script:passed++
    Write-Host "PASS: $Message"
}

# Never install programs, download Python or alter the real user PATH here.
$script:DataRoot = Join-Path $PSScriptRoot ('unused-' + [guid]::NewGuid().ToString('N'))
$script:installed = @{}
function Test-AppInstalled($App) { return $script:installed.ContainsKey($App.Key) }
function Update-SessionPath { }
function Initialize-OperationLog { }
function Get-NvidiaHardware { return [pscustomobject]@{Detected=$false; Names=@(); Versions=@()} }
function Install-App { throw 'must not install during preview' }
function Download-App { throw 'must not download during preview' }
Assert ((@(Get-InstallPlan @('uv')).Key -join ',') -eq 'uv') 'uv selection does not add a Python installation'
Assert ((@(Get-InstallPlan @('poetry')).Key -join ',') -eq 'uv,poetry') 'Poetry automatically adds uv before itself'
Assert ((@(Get-InstallPlan @('poetry','uv','gh')).Key -join ',') -eq 'uv,poetry,gh') 'shared uv selection is deduplicated'
$script:installed['poetry'] = $true
Assert ((@(Get-InstallPlan @('poetry')).Key -join ',') -eq 'poetry') 'existing Poetry needs no new uv installation'
$script:installed.Clear()
$result = @(Invoke-SetupAction @('poetry') 'Install' -Preview)
Assert (($result.Status -join ',') -eq 'Plan,Plan' -and $result[1].Message -match 'uv tool install --python 3.13 poetry') 'Poetry preview describes isolated installation without running installers'
Assert (-not (Test-Path -LiteralPath $script:DataRoot)) 'preview creates no installation data'
$selection = @{}
foreach ($key in @('uv','poetry')) {
    Get-MenuKeyResult 'Enter' (2 + [array]::IndexOf(@($script:Catalog.Key), $key)) $selection | Out-Null
}
Assert (((Get-MenuKeyResult 'Enter' 1 $selection).Keys -join ',') -eq 'uv,poetry') 'uv and Poetry can be selected together from the menu'
$allSelection = Get-MenuKeyResult 'Enter' 0 @{}
Assert ($allSelection.Keys -contains 'uv' -and $allSelection.Keys -contains 'poetry') 'install all includes uv and Poetry'

$script:installCalls = @()
function Install-App($App) {
    $script:installCalls += $App.Key
    if ($App.Key -eq 'uv') { throw 'simulated uv failure' }
}
$result = @(Invoke-SetupAction @('poetry','gh') 'Install')
Assert (($result.Status -join ',') -eq 'Error,Blocked,OK' -and ($script:installCalls -join ',') -eq 'uv,gh') 'uv failure blocks Poetry while independent installs continue'
$script:Apps = @('poetry')
Assert ((Invoke-SetupMain) -eq 1) 'uv failure returns an error exit code'
$script:installed['uv'] = $true
$script:installCalls = @()
$result = @(Invoke-SetupAction @('poetry') 'Install')
Assert (($result.Status -join ',') -eq 'Skipped,OK' -and ($script:installCalls -join ',') -eq 'poetry') 'installed uv is reused for Poetry'
$script:installed['poetry'] = $true
$script:installCalls = @()
$result = @(Invoke-SetupAction @('uv','poetry') 'Install')
Assert (($result.Status -join ',') -eq 'Skipped,Skipped' -and $script:installCalls.Count -eq 0) 'installed uv and Poetry are skipped on rerun'
$script:downloadCalls = @()
function Download-App($App) { $script:downloadCalls += $App.Key }
$result = @(Invoke-SetupAction @('poetry','uv') 'Download')
Assert (($result.Status -join ',') -eq 'Manual,OK' -and ($script:downloadCalls -join ',') -eq 'uv') 'unsupported Poetry download does not block uv download'
$script:downloadCalls = @()
$result = @(Invoke-SetupAction @('poetry') 'Download' -Preview)
Assert ($result[0].Status -eq 'Plan' -and $result[0].Message -match 'не поддерживается' -and $script:downloadCalls.Count -eq 0) 'Poetry download preview explains limitation without side effects'
$script:Download = $true
Assert ((Invoke-SetupMain) -eq 2) 'Poetry download returns action-required exit code'
Assert ($null -eq (Get-CachedDownload (Get-App 'poetry'))) 'Poetry never reports an unsupported cached download'
$thrown = $false
try { & $originalDownload (Get-App 'poetry') } catch { $thrown = $_.Exception.Message -match 'Poetry.*не поддерживается' }
Assert ($thrown -and -not (Test-Path -LiteralPath $script:DataRoot)) 'direct Poetry download is rejected before WinGet, network or file operations'

# Check actual install branches through executable and PATH boundary mocks.
$script:commands = @{'uv.exe'='uv.exe'; 'poetry.exe'='poetry.exe'}
$script:nativeCalls = @()
$script:failToolInstall = $false
function Find-SetupCommand($Name) {
    if ($script:commands.ContainsKey($Name)) { return [pscustomobject]@{Source=$script:commands[$Name]} }
    return $null
}
function Ensure-WinGet { }
function Invoke-InstallerCommand($FilePath, $ArgumentList) {
    $script:nativeCalls += [pscustomobject]@{File=$FilePath; Arguments=@($ArgumentList)}
    if ($script:failToolInstall -and $FilePath -eq 'uv.exe' -and $ArgumentList -contains 'install') { throw 'simulated PyPI error' }
}
& $originalInstall (Get-App 'uv')
$call = $script:nativeCalls[0]
Assert ($call.File -eq 'winget.exe' -and $call.Arguments[2] -eq 'astral-sh.uv' -and $call.Arguments -contains '--exact' -and $call.Arguments -contains '--no-upgrade') 'uv installs the exact official WinGet package'
Assert ($script:nativeCalls.Count -eq 2 -and $script:nativeCalls[1].File -eq 'uv.exe' -and ($script:nativeCalls[1].Arguments -join ' ') -eq '--version') 'uv installation verifies the executable before dependencies proceed'
$script:nativeCalls = @()
& $originalInstall (Get-App 'poetry')
Assert ($script:nativeCalls.Count -eq 3 -and $script:nativeCalls[0].File -eq 'uv.exe' -and ($script:nativeCalls[0].Arguments -join ' ') -eq 'tool install --python 3.13 poetry') 'Poetry installs with uv into its own Python 3.13 environment'
Assert (($script:nativeCalls[1].Arguments -join ' ') -eq 'tool update-shell') 'Poetry executable directory is added to the user shell PATH'
Assert ($script:nativeCalls[2].File -eq 'poetry.exe' -and ($script:nativeCalls[2].Arguments -join ' ') -eq '--version') 'Poetry command is verified after PATH refresh'
$script:commands.Remove('uv.exe')
$script:nativeCalls = @()
$thrown = $false
try { & $originalInstall (Get-App 'poetry') } catch { $thrown = $_.Exception.Message -match 'нужен uv' }
Assert ($thrown -and $script:nativeCalls.Count -eq 0) 'missing uv prevents Poetry installation before any executable runs'
$thrown = $false
try { & $originalInstall (Get-App 'uv') } catch { $thrown = $_.Exception.Message -match 'команда не найдена' }
Assert $thrown 'successful WinGet exit without a uv command remains an error'
$script:commands['uv.exe'] = 'uv.exe'
$script:commands.Remove('poetry.exe')
$script:nativeCalls = @()
$thrown = $false
try { & $originalInstall (Get-App 'poetry') } catch { $thrown = $_.Exception.Message -match 'команда не найдена' }
Assert ($thrown -and $script:nativeCalls.Count -eq 2) 'missing Poetry executable after installation cannot report success'
$script:commands['poetry.cmd'] = 'poetry.cmd'
$script:nativeCalls = @()
& $originalInstall (Get-App 'poetry')
Assert ($script:nativeCalls[2].File -eq 'poetry.cmd') 'Poetry command wrapper is supported as well as an executable'
$script:failToolInstall = $true
$script:nativeCalls = @()
$thrown = $false
try { & $originalInstall (Get-App 'poetry') } catch { $thrown = $true }
Assert ($thrown -and $script:nativeCalls.Count -eq 1) 'failed tool installation does not change shell PATH or report successful verification'
function Get-InstalledAppNames { return @() }
function Get-InstalledAppxNames { return @() }
$script:commands = @{'uv.exe'='uv.exe'}
Assert ((& $originalInstalled (Get-App 'uv')) -and -not (& $originalInstalled (Get-App 'poetry'))) 'uv and Poetry are detected independently'
$script:commands = @{'poetry.exe'='poetry.exe'}
Assert ((& $originalInstalled (Get-App 'poetry')) -and -not (& $originalInstalled (Get-App 'uv'))) 'existing Poetry is detected regardless of install method'
Assert (-not (Test-Path -LiteralPath $script:DataRoot)) 'mocked uv and Poetry tests leave no installation data'
Write-Host "Passed: $script:passed"
