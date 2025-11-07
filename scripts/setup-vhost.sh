#!/bin/bash

#######################################################
# VHost Auto-Generation Setup Script
#
# Sets up automatic virtual host creation system
# with file monitoring
#######################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_DIR="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"

if [[ -z "$PROJECT_DIR" ]]; then
    echo -e "${RED}Error: Project directory not provided${NC}"
    exit 1
fi

echo -e "${YELLOW}Setting up Auto VHost System...${NC}"

# Install vhost creation script
echo "Installing create-vhost script..."

# Copy to /usr/local/bin for global access
sudo cp "$BIN_DIR/create-vhost.sh" /usr/local/bin/create-vhost.sh
sudo chmod +x /usr/local/bin/create-vhost.sh

# Also copy to ~/.local/bin for herd-watcher to use
mkdir -p "$HOME/.local/bin"
cp "$BIN_DIR/create-vhost.sh" "$HOME/.local/bin/create-vhost.sh"
chmod +x "$HOME/.local/bin/create-vhost.sh"

echo -e "${GREEN}✓ create-vhost.sh installed to /usr/local/bin/ and ~/.local/bin/${NC}"

# Create herd-watcher script with custom project directory
echo "Creating herd-watcher script for: $PROJECT_DIR"

# Read the template and replace WATCH_DIR
sed "s|WATCH_DIR=\"/media/adods/Data/Herd\"|WATCH_DIR=\"$PROJECT_DIR\"|g" "$BIN_DIR/herd-watcher.sh" > /tmp/herd-watcher-custom.sh

# Install custom herd-watcher
mkdir -p "$HOME/.local/bin"
cp /tmp/herd-watcher-custom.sh "$HOME/.local/bin/herd-watcher.sh"
chmod +x "$HOME/.local/bin/herd-watcher.sh"
rm /tmp/herd-watcher-custom.sh

echo -e "${GREEN}✓ herd-watcher.sh installed to ~/.local/bin/${NC}"

# Set up systemd service
echo "Setting up systemd service..."

mkdir -p "$HOME/.config/systemd/user"

cat > "$HOME/.config/systemd/user/herd-watcher.service" << EOF
[Unit]
Description=Herd Directory Watcher for Auto VHost Creation
After=network.target

[Service]
Type=simple
ExecStart=$HOME/.local/bin/herd-watcher.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

echo -e "${GREEN}✓ Systemd service file created${NC}"

# Reload systemd and enable service
systemctl --user daemon-reload
systemctl --user enable herd-watcher.service
systemctl --user start herd-watcher.service

# Enable lingering so service runs even when not logged in
sudo loginctl enable-linger "$USER"

echo -e "${GREEN}✓ Service enabled and started${NC}"

# Configure sudo for vhost operations
echo "Configuring sudo permissions..."

sudo tee /etc/sudoers.d/vhost-management > /dev/null << EOF
# Allow vhost management without password
$USER ALL=(ALL) NOPASSWD: /usr/bin/tee /etc/apache2/sites-available/*.conf
$USER ALL=(ALL) NOPASSWD: /usr/bin/tee -a /etc/hosts
$USER ALL=(ALL) NOPASSWD: /usr/sbin/a2ensite
$USER ALL=(ALL) NOPASSWD: /usr/sbin/a2dissite
$USER ALL=(ALL) NOPASSWD: /usr/sbin/apache2ctl
$USER ALL=(ALL) NOPASSWD: /bin/systemctl reload apache2
$USER ALL=(ALL) NOPASSWD: /bin/systemctl restart apache2
EOF

sudo chmod 0440 /etc/sudoers.d/vhost-management

echo -e "${GREEN}✓ Sudo permissions configured${NC}"

# Verify service status
if systemctl --user is-active --quiet herd-watcher.service; then
    echo -e "${GREEN}✓ Herd watcher service is running${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Service may not be running. Check: systemctl --user status herd-watcher${NC}"
fi

echo ""
echo -e "${CYAN}VHost System Configuration:${NC}"
echo "  • Monitored directory: $PROJECT_DIR"
echo "  • Service: herd-watcher.service"
echo "  • Manual command: create-vhost.sh <project-path> [php-version]"
echo ""
echo -e "${GREEN}✓ VHost system setup complete${NC}"
