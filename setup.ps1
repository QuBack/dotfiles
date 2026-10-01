#requires -Version 5.1
<#
Standalone Windows workstation installer. No repository checkout is required.
Run: powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
#>
[CmdletBinding()]
param(
    [switch]$All,
    [switch]$Download,
    [string[]]$Apps,
    [switch]$List,
    [switch]$DryRun,
    [string]$DataDirectory = (Join-Path $env:LOCALAPPDATA 'DotfilesSetup')
)

$script:DataRoot = [IO.Path]::GetFullPath($DataDirectory)
$script:LogFile = $null
$script:InstalledAppNames = $null
$script:InstalledAppxNames = $null
$script:CommandCache = @{}
$script:NvidiaHardware = $null
$script:Catalog = @(
    [pscustomobject]@{Key='git'; Name='Git'; Id='Git.Git'; Kind='winget'; Commands=@('git.exe'); Pattern='^Git( version)? '; Dependencies=@()},
    [pscustomobject]@{Key='terminal'; Name='Windows Terminal'; Id='Microsoft.WindowsTerminal'; Kind='winget'; Commands=@(); Pattern='^Windows Terminal$'; AppxName='Microsoft.WindowsTerminal'; Dependencies=@()},
    [pscustomobject]@{Key='powershell-preview'; Name='PowerShell 7 Preview'; Id='Microsoft.PowerShell.Preview'; Kind='winget'; Commands=@(); Pattern='^PowerShell 7.*(?:preview|rc)'; AppxName='Microsoft.PowerShellPreview'; Dependencies=@()},
    [pscustomobject]@{Key='chrome'; Name='Google Chrome'; Id='Google.Chrome'; Kind='winget'; Commands=@(); Pattern='^Google Chrome$'; Dependencies=@()},
    [pscustomobject]@{Key='vscode'; Name='VS Code'; Id='Microsoft.VisualStudioCode'; Kind='winget'; Commands=@('code.cmd'); Pattern='^Microsoft Visual Studio Code'; Dependencies=@()},
    [pscustomobject]@{Key='python'; Name='Python 3.13'; Id='Python.Python.3.13'; Kind='winget'; Commands=@(); Pattern='^Python 3\.13\.\d+ \((64-bit|32-bit|ARM64)\)$'; Dependencies=@()},
    [pscustomobject]@{Key='node'; Name='Node.js LTS'; Id='OpenJS.NodeJS.LTS'; Kind='winget'; Commands=@('node.exe'); Pattern='^Node\.js$'; Dependencies=@()},
    [pscustomobject]@{Key='codex'; Name='Codex CLI'; Id='@openai/codex'; Kind='npm'; Commands=@('codex.cmd','codex.exe'); Pattern='(?!)'; Dependencies=@('node')},
    [pscustomobject]@{Key='claude'; Name='Claude Code'; Id='@anthropic-ai/claude-code'; Kind='npm'; Commands=@('claude.cmd','claude.exe'); Pattern='(?!)'; Dependencies=@('node')},
    [pscustomobject]@{Key='obsidian'; Name='Obsidian'; Id='Obsidian.Obsidian'; Kind='winget'; Commands=@(); Pattern='^Obsidian( |$)'; Dependencies=@()},
    [pscustomobject]@{Key='amnezia'; Name='AmneziaVPN'; Id='AmneziaVPN.AmneziaVPN'; Kind='winget'; Commands=@(); Pattern='^AmneziaVPN( |$)'; Dependencies=@()},
    [pscustomobject]@{Key='vlc'; Name='VLC'; Id='VideoLAN.VLC'; Kind='winget'; Commands=@('vlc.exe'); Pattern='^VLC media player( |$)'; Dependencies=@()},
    [pscustomobject]@{Key='nvidia'; Name='NVIDIA драйверы'; Id='https://www.nvidia.com/en-us/drivers/'; Kind='manual'; Commands=@(); Pattern='(?!)'; Dependencies=@()}
)

function Get-App([string]$Key) {
    $app = $script:Catalog | Where-Object Key -eq $Key | Select-Object -First 1
    if ($null -eq $app) { throw "Неизвестная программа '$Key'. Доступны: $($script:Catalog.Key -join ', ')." }
    return $app
}

function Update-SessionPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $extra = @((Join-Path $env:APPDATA 'npm'), (Join-Path $env:USERPROFILE '.local\bin'))
    $entries = ((@($env:Path, $machinePath, $userPath) + $extra) -join ';').Split(';') |
        Where-Object { $_ } | Select-Object -Unique
    $env:Path = $entries -join ';'
    $script:CommandCache = @{}
    $script:InstalledAppNames = $null
    $script:InstalledAppxNames = $null
    $script:NvidiaHardware = $null
}

function Find-SetupCommand([string]$Name) {
    if (-not $script:CommandCache.ContainsKey($Name)) {
        $script:CommandCache[$Name] = Get-Command $Name -CommandType Application -ListImported -ErrorAction SilentlyContinue |
            Select-Object -First 1
    }
    return $script:CommandCache[$Name]
}

function Get-InstalledAppNames {
    if ($null -ne $script:InstalledAppNames) { return $script:InstalledAppNames }
    $registryPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $script:InstalledAppNames = @(foreach ($path in $registryPaths) {
        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue |
            Where-Object { $_.PSObject.Properties['DisplayName'] } | ForEach-Object DisplayName
    })
    return $script:InstalledAppNames
}

function Get-InstalledAppxNames {
    if ($null -ne $script:InstalledAppxNames) { return $script:InstalledAppxNames }
    try {
        # Current-user MSIX packages, including apps installed through the Store.
        $script:InstalledAppxNames = @(Get-AppxPackage -ErrorAction Stop | ForEach-Object Name)
    } catch {
        # Registry detection remains available if Appx is unsupported in the host.
        $script:InstalledAppxNames = @()
    }
    return $script:InstalledAppxNames
}

function Test-AppInstalled($App) {
    if ($App.Key -eq 'node') { return (Test-NpmRuntimeReady) }
    if ($App.PSObject.Properties['AppxName'] -and (Get-InstalledAppxNames) -contains $App.AppxName) { return $true }
    foreach ($name in $App.Commands) {
        if (Find-SetupCommand $name) { return $true }
    }
    if (@(Get-InstalledAppNames | Where-Object { $_ -match $App.Pattern }).Count -gt 0) { return $true }
    return $false
}

function Get-NodeMajor {
    $nodeCommand = Find-SetupCommand 'node.exe'
    if (-not $nodeCommand) { return 0 }
    try {
        $versionText = & $nodeCommand.Source --version 2>$null
        if ($LASTEXITCODE -eq 0 -and "$versionText" -match '^v(\d+)\.') { return [int]$Matches[1] }
    } catch { }
    return 0
}

function Test-NpmRuntimeReady {
    return ((Get-NodeMajor) -ge 22 -and $null -ne (Find-SetupCommand 'npm.cmd'))
}

function Get-NvidiaHardware {
    if ($null -ne $script:NvidiaHardware) { return $script:NvidiaHardware }
    try {
        $adapters = @(Get-CimInstance -ClassName Win32_VideoController -OperationTimeoutSec 5 -ErrorAction Stop)
        $nvidia = @($adapters | Where-Object { $_.PNPDeviceID -match 'VEN_10DE' -or $_.Name -match 'NVIDIA' })
        $detected = $null
        if ($nvidia.Count -gt 0) { $detected = $true }
        elseif ($adapters.Count -gt 0) { $detected = $false }
        $script:NvidiaHardware = [pscustomobject]@{Detected=$detected; Names=@($nvidia | ForEach-Object Name); Versions=@($nvidia | ForEach-Object DriverVersion)}
    } catch {
        $script:NvidiaHardware = [pscustomobject]@{Detected=$null; Names=@(); Versions=@()}
    }
    return $script:NvidiaHardware
}

function Open-NvidiaDriverPage {
    $hardware = Get-NvidiaHardware
    if ($hardware.Names.Count -gt 0) {
        Write-Host ('Видеокарта: ' + ($hardware.Names -join ', ')) -ForegroundColor Cyan
        Write-Host ('Версия драйвера Windows: ' + ($hardware.Versions -join ', '))
    } else {
        Write-Host 'Модель GPU не определена. Проверьте её в диспетчере устройств.' -ForegroundColor Yellow
    }
    Write-Host 'Выберите свою видеокарту и Windows на сайте NVIDIA, скачайте и запустите подходящий драйвер.'
    Start-Process -FilePath (Get-App 'nvidia').Id -ErrorAction Stop
}

function Get-InstallPlan([string[]]$Keys) {
    $seen = @{}
    $ordered = [Collections.Generic.List[object]]::new()
    function Add-PlanApp([string]$Key) {
        if ($seen.ContainsKey($Key)) { return }
        $seen[$Key] = $true
        $app = Get-App $Key
        if (-not (Test-AppInstalled $app)) {
            foreach ($dependency in $app.Dependencies) { Add-PlanApp $dependency }
        }
        $ordered.Add($app)
    }
    foreach ($key in $Keys) { Add-PlanApp $key }
    return $ordered.ToArray()
}

function Write-SetupLog([string]$Message) {
    if ($script:LogFile) {
        Add-Content -LiteralPath $script:LogFile -Value (('{0:o} {1}' -f [DateTime]::Now, $Message)) -Encoding UTF8
    }
}

function Invoke-InstallerCommand([string]$FilePath, [string[]]$ArgumentList) {
    # Call an executable with an argument array; never evaluate command strings.
    $ErrorActionPreference = 'Continue'
    $PSNativeCommandUseErrorActionPreference = $false
    & $FilePath @ArgumentList 2>&1 | ForEach-Object {
        Write-Host "$_"
        Write-SetupLog "$_"
    }
    $commandExitCode = $LASTEXITCODE
    if ($commandExitCode -ne 0) { throw "$FilePath завершился с кодом $commandExitCode." }
}

function Ensure-WinGet {
    if (Find-SetupCommand 'winget.exe') { return }
    Write-Host 'WinGet отсутствует. Восстанавливаю через официальный модуль Microsoft...' -ForegroundColor Yellow
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Install-PackageProvider -Name NuGet -Scope CurrentUser -Force -ErrorAction Stop | Out-Null
    Install-Module -Name Microsoft.WinGet.Client -Scope CurrentUser -Repository PSGallery -Force -ErrorAction Stop
    Import-Module Microsoft.WinGet.Client -ErrorAction Stop
    Repair-WinGetPackageManager -Force -Latest -ErrorAction Stop | Out-Host
    Update-SessionPath
    if (-not (Find-SetupCommand 'winget.exe')) {
        throw 'WinGet недоступен. Установите «Установщик приложений» Microsoft и откройте терминал заново.'
    }
}

function Get-ReceiptPath($App) {
    return Join-Path (Join-Path $script:DataRoot 'downloads') ($App.Key + '.json')
}

function Get-DownloadHash([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-', '') }
    finally { $stream.Dispose(); $algorithm.Dispose() }
}

function Save-DownloadReceipt($App, [string]$Directory, [string[]]$Files) {
    if ($Files.Count -eq 0) { throw 'Установщик не найден после скачивания.' }
    $entries = @($Files | ForEach-Object {
        [pscustomobject]@{Path=[IO.Path]::GetFullPath($_); SHA256=(Get-DownloadHash $_)}
    })
    $receipt = [pscustomobject]@{App=$App.Key; PackageId=$App.Id; Kind=$App.Kind; Directory=$Directory; SavedAt=[DateTime]::UtcNow.ToString('o'); Files=$entries}
    $receiptPath = Get-ReceiptPath $App
    New-Item -ItemType Directory -Path (Split-Path -Parent $receiptPath) -Force | Out-Null
    $temporaryPath = $receiptPath + '.tmp'
    $receipt | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $temporaryPath -Encoding UTF8
    Move-Item -LiteralPath $temporaryPath -Destination $receiptPath -Force
}

function Get-CachedDownload($App) {
    $path = Get-ReceiptPath $App
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    try {
        $receipt = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($receipt.App -ne $App.Key -or @($receipt.Files).Count -eq 0) { return $null }
        if ($receipt.PSObject.Properties['PackageId'] -and $receipt.PackageId -ne $App.Id) { return $null }
        if ($receipt.PSObject.Properties['Kind'] -and $receipt.Kind -ne $App.Kind) { return $null }
        if ($App.Kind -eq 'npm' -and (@($receipt.Files).Count -ne 1 -or [IO.Path]::GetExtension($receipt.Files[0].Path) -ne '.tgz')) { return $null }
        $downloadRoot = [IO.Path]::GetFullPath((Join-Path $script:DataRoot 'downloads')) + [IO.Path]::DirectorySeparatorChar
        foreach ($entry in $receipt.Files) {
            if (-not ([IO.Path]::GetFullPath($entry.Path)).StartsWith($downloadRoot, [StringComparison]::OrdinalIgnoreCase)) { return $null }
            if (-not (Test-Path -LiteralPath $entry.Path -PathType Leaf)) { return $null }
            if ((Get-DownloadHash $entry.Path) -ne $entry.SHA256) { return $null }
        }
        return $receipt
    } catch { return $null }
}

function Download-App($App) {
    if ($App.Kind -eq 'manual') { throw 'Для NVIDIA используйте официальный подбор драйвера через меню.' }
    if ($null -ne (Get-CachedDownload $App)) {
        Write-Host "$($App.Name): сохранённый установщик уже есть." -ForegroundColor Green
        return
    }
    $folder = Join-Path (Join-Path $script:DataRoot 'downloads') ($App.Key + '-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    if ($App.Kind -eq 'npm') {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $metadataUri = 'https://registry.npmjs.org/' + $App.Id + '/latest'
        $metadata = Invoke-RestMethod -Uri $metadataUri -TimeoutSec 60 -ErrorAction Stop
        $tarballUri = [uri]$metadata.dist.tarball
        if ($tarballUri.Scheme -ne 'https' -or $tarballUri.Host -ne 'registry.npmjs.org') { throw 'Неожиданный адрес npm-пакета.' }
        $file = Join-Path $folder ($App.Key + '-' + $metadata.version + '.tgz')
        Invoke-WebRequest -Uri $tarballUri.AbsoluteUri -OutFile $file -UseBasicParsing -TimeoutSec 300 -ErrorAction Stop
        $integrity = [string]$metadata.dist.integrity
        if (-not $integrity.StartsWith('sha512-')) { throw 'npm не предоставил SHA512 пакета.' }
        $stream = [IO.File]::OpenRead($file)
        $algorithm = [Security.Cryptography.SHA512]::Create()
        try { $actual = 'sha512-' + [Convert]::ToBase64String($algorithm.ComputeHash($stream)) }
        finally { $stream.Dispose(); $algorithm.Dispose() }
        if ($actual -cne $integrity) { throw 'SHA512 npm-пакета не совпадает.' }
        Save-DownloadReceipt $App $folder @($file)
    } else {
        Ensure-WinGet
        Invoke-InstallerCommand 'winget.exe' @('download','--id',$App.Id,'--exact','--source','winget',
            '--download-directory',$folder,'--skip-dependencies','--accept-package-agreements',
            '--accept-source-agreements','--disable-interactivity')
        $files = @(Get-ChildItem -LiteralPath $folder -File -Recurse | Where-Object {
            $_.Extension -in @('.exe','.msi','.msix','.msixbundle','.appx','.appxbundle','.zip')
        } | ForEach-Object FullName)
        Save-DownloadReceipt $App $folder $files
    }
}

function Install-App($App) {
    if ($App.Kind -eq 'manual') { throw 'Для NVIDIA используйте официальный подбор драйвера через меню.' }
    if ($App.Kind -eq 'npm') {
        Update-SessionPath
        if (-not (Test-NpmRuntimeReady)) {
            throw 'Нужны Node.js 22+ и npm. Откройте терминал заново и повторите установку выбранного CLI.'
        }
        $cache = Get-CachedDownload $App
        $package = $App.Id + '@latest'
        if ($cache) { $package = $cache.Files[0].Path }
        Invoke-InstallerCommand 'npm.cmd' @('install','--global',$package,'--include=optional')
        Update-SessionPath
        $cliCommand = $null
        foreach ($name in $App.Commands) {
            $cliCommand = Find-SetupCommand $name
            if ($cliCommand) { break }
        }
        if (-not $cliCommand) {
            throw "Установка завершилась, но команда $($App.Key) не найдена в PATH."
        }
        Invoke-InstallerCommand $cliCommand.Source @('--version')
    } else {
        Ensure-WinGet
        $arguments = @('install','--id',$App.Id,'--exact','--source','winget',
            '--accept-package-agreements','--accept-source-agreements','--disable-interactivity')
        # Node may need an upgrade or repair when npm is missing or the runtime is too old.
        if ($App.Key -eq 'node') { $arguments += '--force' }
        else { $arguments += '--no-upgrade' }
        Invoke-InstallerCommand 'winget.exe' $arguments
        Update-SessionPath
        if ($App.Key -eq 'node' -and -not (Test-NpmRuntimeReady)) {
            throw 'После установки Node.js LTS не найдены Node.js 22+ и npm. Проверьте PATH и откройте терминал заново.'
        }
    }
}

function ConvertFrom-SetupJsonc([string]$Text) {
    # Keep quoted strings intact while removing JSONC comments and trailing commas.
    $withoutComments = [regex]::Replace($Text, '"(?:\\.|[^"\\])*"|//[^\r\n]*|/\*[\s\S]*?\*/', [Text.RegularExpressions.MatchEvaluator]{
        param($match)
        if ($match.Value.StartsWith('"')) { return $match.Value }
        return (' ' * $match.Length)
    })
    $clean = [regex]::Replace($withoutComments, '("(?:\\.|[^"\\])*")|,(?=\s*[\]}])', [Text.RegularExpressions.MatchEvaluator]{
        param($match)
        if ($match.Groups[1].Success) { return $match.Value }
        return ' '
    })
    if (-not $clean.Trim().StartsWith('{') -or -not $clean.Trim().EndsWith('}')) { throw 'Настройки Terminal должны быть объектом JSON.' }
    $settings = $clean | ConvertFrom-Json -ErrorAction Stop
    return [pscustomobject]@{Settings=$settings; MaskedText=$withoutComments}
}

function Set-JsoncStringProperty([string]$Text, [string]$Name, [string]$Value) {
    $parsed = ConvertFrom-SetupJsonc $Text
    $tokens = [regex]::Matches($parsed.MaskedText, '"(?:\\.|[^"\\])*"|[{}\[\]:,]|[^\s{}\[\]:,]+')
    $depth = 0
    $target = $null
    $propertyCount = 0
    for ($index = 0; $index -lt $tokens.Count; $index++) {
        $token = $tokens[$index]
        if ($token.Value -in @('{','[')) { $depth++; continue }
        if ($token.Value -in @('}',']')) { $depth--; continue }
        if ($depth -eq 1 -and $token.Value.StartsWith('"') -and $tokens[$index + 1].Value -eq ':') {
            $propertyCount++
            if (($token.Value | ConvertFrom-Json) -eq $Name) {
                if ($null -ne $target) { throw "Дублирующийся параметр '$Name' в настройках Terminal." }
                $target = $tokens[$index + 2]
                if (-not $target.Value.StartsWith('"')) { throw "Параметр '$Name' должен быть строкой." }
            }
        }
    }
    $jsonValue = ConvertTo-Json -InputObject $Value -Compress
    if ($null -ne $target) {
        if (($target.Value | ConvertFrom-Json) -eq $Value) { return $Text }
        $updated = $Text.Remove($target.Index, $target.Length).Insert($target.Index, $jsonValue)
    } else {
        $newline = "`n"; if ($Text.Contains("`r`n")) { $newline = "`r`n" }
        $comma = ''; if ($propertyCount -gt 0) { $comma = ',' }
        $jsonName = ConvertTo-Json -InputObject $Name -Compress
        $updated = $Text.Insert($tokens[0].Index + 1, ($newline + '    ' + $jsonName + ': ' + $jsonValue + $comma + $newline))
    }
    ConvertFrom-SetupJsonc $updated | Out-Null
    return $updated
}

function Write-SetupConfigFile([string]$Path, [string]$Text) {
    $exists = Test-Path -LiteralPath $Path -PathType Leaf
    $original = $null
    if ($exists) {
        $original = [IO.File]::ReadAllText($Path)
        if ($original -ceq $Text) { return }
        $backupDirectory = Join-Path $script:DataRoot 'backups'
        New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
        $backup = Join-Path $backupDirectory ((Split-Path -Leaf $Path) + '-' + [guid]::NewGuid().ToString('N') + '.bak')
        Copy-Item -LiteralPath $Path -Destination $backup -ErrorAction Stop
        Write-SetupLog "Backup: $Path -> $backup"
    }
    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $temporary = Join-Path $directory ([guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($temporary, $Text, (New-Object Text.UTF8Encoding($false)))
        if ($exists) {
            if ([IO.File]::ReadAllText($Path) -cne $original) { throw 'Настройки изменены другим процессом. Повторите запуск после закрытия Terminal.' }
            [IO.File]::Replace($temporary, $Path, [System.Management.Automation.Language.NullString]::Value)
        } else { [IO.File]::Move($temporary, $Path) }
    } finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}

function Get-PowerShellPreviewPath {
    # Package-specific alias survives MSIX updates and never resolves to stable pwsh.
    $candidates = @((Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\Microsoft.PowerShellPreview_8wekyb3d8bbwe\pwsh.exe'))
    foreach ($directory in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if ($directory) { $candidates += Join-Path $directory 'PowerShell\7-preview\pwsh.exe' }
    }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    throw 'Не найден исполняемый файл PowerShell 7 Preview. Откройте новый терминал после установки и повторите запуск.'
}

function Set-TerminalPowerShellProfile {
    $shellPath = Get-PowerShellPreviewPath
    $settingsPath = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
    $fragmentPath = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\DotfilesSetup\powershell-preview.json'
    $profileGuid = '{9294768e-46fe-4a9b-b61d-126df67bf7bc}'
    $text = '{}'
    if (Test-Path -LiteralPath $settingsPath -PathType Leaf) { $text = [IO.File]::ReadAllText($settingsPath) }
    $settings = (ConvertFrom-SetupJsonc $text).Settings
    if ($settings.disabledProfileSources -contains 'DotfilesSetup') { throw 'В настройках Terminal отключён источник профилей DotfilesSetup.' }
    if (@($settings.profiles.list | Where-Object { $_.guid -eq $profileGuid -and $_.hidden }).Count -gt 0) {
        throw 'Профиль DotfilesSetup скрыт в настройках Terminal. Сделайте его видимым и повторите запуск.'
    }
    $updated = Set-JsoncStringProperty $text 'defaultProfile' $profileGuid
    $updated = Set-JsoncStringProperty $updated 'firstWindowPreference' 'defaultProfile'
    $updated = Set-JsoncStringProperty $updated 'startupActions' ''
    $fragment = [ordered]@{profiles=@([ordered]@{guid=$profileGuid; name='PowerShell 7 Preview (Dotfiles)'; commandline=('"' + $shellPath + '"'); hidden=$false})} | ConvertTo-Json -Depth 8
    # Only our fragment and three startup fields change; existing profiles stay intact.
    Write-SetupConfigFile $fragmentPath $fragment
    Write-SetupConfigFile $settingsPath $updated
}

function Test-TerminalDefaultSupported([int]$Build, [int]$Revision) {
    return ($Build -ge 22000 -or ($Build -eq 19045 -and $Revision -ge 3031))
}

function Get-TerminalDefaultSupport {
    $version = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
    return (Test-TerminalDefaultSupported ([int]$version.CurrentBuildNumber) ([int]$version.UBR))
}

function Get-TerminalDelegation {
    $path = 'HKCU:\Console\%%Startup'
    $values = $null
    if (Test-Path -LiteralPath $path) { $values = Get-ItemProperty -LiteralPath $path -ErrorAction Stop }
    $console = $null; $terminal = $null
    if ($values -and $values.PSObject.Properties['DelegationConsole']) { $console = $values.DelegationConsole }
    if ($values -and $values.PSObject.Properties['DelegationTerminal']) { $terminal = $values.DelegationTerminal }
    return [pscustomobject]@{Path=$path; DelegationConsole=$console; DelegationTerminal=$terminal}
}

function Set-TerminalDelegationValue([string]$Name, $Value) {
    $path = 'HKCU:\Console\%%Startup'
    if ($null -eq $Value) {
        if (Test-Path -LiteralPath $path) { Remove-ItemProperty -LiteralPath $path -Name $Name -ErrorAction SilentlyContinue }
    } else {
        if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -ErrorAction Stop | Out-Null }
        New-ItemProperty -LiteralPath $path -Name $Name -Value $Value -PropertyType String -Force -ErrorAction Stop | Out-Null
    }
}

function Set-WindowsTerminalDefault {
    # Official stable Terminal CLSIDs from microsoft/terminal policies/WindowsTerminal.admx.
    $console = '{2EACA947-7F5F-4CFA-BA87-8F7FBEEFBE69}'
    $terminal = '{E12CFF52-A866-4C77-9A90-F570A7AA2C6B}'
    $original = Get-TerminalDelegation
    if ($original.DelegationConsole -eq $console -and $original.DelegationTerminal -eq $terminal) { return }
    $backupDirectory = Join-Path $script:DataRoot 'backups'
    New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    $backup = Join-Path $backupDirectory ('terminal-delegation-' + [guid]::NewGuid().ToString('N') + '.json')
    $original | ConvertTo-Json | Set-Content -LiteralPath $backup -Encoding UTF8 -ErrorAction Stop
    Write-SetupLog "Registry backup: $backup"
    try {
        Set-TerminalDelegationValue 'DelegationConsole' $console
        Set-TerminalDelegationValue 'DelegationTerminal' $terminal
        $current = Get-TerminalDelegation
        if ($current.DelegationConsole -ne $console -or $current.DelegationTerminal -ne $terminal) { throw 'Не удалось проверить терминал по умолчанию.' }
    } catch {
        Set-TerminalDelegationValue 'DelegationConsole' $original.DelegationConsole
        Set-TerminalDelegationValue 'DelegationTerminal' $original.DelegationTerminal
        throw
    }
}

function Invoke-TerminalDefaults([string[]]$Keys, [switch]$Preview) {
    if (@($Keys | Where-Object { $_ -in @('terminal','powershell-preview') }).Count -eq 0) { return }
    $operations = @()
    if ($Keys -contains 'terminal') { $operations += 'terminal-default' }
    $operations += 'terminal-profile'
    foreach ($operation in $operations) {
        $name = 'Стартовый профиль PowerShell'; $message = 'PowerShell 7 Preview — стартовый профиль Windows Terminal'
        if ($operation -eq 'terminal-default') { $name = 'Терминал по умолчанию'; $message = 'Windows Terminal — терминал Windows по умолчанию' }
        $status = 'OK'
        if ($Preview) { $status = 'Plan' }
        else {
            try {
                if (-not (Test-AppInstalled (Get-App 'terminal'))) { throw 'Не установлен Windows Terminal. Выберите terminal и powershell-preview.' }
                if ($operation -eq 'terminal-default') {
                    if (-not (Get-TerminalDefaultSupport)) {
                        $status = 'Manual'; $message = 'Для терминала по умолчанию нужна Windows 11 или Windows 10 22H2 с обновлением KB5026435 либо более новым.'
                    } else { Set-WindowsTerminalDefault }
                } else {
                    if (-not (Test-AppInstalled (Get-App 'powershell-preview'))) { throw 'Не установлен PowerShell 7 Preview. Выберите powershell-preview.' }
                    Set-TerminalPowerShellProfile
                }
            } catch { $status = 'Error'; $message = $_.Exception.Message }
        }
        Write-SetupLog "$operation`: $status $message"
        [pscustomobject]@{Key=$operation; Name=$name; Status=$status; Message=$message}
    }
}

function Invoke-SetupAction([string[]]$Keys, [ValidateSet('Install','Download')][string]$Action, [switch]$Preview) {
    if ($Action -eq 'Install') { $plan = @(Get-InstallPlan $Keys) }
    else { $plan = @($Keys | Select-Object -Unique | ForEach-Object { Get-App $_ }) }
    $failed = @{}
    foreach ($app in $plan) {
        $status = 'OK'
        $message = ''
        if ($app.Key -eq 'nvidia' -and (Get-NvidiaHardware).Detected -eq $false) {
            $status = 'Skipped'; $message = 'Видеокарта NVIDIA не обнаружена'
        } elseif ($Preview) {
            $status = 'Plan'
            $message = "$Action $($app.Id)"
            if ($app.Kind -eq 'manual') { $message = 'Открыть сайт NVIDIA; выбрать и установить драйвер вручную' }
            elseif ($Action -eq 'Install' -and (Test-AppInstalled $app)) { $message = 'Уже установлено: будет пропущено' }
        } elseif ($Action -eq 'Install' -and (Test-AppInstalled $app)) {
            $status = 'Skipped'; $message = 'Уже установлено'
        } elseif ($Action -eq 'Install' -and @($app.Dependencies | Where-Object { $failed.ContainsKey($_) }).Count -gt 0) {
            $status = 'Blocked'; $message = 'Не удалось установить зависимость'; $failed[$app.Key] = $true
        } else {
            Write-Host "`n>>> $Action : $($app.Name)" -ForegroundColor Cyan
            try {
                if ($app.Kind -eq 'manual') {
                    Open-NvidiaDriverPage
                    $status = 'Manual'; $message = 'Открыт официальный сайт. Требуется выбор и установка драйвера.'
                } else {
                    if ($Action -eq 'Install') { Install-App $app }
                    else { Download-App $app }
                    $message = 'Готово'
                }
            } catch {
                $status = 'Error'; $message = $_.Exception.Message; $failed[$app.Key] = $true
                Write-Host $message -ForegroundColor Red
            }
        }
        Write-SetupLog "$($app.Key): $status $message"
        [pscustomobject]@{Key=$app.Key; Name=$app.Name; Status=$status; Message=$message}
    }
    if ($Action -eq 'Install') { Invoke-TerminalDefaults $Keys -Preview:$Preview }
}

function Show-Report($Results) {
    Write-Host "`nРезультат:" -ForegroundColor Cyan
    $Results | Format-Table Name,Status,Message -Wrap -AutoSize | Out-Host
    Write-Host 'После установки откройте новый терминал. В Codex/Claude войдите в аккаунт; в Amnezia импортируйте VPN-конфиг.'
    if (@($Results | Where-Object { $_.Key -eq 'nvidia' -and $_.Status -eq 'Manual' }).Count -gt 0) {
        Write-Host 'NVIDIA: скачивание и установка драйвера завершаются на официальном сайте. Драйвер ещё не установлен этим скриптом.' -ForegroundColor Yellow
    }
}

function Initialize-OperationLog {
    $logDirectory = Join-Path $script:DataRoot 'logs'
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    $script:LogFile = Join-Path $logDirectory ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N') + '.log')
}

function Show-Menu([int]$Cursor, $Selected, $Statuses, [string]$Notice) {
    Clear-Host
    Write-Host '  DOTFILES / WINDOWS' -ForegroundColor Cyan
    Write-Host '  Установка программ' -ForegroundColor DarkGray
    Write-Host ''
    $actions = @('Установить всё', ('Установить выбранное ({0})' -f $Selected.Count))
    for ($index = 0; $index -lt $actions.Count; $index++) {
        $pointer = ' '; if ($index -eq $Cursor) { $pointer = '>' }
        $color = 'White'
        if ($index -eq 1 -and $Selected.Count -eq 0) { $color = 'DarkGray' }
        if ($index -eq $Cursor) { $color = 'Cyan' }
        Write-Host ('  {0} {1}' -f $pointer,$actions[$index]) -ForegroundColor $color
    }
    Write-Host ''
    for ($index = 0; $index -lt $script:Catalog.Count; $index++) {
        $app = $script:Catalog[$index]
        $pointer = ' '; if (($index + 2) -eq $Cursor) { $pointer = '>' }
        $mark = ' '; if ($Selected.ContainsKey($app.Key)) { $mark = 'x' }
        $color = 'Gray'; if (($index + 2) -eq $Cursor) { $color = 'Cyan' }
        Write-Host ('  {0} [{1}] {2,-20} {3}' -f $pointer,$mark,$app.Name,$Statuses[$app.Key]) -ForegroundColor $color
    }
    $pointer = ' '; $color = 'DarkGray'
    if ($Cursor -eq ($script:Catalog.Count + 2)) { $pointer = '>'; $color = 'Cyan' }
    Write-Host ('  {0} Выход' -f $pointer) -ForegroundColor $color
    Write-Host '  Стрелки: перемещение | Enter: выбрать / выполнить | Esc: выход'
    Write-Host '  Программы можно отмечать также пробелом.' -ForegroundColor DarkGray
    Write-Host '  Terminal + Preview: настроить запуск по умолчанию. Нужен интернет.' -ForegroundColor DarkGray
    if ($Notice) {
        Write-Host ('  ' + $Notice) -ForegroundColor Yellow
    }
}

function Get-MenuKeyResult([string]$Key, [int]$Cursor, $Selected) {
    # Both action rows, the program rows and Exit share the same navigation.
    $rowCount = $script:Catalog.Count + 3
    $result = [pscustomobject]@{Cursor=$Cursor; Action='None'; Keys=@(); Notice=''}
    switch ($Key) {
        'UpArrow' { $result.Cursor = ($Cursor - 1 + $rowCount) % $rowCount }
        'DownArrow' { $result.Cursor = ($Cursor + 1) % $rowCount }
        'Escape' { $result.Action = 'Exit' }
        { $_ -in @('Enter','Spacebar') } {
            if ($Cursor -ge 2 -and $Cursor -lt ($script:Catalog.Count + 2)) {
                $appKey = $script:Catalog[$Cursor - 2].Key
                if ($Selected.ContainsKey($appKey)) { $Selected.Remove($appKey) }
                else { $Selected[$appKey] = $true }
            } elseif ($Key -eq 'Enter') {
                if ($Cursor -eq 0) {
                    $result.Action = 'Install'
                    $result.Keys = @($script:Catalog.Key)
                } elseif ($Cursor -eq 1) {
                    $result.Keys = @($script:Catalog | Where-Object { $Selected.ContainsKey($_.Key) } | ForEach-Object Key)
                    if ($result.Keys.Count -gt 0) { $result.Action = 'Install' }
                    else { $result.Notice = 'Отметьте нужные программы в списке ниже.' }
                } else { $result.Action = 'Exit' }
            }
        }
    }
    return $result
}

function Read-MenuKey {
    return [Console]::ReadKey($true).Key.ToString()
}

function Get-MenuStatuses {
    $statuses = @{}
    foreach ($app in $script:Catalog) {
        if ($app.Key -eq 'nvidia') {
            $hardware = Get-NvidiaHardware
            $text = 'Выбрать драйвер на сайте'
            if ($hardware.Detected -eq $false) { $text = 'NVIDIA не обнаружена / пропуск' }
            elseif ($null -eq $hardware.Detected) { $text = 'GPU не определена / ручной подбор' }
            else { $text = ($hardware.Names -join ', ') + ' / ручной подбор' }
            $statuses[$app.Key] = $text
            continue
        }
        $text = 'Не установлено'
        if (Test-AppInstalled $app) { $text = 'Установлено' }
        if ($null -ne (Get-CachedDownload $app)) { $text += ' / Скачано' }
        $statuses[$app.Key] = $text
    }
    return $statuses
}

function Start-SetupMenu {
    if ([Console]::IsInputRedirected -or $Host.Name -ne 'ConsoleHost') {
        throw 'Откройте обычный терминал для меню или используйте -All / -Apps / -List.'
    }
    $selected = @{}
    $cursor = 0
    $notice = ''
    $statuses = Get-MenuStatuses
    while ($true) {
        Show-Menu $cursor $selected $statuses $notice
        $inputResult = Get-MenuKeyResult (Read-MenuKey) $cursor $selected
        $cursor = $inputResult.Cursor
        $notice = $inputResult.Notice
        if ($inputResult.Action -eq 'Exit') { return }
        if ($inputResult.Action -eq 'Install') {
            Clear-Host
            Initialize-OperationLog
            $results = @(Invoke-SetupAction $inputResult.Keys 'Install')
            Show-Report $results
            Write-Host "Журнал: $script:LogFile"
            Write-Host "`nEnter — вернуться в меню..."
            while ((Read-MenuKey) -ne 'Enter') { }
            Update-SessionPath
            $statuses = Get-MenuStatuses
        }
    }
}

function Invoke-SetupMain {
    if ($env:OS -ne 'Windows_NT') { throw 'Эта версия установщика поддерживает Windows.' }
    # powershell.exe -File passes comma-separated app names as one string.
    if ($Apps) { $Apps = @($Apps | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }
    if ($All -and $Apps) { throw 'Используйте -All или -Apps, а не оба параметра.' }
    if ($List -and ($All -or $Apps -or $Download -or $DryRun)) { throw '-List используется отдельно.' }
    if (($Download -or $DryRun) -and -not ($All -or $Apps)) { throw 'Для -Download / -DryRun укажите -All или -Apps.' }
    Update-SessionPath
    if ($List) {
        $statuses = Get-MenuStatuses
        $script:Catalog | Select-Object Key,Name,Id,@{Name='Status';Expression={$statuses[$_.Key]}} | Format-Table -AutoSize | Out-Host
        return 0
    }
    if (-not ($All -or $Apps)) { Start-SetupMenu; return 0 }
    $keys = $Apps; if ($All) { $keys = @($script:Catalog.Key) }
    foreach ($key in $keys) { Get-App $key | Out-Null }
    if (-not $DryRun) { Initialize-OperationLog }
    $action = 'Install'; if ($Download) { $action = 'Download' }
    $results = @(Invoke-SetupAction $keys $action -Preview:$DryRun)
    Show-Report $results
    if ($script:LogFile) { Write-Host "Журнал: $script:LogFile" }
    if (@($results | Where-Object { $_.Status -in @('Error','Blocked') }).Count -gt 0) { return 1 }
    if (@($results | Where-Object Status -eq 'Manual').Count -gt 0) { return 2 }
    return 0
}

# Dot sourcing loads functions for local tests without performing any action.
if ($MyInvocation.InvocationName -ne '.') {
    $ErrorActionPreference = 'Stop'
    try { $setupExitCode = Invoke-SetupMain; exit $setupExitCode }
    catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }
}
