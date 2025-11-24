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

# Load NVM into current shell
export NVM_DIR="$HOME/.nvm"

# Try multiple ways to load NVM
if [ -s "$NVM_DIR/nvm.sh" ]; then
    echo "Loading NVM..."
    \. "$NVM_DIR/nvm.sh"
    echo -e "${GREEN}✓ NVM loaded${NC}"
else
    echo -e "${YELLOW}⚠ NVM script not found at expected location${NC}"
    echo -e "${YELLOW}Trying alternative paths...${NC}"

    # Try loading from common locations
    for nvmsh in "$HOME/.nvm/nvm.sh" "/usr/local/share/nvm/nvm.sh" "$NVM_DIR/nvm.sh"; do
        if [ -s "$nvmsh" ]; then
            \. "$nvmsh"
            echo -e "${GREEN}✓ NVM loaded from $nvmsh${NC}"
            break
        fi
    done
fi

# Verify NVM is loaded
if ! command -v nvm &> /dev/null; then
    echo -e "${YELLOW}⚠ NVM command not available, attempting manual load...${NC}"
    # Source bashrc/profile to get NVM
    [ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc"
    [ -f "$HOME/.bash_profile" ] && source "$HOME/.bash_profile"
    [ -f "$HOME/.profile" ] && source "$HOME/.profile"
fi

# Check if NVM is now available
if command -v nvm &> /dev/null; then
    echo -e "${GREEN}✓ NVM is ready${NC}"

    # Install Node.js LTS
    echo "Installing Node.js LTS..."

    # Check if Node.js is already installed
    if nvm ls | grep -q "lts"; then
        echo -e "${GREEN}✓ Node.js LTS already installed${NC}"
        nvm use --lts
    else
        nvm install --lts
        echo -e "${GREEN}✓ Node.js LTS installed${NC}"
    fi

    # Set as default
    nvm use --lts
    nvm alias default lts/*

    # Verify installation
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        NPM_VERSION=$(npm --version)

        echo ""
        echo -e "${CYAN}Installed versions:${NC}"
        echo "  • Node.js: $NODE_VERSION"
        echo "  • npm: $NPM_VERSION"
        echo -e "${GREEN}✓ Node.js installation complete${NC}"
    else
        echo -e "${YELLOW}⚠ Node.js installed but not available in current shell${NC}"
        echo -e "${YELLOW}Please run: source ~/.bashrc${NC}"
        echo -e "${YELLOW}Or log out and log back in${NC}"
    fi
else
    echo -e "${YELLOW}⚠ NVM could not be loaded automatically${NC}"
    echo -e "${YELLOW}Please run the following commands manually:${NC}"
    echo -e "${CYAN}  source ~/.nvm/nvm.sh${NC}"
    echo -e "${CYAN}  nvm install --lts${NC}"
    echo -e "${CYAN}  nvm use --lts${NC}"
    echo -e "${CYAN}  nvm alias default lts/*${NC}"
fi
