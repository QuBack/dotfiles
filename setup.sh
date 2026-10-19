#!/bin/bash
# Standalone macOS workstation installer. No repository checkout is required.
# Run: bash setup.sh   (bash 3.2 from macOS is enough)
#
# Homebrew formulae are never used: on Intel Macs Homebrew no longer ships
# bottles (Tier 3 since September 2026) and would compile everything from
# source. GUI apps come from casks (prebuilt vendor binaries), CLI tools from
# official prebuilt releases.

DATA_ROOT="${DOTFILES_DATA:-$HOME/Library/Application Support/DotfilesSetup}"
LOG_FILE=''
ARCH="$(uname -m)"

# key|Name|kind|id|commands (space separated)|app bundle in /Applications|dependencies
CATALOG='git|Git (Command Line Tools)|clt|xcode-select||
brew|Homebrew|brew|https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh|brew||
gh|GitHub CLI|release|cli/cli|gh||
iterm2|iTerm2|cask|iterm2||iTerm.app|brew
font|JetBrains Mono Nerd Font|cask|font-jetbrains-mono-nerd-font|||brew
iterm-profile|iTerm2: тема и шрифт|iterm-profile|8C1E5A2D-4F3B-4C6E-9A7D-D0F11E5E7A01|||iterm2 font
starship|Starship (промпт)|release|starship/starship|starship||
fzf|fzf (поиск)|release|junegunn/fzf|fzf||
bat|bat (cat с подсветкой)|release|sharkdp/bat|bat||
lsd|lsd (ls с иконками)|release|lsd-rs/lsd|lsd||
zsh|zsh: Oh My Zsh + плагины|zsh|https://github.com/ohmyzsh/ohmyzsh.git|||git starship
unarchiver|The Unarchiver|cask|the-unarchiver||The Unarchiver.app|brew
chrome|Google Chrome|cask|google-chrome||Google Chrome.app|brew
telegram|Telegram Desktop|cask|telegram-desktop||Telegram Desktop.app|brew
vscode|VS Code|cask|visual-studio-code|code|Visual Studio Code.app|brew
uv|uv|script|https://astral.sh/uv/install.sh|uv||
python|Python 3.13|uv-python|3.13|python3.13||uv
poetry|Poetry|uv-tool|poetry|poetry||uv
node|Node.js LTS|node|https://nodejs.org/dist|node||
docker|Docker Desktop|cask|docker-desktop|docker|Docker.app|brew
codex|Codex CLI|cask|codex|codex||brew
codex-desktop|Codex (интерфейс)|cask|codex-app||Codex.app|brew
claude|Claude Code CLI|cask|claude-code|claude||brew
claude-desktop|Claude (интерфейс)|cask|claude||Claude.app|brew
obsidian|Obsidian|cask|obsidian||Obsidian.app|brew
amnezia|AmneziaVPN|cask|amneziavpn||AmneziaVPN.app|brew
vlc|VLC|cask|vlc||VLC.app|brew
steam|Steam|cask|steam||Steam.app|brew'

catalog_keys() { printf '%s\n' "$CATALOG" | cut -d'|' -f1; }

app_field() { # key field-number
    printf '%s\n' "$CATALOG" | awk -F'|' -v k="$1" -v f="$2" '$1 == k { print $f; exit }'
}

app_exists() { [ -n "$(app_field "$1" 1)" ]; }

log() {
    if [ -n "$LOG_FILE" ]; then printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*" >> "$LOG_FILE"; fi
}

say() { printf '%s\n' "$*"; log "$*"; }

pad() { # text width; printf pads by bytes, which breaks Cyrillic columns
    local text="$1" fill=$(( $2 - ${#1} ))
    [ $fill -gt 0 ] && text="$text$(printf '%*s' "$fill" '')"
    printf '%s' "$text"
}

color() { # code text
    if [ -t 1 ]; then printf '\033[%sm%s\033[0m' "$1" "$2"; else printf '%s' "$2"; fi
}

refresh_path() {
    local dir
    for dir in "$HOME/.local/bin" /usr/local/bin /opt/homebrew/bin; do
        case ":$PATH:" in *":$dir:"*) ;; *) [ -d "$dir" ] && PATH="$dir:$PATH" ;; esac
    done
    export PATH
}

brew_bin() {
    command -v brew 2>/dev/null && return
    local candidate
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$candidate" ]; then printf '%s\n' "$candidate"; return; fi
    done
    return 1
}

node_major() {
    local version
    version="$(node --version 2>/dev/null)" || { echo 0; return; }
    version="${version#v}"
    echo "${version%%.*}"
}

is_installed() {
    local key="$1" kind cmd bundle
    kind="$(app_field "$key" 3)"
    case "$kind" in
        clt) xcode-select -p >/dev/null 2>&1 && /usr/bin/git --version >/dev/null 2>&1; return ;;
        brew) brew_bin >/dev/null; return ;;
        node) [ "$(node_major)" -ge 22 ] && command -v npm >/dev/null 2>&1; return ;;
        # Config items count as installed only while they match this script's version.
        zsh) zsh_installed; return ;;
        iterm-profile) [ "$(cat "$ITERM_PROFILE_FILE" 2>/dev/null)" = "$(iterm_profile_json)" ]; return ;;
    esac
    if [ "$key" = font ]; then
        ls "$HOME/Library/Fonts"/JetBrainsMonoNerdFont* >/dev/null 2>&1 || ls /Library/Fonts/JetBrainsMonoNerdFont* >/dev/null 2>&1; return
    fi
    bundle="$(app_field "$key" 6)"
    if [ -n "$bundle" ] && { [ -d "/Applications/$bundle" ] || [ -d "$HOME/Applications/$bundle" ]; }; then return 0; fi
    for cmd in $(app_field "$key" 5); do
        command -v "$cmd" >/dev/null 2>&1 && return 0
    done
    return 1
}

# Prints the ordered plan: dependencies of missing apps come first, each key once.
install_plan() {
    local seen=' ' key
    add_plan_key() {
        local k="$1" dep
        case "$seen" in *" $k "*) return ;; esac
        seen="$seen$k "
        if ! is_installed "$k"; then
            for dep in $(app_field "$k" 7); do add_plan_key "$dep"; done
        fi
        printf '%s\n' "$k"
    }
    for key in "$@"; do add_plan_key "$key"; done
}

run() {
    log "\$ $*"
    if [ -n "$LOG_FILE" ]; then
        "$@" 2>&1 | tee -a "$LOG_FILE"
        return "${PIPESTATUS[0]}"
    fi
    "$@"
}

download() { # url destination
    curl --fail --location --silent --show-error --retry 3 --connect-timeout 20 -o "$2" "$1"
}

new_temp_dir() { mktemp -d "${TMPDIR:-/tmp}/dotfiles-setup.XXXXXX"; }

install_clt() {
    # The installer is a system dialog; the script cannot wait for it reliably.
    xcode-select --install >/dev/null 2>&1
    MESSAGE='Откроется окно установки Command Line Tools. Завершите его и запустите установщик снова.'
    return 2
}

install_brew() {
    local dir
    dir="$(new_temp_dir)" || return 1
    download "$(app_field brew 4)" "$dir/install.sh" || { rm -rf "$dir"; return 1; }
    # The official installer asks for the administrator password itself.
    run /bin/bash "$dir/install.sh"
    local status=$?
    rm -rf "$dir"
    [ $status -eq 0 ] || return $status
    eval "$("$(brew_bin)" shellenv)"
    local profile="$HOME/.zprofile"
    if ! grep -qs 'brew shellenv' "$profile"; then
        printf '\neval "$(%s shellenv)"\n' "$(brew_bin)" >> "$profile"
        log "Добавлено brew shellenv в $profile"
    fi
}

install_cask() {
    local brew
    brew="$(brew_bin)" || { MESSAGE='Нужен Homebrew. Выберите brew.'; return 1; }
    # Cask downloads are vendor binaries, so they stay fast on Intel too.
    HOMEBREW_NO_INSTALL_CLEANUP=1 run "$brew" install --cask "$(app_field "$1" 4)"
}

release_suffix() { # key: the end of the macOS asset name for this Mac
    local go=amd64 rust=x86_64
    [ "$ARCH" = arm64 ] && { go=arm64; rust=aarch64; }
    case "$1" in
        gh) echo "_macOS_$go.zip" ;;
        fzf) echo "-darwin_$go.tar.gz" ;;
        *) echo "-$rust-apple-darwin.tar.gz" ;;
    esac
}

# Prints "sha256:<hex> <url>" of the latest release asset ending with the suffix.
release_asset() { # release-json-file suffix
    # GitHub publishes a SHA256 digest for every release asset in the API.
    awk -v suffix="$2" '
        /"digest":/ { digest = $2; gsub(/[",]/, "", digest) }
        /"browser_download_url":/ {
            url = $2; gsub(/[",]/, "", url)
            if (substr(url, length(url) - length(suffix) + 1) == suffix) { print digest, url; exit }
            digest = ""
        }' "$1"
}

install_release() {
    local key="$1" cmd dir asset digest url binary
    cmd="$(app_field "$key" 5)"
    dir="$(new_temp_dir)" || return 1
    download "https://api.github.com/repos/$(app_field "$key" 4)/releases/latest" "$dir/release.json" || { rm -rf "$dir"; return 1; }
    asset="$(release_asset "$dir/release.json" "$(release_suffix "$key")")"
    digest="${asset%% *}"; url="${asset#* }"
    case "$digest" in
        sha256:*) ;;
        *) MESSAGE="Не найден архив $(app_field "$key" 2) для macOS $ARCH с SHA256."; rm -rf "$dir"; return 1 ;;
    esac
    say "Скачиваю $url"
    download "$url" "$dir/archive" || { rm -rf "$dir"; return 1; }
    if [ "$(shasum -a 256 "$dir/archive" | cut -d' ' -f1)" != "${digest#sha256:}" ]; then
        MESSAGE="SHA256 архива $(app_field "$key" 2) не совпадает."; rm -rf "$dir"; return 1
    fi
    mkdir "$dir/unpacked"
    case "$url" in
        *.zip) unzip -q "$dir/archive" -d "$dir/unpacked" ;;
        *) tar -xzf "$dir/archive" -C "$dir/unpacked" ;;
    esac || { rm -rf "$dir"; return 1; }
    binary="$(find "$dir/unpacked" -type f -name "$cmd" -perm -u+x | head -n1)"
    if [ -z "$binary" ]; then MESSAGE="В архиве нет программы $cmd."; rm -rf "$dir"; return 1; fi
    mkdir -p "$HOME/.local/bin"
    install -m 755 "$binary" "$HOME/.local/bin/$cmd"
    rm -rf "$dir"
    refresh_path
    run "$HOME/.local/bin/$cmd" --version
}

install_node() {
    local dir base version pkg
    dir="$(new_temp_dir)" || return 1
    base="$(app_field node 4)"
    # index.json is sorted newest first; the first entry with "lts" set is current LTS.
    version="$(curl -fsSL "$base/index.json" | tr '{' '\n' | grep -v '"lts":false' |
        sed -n 's/.*"version":"\(v[0-9.]*\)".*/\1/p' | head -n1)"
    if [ -z "$version" ]; then MESSAGE='Не удалось узнать версию Node.js LTS.'; rm -rf "$dir"; return 1; fi
    pkg="node-$version.pkg"
    download "$base/$version/$pkg" "$dir/$pkg" && download "$base/$version/SHASUMS256.txt" "$dir/SHASUMS256.txt" || { rm -rf "$dir"; return 1; }
    if ! (cd "$dir" && grep "  $pkg\$" SHASUMS256.txt | shasum -a 256 -c - >/dev/null); then
        MESSAGE='SHA256 установщика Node.js не совпадает.'; rm -rf "$dir"; return 1
    fi
    say "Node.js $version: установщик macOS запросит пароль администратора."
    run sudo /usr/sbin/installer -pkg "$dir/$pkg" -target /
    local status=$?
    rm -rf "$dir"
    [ $status -eq 0 ] || return $status
    hash -r
    run node --version
}

install_uv() {
    local dir
    dir="$(new_temp_dir)" || return 1
    download "$(app_field uv 4)" "$dir/install.sh" || { rm -rf "$dir"; return 1; }
    run /bin/sh "$dir/install.sh"
    local status=$?
    rm -rf "$dir"
    [ $status -eq 0 ] || return $status
    refresh_path
    run uv --version
}

install_uv_python() {
    command -v uv >/dev/null 2>&1 || { MESSAGE='Для Python нужен uv. Выберите uv.'; return 1; }
    run uv python install "$(app_field "$1" 4)" || return 1
    refresh_path
}

install_uv_tool() {
    command -v uv >/dev/null 2>&1 || { MESSAGE='Для Poetry нужен uv. Выберите uv и poetry.'; return 1; }
    run uv tool install --python 3.13 "$(app_field "$1" 4)" || return 1
    run uv tool update-shell
    refresh_path
    run poetry --version
}

# ---- zsh and iTerm2 configuration --------------------------------------------

ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_MANAGED="$HOME/.config/dotfiles/zshrc.zsh"
ZSH_SOURCE_LINE='[ -f ~/.config/dotfiles/zshrc.zsh ] && source ~/.config/dotfiles/zshrc.zsh'
ZSH_PLUGINS='zsh-users/zsh-autosuggestions zsh-users/zsh-syntax-highlighting'
ITERM_PROFILE_FILE="$HOME/Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json"

zsh_managed_config() {
    cat <<'ZSHRC'
# Managed by dotfiles setup.sh and replaced on every run (old copies go to backups).
# Put personal settings in ~/.zshrc after the line that sources this file.

typeset -U path
path=("$HOME/.local/bin" $path)

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""  # the prompt comes from Starship
zstyle ':omz:update' mode reminder
plugins=(git)
(( $+commands[fzf] )) && plugins+=(fzf)
plugins+=(zsh-autosuggestions zsh-syntax-highlighting)  # highlighting must stay last
source "$ZSH/oh-my-zsh.sh"

if (( $+commands[lsd] )); then
  alias ls='lsd' ll='lsd -l' la='lsd -la' lt='lsd --tree'
fi
if (( $+commands[bat] )); then
  alias cat='bat --paging=never'
fi
(( $+commands[starship] )) && eval "$(starship init zsh)"
ZSHRC
}

zsh_installed() {
    local repo
    [ -d "$ZSH_DIR/.git" ] || return 1
    for repo in $ZSH_PLUGINS; do [ -d "$ZSH_DIR/custom/plugins/${repo#*/}/.git" ] || return 1; done
    grep -qsF "$ZSH_SOURCE_LINE" "$HOME/.zshrc" || return 1
    [ "$(cat "$ZSH_MANAGED" 2>/dev/null)" = "$(zsh_managed_config)" ]
}

backup_file() { # path
    [ -f "$1" ] || return 0
    local backup="$DATA_ROOT/backups/$(basename "$1")-$(date '+%Y%m%d-%H%M%S')-$$.bak"
    mkdir -p "$DATA_ROOT/backups" && cp -p "$1" "$backup" && log "Backup: $1 -> $backup"
}

write_managed_file() { # path content; backs up a differing old copy, replaces atomically
    [ "$(cat "$1" 2>/dev/null)" = "$2" ] && return 0
    backup_file "$1" || return 1
    mkdir -p "$(dirname "$1")" || return 1
    printf '%s\n' "$2" > "$1.tmp.$$" && mv -f "$1.tmp.$$" "$1"
}

clone_once() { # url directory
    [ -d "$2/.git" ] && return 0
    run git clone --depth 1 --quiet "$1" "$2"
}

install_zsh() {
    local repo
    command -v git >/dev/null 2>&1 || { MESSAGE='Нужен Git. Выберите git.'; return 1; }
    # Plain clones instead of the Oh My Zsh installer, which would replace ~/.zshrc.
    clone_once "$(app_field zsh 4)" "$ZSH_DIR" || return 1
    for repo in $ZSH_PLUGINS; do
        clone_once "https://github.com/$repo.git" "$ZSH_DIR/custom/plugins/${repo#*/}" || return 1
    done
    write_managed_file "$ZSH_MANAGED" "$(zsh_managed_config)" || return 1
    if ! grep -qsF "$ZSH_SOURCE_LINE" "$HOME/.zshrc"; then
        backup_file "$HOME/.zshrc" || return 1
        printf '\n# dotfiles: Oh My Zsh, Starship, fzf, bat, lsd\n%s\n' "$ZSH_SOURCE_LINE" >> "$HOME/.zshrc"
    fi
    if ! zsh -i -c 'exit 0' >/dev/null 2>&1; then
        MESSAGE='Новый zsh не запускается. Проверьте zsh -i и журнал; копия прежнего ~/.zshrc в backups.'
        return 1
    fi
    MESSAGE='Готово. Откройте новую вкладку терминала.'
}

iterm_color() { # #RRGGBB -> iTerm2 color dictionary
    local hex="${1#\#}"
    LC_ALL=C awk -v r=$((16#${hex:0:2})) -v g=$((16#${hex:2:2})) -v b=$((16#${hex:4:2})) 'BEGIN {
        printf "{\"Color Space\": \"sRGB\", \"Alpha Component\": 1, \"Red Component\": %.4f, \"Green Component\": %.4f, \"Blue Component\": %.4f}", r/255, g/255, b/255 }'
}

iterm_profile_json() {
    # Catppuccin Mocha palette: https://github.com/catppuccin/iterm
    local ansi='45475A F38BA8 A6E3A1 F9E2AF 89B4FA F5C2E7 94E2D5 BAC2DE 585B70 F38BA8 A6E3A1 F9E2AF 89B4FA F5C2E7 94E2D5 A6ADC8'
    local index=0 hex colors=''
    for hex in $ansi; do
        colors="$colors      \"Ansi $index Color\": $(iterm_color "$hex"),
"
        index=$((index + 1))
    done
    cat <<JSON
{
  "Profiles": [
    {
      "Name": "Dotfiles",
      "Guid": "$(app_field iterm-profile 4)",
      "Normal Font": "JetBrainsMonoNFM-Regular 14",
      "Use Non-ASCII Font": false,
      "Columns": 120,
      "Rows": 34,
      "Unlimited Scrollback": true,
      "Silence Bell": true,
      "Option Key Sends": 2,
$colors      "Background Color": $(iterm_color 1E1E2E),
      "Foreground Color": $(iterm_color CDD6F4),
      "Bold Color": $(iterm_color CDD6F4),
      "Cursor Color": $(iterm_color F5E0DC),
      "Cursor Text Color": $(iterm_color 1E1E2E),
      "Selection Color": $(iterm_color 585B70),
      "Selected Text Color": $(iterm_color CDD6F4),
      "Link Color": $(iterm_color 89B4FA),
      "Keyboard Map": {
        "0xf702-0x280000": {"Action": 10, "Text": "b"},
        "0xf703-0x280000": {"Action": 10, "Text": "f"},
        "0xf702-0x300000": {"Action": 11, "Text": "0x1"},
        "0xf703-0x300000": {"Action": 11, "Text": "0x5"},
        "0x7f-0x80000": {"Action": 11, "Text": "0x17"},
        "0x7f-0x100000": {"Action": 11, "Text": "0x15"}
      }
    }
  ]
}
JSON
}

iterm_running() { ps -axo comm= | grep -q '/iTerm.app/Contents/MacOS/iTerm2$'; }

install_iterm_profile() {
    # Dynamic profiles are picked up live and never touch the user's own profiles.
    write_managed_file "$ITERM_PROFILE_FILE" "$(iterm_profile_json)" || return 1
    if iterm_running; then
        # A running iTerm2 overwrites its preferences on quit, so only the user can switch.
        MESSAGE='Профиль Dotfiles добавлен. Сделайте его основным: iTerm2 → Settings → Profiles → Dotfiles → Other Actions → Set as Default.'
        return 2
    fi
    run defaults write com.googlecode.iterm2 'Default Bookmark Guid' -string "$(app_field iterm-profile 4)"
    MESSAGE='Профиль Dotfiles назначен основным в iTerm2.'
}

install_app() {
    case "$(app_field "$1" 3)" in
        clt) install_clt ;;
        brew) install_brew ;;
        cask) install_cask "$1" ;;
        release) install_release "$1" ;;
        zsh) install_zsh ;;
        iterm-profile) install_iterm_profile ;;
        node) install_node ;;
        script) install_uv ;;
        uv-python) install_uv_python "$1" ;;
        uv-tool) install_uv_tool "$1" ;;
        *) MESSAGE="Неизвестный способ установки для $1"; return 1 ;;
    esac
}

plan_message() {
    case "$(app_field "$1" 3)" in
        clt) echo 'xcode-select --install (системное окно)' ;;
        brew) echo 'Официальный установщик Homebrew; запрос пароля' ;;
        cask) echo "brew install --cask $(app_field "$1" 4)" ;;
        release) echo "Релиз github.com/$(app_field "$1" 4) в ~/.local/bin, проверка SHA256" ;;
        zsh) echo 'Oh My Zsh, плагины, ~/.config/dotfiles/zshrc.zsh; ~/.zshrc только дополняется' ;;
        iterm-profile) echo 'Профиль iTerm2 Catppuccin Mocha + JetBrains Mono Nerd Font' ;;
        node) echo 'Официальный .pkg Node.js LTS; запрос пароля' ;;
        script) echo 'Официальный установщик uv в ~/.local/bin' ;;
        uv-python) echo "uv python install $(app_field "$1" 4)" ;;
        uv-tool) echo "uv tool install --python 3.13 $(app_field "$1" 4)" ;;
    esac
}

# Prints "key|status|message" lines and returns the overall exit code.
RESULTS=''
run_setup() { # preview(0/1) keys...
    local preview="$1" key status deps dep failed=' ' pending=' '
    shift
    RESULTS=''
    for key in $(install_plan "$@"); do
        status='OK'; MESSAGE=''
        deps="$(app_field "$key" 7)"
        if [ "$preview" = 1 ]; then
            status='Plan'; MESSAGE="$(plan_message "$key")"
            is_installed "$key" && MESSAGE='Уже установлено: будет пропущено'
        elif is_installed "$key"; then
            status='Skipped'; MESSAGE='Уже установлено'
        else
            for dep in $deps; do
                case "$failed" in *" $dep "*) status='Blocked'; MESSAGE='Не удалось установить зависимость' ;; esac
                case "$pending" in *" $dep "*) [ "$status" = OK ] && { status='Manual'; MESSAGE="Сначала завершите установку $(app_field "$dep" 2)"; } ;; esac
            done
            if [ "$status" = OK ]; then
                printf '\n%s\n' "$(color 36 ">>> Install : $(app_field "$key" 2)")"
                install_app "$key"
                case $? in
                    0) [ -n "$MESSAGE" ] || MESSAGE='Готово' ;;
                    2) status='Manual' ;;
                    *) status='Error'; [ -n "$MESSAGE" ] || MESSAGE='Ошибка установки, подробности выше и в журнале' ;;
                esac
            fi
            case "$status" in
                Error|Blocked) failed="$failed$key " ;;
                Manual) pending="$pending$key " ;;
            esac
        fi
        log "$key: $status $MESSAGE"
        RESULTS="$RESULTS$key|$status|$MESSAGE
"
    done
}

show_report() {
    local key status message
    printf '\n%s\n' "$(color 36 'Результат:')"
    while IFS='|' read -r key status message; do
        [ -n "$key" ] || continue
        printf '  %s %-8s %s\n' "$(pad "$(app_field "$key" 2)" 26)" "$status" "$message"
    done <<EOF
$RESULTS
EOF
    echo 'После установки откройте новый терминал. В Codex/Claude войдите в аккаунт; в Amnezia импортируйте VPN-конфиг.'
    case "$RESULTS" in *'gh|OK'*|*'gh|Skipped'*) echo 'GitHub CLI: для входа выполните gh auth login.' ;; esac
    case "$RESULTS" in *'docker|OK'*|*'docker|Skipped'*) echo 'Docker: откройте Docker Desktop, дождитесь запуска движка и выполните docker run --rm hello-world.' ;; esac
}

results_exit_code() {
    case "$RESULTS" in *'|Error|'*|*'|Blocked|'*) return 1 ;; esac
    case "$RESULTS" in *'|Manual|'*) return 2 ;; esac
    return 0
}

init_log() {
    mkdir -p "$DATA_ROOT/logs"
    LOG_FILE="$DATA_ROOT/logs/$(date '+%Y%m%d-%H%M%S')-$$.log"
    : > "$LOG_FILE"
}

status_text() {
    if is_installed "$1"; then echo 'Установлено'; else echo 'Не установлено'; fi
}

# ---- Interactive menu -------------------------------------------------------

SELECTED=' '
STATUSES=''

load_statuses() {
    local key
    STATUSES=''
    for key in $(catalog_keys); do STATUSES="$STATUSES$key|$(status_text "$key")
"; done
}

selected_keys() { # in catalog order
    local key
    for key in $(catalog_keys); do
        case "$SELECTED" in *" $key "*) printf '%s\n' "$key" ;; esac
    done
}

# Updates CURSOR, SELECTED and sets ACTION (None/Install/Exit), ACTION_KEYS, NOTICE.
menu_key() { # key-name cursor
    local name="$1" keys count rows app
    keys="$(catalog_keys)"
    count="$(printf '%s\n' "$keys" | wc -l | tr -d ' ')"
    rows=$((count + 3))
    CURSOR="$2"; ACTION='None'; ACTION_KEYS=''; NOTICE=''
    case "$name" in
        Up) CURSOR=$(( (CURSOR - 1 + rows) % rows )) ;;
        Down) CURSOR=$(( (CURSOR + 1) % rows )) ;;
        Escape) ACTION='Exit' ;;
        Enter|Space)
            if [ "$CURSOR" -ge 2 ] && [ "$CURSOR" -lt $((count + 2)) ]; then
                app="$(printf '%s\n' "$keys" | sed -n "$((CURSOR - 1))p")"
                case "$SELECTED" in
                    *" $app "*) SELECTED="${SELECTED/ $app / }" ;;
                    *) SELECTED="$SELECTED$app " ;;
                esac
            elif [ "$name" = Enter ]; then
                if [ "$CURSOR" -eq 0 ]; then
                    ACTION='Install'; ACTION_KEYS="$keys"
                elif [ "$CURSOR" -eq 1 ]; then
                    ACTION_KEYS="$(selected_keys)"
                    if [ -n "$ACTION_KEYS" ]; then ACTION='Install'; else NOTICE='Отметьте нужные программы в списке ниже.'; fi
                else
                    ACTION='Exit'
                fi
            fi
            ;;
    esac
}

read_menu_key() {
    local char rest
    IFS= read -rsn1 char
    case "$char" in
        $'\e')
            IFS= read -rsn2 -t 1 rest
            case "$rest" in '[A') echo Up ;; '[B') echo Down ;; '') echo Escape ;; *) echo Other ;; esac ;;
        '') echo Enter ;;
        ' ') echo Space ;;
        *) echo Other ;;
    esac
}

show_menu() {
    local index=0 key pointer mark text count selected_count
    count="$(catalog_keys | wc -l | tr -d ' ')"
    selected_count="$(selected_keys | grep -c .)"
    printf '\033[H\033[2J'
    echo "  $(color 36 "DOTFILES / macOS ($ARCH)")"
    echo "  $(color 90 'Установка программ')"
    echo
    for text in 'Установить всё' "Установить выбранное ($selected_count)"; do
        if [ $index -eq "$CURSOR" ]; then echo "  $(color 36 "> $text")"; else echo "    $text"; fi
        index=$((index + 1))
    done
    echo
    for key in $(catalog_keys); do
        pointer=' '; [ $index -eq "$CURSOR" ] && pointer='>'
        mark=' '; case "$SELECTED" in *" $key "*) mark='x' ;; esac
        text="$(printf '  %s [%s] %s %s' "$pointer" "$mark" "$(pad "$(app_field "$key" 2)" 26)" \
            "$(printf '%s\n' "$STATUSES" | awk -F'|' -v k="$key" '$1 == k { print $2 }')")"
        if [ $index -eq "$CURSOR" ]; then echo "$(color 36 "$text")"; else echo "$text"; fi
        index=$((index + 1))
    done
    if [ "$CURSOR" -eq $((count + 2)) ]; then echo "  $(color 36 '> Выход')"; else echo "  $(color 90 '  Выход')"; fi
    echo '  Стрелки: перемещение | Enter/пробел: выбрать / выполнить | Esc: выход'
    [ -n "$NOTICE" ] && echo "  $(color 33 "$NOTICE")"
}

start_menu() {
    if [ ! -t 0 ] || [ ! -t 1 ]; then
        echo 'Откройте обычный терминал для меню или используйте --all / --apps / --list.' >&2
        return 1
    fi
    CURSOR=0; NOTICE=''
    load_statuses
    while true; do
        show_menu
        menu_key "$(read_menu_key)" "$CURSOR"
        [ "$ACTION" = Exit ] && return 0
        if [ "$ACTION" = Install ]; then
            printf '\033[H\033[2J'
            init_log
            # shellcheck disable=SC2086
            run_setup 0 $ACTION_KEYS
            show_report
            echo "Журнал: $LOG_FILE"
            printf '\nEnter — вернуться в меню...'
            while [ "$(read_menu_key)" != Enter ]; do :; done
            refresh_path
            load_statuses
        fi
    done
}

usage() {
    cat <<'EOF'
Использование: bash setup.sh [--all | --apps git,chrome,... | --list] [--dry-run]
Без параметров открывается меню.
EOF
}

main() {
    local all=0 list=0 dry=0 apps='' key keys
    while [ $# -gt 0 ]; do
        case "$1" in
            --all) all=1 ;;
            --apps) shift; apps="$1" ;;
            --apps=*) apps="${1#--apps=}" ;;
            --list) list=1 ;;
            --dry-run) dry=1 ;;
            -h|--help) usage; return 0 ;;
            *) echo "Неизвестный параметр: $1" >&2; usage >&2; return 1 ;;
        esac
        shift
    done
    if [ "$(uname -s)" != Darwin ]; then echo 'Эта версия установщика поддерживает macOS. Для Windows используйте setup.ps1.' >&2; return 1; fi
    if [ $all = 1 ] && [ -n "$apps" ]; then echo 'Используйте --all или --apps, а не оба параметра.' >&2; return 1; fi
    if [ $list = 1 ] && [ $all = 1 -o -n "$apps" -o $dry = 1 ]; then echo '--list используется отдельно.' >&2; return 1; fi
    if [ $dry = 1 ] && [ $all = 0 ] && [ -z "$apps" ]; then echo 'Для --dry-run укажите --all или --apps.' >&2; return 1; fi
    refresh_path
    if [ $list = 1 ]; then
        for key in $(catalog_keys); do printf '%-15s %s %s\n' "$key" "$(pad "$(app_field "$key" 2)" 26)" "$(status_text "$key")"; done
        return 0
    fi
    if [ $all = 0 ] && [ -z "$apps" ]; then start_menu; return; fi
    if [ $all = 1 ]; then keys="$(catalog_keys)"; else keys="$(printf '%s' "$apps" | tr ',' ' ')"; fi
    for key in $keys; do
        app_exists "$key" || { echo "Неизвестная программа '$key'. Доступны: $(catalog_keys | tr '\n' ' ')" >&2; return 1; }
    done
    [ $dry = 1 ] || init_log
    # shellcheck disable=SC2086
    run_setup $dry $keys
    show_report
    [ -n "$LOG_FILE" ] && echo "Журнал: $LOG_FILE"
    results_exit_code
}

# Sourcing loads functions for local tests without performing any action.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
    exit $?
fi
