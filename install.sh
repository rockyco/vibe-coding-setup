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
echo "  - Web terminal access via ttyd"
echo ""
read -p "Continue? [Y/n] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]?$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
log_info "Checking prerequisites..."
echo ""

# Check prerequisites
MISSING_DEPS=()

if ! check_command tmux; then
    MISSING_DEPS+=("tmux")
fi

if ! check_command ttyd; then
    MISSING_DEPS+=("ttyd")
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
cp "$SCRIPT_DIR/config/systemd/ttyd.service" ~/.config/systemd/user/

# Update ttyd.service with correct node path
NODE_PATH=""
if command -v node &> /dev/null; then
    NODE_PATH="$(dirname $(which node))"
fi

# Update the PATH in ttyd.service
sed -i "s|%h/.nvm/versions/node/v22.17.0/bin|${NODE_PATH:-/usr/local/bin}|g" \
    ~/.config/systemd/user/ttyd.service

log_success "systemd services installed"

# Reload and enable services
systemctl --user daemon-reload
systemctl --user enable claude-tmux.service ttyd.service

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
systemctl --user start claude-tmux.service ttyd.service

# Wait a moment for services to start
sleep 2

# Check status
if systemctl --user is-active --quiet ttyd.service; then
    log_success "ttyd service running"
else
    log_warn "ttyd service may have issues - check with: journalctl --user -u ttyd.service"
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
echo ""
echo "On your phone:"
echo "  1. Install Tailscale app"
echo "  2. Sign in with same account"
echo "  3. Open browser to the URL above"
echo ""
