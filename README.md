# Vibe Coding Setup

**Access Claude Code from your phone, tablet, or any device with a web browser.**

A complete setup for persistent Claude Code sessions accessible via web terminal - perfect for mobile coding, remote access, and couch-based development.

<p align="center">
  <img src="docs/images/mobile-browser.svg" alt="Mobile browser accessing Claude Code" width="240"/>
</p>

## Features

- **Mobile-first**: Touch-friendly tmux configuration with tap/swipe gestures
- **Persistent sessions**: Claude keeps running even when you disconnect
- **Secure access**: Only accessible via Tailscale VPN (not exposed to internet)
- **Auto-start**: Sessions survive reboots via systemd
- **Multi-pane layout**: 3x2 grid with Claude in top-left, 5 extra shells

## Architecture

<p align="center">
  <img src="docs/images/architecture.svg" alt="System architecture" width="700"/>
</p>

<details>
<summary>ASCII diagram (text version)</summary>

```
+------------------+          +-------------------+          +------------------+
|                  |   VPN    |                   |   Web    |                  |
|   Your Phone     |--------->|    Tailscale      |--------->|   Your Server    |
|   (Browser)      |          |    Network        |          |   (ttyd+tmux)    |
|                  |          |                   |          |                  |
+------------------+          +-------------------+          +------------------+
        |                                                            |
        |                                                            v
        |                                                    +-------+-------+-------+
        |                                                    |       |       |       |
        |                                                    | Claude|  sh2  |  sh3  |
        +---------------------------------------------------->       |       |       |
                      http://100.x.x.x:7681                  +-------+-------+-------+
                                                             |       |       |       |
                                                             |  sh4  |  sh5  |  sh6  |
                                                             |       |       |       |
                                                             +-------+-------+-------+
```
</details>

### How It Works

1. **ttyd** serves a web terminal on port 7681
2. **tmux** provides persistent sessions with multiple panes
3. **Tailscale** secures access (only your devices can connect)
4. **systemd** keeps everything running after reboots

## Quick Start

```bash
# One-click install
curl -fsSL https://raw.githubusercontent.com/rockyco/vibe-coding-setup/main/install.sh | bash

# Or clone and run locally
git clone https://github.com/rockyco/vibe-coding-setup.git
cd vibe-coding-setup
./install.sh
```

After installation, access from your phone:
1. Install Tailscale on your phone
2. Open browser to `http://<your-tailscale-ip>:7681`
3. Start coding!

## Prerequisites

| Requirement | Purpose | Install Command |
|------------|---------|-----------------|
| Linux with systemd | Service management | (most distros) |
| tmux | Terminal multiplexer | `sudo apt install tmux` |
| ttyd | Web terminal | See below |
| Tailscale | Secure VPN | `curl -fsSL https://tailscale.com/install.sh \| sh` |
| Claude Code | AI coding assistant | `npm install -g @anthropic-ai/claude-code` |

### Installing ttyd

```bash
# Ubuntu/Debian
sudo apt install ttyd

# Or build from source
git clone https://github.com/tsl0922/ttyd.git
cd ttyd && mkdir build && cd build
cmake .. && make && sudo make install
```

## Manual Installation

### 1. Install the session management scripts

```bash
# Create bin directory
mkdir -p ~/bin

# Copy scripts
cp config/claude-session ~/bin/
cp config/claude-web ~/bin/

# Make executable
chmod +x ~/bin/claude-session ~/bin/claude-web

# Add to PATH (add to .bashrc)
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### 2. Install tmux configuration

```bash
# Backup existing config
[ -f ~/.tmux.conf ] && mv ~/.tmux.conf ~/.tmux.conf.backup

# Install mobile-friendly config
cp config/tmux.conf ~/.tmux.conf
```

### 3. Set up systemd services (auto-start)

```bash
# Create user systemd directory
mkdir -p ~/.config/systemd/user

# Copy service files
cp config/systemd/claude-tmux.service ~/.config/systemd/user/
cp config/systemd/ttyd.service ~/.config/systemd/user/

# Edit ttyd.service to fix the PATH for your system
# Update the node path to match your installation
nano ~/.config/systemd/user/ttyd.service

# Enable and start services
systemctl --user daemon-reload
systemctl --user enable claude-tmux.service ttyd.service
systemctl --user start claude-tmux.service ttyd.service

# Enable lingering (services run even when logged out)
sudo loginctl enable-linger $USER
```

### 4. Configure Tailscale

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Authenticate
sudo tailscale up

# Get your Tailscale IP
tailscale ip -4
```

### 5. Verify the setup

```bash
# Check services are running
systemctl --user status claude-tmux.service
systemctl --user status ttyd.service

# Check the URL
echo "Access at: http://$(tailscale ip -4):7681"
```

## Accessing from Mobile

### Phone/Tablet Setup

1. **Install Tailscale** on your device from App Store or Play Store
2. **Sign in** with the same account as your server
3. **Open browser** and go to `http://<tailscale-ip>:7681`
4. **Bookmark** the URL for quick access

### Touch Gestures Reference

<p align="center">
  <img src="docs/images/gestures.svg" alt="Touch gestures guide" width="600"/>
</p>

| Gesture | Action |
|---------|--------|
| Tap | Click / Select pane |
| Double-tap | Zoom pane (toggle fullscreen) |
| Swipe | Scroll through output |
| Long press | Open context menu |
| Pinch | Zoom text (browser native) |

### Mobile Tips

- **Landscape mode**: Better for the 3x2 layout
- **Bookmark**: Add to home screen for app-like experience
- **Keyboard**: Use an external Bluetooth keyboard for heavy typing
- **Double-tap pane**: Zooms Claude pane to fullscreen

## Accessing from Another Computer

### Via SSH

```bash
# SSH to your server and attach to session
ssh yourserver
tmux attach -t claude-main
```

### Via Web Browser

Open `http://<tailscale-ip>:7681` in any browser on your Tailscale network.

## Command Reference

### claude-session

```bash
claude-session              # Attach to default session (claude-main)
claude-session project      # Attach to claude-project
claude-session -l           # List all claude sessions
claude-session -k           # Kill default session
claude-session -k project   # Kill claude-project
claude-session -n test      # Create claude-test without attaching
claude-session -r           # Recreate default session (fresh 6-pane layout)
```

### tmux Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl-b d` | Detach from session |
| `Ctrl-b [` | Enter scroll mode |
| `Ctrl-b z` | Zoom current pane |
| `Ctrl-b \|` | Split pane vertically |
| `Ctrl-b -` | Split pane horizontally |
| `Ctrl-b arrows` | Navigate panes |
| `Ctrl-b r` | Reload tmux config |

## The 6-Pane Layout

The default layout creates a 3x2 grid:

<p align="center">
  <img src="docs/images/6-pane-layout.svg" alt="6-pane tmux layout" width="600"/>
</p>

<details>
<summary>ASCII diagram (text version)</summary>

```
+-------------------+-------------------+-------------------+
|                   |                   |                   |
|      Pane 1       |      Pane 2       |      Pane 3       |
|   (Claude Code)   |     (shell)       |     (shell)       |
|                   |                   |                   |
+-------------------+-------------------+-------------------+
|                   |                   |                   |
|      Pane 4       |      Pane 5       |      Pane 6       |
|     (shell)       |     (shell)       |     (shell)       |
|                   |                   |                   |
+-------------------+-------------------+-------------------+
```
</details>

**Why 6 panes?**
- Pane 1: Claude Code - your AI assistant
- Pane 2-3: Running servers, watching logs, tests
- Pane 4-6: Git operations, file navigation, ad-hoc commands

## Troubleshooting

### Service won't start

```bash
# Check service logs
journalctl --user -u ttyd.service -f

# Verify ttyd is installed
which ttyd

# Check Tailscale is connected
tailscale status
```

### Can't connect from phone

1. Verify Tailscale is running on both devices
2. Check `tailscale status` shows both devices
3. Try pinging your server: `ping <tailscale-ip>`
4. Verify the service: `curl http://localhost:7681`

### Session not persisting

```bash
# Ensure lingering is enabled
sudo loginctl enable-linger $USER

# Check services are enabled
systemctl --user is-enabled ttyd.service
```

### Pane layout looks wrong

```bash
# Recreate session with fresh layout
claude-session -r
```

## Customization

### Changing the number of panes

Edit `~/bin/claude-session` and modify the `create_session()` function:

```bash
# For 4 panes (2x2 grid):
# Remove the third split in each row
```

### Different port

Edit `~/.config/systemd/user/ttyd.service`:

```ini
ExecStart=/usr/bin/ttyd --port 8080 --interface tailscale0 ...
```

Then reload:

```bash
systemctl --user daemon-reload
systemctl --user restart ttyd.service
```

### Adding authentication

ttyd supports basic auth:

```bash
ttyd --port 7681 --credential user:password ...
```

Or use Tailscale ACLs for more granular control.

### Theming tmux

Edit `~/.tmux.conf` to customize colors:

```bash
# Dark blue theme
set -g status-style 'bg=#1a1a2e fg=#eaeaea'
set -g pane-active-border-style 'fg=#5294e2'

# Green theme
set -g status-style 'bg=#1d3d1d fg=#98fb98'
set -g pane-active-border-style 'fg=#32cd32'
```

## Security Considerations

- **Tailscale-only**: The web terminal binds to `tailscale0` interface only
- **No public exposure**: Not accessible from the internet
- **VPN encryption**: All traffic encrypted via WireGuard (Tailscale)
- **Optional auth**: Can add password protection to ttyd

## Contributing

Pull requests welcome! Areas for improvement:

- [ ] Mobile keyboard shortcuts
- [ ] Alternative layouts
- [ ] iOS Shortcuts integration
- [ ] Android automation

## License

MIT License - see LICENSE file.

## Credits

Built with:
- [ttyd](https://github.com/tsl0922/ttyd) - Web terminal
- [tmux](https://github.com/tmux/tmux) - Terminal multiplexer
- [Tailscale](https://tailscale.com) - Zero-config VPN
- [Claude Code](https://claude.com/claude-code) - AI coding assistant
