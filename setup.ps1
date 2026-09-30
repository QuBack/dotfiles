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
$script:CommandCache = @{}
$script:NvidiaHardware = $null
$script:Catalog = @(
    [pscustomobject]@{Key='git'; Name='Git'; Id='Git.Git'; Kind='winget'; Commands=@('git.exe'); Pattern='^Git( version)? '; Dependencies=@()},
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

function Test-AppInstalled($App) {
    if ($App.Key -eq 'node') { return (Test-NpmRuntimeReady) }
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
}

function Show-Report($Results) {
    Write-Host "`nРезультат:" -ForegroundColor Cyan
    $Results | Format-Table Name,Status,Message -Wrap -AutoSize | Out-Host
    Write-Host 'После установки откройте новый терминал. В Codex/Claude войдите в аккаунт; в Amnezia импортируйте VPN-конфиг.'
    if (@($Results | Where-Object Status -eq 'Manual').Count -gt 0) {
        Write-Host 'NVIDIA: скачивание и установка драйвера завершаются на официальном сайте. Драйвер ещё не установлен этим скриптом.' -ForegroundColor Yellow
    }
}

function Initialize-OperationLog {
    $logDirectory = Join-Path $script:DataRoot 'logs'
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    $script:LogFile = Join-Path $logDirectory ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N') + '.log')
}

function Show-Menu([int]$Cursor, $Selected, $Statuses) {
    Clear-Host
    Write-Host '  DOTFILES / WINDOWS' -ForegroundColor Cyan
    Write-Host '  Рабочие программы за один запуск' -ForegroundColor DarkGray
    Write-Host ''
    for ($index = 0; $index -lt $script:Catalog.Count; $index++) {
        $app = $script:Catalog[$index]
        $pointer = ' '; if ($index -eq $Cursor) { $pointer = '>' }
        $mark = ' '; if ($Selected.ContainsKey($app.Key)) { $mark = 'x' }
        $color = 'Gray'; if ($index -eq $Cursor) { $color = 'Cyan' }
        Write-Host ('  {0} [{1}] {2,-18} {3}' -f $pointer,$mark,$app.Name,$Statuses[$app.Key]) -ForegroundColor $color
    }
    Write-Host ''
    Write-Host '  Стрелки: выбор | Пробел: отметить | S: отметить/снять всё'
    Write-Host '  D: скачать отмеченные | I: установить отмеченные | A: установить всё'
    Write-Host '  P: показать план | R: проверить статусы | O: открыть загрузки | Q: выход'
    Write-Host ''
    Write-Host '  Установка через WinGet требует интернет; сохранённые файлы можно открыть вручную.' -ForegroundColor DarkGray
    Write-Host '  Codex и Claude устанавливаются через npm; Node.js LTS подготавливается автоматически.' -ForegroundColor DarkGray
    Write-Host '  NVIDIA: официальный подбор драйвера в браузере, установка вручную.' -ForegroundColor DarkGray
    if (-not (Find-SetupCommand 'winget.exe')) {
        Write-Host '  WinGet будет подготовлен при первой операции с программами Windows.' -ForegroundColor Yellow
    }
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
    foreach ($app in $script:Catalog) { $selected[$app.Key] = $true }
    $cursor = 0
    $statuses = Get-MenuStatuses
    while ($true) {
        Show-Menu $cursor $selected $statuses
        $key = [Console]::ReadKey($true)
        switch ($key.Key.ToString()) {
            'UpArrow' { $cursor = ($cursor - 1 + $script:Catalog.Count) % $script:Catalog.Count }
            'DownArrow' { $cursor = ($cursor + 1) % $script:Catalog.Count }
            'Spacebar' {
                $appKey = $script:Catalog[$cursor].Key
                if ($selected.ContainsKey($appKey)) { $selected.Remove($appKey) } else { $selected[$appKey] = $true }
            }
            'S' {
                if ($selected.Count -eq $script:Catalog.Count) { $selected.Clear() }
                else { foreach ($app in $script:Catalog) { $selected[$app.Key] = $true } }
            }
            'Q' { return }
            'R' { Update-SessionPath; $statuses = Get-MenuStatuses }
            'O' {
                $folder = Join-Path $script:DataRoot 'downloads'
                if (Test-Path -LiteralPath $folder) { Start-Process explorer.exe -ArgumentList ('"' + $folder + '"') -WindowStyle Hidden }
            }
            { $_ -in @('D','I','A','P') } {
                $keys = @($script:Catalog | Where-Object { $selected.ContainsKey($_.Key) } | ForEach-Object Key)
                if ($key.Key.ToString() -eq 'A') { $keys = @($script:Catalog.Key) }
                if ($keys.Count -eq 0) { continue }
                $action = 'Install'; if ($key.Key.ToString() -eq 'D') { $action = 'Download' }
                $preview = $key.Key.ToString() -eq 'P'
                if (-not $preview) { Initialize-OperationLog }
                $results = @(Invoke-SetupAction $keys $action -Preview:$preview)
                Show-Report $results
                if (-not $preview) { Write-Host "Журнал: $script:LogFile" }
                Write-Host "`nНажмите любую клавишу для возврата в меню..."
                [Console]::ReadKey($true) | Out-Null
                $statuses = Get-MenuStatuses
            }
        }
    }
}

function Invoke-SetupMain {
    if ($env:OS -ne 'Windows_NT') { throw 'Эта версия установщика поддерживает Windows.' }
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
