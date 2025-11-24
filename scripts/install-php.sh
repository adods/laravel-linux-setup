#!/bin/bash

#######################################################
# PHP Installation Module
#
# Installs PHP 8.3 (default) + PHP 8.4
# with all Laravel required extensions
#######################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# PHP versions to install
DEFAULT_PHP="8.3"
LATEST_PHP="8.4"

echo -e "${YELLOW}Installing PHP...${NC}"

# Add ondrej/php repository
echo "Adding PHP repository..."

# Function to check if repository is configured
check_php_repo() {
    # Check if any PHP repository source exists
    if ls /etc/apt/sources.list.d/*php*.list 2>/dev/null | grep -q . || \
       grep -r "packages.sury.org/php" /etc/apt/sources.list.d/ 2>/dev/null | grep -q .; then
        return 0
    fi
    return 1
}

# Check if repository already exists
if check_php_repo; then
    echo -e "${GREEN}✓ PHP repository already exists${NC}"
else
    # Detect distribution info
    if [ -f /etc/os-release ]; then
        . /etc/os-release
    fi

    # Determine distribution codename
    DISTRO_CODENAME=""

    # Try lsb_release first
    if command -v lsb_release &> /dev/null; then
        DISTRO_CODENAME=$(lsb_release -cs 2>/dev/null)
    fi

    # Fallback to os-release VERSION_CODENAME
    if [ -z "$DISTRO_CODENAME" ] && [ -n "$VERSION_CODENAME" ]; then
        DISTRO_CODENAME="$VERSION_CODENAME"
    fi

    # For Kali, use the Debian base version
    if [ "$ID" = "kali" ]; then
        # Kali Rolling is based on Debian Testing/Sid, but we'll use bookworm for stability
        DISTRO_CODENAME="bookworm"
        echo "Detected Kali Linux, using Debian $DISTRO_CODENAME base"
    fi

    echo "Distribution: $ID"
    echo "Codename: $DISTRO_CODENAME"

    # Try add-apt-repository first (Ubuntu/Debian with software-properties-common)
    if command -v add-apt-repository &> /dev/null && [ "$ID" != "kali" ]; then
        echo "Using add-apt-repository..."
        if sudo add-apt-repository -y ppa:ondrej/php 2>&1; then
            sudo apt update -qq
            echo -e "${GREEN}✓ PHP repository added via PPA${NC}"
        else
            echo -e "${YELLOW}⚠ PPA method failed, trying manual method...${NC}"
            DISTRO_CODENAME=""  # Force manual method
        fi
    fi

    # Manual method for Kali or if add-apt-repository failed/unavailable
    if ! check_php_repo; then
        if [ -z "$DISTRO_CODENAME" ]; then
            echo -e "${YELLOW}⚠ Cannot detect distribution codename${NC}"
            echo -e "${YELLOW}Attempting to use system's default PHP packages...${NC}"
        else
            echo "Adding repository manually for $ID ($DISTRO_CODENAME)..."

            # Add GPG key
            sudo mkdir -p /etc/apt/keyrings
            echo "Downloading Sury PHP repository GPG key..."

            if curl -fsSL https://packages.sury.org/php/apt.gpg -o /tmp/php-sury.gpg 2>&1; then
                sudo gpg --dearmor -o /etc/apt/keyrings/php-sury.gpg /tmp/php-sury.gpg 2>/dev/null
                rm -f /tmp/php-sury.gpg
                echo -e "${GREEN}✓ GPG key added${NC}"
            else
                echo -e "${YELLOW}⚠ Failed to download GPG key, trying without signature verification...${NC}"
            fi

            # Add repository
            if [ -f /etc/apt/keyrings/php-sury.gpg ]; then
                echo "deb [signed-by=/etc/apt/keyrings/php-sury.gpg] https://packages.sury.org/php/ $DISTRO_CODENAME main" | \
                    sudo tee /etc/apt/sources.list.d/php-sury.list > /dev/null
            else
                # Fallback without signature (less secure but works)
                echo "deb https://packages.sury.org/php/ $DISTRO_CODENAME main" | \
                    sudo tee /etc/apt/sources.list.d/php-sury.list > /dev/null
            fi

            echo "Updating package lists..."
            if sudo apt update 2>&1; then
                echo -e "${GREEN}✓ PHP repository added manually${NC}"
            else
                echo -e "${YELLOW}⚠ Repository added but apt update had warnings${NC}"
            fi
        fi
    fi
fi

# Verify repository is accessible
if ! check_php_repo; then
    echo -e "${YELLOW}⚠ Warning: PHP repository may not be properly configured${NC}"
    echo -e "${YELLOW}Will attempt to install PHP packages anyway...${NC}"
fi

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

# Install PHP 8.3 (default)
echo -e "${CYAN}Installing PHP ${DEFAULT_PHP} (default)...${NC}"

# First, try to install PHP core package to verify repository is working
echo "Installing PHP ${DEFAULT_PHP} core package..."
if ! sudo apt install -y php${DEFAULT_PHP} php${DEFAULT_PHP}-cli php${DEFAULT_PHP}-fpm 2>&1; then
    echo -e "${YELLOW}⚠ Warning: Failed to install PHP ${DEFAULT_PHP}${NC}"
    echo -e "${YELLOW}This usually means the repository is not accessible or the version is not available.${NC}"
    echo -e "${YELLOW}Checking available PHP versions...${NC}"
    apt-cache search "^php[0-9]\.[0-9]-fpm$" | head -5
    exit 1
fi

echo -e "${GREEN}✓ PHP ${DEFAULT_PHP} core installed${NC}"

# Install extensions one by one for better error handling
echo "Installing PHP ${DEFAULT_PHP} extensions..."
FAILED_EXTENSIONS=()

for ext in "${PHP_EXTENSIONS[@]}"; do
    # Skip already installed packages
    if [ "$ext" = "cli" ] || [ "$ext" = "fpm" ] || [ "$ext" = "common" ]; then
        continue
    fi

    package="php${DEFAULT_PHP}-${ext}"
    echo -n "  Installing $package... "

    if sudo apt install -y "$package" >> /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠ (skipped)${NC}"
        FAILED_EXTENSIONS+=("$ext")
    fi
done

if [ ${#FAILED_EXTENSIONS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠ Some extensions could not be installed: ${FAILED_EXTENSIONS[*]}${NC}"
    echo -e "${YELLOW}Laravel may still work, but some features might be limited.${NC}"
else
    echo -e "${GREEN}✓ All PHP ${DEFAULT_PHP} extensions installed${NC}"
fi

# Install PHP 8.4 (latest)
echo -e "${CYAN}Installing PHP ${LATEST_PHP}...${NC}"

PHP_PACKAGES_LATEST=()
for ext in "${PHP_EXTENSIONS[@]}"; do
    PHP_PACKAGES_LATEST+=("php${LATEST_PHP}-${ext}")
done

sudo apt install -y "${PHP_PACKAGES_LATEST[@]}" || {
    echo -e "${YELLOW}⚠ Warning: PHP ${LATEST_PHP} installation failed. Continuing with ${DEFAULT_PHP} only.${NC}"
}

if command -v php${LATEST_PHP} &> /dev/null; then
    echo -e "${GREEN}✓ PHP ${LATEST_PHP} installed with all extensions${NC}"
fi

# Set PHP 8.3 as default
echo "Setting PHP ${DEFAULT_PHP} as default..."
sudo update-alternatives --set php /usr/bin/php${DEFAULT_PHP}
sudo update-alternatives --set phar /usr/bin/phar${DEFAULT_PHP}
sudo update-alternatives --set phar.phar /usr/bin/phar.phar${DEFAULT_PHP}
sudo update-alternatives --set phpize /usr/bin/phpize${DEFAULT_PHP}
sudo update-alternatives --set php-config /usr/bin/php-config${DEFAULT_PHP}

echo -e "${GREEN}✓ PHP ${DEFAULT_PHP} set as default${NC}"

# Enable and start PHP-FPM services
echo "Enabling PHP-FPM services..."
sudo systemctl enable php${DEFAULT_PHP}-fpm
sudo systemctl start php${DEFAULT_PHP}-fpm

if command -v php${LATEST_PHP}-fpm &> /dev/null; then
    sudo systemctl enable php${LATEST_PHP}-fpm
    sudo systemctl start php${LATEST_PHP}-fpm
    echo -e "${GREEN}✓ PHP-FPM services enabled and started (${DEFAULT_PHP}, ${LATEST_PHP})${NC}"
else
    echo -e "${GREEN}✓ PHP-FPM service enabled and started (${DEFAULT_PHP})${NC}"
fi

# Display PHP version
echo ""
echo -e "${CYAN}Installed PHP versions:${NC}"
php -v | head -n1
if command -v php${LATEST_PHP} &> /dev/null; then
    php${LATEST_PHP} -v | head -n1
fi

echo -e "${GREEN}✓ PHP installation complete${NC}"
