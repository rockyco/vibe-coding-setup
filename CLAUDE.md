# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Vibe-coding-setup enables persistent Claude Code sessions accessible via web browser from any device (phone, tablet, laptop). Two web terminal options: agentboard (port 4040, recommended for mobile/iOS) or ttyd (port 7681, lightweight). Both use tmux (persistent sessions) -> Tailscale (VPN security) -> systemd (auto-start on boot).

## Architecture

```
Browser (any device) --> Tailscale VPN --> agentboard:4040 or ttyd:7681 --> tmux session --> Claude Code
```

Key design decisions:
- Two web terminals: agentboard (full mobile support, clipboard, DPad) or ttyd (lightweight)
- Tailscale-only access: both bind to tailscale0 interface, never exposed to public internet
- tmux prefix is single quote (`'`) instead of Ctrl+B, optimized for iOS keyboards lacking Ctrl key
- 6-pane layout (3x2 grid): pane 1 runs Claude Code, panes 2-6 are auxiliary shells
- systemd user services with lingering enabled so sessions survive logout and reboot
- OOM protection on claude-tmux.service (90% threshold, OOMScoreAdjust=-500)

## Key Files

- `config/tmux.conf` - Mobile-friendly tmux config with iOS keybindings
- `config/claude-session` - Bash script for session lifecycle management
- `config/claude-web` - Wrapper that launches ttyd bound to Tailscale interface
- `config/systemd/claude-tmux.service` - Auto-start tmux session service
- `config/systemd/agentboard.service` - Agentboard web terminal service (port 4040)
- `config/systemd/ttyd.service` - ttyd web terminal service (port 7681)
- `install.sh` - One-click installer (checks deps, copies configs, enables services)

## Common Commands

```bash
# Installation
./install.sh

# Service management
systemctl --user status agentboard.service  # or ttyd.service
systemctl --user status claude-tmux.service
systemctl --user restart agentboard.service  # or ttyd.service
systemctl --user daemon-reload    # after editing .service files
journalctl --user -u agentboard.service -f  # or ttyd.service

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

- Clipboard: solved by agentboard (multi-strategy clipboard). With ttyd: `'Y` shows buffer in popup for manual copy
- Spacebar-as-arrow: does not work in web terminals. Agentboard has on-screen DPad. With ttyd: `'i`/`'o`/`'b`/`'f` keybindings
