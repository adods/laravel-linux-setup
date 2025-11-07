#!/bin/bash

#######################################################
# Node.js Installation Module (via NVM)
#
# Installs NVM and Node.js LTS for Laravel frontend
# asset compilation
#######################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${YELLOW}Installing NVM and Node.js...${NC}"

# Check if NVM is already installed
if [ -d "$HOME/.nvm" ]; then
    echo -e "${GREEN}✓ NVM already installed${NC}"
else
    # Install NVM
    echo "Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

    echo -e "${GREEN}✓ NVM installed${NC}"
fi

# Load NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Install Node.js LTS
echo "Installing Node.js LTS..."
nvm install --lts
nvm use --lts
nvm alias default lts/*

echo -e "${GREEN}✓ Node.js LTS installed${NC}"

# Verify installation
NODE_VERSION=$(node --version)
NPM_VERSION=$(npm --version)

echo ""
echo -e "${CYAN}Installed versions:${NC}"
echo "  • Node.js: $NODE_VERSION"
echo "  • npm: $NPM_VERSION"

echo -e "${GREEN}✓ Node.js installation complete${NC}"
