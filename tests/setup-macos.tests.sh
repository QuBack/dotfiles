#!/bin/bash
# Offline tests for setup.sh: no installers run. Usage: bash tests/setup-macos.tests.sh
SETUP="$(dirname "$0")/../setup.sh"
. "$SETUP"
passed=0
check() { # message command...
    local message="$1"; shift
    if "$@"; then passed=$((passed + 1)); echo "PASS: $message"; else echo "FAIL: $message"; exit 1; fi
}
lines() { printf '%s\n' "$1" | tr '\n' ',' | sed 's/,$//'; }

INSTALLED=' '
is_installed() { case "$INSTALLED" in *" $1 "*) return 0 ;; esac; return 1; }

# Menu input returns an explicit action without running installers.
SELECTED=' '
menu_key Enter 1
check 'empty selection cannot start an installation' [ "$ACTION" = None -a -n "$NOTICE" ]
menu_key Enter 2
check 'Enter on a program selects it without installing' [ "$SELECTED" = ' git ' -a "$ACTION" = None ]
menu_key Space 2
check 'Space toggles a selected program off' [ "$SELECTED" = ' ' ]
claude_row=$(( $(catalog_keys | grep -n '^claude$' | cut -d: -f1) + 1 ))
menu_key Space "$claude_row"; menu_key Enter 2; menu_key Enter 1
check 'selected action includes only checked programs in catalog order' [ "$ACTION" = Install -a "$(lines "$ACTION_KEYS")" = git,claude ]
menu_key Enter 0
check 'install all takes the whole catalog' [ "$(lines "$ACTION_KEYS")" = "$(lines "$(catalog_keys)")" ]
menu_key Space 0
check 'Space on an action cannot trigger installation' [ "$ACTION" = None ]
exit_row=$(( $(catalog_keys | wc -l) + 2 ))
menu_key Up 0
check 'Up wraps from first action to Exit' [ "$CURSOR" -eq "$exit_row" ]
menu_key Down "$exit_row"
check 'Down wraps from Exit to first action' [ "$CURSOR" -eq 0 ]
menu_key Enter "$exit_row"
check 'Exit row exits on Enter' [ "$ACTION" = Exit ]
menu_key Escape 3
check 'Escape exits from the program list' [ "$ACTION" = Exit ]

# Dependencies of missing apps come first; installed ones are skipped later.
check 'casks pull in Homebrew' [ "$(lines "$(install_plan chrome vlc)")" = brew,chrome,vlc ]
check 'Poetry and Python share one uv' [ "$(lines "$(install_plan poetry python)")" = uv,poetry,python ]
INSTALLED=' chrome poetry '
check 'installed apps do not pull dependencies' [ "$(lines "$(install_plan chrome poetry)")" = chrome,poetry ]
INSTALLED=' '

# A failed dependency blocks dependents; a manual step defers them.
install_app() { case "$1" in brew) MESSAGE='boom'; return 1 ;; uv) return 2 ;; esac; return 0; }
run_setup 0 chrome poetry gh >/dev/null
check 'failed Homebrew blocks casks' [ -n "$(printf '%s' "$RESULTS" | grep '^chrome|Blocked|')" ]
check 'pending uv defers Poetry' [ -n "$(printf '%s' "$RESULTS" | grep '^poetry|Manual|')" ]
check 'independent apps still install' [ -n "$(printf '%s' "$RESULTS" | grep '^gh|OK|')" ]
results_exit_code; check 'errors produce exit code 1' [ $? -eq 1 ]
RESULTS='gh|OK|
uv|Manual|x
'
results_exit_code; check 'manual steps produce exit code 2' [ $? -eq 2 ]

# Release assets: the right file for this Mac and its digest from the GitHub API.
release_json="$(mktemp)"
cat > "$release_json" <<'JSON'
  "assets": [
    { "name": "bat-x86_64-apple-darwin.tar.gz", "uploader": { "login": "bot" },
      "digest": "sha256:aaa",
      "browser_download_url": "https://example.test/bat-x86_64-apple-darwin.tar.gz" },
    { "name": "bat-aarch64-apple-darwin.tar.gz",
      "digest": null,
      "browser_download_url": "https://example.test/bat-aarch64-apple-darwin.tar.gz" }
  ]
JSON
ARCH=x86_64
check 'Intel Mac gets the x86_64 asset with its digest' [ "$(release_asset "$release_json" "$(release_suffix bat)")" = 'sha256:aaa https://example.test/bat-x86_64-apple-darwin.tar.gz' ]
check 'fzf and gh use Go architecture names' [ "$(release_suffix fzf)$(release_suffix gh)" = '-darwin_amd64.tar.gz_macOS_amd64.zip' ]
ARCH=arm64
check 'asset without a digest is not accepted' [ "$(release_asset "$release_json" "$(release_suffix bat)" | cut -d' ' -f1)" = null ]
rm -f "$release_json"

check 'iTerm2 profile is valid JSON with a dot decimal separator' bash -c '. "$1"; LC_ALL=ru_RU.UTF-8 iterm_profile_json | plutil -convert xml1 -o /dev/null -- -' _ "$SETUP"
check 'managed zsh config keeps syntax highlighting last' bash -c '. "$1"; zsh_managed_config | grep -q "zsh-autosuggestions zsh-syntax-highlighting)"' _ "$SETUP"

check 'pad counts Cyrillic letters, not bytes' [ "$(pad 'Codex (интерфейс)' 20)" = 'Codex (интерфейс)   ' ]
check 'unknown app is rejected' [ "$(main --apps nope 2>&1 >/dev/null)" != '' ]
main --all --apps git >/dev/null 2>&1; check '--all and --apps are exclusive' [ $? -eq 1 ]
main --dry-run >/dev/null 2>&1; check '--dry-run needs a selection' [ $? -eq 1 ]

echo "OK: $passed tests passed"
