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
  Рабочие программы за один запуск

  > [x] Git                Установлено
    [x] VS Code            Не установлено
    [x] Python 3.13        Не установлено
    [x] Node.js LTS        Не установлено
    [x] Codex CLI          Не установлено
    [x] Claude Code        Не установлено
    [x] Obsidian           Не установлено
    [x] AmneziaVPN         Не установлено / Скачано
    [x] VLC                Не установлено
    [x] NVIDIA драйверы    GTX 1660 Ti / ручной подбор
```

| Клавиша | Действие |
|---|---|
| ↑ / ↓ | Переместить курсор |
| Пробел | Отметить / снять отметку |
| S | Отметить / снять всё |
| D | Скачать отмеченные программы |
| I | Установить отмеченные программы |
| A | Установить программы из списка; для NVIDIA открыть официальный подбор |
| P | Показать план установки без изменений |
| R | Проверить статусы заново |
| O | Открыть папку скачанных файлов |
| Q | Выйти |

При открытии меню отмечены все программы. Установка начинается только после
нажатия I или A; скачивание — после D. Перед первой операцией можно снять
лишние отметки или посмотреть план через P.

Уже установленные программы пропускаются. Их наличие проверяется по командам
в PATH и записям установленных приложений Windows; удалённые вручную файлы
при оставшихся записях реестра могут потребовать исправления средствами Windows.
Для обновления программ используйте команды ниже. Codex и Claude Code
устанавливаются через npm. Выбор любого из них автоматически добавляет Node.js
LTS с npm, если Node.js отсутствует, старее 22 или npm не найден. Подходящий
Node.js с npm пропускается. При необходимости Node.js LTS обновляется или
переустанавливается через WinGet; это может повлиять на проекты со старой версией
Node.js. Уже установленные CLI пропускаются независимо от способа их установки.
Ошибка подготовки Node.js блокирует оба CLI, но не мешает независимым программам.

## Без меню

```powershell
# Установить всё из каталога
.\setup.ps1 -All

# Только нужные программы
.\setup.ps1 -Apps codex,claude,obsidian

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
успехе, 1 при ошибке или заблокированной зависимости, 2 если требуется ручная
установка драйвера NVIDIA. WinGet принимает лицензии
выбранных программ, чтобы не запрашивать их в ходе каждой установки; UAC и
особенности стороннего установщика могут потребовать участия пользователя.

## Скачивание и установка

Файлы хранятся в `%LOCALAPPDATA%\DotfilesSetup\downloads`, журналы — в
`%LOCALAPPDATA%\DotfilesSetup\logs`. Выбор меню действует в текущем запуске,
а статус скачивания сохраняется между запусками. Повторное D использует
сохранённые файлы, если они существуют и их SHA256 совпадает. Удаление или
изменение файла сбрасывает статус. Неудачное скачивание не получает статус
«Скачано». Обновления с момента скачивания автоматически не проверяются:
для новой загрузки удалите соответствующий `downloads\<имя>.json`.

**Установка программ WinGet выполняется через `winget install`: он сам получает
подходящий установщик и проверяет его. Сохранённые через D установщики нужны для
ручного запуска или переноса; они не используются автоматически командой I/A.**
Это значит, что после D установка через WinGet может скачать пакет ещё раз.
Офлайн-установка и скачивание всех зависимостей в этой версии не реализованы.

Для Codex и Claude Code D сохраняет соответствующий официальный npm-архив и
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
установщик. И D, и I/A для этого пункта открывают сайт; драйвер не скачивается
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
| VS Code | `winget install -e --id Microsoft.VisualStudioCode --source winget` | `winget upgrade -e --id Microsoft.VisualStudioCode --source winget` |
| Python 3.13 | `winget install -e --id Python.Python.3.13 --source winget` | `winget upgrade -e --id Python.Python.3.13 --source winget` |
| Node.js LTS | `winget install -e --id OpenJS.NodeJS.LTS --source winget` | `winget upgrade -e --id OpenJS.NodeJS.LTS --source winget` |
| Codex CLI | `npm install -g @openai/codex@latest` | `npm install -g @openai/codex@latest` |
| Claude Code | `npm install -g @anthropic-ai/claude-code@latest` | `npm install -g @anthropic-ai/claude-code@latest` |
| Obsidian | `winget install -e --id Obsidian.Obsidian --source winget` | `winget upgrade -e --id Obsidian.Obsidian --source winget` |
| AmneziaVPN | `winget install -e --id AmneziaVPN.AmneziaVPN --source winget` | `winget upgrade -e --id AmneziaVPN.AmneziaVPN --source winget` |
| VLC | `winget install -e --id VideoLAN.VLC --source winget` | `winget upgrade -e --id VideoLAN.VLC --source winget` |
| NVIDIA драйверы | `.\setup.ps1 -Apps nvidia` — открыть официальный подбор | Тот же пункт для подбора нового драйвера |

Python выбран явно в ветке 3.13, чтобы устанавливать определённое рабочее окружение.
Перед сменой версии проверьте требования своих проектов. Для установки CLI
через npm выбран минимум Node.js 22, соответствующий текущим требованиям
[Claude Code](https://code.claude.com/docs/en/setup#install-with-npm).

Источники:

- [WinGet: установка](https://learn.microsoft.com/en-us/windows/package-manager/winget/install)
- [WinGet: скачивание](https://learn.microsoft.com/en-us/windows/package-manager/winget/download)
- [Microsoft: восстановление WinGet](https://learn.microsoft.com/en-us/windows/package-manager/winget/troubleshooting)
- [OpenAI Docs: установка Codex через npm](https://developers.openai.com/cookbook/examples/codex/using_goals_in_codex)
- [Claude Code: установка](https://code.claude.com/docs/en/setup)
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

Проверено 30 сентября 2026 года: 41 локальная проверка прошла в Windows PowerShell
5.1 и PowerShell 7. В терминале проверены открытие меню, стрелки, переключение
отметок, просмотр плана, возврат в список и выход. `-List` и `-All -DryRun`
запускались с настоящей проверкой установленных приложений.

Проверка реального скачивания/установки на чистой Windows, восстановления WinGet,
подбора драйвера в браузере и запросов UAC пока не выполнена. Скрипт и тесты сохранены в UTF-8 с BOM для
поддержки русского текста в Windows PowerShell 5.1.

## Что хранить на GitHub

Храните исходные скрипты и настройки. Установщики скачиваются из источников
пакетов; `.gitignore` исключает бинарники, журналы и файлы авторизации.
Сами бинарники допустимы в GitHub Releases при наличии права их распространять;
каждый файл должен быть меньше 2 GiB. Обычный Git ограничивает файл примерно
100 MiB. [Ограничения репозитория](https://docs.github.com/en/repositories/creating-and-managing-repositories/repository-limits),
[GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases).
