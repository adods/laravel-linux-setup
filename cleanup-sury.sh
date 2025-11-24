#!/bin/bash

#######################################################
# Sury Repository Cleanup Script
#
# Removes all traces of Sury/Ondrej PHP repositories
# that cause HTTP 418 and signature errors
#######################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Sury Repository Cleanup Tool                        ║${NC}"
echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}✗ Do not run this script as root${NC}"
    echo -e "${YELLOW}  Run as regular user (will use sudo when needed)${NC}"
    exit 1
fi

echo -e "${YELLOW}This script will remove all Sury/Ondrej PHP repositories${NC}"
echo -e "${YELLOW}Continue? (y/N)${NC}"
read -p "> " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo -e "${CYAN}[1/5] Searching for Sury repositories...${NC}"

# Find all Sury-related files
echo "Checking /etc/apt/sources.list.d/..."
SURY_FILES=$(sudo find /etc/apt/sources.list.d/ -type f \( -name "*sury*" -o -name "*ondrej*" -o -name "*php*.list" \) 2>/dev/null)

if [ -n "$SURY_FILES" ]; then
    echo -e "${YELLOW}Found repository files:${NC}"
    echo "$SURY_FILES"
else
    echo -e "${GREEN}✓ No Sury files in sources.list.d${NC}"
fi

echo ""
echo "Checking /etc/apt/sources.list..."
if sudo grep -n "sury.org\|ondrej.*php\|ppa.launchpad.net.*ondrej" /etc/apt/sources.list 2>/dev/null; then
    echo -e "${YELLOW}Found Sury entries in sources.list (shown above)${NC}"
else
    echo -e "${GREEN}✓ No Sury entries in sources.list${NC}"
fi

echo ""
echo -e "${CYAN}[2/5] Removing repository files...${NC}"

sudo find /etc/apt/sources.list.d/ -type f \( -name "*sury*" -o -name "*ondrej*" -o -name "*php*.list" \) -delete 2>/dev/null && \
    echo -e "${GREEN}✓ Removed repository files${NC}" || \
    echo -e "${GREEN}✓ No files to remove${NC}"

echo ""
echo -e "${CYAN}[3/5] Cleaning sources.list...${NC}"

if sudo grep -q "sury.org\|ondrej.*php" /etc/apt/sources.list 2>/dev/null; then
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup.$(date +%Y%m%d_%H%M%S)
    sudo sed -i '/sury\.org/d' /etc/apt/sources.list
    sudo sed -i '/ondrej.*php/d' /etc/apt/sources.list
    sudo sed -i '/ppa\.launchpad\.net.*ondrej.*php/d' /etc/apt/sources.list
    echo -e "${GREEN}✓ Removed Sury entries from sources.list${NC}"
    echo -e "${CYAN}  Backup saved to sources.list.backup.*${NC}"
else
    echo -e "${GREEN}✓ No Sury entries in sources.list${NC}"
fi

echo ""
echo -e "${CYAN}[4/5] Removing GPG keys...${NC}"

# Remove GPG keys - use -rf to force removal
sudo rm -rf /etc/apt/keyrings/*sury* 2>/dev/null
sudo rm -rf /etc/apt/keyrings/*php* 2>/dev/null
sudo rm -rf /etc/apt/trusted.gpg.d/*sury* 2>/dev/null
sudo rm -rf /etc/apt/trusted.gpg.d/*ondrej* 2>/dev/null
sudo rm -rf /etc/apt/trusted.gpg.d/*php* 2>/dev/null

# Also check for specific files
sudo rm -f /etc/apt/keyrings/php-sury.gpg 2>/dev/null

# Remove from legacy keyring
if command -v apt-key &> /dev/null; then
    sudo apt-key del 14AA40EC0831756756D7F66C4F4EA0AAE5267A6C 2>/dev/null || true
fi

# Verify removal
echo "Checking for remaining GPG keys..."
REMAINING=$(sudo find /etc/apt/keyrings /etc/apt/trusted.gpg.d -name '*sury*' -o -name '*ondrej*' -o -name '*php*' 2>/dev/null)
if [ -n "$REMAINING" ]; then
    echo -e "${YELLOW}⚠ Some GPG files still present:${NC}"
    echo "$REMAINING"
    echo -e "${YELLOW}Forcing removal...${NC}"
    echo "$REMAINING" | while read file; do
        sudo rm -rf "$file" 2>/dev/null && echo "  Removed: $file"
    done
fi

echo -e "${GREEN}✓ GPG keys removed${NC}"

echo ""
echo -e "${CYAN}[5/5] Updating package lists...${NC}"

if sudo apt update 2>&1 | tee /tmp/cleanup-apt-update.log; then
    echo -e "${GREEN}✓ Package lists updated successfully${NC}"
else
    echo -e "${YELLOW}⚠ apt update completed with warnings${NC}"
fi

# Check for remaining Sury errors
if grep -qi "sury\|418" /tmp/cleanup-apt-update.log 2>/dev/null; then
    echo ""
    echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
    echo -e "${RED}✗ SURY ERRORS STILL PRESENT${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}The following locations may still contain Sury references:${NC}"
    echo ""
    sudo grep -r "sury.org" /etc/apt/ 2>/dev/null || true
    echo ""
    echo -e "${YELLOW}Run these commands to find and remove manually:${NC}"
    echo -e "${CYAN}  sudo grep -r 'sury.org' /etc/apt/${NC}"
    echo -e "${CYAN}  sudo grep -r 'ondrej' /etc/apt/${NC}"
    echo -e "${CYAN}  sudo nano /etc/apt/sources.list${NC}"
else
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ SUCCESS - All Sury repositories removed${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}You can now proceed with the installation:${NC}"
    echo -e "${CYAN}  ./install.sh${NC}"
fi

rm -f /tmp/cleanup-apt-update.log

echo ""
