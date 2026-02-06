# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Vibe-coding-setup enables persistent Claude Code sessions accessible via web browser from any device (phone, tablet, laptop). The stack: ttyd (web terminal on port 7681) -> tmux (persistent sessions) -> Tailscale (VPN security) -> systemd (auto-start on boot).

## Architecture

```
Browser (any device) --> Tailscale VPN --> ttyd:7681 --> tmux session --> Claude Code
```

Key design decisions:
- Tailscale-only access: ttyd binds to tailscale0 interface, never exposed to public internet
- tmux prefix is single quote (`'`) instead of Ctrl+B, optimized for iOS keyboards lacking Ctrl key
- 6-pane layout (3x2 grid): pane 1 runs Claude Code, panes 2-6 are auxiliary shells
- systemd user services with lingering enabled so sessions survive logout and reboot
- OOM protection on claude-tmux.service (90% threshold, OOMScoreAdjust=-500)

## Key Files

- `config/tmux.conf` - Mobile-friendly tmux config with iOS keybindings
- `config/claude-session` - Bash script for session lifecycle management
- `config/claude-web` - Wrapper that launches ttyd bound to Tailscale interface
- `config/systemd/claude-tmux.service` - Auto-start tmux session service
- `config/systemd/ttyd.service` - Auto-start web terminal service
- `install.sh` - One-click installer (checks deps, copies configs, enables services)

## Common Commands

```bash
# Installation
./install.sh

# Service management
systemctl --user status ttyd.service
systemctl --user status claude-tmux.service
systemctl --user restart ttyd.service
systemctl --user daemon-reload    # after editing .service files
journalctl --user -u ttyd.service -f

# Session management
claude-session          # attach to default session
claude-session -l       # list sessions
claude-session -r       # recreate session (fresh 6-pane layout)
claude-session -k       # kill session
```

## Conventions

- Bash scripts use `set -e` and color-coded output (RED/GREEN/YELLOW/BLUE)
- After modifying service files in `config/systemd/`, they must be copied to `~/.config/systemd/user/` and reloaded with `daemon-reload`
- tmux.conf changes require either `tmux source-file` or killing/recreating the session to take effect
- No build system or test suite - this is a shell configuration project validated through real-world usage

## Known iOS Safari Limitations

- Clipboard API blocked: touch-based copy does not work. Workaround: `'Y` shows buffer in popup for manual copy
- Spacebar-as-arrow simulation does not work in ttyd. Workaround: `'i`/`'o`/`'b`/`'f` keybindings for arrow keys
