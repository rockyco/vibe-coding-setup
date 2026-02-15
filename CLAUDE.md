# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Vibe-coding-setup enables persistent Claude Code sessions accessible via web browser from any device (phone, tablet, laptop). Supports multi-agent parallel coding via git worktree sessions with monitoring, review, and merge workflows. Two web terminal options: agentboard (port 4040, recommended for mobile/iOS) or ttyd (port 7681, lightweight). All features accessible from iOS/mobile.

## Architecture

```
Browser (any device) --> Tailscale VPN --> agentboard:4040 or ttyd:7681 --> tmux session --> Claude Code

Multi-agent setup:
  claude-main          (primary session, $HOME)
  claude-wt-fix-auth   (worktree session, ../repo-wt-fix-auth/)
  claude-wt-add-tests  (worktree session, ../repo-wt-add-tests/)
  ...each with isolated 6-pane layout + own Claude Code instance
```

Key design decisions:
- Two web terminals: agentboard (full mobile support, clipboard, DPad) or ttyd (lightweight)
- Tailscale-only access: both bind to tailscale0 interface, never exposed to public internet
- tmux prefix is single quote (`'`) instead of Ctrl+B, optimized for iOS keyboards lacking Ctrl key
- 6-pane layout (3x2 grid): pane 1 runs Claude Code, panes 2-6 are auxiliary shells
- systemd user services with lingering enabled so sessions survive logout and reboot
- OOM protection on claude-tmux.service (90% threshold, OOMScoreAdjust=-500)
- Git worktree isolation: each agent gets its own worktree on a `wt/<name>` branch
- State tracking in `~/.local/state/claude-vibe/` (flat key=value files, no jq dependency)
- File-lock based port allocation in `~/.local/state/claude-vibe/ports/`

## Key Files

### Core
- `config/tmux.conf` - Mobile-friendly tmux config with iOS keybindings (Parts 1-9)
- `config/claude-session` - Session lifecycle: create, attach, worktree, finish, merge
- `config/claude-session-menu` - tmux display-menu for session switching
- `config/claude-web` - Wrapper that launches ttyd bound to Tailscale interface
- `install.sh` - One-click installer (checks deps, copies configs, enables services)

### Monitor system
- `config/claude-monitor-detect` - Status detection from pane content (WAITING/WORKING/IDLE/SHELL)
- `config/claude-monitor-daemon` - Background polling (3s), state transitions, bell notifications
- `config/claude-monitor-dashboard` - Interactive popup: status table, session switching, bulk approve
- `config/claude-monitor-statusbar` - Tmux status bar renderer `[2*|1-|1!]`

### Review workflow
- `config/claude-review` - 5 modes: --list, --summary, --diff, --browse, --merge-interactive
- `config/claude-review-status` - Status bar counter for worktrees with pending changes

### Systemd services
- `config/systemd/claude-tmux.service` - Auto-start tmux session service
- `config/systemd/agentboard.service` - Agentboard web terminal (port 4040, DISCOVER_PREFIXES=claude-wt)
- `config/systemd/ttyd.service` - ttyd web terminal service (port 7681)

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
claude-session              # attach to default session
claude-session -l           # list sessions
claude-session -r           # recreate session (fresh 6-pane layout)
claude-session -k           # kill session

# Multi-agent worktree sessions
claude-session -w fix-auth        # create worktree session
claude-session -w fix-auth develop  # from specific branch
claude-session -W                 # list worktree sessions with status
claude-session -f fix-auth        # finish (kill session + remove worktree)
claude-session -m fix-auth        # merge to main + finish

# Monitor
claude-monitor-daemon start       # start background polling
claude-monitor-daemon status      # check daemon status
claude-monitor-detect claude-main:main.1  # detect pane status

# Review
claude-review --list              # review dashboard
claude-review --summary           # change summary (current repo)
claude-review --diff              # full diff vs main
claude-review --browse            # file-by-file navigation
claude-review --merge-interactive # merge strategy menu
```

## Tmux Keybindings Reference

| Binding | Feature | Category |
|---------|---------|----------|
| `'M` | Session monitor dashboard | Multi-agent |
| `'A` | Add new worktree session | Multi-agent |
| `'F` | Finish current worktree | Multi-agent |
| `Alt+1-4` | Direct session switching | Multi-agent |
| `Alt+m` | Monitor (no prefix) | Multi-agent |
| `'R` | Review dashboard | Review |
| `'G` | Git change summary | Review |
| `'E` | Examine full diff | Review |
| `'B` | Browse file-by-file | Review |
| `'O` | Operations (merge menu) | Review |
| `'S` | Choose session (built-in) | Session |
| `'H/J/K/L` | Pane navigation | Navigation |

## Per-Project Config

Projects can add `.claude-vibe/` to their repo root for multi-agent customization:

```
.claude-vibe/
  config     # bash-sourceable: VIBE_BRANCH_PATTERN, VIBE_PORT_RANGE_START/END, VIBE_SYMLINKS
  setup      # executable: runs after worktree creation (npm install, cp .env, etc.)
  teardown   # executable: runs before worktree removal
```

## Conventions

- Bash scripts use `set -e` and color-coded output (RED/GREEN/YELLOW/BLUE)
- State files use flat key=value format (parsed with grep/cut, no jq dependency)
- After modifying service files in `config/systemd/`, they must be copied to `~/.config/systemd/user/` and reloaded with `daemon-reload`
- tmux.conf changes require either `tmux source-file` or killing/recreating the session to take effect
- No build system or test suite - this is a shell configuration project validated through real-world usage
- Monitor daemon writes to `/tmp/claude-monitor/` (ephemeral, recreated on boot)
- Worktree sessions use naming convention `claude-wt-<name>` with branches `wt/<name>`

## Known iOS Safari Limitations

- Clipboard: solved by agentboard (multi-strategy clipboard). With ttyd: `'Y` shows buffer in popup for manual copy
- Spacebar-as-arrow: does not work in web terminals. Agentboard has on-screen DPad. With ttyd: `'i`/`'o`/`'b`/`'f` keybindings
