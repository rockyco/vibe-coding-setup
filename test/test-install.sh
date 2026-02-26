#!/bin/bash
# test-install.sh - Tests for install.sh and project config files
# Run: bash test/test-install.sh

set -e

# -- Test infrastructure -------------------------------------------------------

PASS=0
FAIL=0
ERRORS=()
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

red()   { printf '\033[0;31m%s\033[0m' "$*"; }
green() { printf '\033[0;32m%s\033[0m' "$*"; }
bold()  { printf '\033[1m%s\033[0m' "$*"; }

pass() {
    PASS=$((PASS + 1))
    echo "  $(green PASS) $1"
}

fail() {
    FAIL=$((FAIL + 1))
    ERRORS+=("$1: $2")
    echo "  $(red FAIL) $1 - $2"
}

assert_file_exists() {
    local path="$1" label="${2:-$1}"
    if [[ -f "$path" ]]; then
        pass "$label exists"
    else
        fail "$label exists" "file not found: $path"
    fi
}

assert_file_executable() {
    local path="$1" label="${2:-$1}"
    if [[ -x "$path" ]]; then
        pass "$label is executable"
    else
        fail "$label is executable" "not executable: $path"
    fi
}

assert_contains() {
    local file="$1" pattern="$2" label="$3"
    if grep -qE -- "$pattern" "$file" 2>/dev/null; then
        pass "$label"
    else
        fail "$label" "pattern '$pattern' not found in $file"
    fi
}

assert_not_contains() {
    local file="$1" pattern="$2" label="$3"
    if ! grep -qE -- "$pattern" "$file" 2>/dev/null; then
        pass "$label"
    else
        fail "$label" "pattern '$pattern' unexpectedly found in $file"
    fi
}

assert_command_exists() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
        pass "command '$cmd' available"
    else
        fail "command '$cmd' available" "not found in PATH"
    fi
}

assert_syntax_ok() {
    local file="$1" label="${2:-$1}"
    local output
    if output=$(bash -n "$file" 2>&1); then
        pass "$label syntax OK"
    else
        fail "$label syntax OK" "$output"
    fi
}

section() {
    echo ""
    echo "$(bold "==> $1")"
}

# -- Tests ---------------------------------------------------------------------

section "1. Bash syntax validation"

assert_syntax_ok "$REPO_DIR/install.sh" "install.sh"
assert_syntax_ok "$REPO_DIR/config/claude-session" "claude-session"
assert_syntax_ok "$REPO_DIR/config/claude-web" "claude-web"

section "2. Required commands on this system"

assert_command_exists bash
assert_command_exists tmux
assert_command_exists tailscale
assert_command_exists git
assert_command_exists systemctl
assert_command_exists sed
assert_command_exists grep
assert_command_exists curl

section "3. Config files exist"

assert_file_exists "$REPO_DIR/install.sh"
assert_file_exists "$REPO_DIR/config/tmux.conf"
assert_file_exists "$REPO_DIR/config/claude-session"
assert_file_exists "$REPO_DIR/config/claude-web"
assert_file_exists "$REPO_DIR/config/systemd/claude-tmux.service"
assert_file_exists "$REPO_DIR/config/systemd/agentboard.service"
assert_file_exists "$REPO_DIR/config/systemd/ttyd.service"
assert_file_exists "$REPO_DIR/CLAUDE.md"
assert_file_exists "$REPO_DIR/README.md"

section "4. Scripts are executable"

assert_file_executable "$REPO_DIR/install.sh"
assert_file_executable "$REPO_DIR/config/claude-session"
assert_file_executable "$REPO_DIR/config/claude-web"

section "5. Scripts have proper shebangs"

for script in install.sh config/claude-session config/claude-web; do
    first_line=$(head -n1 "$REPO_DIR/$script")
    if [[ "$first_line" == "#!/bin/bash" ]]; then
        pass "$script has bash shebang"
    else
        fail "$script has bash shebang" "got: $first_line"
    fi
done

section "6. Scripts use set -e"

assert_contains "$REPO_DIR/install.sh" '^set -e' "install.sh uses set -e"
assert_contains "$REPO_DIR/config/claude-session" '^set -e' "claude-session uses set -e"

section "7. Systemd service file structure"

for service_file in claude-tmux.service agentboard.service ttyd.service; do
    path="$REPO_DIR/config/systemd/$service_file"
    echo ""
    echo "  $(bold "--- $service_file ---")"

    # Required INI sections
    assert_contains "$path" '^\[Unit\]'    "$service_file has [Unit] section"
    assert_contains "$path" '^\[Service\]' "$service_file has [Service] section"
    assert_contains "$path" '^\[Install\]' "$service_file has [Install] section"

    # Must have Description
    assert_contains "$path" '^Description=' "$service_file has Description"

    # Must have ExecStart
    assert_contains "$path" '^ExecStart=' "$service_file has ExecStart"

    # Must have Restart policy
    assert_contains "$path" '^Restart=' "$service_file has Restart policy"

    # Must be enabled via WantedBy
    assert_contains "$path" '^WantedBy=' "$service_file has WantedBy target"
done

section "8. Service-specific checks"

# claude-tmux.service
assert_contains "$REPO_DIR/config/systemd/claude-tmux.service" \
    'Type=forking' "claude-tmux uses forking type (tmux detaches)"
assert_contains "$REPO_DIR/config/systemd/claude-tmux.service" \
    'OOMScoreAdjust=' "claude-tmux has OOM protection"
assert_contains "$REPO_DIR/config/systemd/claude-tmux.service" \
    'claude-session' "claude-tmux ExecStart references claude-session"

# agentboard.service
assert_contains "$REPO_DIR/config/systemd/agentboard.service" \
    'After=.*claude-tmux.service' "agentboard starts after claude-tmux"
assert_contains "$REPO_DIR/config/systemd/agentboard.service" \
    'PORT=4040' "agentboard uses port 4040"
assert_contains "$REPO_DIR/config/systemd/agentboard.service" \
    'tailscale ip' "agentboard resolves Tailscale IP"
assert_contains "$REPO_DIR/config/systemd/agentboard.service" \
    'ExecStartPre=' "agentboard has Tailscale readiness check"

# ttyd.service
assert_contains "$REPO_DIR/config/systemd/ttyd.service" \
    'After=.*claude-tmux.service' "ttyd starts after claude-tmux"
assert_contains "$REPO_DIR/config/systemd/ttyd.service" \
    '--port 7681' "ttyd uses port 7681"
assert_contains "$REPO_DIR/config/systemd/ttyd.service" \
    '--interface tailscale0' "ttyd binds to tailscale0 only"
assert_contains "$REPO_DIR/config/systemd/ttyd.service" \
    'ExecStartPre=' "ttyd has Tailscale readiness check"

section "9. tmux.conf validation"

TMUX_CONF="$REPO_DIR/config/tmux.conf"

# Prefix override
assert_contains "$TMUX_CONF" "unbind C-b" "tmux.conf unbinds default prefix"
assert_contains "$TMUX_CONF" "set-option -g prefix" "tmux.conf sets custom prefix"

# Mouse support (required for mobile)
assert_contains "$TMUX_CONF" 'set -g mouse on' "tmux.conf enables mouse"

# Clipboard integration
assert_contains "$TMUX_CONF" 'set-clipboard on' "tmux.conf enables OSC 52 clipboard"

# Vi mode
assert_contains "$TMUX_CONF" 'mode-keys vi' "tmux.conf uses vi copy mode"

# Scrollback
assert_contains "$TMUX_CONF" 'history-limit' "tmux.conf sets scrollback limit"

# iOS key bindings (Ctrl alternatives via prefix)
for key in c d l z a e; do
    assert_contains "$TMUX_CONF" "bind $key send-keys C-$key" \
        "tmux.conf maps '$key to Ctrl+$(echo $key | tr '[:lower:]' '[:upper:]')"
done

# Arrow key alternatives
assert_contains "$TMUX_CONF" 'bind i send-keys Up' "tmux.conf maps 'i to Up"
assert_contains "$TMUX_CONF" 'bind o send-keys Down' "tmux.conf maps 'o to Down"
assert_contains "$TMUX_CONF" 'bind t send-keys Tab' "tmux.conf maps 't to Tab"

section "10. install.sh content checks"

# Color output setup
assert_contains "$REPO_DIR/install.sh" 'RED=' "install.sh defines color codes"
assert_contains "$REPO_DIR/install.sh" 'GREEN=' "install.sh defines color codes"

# Dependency checking functions
assert_contains "$REPO_DIR/install.sh" 'check_command' "install.sh has check_command helper"
assert_contains "$REPO_DIR/install.sh" 'MISSING_DEPS' "install.sh tracks missing deps"

# Key operations present
assert_contains "$REPO_DIR/install.sh" 'mkdir -p ~/bin' "install.sh creates ~/bin"
assert_contains "$REPO_DIR/install.sh" 'systemctl --user daemon-reload' \
    "install.sh reloads systemd after install"
assert_contains "$REPO_DIR/install.sh" 'systemctl --user enable' \
    "install.sh enables services"

# Backs up existing tmux.conf
assert_contains "$REPO_DIR/install.sh" 'tmux.conf.backup' \
    "install.sh backs up existing tmux.conf"

# No unsafe patterns
assert_not_contains "$REPO_DIR/install.sh" 'rm -rf' \
    "install.sh has no rm -rf"

# -- Summary -------------------------------------------------------------------

echo ""
echo "$(bold '============================================')"
TOTAL=$((PASS + FAIL))
if [[ $FAIL -eq 0 ]]; then
    echo "  $(green "All $TOTAL tests passed")"
else
    echo "  $(green "$PASS passed"), $(red "$FAIL failed") out of $TOTAL"
    echo ""
    for err in "${ERRORS[@]}"; do
        echo "  $(red 'x') $err"
    done
fi
echo "$(bold '============================================')"

exit "$FAIL"
