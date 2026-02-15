#!/bin/bash
# install.sh - One-click installation for vibe-coding-setup
# Sets up persistent Claude Code sessions accessible via web browser

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_header() {
    echo -e "${BLUE}"
    cat << 'EOF'
 __     _____ ____  _____    ____          _ _
 \ \   / /_ _| __ )| ____|  / ___|___   __| (_)_ __   __ _
  \ \ / / | ||  _ \|  _|   | |   / _ \ / _` | | '_ \ / _` |
   \ V /  | || |_) | |___  | |__| (_) | (_| | | | | | (_| |
    \_/  |___|____/|_____|  \____\___/ \__,_|_|_| |_|\__, |
                                                     |___/
    Mobile Claude Code Setup
EOF
    echo -e "${NC}"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_command() {
    if command -v "$1" &> /dev/null; then
        log_success "$1 found"
        return 0
    else
        return 1
    fi
}

print_header

echo ""
echo "This script will set up:"
echo "  - claude-session script for managing tmux sessions"
echo "  - Mobile-friendly tmux configuration"
echo "  - systemd services for auto-start"
echo "  - Web terminal (agentboard or ttyd)"
echo ""
read -p "Continue? [Y/n] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]?$ ]]; then
    echo "Aborted."
    exit 1
fi

# Choose web terminal
echo ""
log_info "Choose your web terminal:"
echo ""
echo "  [1] agentboard - full mobile support with iOS clipboard, on-screen"
echo "      controls, DPad, session tracking (requires Bun)"
echo ""
echo "  [2] ttyd - lightweight, no extra dependencies"
echo ""
read -p "Choice [1/2]: " -n 1 -r WEB_TERMINAL_CHOICE
echo ""
if [[ "$WEB_TERMINAL_CHOICE" == "2" ]]; then
    WEB_TERMINAL="ttyd"
else
    WEB_TERMINAL="agentboard"
fi
log_info "Selected: $WEB_TERMINAL"

echo ""
log_info "Checking prerequisites..."
echo ""

# Check prerequisites
MISSING_DEPS=()

if ! check_command tmux; then
    MISSING_DEPS+=("tmux")
fi

if [[ "$WEB_TERMINAL" == "ttyd" ]]; then
    if ! check_command ttyd; then
        MISSING_DEPS+=("ttyd")
    fi
fi

if ! check_command tailscale; then
    MISSING_DEPS+=("tailscale")
fi

if ! check_command claude; then
    log_warn "Claude Code not found - install from: npm install -g @anthropic-ai/claude-code"
fi

# Install missing dependencies
if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo ""
    log_warn "Missing dependencies: ${MISSING_DEPS[*]}"

    if command -v apt &> /dev/null; then
        echo ""
        read -p "Install missing packages with apt? [Y/n] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]?$ ]]; then
            for dep in "${MISSING_DEPS[@]}"; do
                case "$dep" in
                    tailscale)
                        log_info "Installing Tailscale..."
                        curl -fsSL https://tailscale.com/install.sh | sh
                        ;;
                    *)
                        log_info "Installing $dep..."
                        sudo apt install -y "$dep"
                        ;;
                esac
            done
        else
            log_error "Please install missing dependencies and re-run."
            exit 1
        fi
    else
        log_error "Please install missing dependencies: ${MISSING_DEPS[*]}"
        exit 1
    fi
fi

echo ""
log_info "Installing scripts..."

# Create bin directory
mkdir -p ~/bin

# Copy scripts
cp "$SCRIPT_DIR/config/claude-session" ~/bin/
cp "$SCRIPT_DIR/config/claude-web" ~/bin/
chmod +x ~/bin/claude-session ~/bin/claude-web

log_success "Scripts installed to ~/bin/"

# Add to PATH if not already
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
    export PATH="$HOME/bin:$PATH"
    log_success "Added ~/bin to PATH"
fi

# Install agentboard if selected
if [[ "$WEB_TERMINAL" == "agentboard" ]]; then
    echo ""
    log_info "Setting up agentboard..."

    # Install Bun if not present
    if ! command -v bun &> /dev/null; then
        log_info "Installing Bun runtime..."
        curl -fsSL https://bun.sh/install | bash
        export BUN_INSTALL="$HOME/.bun"
        export PATH="$BUN_INSTALL/bin:$PATH"
        if command -v bun &> /dev/null; then
            log_success "Bun $(bun --version) installed"
        else
            log_error "Bun installation failed. Install manually: https://bun.sh"
            exit 1
        fi
    else
        log_success "Bun $(bun --version) found"
    fi

    # Check Bun version >= 1.3.6
    BUN_VERSION=$(bun --version)
    BUN_MAJOR=$(echo "$BUN_VERSION" | cut -d. -f1)
    BUN_MINOR=$(echo "$BUN_VERSION" | cut -d. -f2)
    BUN_PATCH=$(echo "$BUN_VERSION" | cut -d. -f3)
    if [[ "$BUN_MAJOR" -lt 1 ]] || [[ "$BUN_MAJOR" -eq 1 && "$BUN_MINOR" -lt 3 ]] || \
       [[ "$BUN_MAJOR" -eq 1 && "$BUN_MINOR" -eq 3 && "$BUN_PATCH" -lt 6 ]]; then
        log_warn "Bun $BUN_VERSION found but 1.3.6+ required (PTY bugs in older versions)"
        log_info "Updating Bun..."
        bun upgrade
    fi

    # Clone or update agentboard
    if [ -d "$HOME/.agentboard-app" ]; then
        log_info "Updating existing agentboard installation..."
        cd "$HOME/.agentboard-app" && git pull && bun install && bun run build
        cd "$SCRIPT_DIR"
    else
        log_info "Cloning agentboard..."
        git clone https://github.com/gbasin/agentboard.git "$HOME/.agentboard-app"
        cd "$HOME/.agentboard-app" && bun install && bun run build
        cd "$SCRIPT_DIR"
    fi
    log_success "Agentboard installed to ~/.agentboard-app"
fi

echo ""
log_info "Installing tmux configuration..."

# Backup existing tmux config
if [ -f ~/.tmux.conf ]; then
    cp ~/.tmux.conf ~/.tmux.conf.backup.$(date +%Y%m%d_%H%M%S)
    log_info "Backed up existing ~/.tmux.conf"
fi

cp "$SCRIPT_DIR/config/tmux.conf" ~/.tmux.conf
log_success "tmux config installed"

echo ""
log_info "Setting up systemd services..."

# Create systemd user directory
mkdir -p ~/.config/systemd/user

# Copy service files
cp "$SCRIPT_DIR/config/systemd/claude-tmux.service" ~/.config/systemd/user/

if [[ "$WEB_TERMINAL" == "agentboard" ]]; then
    cp "$SCRIPT_DIR/config/systemd/agentboard.service" ~/.config/systemd/user/
    log_success "systemd services installed (claude-tmux + agentboard)"

    systemctl --user daemon-reload
    systemctl --user enable claude-tmux.service agentboard.service
    # Disable ttyd if it was previously enabled
    systemctl --user disable ttyd.service 2>/dev/null || true
else
    cp "$SCRIPT_DIR/config/systemd/ttyd.service" ~/.config/systemd/user/

    # Update ttyd.service with correct node path
    NODE_PATH=""
    if command -v node &> /dev/null; then
        NODE_PATH="$(dirname $(which node))"
    fi
    sed -i "s|%h/.nvm/versions/node/v22.17.0/bin|${NODE_PATH:-/usr/local/bin}|g" \
        ~/.config/systemd/user/ttyd.service

    log_success "systemd services installed (claude-tmux + ttyd)"

    systemctl --user daemon-reload
    systemctl --user enable claude-tmux.service ttyd.service
    # Disable agentboard if it was previously enabled
    systemctl --user disable agentboard.service 2>/dev/null || true
fi

log_success "Services enabled"

echo ""
log_info "Checking Tailscale status..."

if ! tailscale status &> /dev/null; then
    log_warn "Tailscale not connected"
    echo ""
    read -p "Run 'sudo tailscale up' now? [Y/n] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]?$ ]]; then
        sudo tailscale up
    else
        log_warn "Remember to run 'sudo tailscale up' before accessing remotely"
    fi
fi

# Enable lingering for user services to run without login
if ! loginctl show-user "$USER" 2>/dev/null | grep -q "Linger=yes"; then
    log_info "Enabling lingering for persistent services..."
    sudo loginctl enable-linger "$USER"
    log_success "Lingering enabled"
fi

# Start services
echo ""
log_info "Starting services..."

if [[ "$WEB_TERMINAL" == "agentboard" ]]; then
    systemctl --user start claude-tmux.service agentboard.service
    sleep 2
    if systemctl --user is-active --quiet agentboard.service; then
        log_success "agentboard service running"
    else
        log_warn "agentboard service may have issues - check with: journalctl --user -u agentboard.service"
    fi
else
    systemctl --user start claude-tmux.service ttyd.service
    sleep 2
    if systemctl --user is-active --quiet ttyd.service; then
        log_success "ttyd service running"
    else
        log_warn "ttyd service may have issues - check with: journalctl --user -u ttyd.service"
    fi
fi

# Get access URL
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "YOUR_TAILSCALE_IP")

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}       Installation Complete!              ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Access your Claude Code session:"
echo ""
if [[ "$WEB_TERMINAL" == "agentboard" ]]; then
    echo -e "  ${BLUE}http://${TAILSCALE_IP}:4040${NC}"
    echo ""
    echo "Quick commands:"
    echo "  claude-session       - Attach to session locally"
    echo "  claude-session -l    - List sessions"
    echo "  claude-session -r    - Recreate session"
    echo ""
    echo "Services:"
    echo "  systemctl --user status agentboard.service"
    echo "  systemctl --user status claude-tmux.service"
else
    echo -e "  ${BLUE}http://${TAILSCALE_IP}:7681${NC}"
    echo ""
    echo "Quick commands:"
    echo "  claude-session       - Attach to session locally"
    echo "  claude-session -l    - List sessions"
    echo "  claude-session -r    - Recreate session"
    echo ""
    echo "Services:"
    echo "  systemctl --user status ttyd.service"
    echo "  systemctl --user status claude-tmux.service"
fi
echo ""
echo "On your phone:"
echo "  1. Install Tailscale app"
echo "  2. Sign in with same account"
echo "  3. Open browser to the URL above"
echo ""
