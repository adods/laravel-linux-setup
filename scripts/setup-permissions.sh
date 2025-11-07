#!/bin/bash

#######################################################
# Permissions Setup Script
#
# Configures proper permissions for Laravel development
#######################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PROJECT_DIR="$1"

if [[ -z "$PROJECT_DIR" ]]; then
    echo -e "${RED}Error: Project directory not provided${NC}"
    exit 1
fi

echo -e "${YELLOW}Setting up permissions...${NC}"

# Add user to www-data group
echo "Adding $USER to www-data group..."
sudo usermod -a -G www-data "$USER"
echo -e "${GREEN}✓ User added to www-data group${NC}"

# Ensure home directory is traversable by Apache (www-data)
echo "Checking home directory permissions..."
HOME_DIR=$(eval echo ~$USER)
CURRENT_PERMS=$(stat -c "%a" "$HOME_DIR")

# Check if "others" have execute permission
if [[ ! "$CURRENT_PERMS" =~ [0-9][0-9][5-7] ]]; then
    echo "Making home directory traversable for Apache..."
    chmod o+rx "$HOME_DIR"
    echo -e "${GREEN}✓ Home directory permissions updated${NC}"
else
    echo -e "${GREEN}✓ Home directory already has correct permissions${NC}"
fi

# Set ownership and permissions on project directory
if [[ -d "$PROJECT_DIR" ]]; then
    echo "Setting ownership on project directory..."
    sudo chown -R "$USER":www-data "$PROJECT_DIR"

    echo "Setting permissions on project directory..."
    sudo chmod -R 775 "$PROJECT_DIR"

    echo "Applying setgid bit to directories..."
    sudo find "$PROJECT_DIR" -type d -exec chmod g+s {} \;

    echo -e "${GREEN}✓ Permissions configured on $PROJECT_DIR${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Project directory doesn't exist yet. Permissions will be set when directory is created.${NC}"
fi

echo ""
echo -e "${CYAN}Permissions Configuration:${NC}"
echo "  • User: $USER"
echo "  • Group: www-data"
echo "  • Directory permissions: 775 (rwxrwxr-x)"
echo "  • File permissions: 664 (rw-rw-r--)"
echo "  • Setgid: Enabled (new files inherit www-data group)"
echo ""
echo -e "${YELLOW}⚠ IMPORTANT: Log out and log back in for group changes to take effect!${NC}"
echo ""
echo -e "${GREEN}✓ Permissions setup complete${NC}"
