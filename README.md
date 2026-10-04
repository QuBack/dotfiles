# Рабочий компьютер за один запуск

Консольный установщик программ с меню на русском языке. Текущая версия — для
Windows 10/11, Windows PowerShell 5.1 или PowerShell 7. Python, Node.js и модули
для интерфейса не нужны для запуска самого установщика.

## Запуск

Скачайте **`setup.ps1`** и запустите в терминале из папки с файлом:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

Если скачали репозиторий целиком, можно дважды нажать `start-windows.cmd`.
Этот небольшой файл запускает лежащий рядом `setup.ps1`. Для установки
достаточно одного `setup.ps1`: он не зависит от остальных файлов репозитория.

После публикации на GitHub файл можно скачать из браузера через **Raw → Download**.
Пример скачивания из PowerShell (замените `OWNER` своим GitHub-логином):

```powershell
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/OWNER/dotfiles/main/setup.ps1' -OutFile setup.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

`ExecutionPolicy Bypass` действует только в запущенном процессе. Начинайте из
обычного терминала своего пользователя; отдельные установщики могут запросить
права администратора. Нужен интернет. Если WinGet отсутствует, приложение
подготовит его при первой установке/скачивании через официальный модуль Microsoft.
Подготовка WinGet может потребовать дополнительного подтверждения или перезапуска
терминала на конкретной Windows; в случае ошибки приложение покажет причину.

## Меню

```text
  DOTFILES / WINDOWS
  Установка программ

  > Установить всё
    Установить выбранное (0)

    [ ] Git                  Установлено
    [ ] Windows Terminal     Не установлено
    [ ] PowerShell 7 Preview Не установлено
    [ ] Google Chrome        Не установлено
    [ ] VS Code              Не установлено
    [ ] Python 3.13          Не установлено
    [ ] Node.js LTS          Не установлено
    [ ] Codex CLI            Не установлено
    [ ] Codex (интерфейс)    Не установлено
    [ ] Claude Code CLI      Не установлено
    [ ] Claude (интерфейс)   Не установлено
    [ ] Obsidian             Не установлено
    [ ] AmneziaVPN           Не установлено
    [ ] VLC                  Не установлено
    [ ] Steam                Не установлено
    [ ] NVIDIA драйверы      GTX 1660 Ti / ручной подбор
    Выход
  Стрелки: перемещение | Enter: выбрать / выполнить | Esc: выход
  Программы можно отмечать также пробелом.
  Terminal + Preview: настроить запуск по умолчанию. Нужен интернет.
```

| Клавиша | Действие |
|---|---|
| ↑ / ↓ | Переместить курсор |
| Enter | На программе — переключить отметку; на действии — выполнить его |
| Пробел | Отметить / снять отметку с программы |
| Esc | Выйти |

Для полного набора выберите «Установить всё» и нажмите Enter. Для отдельных
программ отметьте их в списке, перейдите на «Установить выбранное» и нажмите
Enter. Изначально отметок нет; пустой выбор не запускает установку.
Статусы обновляются автоматически после операции. Чтобы закрыть приложение,
выберите «Выход» или нажмите Esc.

Скачивание, предварительный просмотр и вывод списка доступны через параметры
командной строки ниже.

Уже установленные программы пропускаются; настройка запуска Terminal и Preview
выполняется также при повторном выборе уже установленных программ.
Их наличие проверяется по командам
в PATH и записям установленных приложений Windows; удалённые вручную файлы
при оставшихся записях реестра могут потребовать исправления средствами Windows.
Для обновления программ используйте команды ниже. Codex CLI и Claude Code CLI
устанавливаются через npm. Выбор любого из них автоматически добавляет Node.js
LTS с npm, если Node.js отсутствует, старее 22 или npm не найден. Подходящий
Node.js с npm пропускается. При необходимости Node.js LTS обновляется или
переустанавливается через WinGet; это может повлиять на проекты со старой версией
Node.js. Уже установленные CLI пропускаются независимо от способа их установки.
Ошибка подготовки Node.js блокирует оба CLI, но не мешает независимым программам.

### Приложение или CLI

Для Codex и Claude предусмотрены отдельные отметки «CLI» и «интерфейс».
Можно установить любой вариант или оба одновременно. «Установить всё» включает
оба варианта каждого инструмента, Google Chrome и Steam.

| Вариант | Ключ для `-Apps` | Способ установки |
|---|---|---|
| Codex CLI | `codex` | npm: `@openai/codex` |
| Codex с интерфейсом | `codex-desktop` | WinGet, источник Microsoft Store: `9PLM9XGG6VKS` |
| Claude Code CLI | `claude` | npm: `@anthropic-ai/claude-code` |
| Claude Code с интерфейсом | `claude-desktop` | WinGet: `Anthropic.Claude` (Claude Desktop, вкладка Code) |
| Google Chrome | `chrome` | WinGet: `Google.Chrome` |
| Steam | `steam` | WinGet: `Valve.Steam` |

Приложения не требуют установки отдельного CLI и не добавляют Node.js/npm
в план. Их наличие проверяется отдельно от CLI. Старые команды с ключами
`codex` и `claude` продолжают устанавливать CLI.

В актуальной [OpenAI Docs](https://learn.chatgpt.com/docs/windows/windows-app)
приложение Codex описывается как ChatGPT desktop app; в меню установщика
сохранено понятное обозначение «Codex (интерфейс)». После установки найдите
Codex/ChatGPT в меню «Пуск» и войдите в аккаунт.
Для [Claude Code в Claude Desktop](https://code.claude.com/docs/en/desktop)
откройте вкладку Code; требуется подходящая платная подписка Claude.
Установка программы сама по себе не предоставляет доступ к сервису.

## Без меню

```powershell
# Установить всё из каталога
.\setup.ps1 -All

# Только нужные программы
.\setup.ps1 -Apps codex,claude,obsidian

# Codex и Claude с графическим интерфейсом
.\setup.ps1 -Apps codex-desktop,claude-desktop

# Оба интерфейса и оба CLI
.\setup.ps1 -Apps codex,codex-desktop,claude,claude-desktop

# Современный терминал и PowerShell 7 Preview
.\setup.ps1 -Apps terminal,powershell-preview

# Google Chrome и Steam
.\setup.ps1 -Apps chrome,steam

# Скачать выбранные программы
.\setup.ps1 -Apps amnezia,obsidian -Download

# Посмотреть весь план; ничего не скачивает и не создаёт файлы
.\setup.ps1 -All -DryRun

# Посмотреть доступные программы и статусы
.\setup.ps1 -List

# Хранить загрузки и журнал в выбранной папке
.\setup.ps1 -DataDirectory D:\WorkstationSetup
```

Если политика выполнения блокирует прямой запуск `.\setup.ps1`, используйте
полную команду запуска с `powershell.exe -ExecutionPolicy Bypass -File`, добавив
те же параметры после имени файла. Автоматический режим возвращает код 0 при
успехе, 1 при ошибке или заблокированной зависимости, 2 если требуется ручное
действие (драйвер NVIDIA, отдельное скачивание приложения Microsoft Store
или неподдерживаемая Windows для терминала по умолчанию).
WinGet принимает лицензии
выбранных программ, чтобы не запрашивать их в ходе каждой установки; UAC и
особенности стороннего установщика могут потребовать участия пользователя.

## Скачивание и установка

Файлы хранятся в `%LOCALAPPDATA%\DotfilesSetup\downloads`, журналы — в
`%LOCALAPPDATA%\DotfilesSetup\logs`. Выбор меню действует в текущем запуске,
а статус скачивания сохраняется между запусками. Повторный запуск с `-Download` использует
сохранённые файлы, если они существуют и их SHA256 совпадает. Удаление или
изменение файла сбрасывает статус. Неудачное скачивание не получает статус
«Скачано». Обновления с момента скачивания автоматически не проверяются:
для новой загрузки удалите соответствующий `downloads\<имя>.json`.

**Установка программ WinGet выполняется через `winget install`: он сам получает
подходящий установщик и проверяет его. Сохранённые через `-Download` установщики нужны для
ручного запуска или переноса; они не используются автоматически при установке.**
Это значит, что после `-Download` установка через WinGet может скачать пакет ещё раз.
Офлайн-установка и скачивание всех зависимостей в этой версии не реализованы.

Для `codex-desktop` поддерживается установка через источник `msstore`.
Отдельное скачивание через `-Download` в этом скрипте не поддерживается:
оно возвращает `Manual` и предлагает выбрать установку, без статуса «Скачано».
Другие выбранные загрузки продолжаются. У Microsoft Store packaged apps есть
[ограничения авторизации при скачивании через WinGet](https://learn.microsoft.com/en-us/windows/package-manager/winget/download).
Если компоненты Store отключены, проверьте их доступность перед установкой.

Для Codex CLI и Claude Code CLI `-Download` сохраняет соответствующий официальный npm-архив и
проверяет его SHA512 по метаданным npm. Скачивание этих архивов не требует
установки Node.js/npm. Установка использует сохранённый архив, иначе актуальный
`@openai/codex@latest` или `@anthropic-ai/claude-code@latest`. npm дополнительно
получает зависимости и исполняемые файлы для Windows из интернета; включена
установка optional dependencies. Архив не является полным офлайн-набором.
Сохранённый EXE Claude из предыдущей версии не используется для npm-установки.

## Драйверы NVIDIA

Пункт `nvidia` показывает определённую видеокарту и открывает
[официальный подбор драйверов NVIDIA](https://www.nvidia.com/en-us/drivers/).
На сайте выберите модель, свою Windows и драйвер, затем скачайте и запустите
установщик. И скачивание, и установка для этого пункта открывают сайт; драйвер не скачивается
и не устанавливается скриптом. Статус `Manual` в отчёте означает, что этот
шаг ещё нужно завершить. Наличие NVIDIA App не считается установкой драйвера.

Если видеокарты NVIDIA нет, пункт пропускается. Если прочитать сведения
оборудования не получилось, доступен ручной подбор. Определение оборудования
проверяет в том числе PCI-производителя `VEN_10DE`, чтобы распознать NVIDIA при
названии «Microsoft Basic Display Adapter». Это не гарантирует обнаружение
карты, которая совсем отсутствует в списке устройств Windows.

Для полностью автоматического подбора нужно отдельно реализовать сопоставление
модели GPU, версии Windows и поддерживаемой ветки драйверов. Один фиксированный
EXE для всех NVIDIA не подходит. NVIDIA App может помогать с обновлениями на
поддерживаемых картах, но перед её установкой нужно проверить
[системные требования](https://www.nvidia.com/en-us/software/nvidia-app/system-requirements/).

```powershell
# Установить VLC и открыть официальный подбор драйвера NVIDIA
.\setup.ps1 -Apps vlc,nvidia
```

После установки откройте новый терминал:

```powershell
git --version
node --version
py -3.13 --version
codex --version
claude --version
```

Первый запуск `codex` / `claude` требует входа в аккаунт. В AmneziaVPN нужно
импортировать свой VPN-конфиг. Obsidian устанавливается как приложение;
хранилище заметок переносится отдельно. Приложение не копирует личные настройки,
не сохраняет пароли и не настраивает VPN-сервер.

## Отдельные команды установки и обновления

| Программа | Установить | Обновить |
|---|---|---|
| Git | `winget install -e --id Git.Git --source winget` | `winget upgrade -e --id Git.Git --source winget` |
| Windows Terminal | `winget install -e --id Microsoft.WindowsTerminal --source winget` | `winget upgrade -e --id Microsoft.WindowsTerminal --source winget` |
| PowerShell 7 Preview | `winget install -e --id Microsoft.PowerShell.Preview --source winget` | `winget upgrade -e --id Microsoft.PowerShell.Preview --source winget` |
| Google Chrome | `winget install -e --id Google.Chrome --source winget` | `winget upgrade -e --id Google.Chrome --source winget` |
| VS Code | `winget install -e --id Microsoft.VisualStudioCode --source winget` | `winget upgrade -e --id Microsoft.VisualStudioCode --source winget` |
| Python 3.13 | `winget install -e --id Python.Python.3.13 --source winget` | `winget upgrade -e --id Python.Python.3.13 --source winget` |
| Node.js LTS | `winget install -e --id OpenJS.NodeJS.LTS --source winget` | `winget upgrade -e --id OpenJS.NodeJS.LTS --source winget` |
| Codex CLI | `npm install -g @openai/codex@latest` | `npm install -g @openai/codex@latest` |
| Codex (интерфейс) | `winget install -e --id 9PLM9XGG6VKS --source msstore` | `winget upgrade -e --id 9PLM9XGG6VKS --source msstore` |
| Claude Code CLI | `npm install -g @anthropic-ai/claude-code@latest` | `npm install -g @anthropic-ai/claude-code@latest` |
| Claude (интерфейс) | `winget install -e --id Anthropic.Claude --source winget` | `winget upgrade -e --id Anthropic.Claude --source winget` |
| Obsidian | `winget install -e --id Obsidian.Obsidian --source winget` | `winget upgrade -e --id Obsidian.Obsidian --source winget` |
| AmneziaVPN | `winget install -e --id AmneziaVPN.AmneziaVPN --source winget` | `winget upgrade -e --id AmneziaVPN.AmneziaVPN --source winget` |
| VLC | `winget install -e --id VideoLAN.VLC --source winget` | `winget upgrade -e --id VideoLAN.VLC --source winget` |
| Steam | `winget install -e --id Valve.Steam --source winget` | `winget upgrade -e --id Valve.Steam --source winget` |
| NVIDIA драйверы | `.\setup.ps1 -Apps nvidia` — открыть официальный подбор | Тот же пункт для подбора нового драйвера |

Python выбран явно в ветке 3.13, чтобы устанавливать определённое рабочее окружение.
Перед сменой версии проверьте требования своих проектов. Для установки CLI
через npm выбран минимум Node.js 22, соответствующий текущим требованиям
[Claude Code](https://code.claude.com/docs/en/setup#install-with-npm).

Источники:

- [Windows Terminal: установка](https://github.com/microsoft/terminal#via-windows-package-manager-cli-aka-winget)
- [PowerShell: установка и Preview](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-windows)
- [Манифесты Google Chrome](https://github.com/microsoft/winget-pkgs/tree/master/manifests/g/Google/Chrome)
- [WinGet: установка](https://learn.microsoft.com/en-us/windows/package-manager/winget/install)
- [WinGet: скачивание](https://learn.microsoft.com/en-us/windows/package-manager/winget/download)
- [Microsoft: восстановление WinGet](https://learn.microsoft.com/en-us/windows/package-manager/winget/troubleshooting)
- [OpenAI Docs: установка Codex через npm](https://developers.openai.com/cookbook/examples/codex/using_goals_in_codex)
- [OpenAI Docs: приложение Codex/ChatGPT для Windows](https://learn.chatgpt.com/docs/windows/windows-app)
- [Claude Code: установка](https://code.claude.com/docs/en/setup)
- [Claude Code в Claude Desktop](https://code.claude.com/docs/en/desktop)
- [Манифесты Claude Desktop](https://github.com/microsoft/winget-pkgs/tree/master/manifests/a/Anthropic/Claude)
- [Манифесты Steam](https://github.com/microsoft/winget-pkgs/tree/master/manifests/v/Valve/Steam)
- [Манифесты AmneziaVPN](https://github.com/microsoft/winget-pkgs/tree/master/manifests/a/AmneziaVPN/AmneziaVPN)
- [Загрузки AmneziaVPN](https://amnezia.org/en/downloads)
- [Загрузки Obsidian](https://obsidian.md/download)
- [Манифесты VLC](https://github.com/microsoft/winget-pkgs/tree/master/manifests/v/VideoLAN/VLC)
- [Официальные драйверы NVIDIA](https://www.nvidia.com/en-us/drivers/)

## macOS и Linux

В этой первой версии реализована Windows. Следующие отдельные скрипты смогут
использовать Homebrew для macOS и пакетный менеджер выбранного дистрибутива Linux.
Версии macOS/архитектуру и дистрибутив Linux нужно определить перед реализацией.

## Проверки

Сценарии перечислены в [TEST_PLAN.md](TEST_PLAN.md). Локальные тесты используют
подменённые операции установки/скачивания и не устанавливают программы:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\setup.tests.ps1
```

Проверено 1 октября 2026 года: 98 локальных проверок прошли в Windows PowerShell
5.1, включая выбор программ и защиту от запуска при пустом выборе. Новое меню
проверено в терминале: открытие, стрелки, отметки через Enter и пробел,
сообщение при пустом выборе и выход через Esc. `-All -DryRun` запускался
с настоящей проверкой установленных приложений. Проверены также точные пакеты
Windows Terminal / PowerShell Preview, определение MSIX и MSI и разбор списка
программ при запуске через `powershell.exe -File`. Настройка стартового профиля
проверена на временных файлах, настройка терминала Windows — с подменёнными
операциями реестра. Проверены резервные копии, сохранение JSONC, повторный запуск,
откат частичной ошибки и отсутствие изменений при DryRun/скачивании.

Проверено 3 октября 2026 года: 116 локальных проверок прошли в Windows
PowerShell 5.1 и PowerShell 7 Preview. Проверены независимый выбор приложений
и CLI, определение установленных вариантов, источник Microsoft Store для
Codex, пакеты Claude Desktop и Steam, поведение `-Download` для Store.
Также проверены `-List` в PowerShell 7 с настоящими статусами приложений
и `-DryRun` новых пунктов при запуске через `powershell.exe -File`.

Проверка реального скачивания/установки на чистой Windows, восстановления WinGet,
подбора драйвера в браузере и запросов UAC пока не выполнена. Скрипт и тесты сохранены в UTF-8 с BOM для
поддержки русского текста в Windows PowerShell 5.1.

## Следующие шаги

Git уже входит в каталог. Добавление GitHub CLI (`gh`), официального плагина
`frontend-design` для Claude Code описаны в
[NEXT_STEPS.md](NEXT_STEPS.md).

Windows Terminal (стабильный канал), PowerShell 7 Preview и Google Chrome уже
включены в меню и `-All`. WinGet выбирает доступную актуальную версию каждого пакета; уже
установленные программы пропускаются, обновление выполняется отдельной командой
из таблицы выше. Для Terminal и PowerShell Preview проверяются также MSIX-пакеты
текущего пользователя. Стабильный PowerShell 7 не считается установленным Preview.
## Запуск терминала по умолчанию

После установки выбранного `terminal` скрипт назначает стабильный Windows
Terminal терминалом Windows по умолчанию для текущего пользователя. Для этого
нужна Windows 11 либо Windows 10 22H2 с обновлением KB5026435 или более новым.
На неподдерживаемой Windows установка остаётся доступна, а отчёт показывает
ручной шаг вместо сообщения об успешной настройке.

При выборе `terminal` или `powershell-preview` скрипт также назначает Preview
стартовым профилем Terminal. Для этого обе программы должны быть установлены;
при выборочной установке недостающие программы показываются как ошибка
настройки. Выбор `chrome` отдельно не меняет настройки терминала.

Добавляется отдельный профиль «PowerShell 7 Preview (Dotfiles)» через
[JSON-фрагмент](https://learn.microsoft.com/en-us/windows/terminal/json-fragment-extensions).
В `settings.json` меняются только три параметра запуска: `defaultProfile`,
`firstWindowPreference` и `startupActions`. Старый сохранённый макет окна и
команды запуска перестают переопределять стартовый профиль; остальные профили,
тема, сочетания клавиш и комментарии сохраняются. Некорректный JSONC не
перезаписывается, ошибка показывается отдельной строкой отчёта.

Перед изменениями существующие файлы и прежние значения `HKCU\Console\%%Startup`
сохраняются в `%LOCALAPPDATA%\DotfilesSetup\backups` (либо в `backups` выбранного
`-DataDirectory`). Журнал содержит пути исходных файлов и копий. Файлы `.bak`
можно вернуть на исходное место при закрытом Terminal; значения реестра
сохранены в `terminal-delegation-*.json`. При частичной ошибке записи реестра
скрипт восстанавливает предыдущие значения. Повторный запуск с теми же
настройками не создаёт дополнительные копии.

После установки закройте и снова откройте Windows Terminal. Реальное открытие
профиля и применение системного терминала на чистой Windows ещё не проверены.
[Microsoft: установка и выбор терминала](https://learn.microsoft.com/en-us/windows/terminal/install),
[официальные значения делегирования](https://github.com/microsoft/terminal/blob/main/policies/WindowsTerminal.admx).

## Что хранить на GitHub

Храните исходные скрипты и настройки. Установщики скачиваются из источников
пакетов; `.gitignore` исключает бинарники, журналы и файлы авторизации.
Сами бинарники допустимы в GitHub Releases при наличии права их распространять;
каждый файл должен быть меньше 2 GiB. Обычный Git ограничивает файл примерно
100 MiB. [Ограничения репозитория](https://docs.github.com/en/repositories/creating-and-managing-repositories/repository-limits),
[GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases).
