#!/bin/bash

#######################################################
# Install Specific PHP Version
#
# Usage: install-php-version.sh <version> [--with-sury]
# Example: install-php-version.sh 8.2
# Example: install-php-version.sh 8.3 --with-sury
#
# Installs specified PHP version with all Laravel
# required extensions. Uses system packages by default,
# or Sury repository if --with-sury flag is provided.
#######################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}✗ Please do not run this script as root${NC}"
    echo -e "${YELLOW}Run without sudo. The script will request sudo when needed.${NC}"
    exit 1
fi

# Parse arguments
PHP_VERSION=""
USE_SURY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --with-sury)
            USE_SURY=true
            shift
            ;;
        --help|-h)
            echo "Usage: $(basename $0) <version> [--with-sury]"
            echo ""
            echo "Install specific PHP version with all Laravel extensions"
            echo ""
            echo "Arguments:"
            echo "  <version>      PHP version to install (e.g., 8.1, 8.2, 8.3, 8.4)"
            echo ""
            echo "Options:"
            echo "  --with-sury    Use Sury repository (provides latest PHP versions)"
            echo "  --help, -h     Show this help message"
            echo ""
            echo "Examples:"
            echo "  $(basename $0) 8.2"
            echo "  $(basename $0) 8.3 --with-sury"
            echo ""
            echo "Laravel Required Extensions:"
            echo "  cli, fpm, mysql, pgsql, sqlite3, mbstring, xml,"
            echo "  bcmath, curl, zip, gd, intl, soap, redis,"
            echo "  memcached, imagick, common"
            exit 0
            ;;
        *)
            if [ -z "$PHP_VERSION" ]; then
                PHP_VERSION="$1"
            else
                echo -e "${RED}✗ Unknown argument: $1${NC}"
                echo "Use --help for usage information"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate PHP version argument
if [ -z "$PHP_VERSION" ]; then
    echo -e "${RED}✗ Error: PHP version not specified${NC}"
    echo ""
    echo "Usage: $(basename $0) <version> [--with-sury]"
    echo "Example: $(basename $0) 8.2"
    echo ""
    echo "Use --help for more information"
    exit 1
fi

# Validate version format (should be X.Y)
if ! [[ "$PHP_VERSION" =~ ^[0-9]\.[0-9]$ ]]; then
    echo -e "${RED}✗ Error: Invalid PHP version format: $PHP_VERSION${NC}"
    echo -e "${YELLOW}Version should be in format X.Y (e.g., 8.2, 8.3, 8.4)${NC}"
    exit 1
fi

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Installing PHP ${PHP_VERSION}${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Laravel required PHP extensions
PHP_EXTENSIONS=(
    "cli"
    "fpm"
    "mysql"
    "pgsql"
    "sqlite3"
    "mbstring"
    "xml"
    "bcmath"
    "curl"
    "zip"
    "gd"
    "intl"
    "soap"
    "redis"
    "memcached"
    "imagick"
    "common"
)

# Function to setup Sury repository
setup_sury_repo() {
    echo -e "${YELLOW}Setting up Sury PHP repository...${NC}"

    # Detect distribution info
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    fi

    # Determine distribution codename
    DISTRO_CODENAME=""

    if command -v lsb_release &> /dev/null; then
        DISTRO_CODENAME=$(lsb_release -cs 2>/dev/null)
    fi

    if [ -z "$DISTRO_CODENAME" ] && [ -n "$VERSION_CODENAME" ]; then
        DISTRO_CODENAME="$VERSION_CODENAME"
    fi

    # For Kali, use Debian base
    if [ "$ID" = "kali" ]; then
        DISTRO_CODENAME="bookworm"
        echo "Detected Kali Linux, using Debian $DISTRO_CODENAME base"
    fi

    if [ -z "$DISTRO_CODENAME" ]; then
        echo -e "${RED}✗ Could not detect distribution codename${NC}"
        exit 1
    fi

    echo "Distribution: $ID ($DISTRO_CODENAME)"

    # Install required packages
    echo "Installing repository dependencies..."
    if command -v add-apt-repository &> /dev/null; then
        # Use add-apt-repository if available (Ubuntu/Debian with software-properties-common)
        echo "Adding Sury PHP PPA..."
        sudo add-apt-repository -y ppa:ondrej/php
        sudo apt update -qq
    else
        # Manual repository setup (for Kali and other distros without add-apt-repository)
        echo "Setting up repository manually..."

        # Create keyrings directory
        sudo mkdir -p /etc/apt/keyrings

        # Download and install GPG key
        echo "Downloading Sury GPG key..."
        curl -fsSL https://packages.sury.org/php/apt.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/php-sury.gpg

        # Add repository
        echo "Adding Sury repository..."
        echo "deb [signed-by=/etc/apt/keyrings/php-sury.gpg] https://packages.sury.org/php/ $DISTRO_CODENAME main" | \
            sudo tee /etc/apt/sources.list.d/php-sury.list > /dev/null

        # Update package lists
        sudo apt update -qq
    fi

    echo -e "${GREEN}✓ Sury repository configured${NC}"
}

# Setup repository if requested
if [ "$USE_SURY" = true ]; then
    setup_sury_repo
else
    echo -e "${CYAN}Using system packages (add --with-sury flag to use Sury repository)${NC}"
fi

# Check if PHP version is available
echo ""
echo "Checking if PHP ${PHP_VERSION} is available..."

if ! apt-cache search "^php${PHP_VERSION}-fpm$" 2>/dev/null | grep -q "php${PHP_VERSION}-fpm"; then
    echo -e "${RED}✗ PHP ${PHP_VERSION} is not available in repositories${NC}"
    echo ""

    if [ "$USE_SURY" = false ]; then
        echo -e "${YELLOW}Tip: Try running with --with-sury flag to access more PHP versions:${NC}"
        echo -e "${YELLOW}  $(basename $0) ${PHP_VERSION} --with-sury${NC}"
    else
        echo -e "${YELLOW}Available PHP versions:${NC}"
        apt-cache search "^php[0-9]\.[0-9]-fpm$" 2>/dev/null | grep -oP "php\K[0-9]\.[0-9]" | sort -V | sed 's/^/  - PHP /'
    fi

    exit 1
fi

echo -e "${GREEN}✓ PHP ${PHP_VERSION} is available${NC}"

# Install PHP core packages
echo ""
echo -e "${CYAN}Installing PHP ${PHP_VERSION} core packages...${NC}"

if sudo apt install -y php${PHP_VERSION} php${PHP_VERSION}-cli php${PHP_VERSION}-fpm; then
    echo -e "${GREEN}✓ PHP ${PHP_VERSION} core installed${NC}"
else
    echo -e "${RED}✗ Failed to install PHP ${PHP_VERSION}${NC}"
    exit 1
fi

# Install extensions
echo ""
echo -e "${CYAN}Installing PHP ${PHP_VERSION} extensions...${NC}"
FAILED_EXTENSIONS=()
INSTALLED_COUNT=0

for ext in "${PHP_EXTENSIONS[@]}"; do
    # Skip already installed packages
    if [ "$ext" = "cli" ] || [ "$ext" = "fpm" ] || [ "$ext" = "common" ]; then
        continue
    fi

    package="php${PHP_VERSION}-${ext}"
    echo -n "  Installing $package... "

    if sudo apt install -y "$package" >> /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        ((INSTALLED_COUNT++))
    else
        echo -e "${YELLOW}⚠ (not available)${NC}"
        FAILED_EXTENSIONS+=("$ext")
    fi
done

# Summary
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Installation Summary${NC}"
echo -e "${CYAN}========================================${NC}"

if [ ${#FAILED_EXTENSIONS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠ Some extensions could not be installed (${#FAILED_EXTENSIONS[@]} failed):${NC}"
    for ext in "${FAILED_EXTENSIONS[@]}"; do
        echo -e "  ${YELLOW}✗${NC} $ext"
    done
    echo ""
    echo -e "${YELLOW}Laravel may still work, but some features might be limited.${NC}"
else
    echo -e "${GREEN}✓ All extensions installed successfully ($INSTALLED_COUNT extensions)${NC}"
fi

# Enable and start PHP-FPM service
echo ""
echo "Enabling PHP ${PHP_VERSION}-FPM service..."

if sudo systemctl enable php${PHP_VERSION}-fpm && sudo systemctl start php${PHP_VERSION}-fpm; then
    echo -e "${GREEN}✓ PHP ${PHP_VERSION}-FPM service enabled and started${NC}"
else
    echo -e "${YELLOW}⚠ Failed to start PHP-FPM service${NC}"
fi

# Check service status
if sudo systemctl is-active --quiet php${PHP_VERSION}-fpm; then
    echo -e "${GREEN}✓ PHP ${PHP_VERSION}-FPM is running${NC}"
else
    echo -e "${RED}✗ PHP ${PHP_VERSION}-FPM is not running${NC}"
    echo "Check status with: sudo systemctl status php${PHP_VERSION}-fpm"
fi

# Display installed version
echo ""
echo -e "${CYAN}Installed version:${NC}"
php${PHP_VERSION} -v | head -n1

# Display socket path
echo ""
echo -e "${CYAN}PHP-FPM socket: ${GREEN}/run/php/php${PHP_VERSION}-fpm.sock${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ PHP ${PHP_VERSION} installation complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Show next steps
echo -e "${CYAN}Next steps:${NC}"
echo ""
echo "1. Set as default CLI version (optional):"
echo "   ${YELLOW}sudo update-alternatives --set php /usr/bin/php${PHP_VERSION}${NC}"
echo ""
echo "2. Use in virtual host with create-vhost.sh:"
echo "   ${YELLOW}create-vhost.sh /path/to/project ${PHP_VERSION}${NC}"
echo ""
echo "3. Verify installation:"
echo "   ${YELLOW}php${PHP_VERSION} -m${NC}  (list loaded modules)"
echo "   ${YELLOW}php${PHP_VERSION} -v${NC}  (show version)"
echo ""
