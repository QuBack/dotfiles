# Следующие шаги

Обновлено 1 октября 2026 года. Упрощено меню установки, добавлены Windows Terminal
и PowerShell 7 Preview, добавлены Google Chrome и настройка запуска по умолчанию.

## Git и GitHub CLI

Git уже есть в каталоге (`Git.Git`). Следующим этапом добавить отдельный пункт
GitHub CLI (`gh`, пакет WinGet `GitHub.cli`) и проверку `gh.exe`.
Уточнить состав общего набора и автоматические зависимости для CLI.
Установка gh и вход в GitHub — отдельные шаги; вход выполняет пользователь.

## Claude Code: frontend-design

Использовать официальный плагин Anthropic
[frontend-design](https://github.com/anthropics/claude-plugins-official/tree/main/plugins/frontend-design).
Предпочтительный путь — штатные команды Claude Code после успешной установки
CLI, с областью пользователя:

```powershell
claude plugin marketplace add anthropics/claude-plugins-official
claude plugin install frontend-design@claude-plugins-official --scope user
claude plugin list
```

[Документация Anthropic](https://code.claude.com/docs/en/discover-plugins)
подтверждает установку из оболочки и необходимость регистрации marketplace
на новой машине. Перед реализацией проверить повторный запуск, уже установленный
плагин, наличие Git и обработку сетевых ошибок. Ошибку плагина показывать
отдельно от результата установки Claude Code. Эти команды пока не выполнялись.

## Терминал Windows

Выбраны и включены в каталог **Windows Terminal + PowerShell 7 Preview**
(`terminal` и `powershell-preview`).
Терминал отвечает за окно, вкладки и панели, PowerShell — за исполнение команд.
Текущий установщик продолжает работать в Windows PowerShell 5.1.

- [Windows Terminal](https://learn.microsoft.com/en-us/windows/terminal/):
  удобный основной вариант для Windows, PowerShell, cmd и WSL.
- [WezTerm](https://wezterm.org/index.html): альтернатива для одинаковой среды
  на Windows/macOS/Linux и гибкой настройки через Lua.
- [PowerShell 7](https://learn.microsoft.com/en-us/powershell/scripting/install/install-powershell-on-windows):
  отдельная оболочка, устанавливается рядом с Windows PowerShell 5.1.

Оба пункта входят в «Установить всё» и доступны для отдельного выбора.
Версия выбирается WinGet без фиксации номера. Добавлены системный терминал
Windows Terminal по умолчанию и отдельный стартовый профиль PowerShell 7 Preview.
Существующие профили сохраняются, изменённые файлы и значения реестра копируются
в `backups`. Реальное применение на чистой Windows ещё не проверено.

## zsh и удобства — следующий этап

Для Windows предлагается отдельный профиль **WSL + Ubuntu + zsh + Oh My Zsh**;
основным профилем Windows остаётся PowerShell 7 Preview. Перед реализацией
согласовать дистрибутив, тему, набор плагинов и работу с существующими `.zshrc`.
WSL и zsh пока не устанавливаются.

Кандидаты для обсуждения: автоподсказки, подсветка синтаксиса, поиск истории
через fzf и быстрые переходы по каталогам через zoxide. Для PowerShell отдельно
можно обсудить PSReadLine и оформление приглашения. Конфигурации должны
сохранять пользовательские изменения и создавать резервные копии.

[Microsoft: WSL](https://learn.microsoft.com/en-us/windows/wsl/),
[официальный Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh).
