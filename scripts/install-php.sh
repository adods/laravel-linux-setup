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

    # Note: ppa:ondrej/php and packages.sury.org are the SAME repository
    # Both are maintained by Ondřej Surý and both can return HTTP 418 errors

    # Skip third-party repositories - just use system packages
    # Reasons:
    # 1. Sury/Ondrej repository often blocks IPs (HTTP 418 "I'm a teapot")
    # 2. Signature verification issues ("not signed" errors)
    # 3. Network/firewall restrictions in security-focused environments
    # 4. System packages are more stable and tested for each distro

    echo -e "${CYAN}Using system's native PHP packages for better reliability${NC}"
    echo -e "${CYAN}System packages are tested and maintained by your distribution${NC}"

    # Optional: Only try PPA on standard Ubuntu if explicitly requested
    # Uncomment the following lines if you want to try PPA on Ubuntu:
    # if [ "$ID" = "ubuntu" ] && [ "$ID_LIKE" != "*debian*kali*" ] && command -v add-apt-repository &> /dev/null; then
    #     echo "Attempting to add Ondrej PHP PPA (may fail with HTTP 418)..."
    #     sudo add-apt-repository -y ppa:ondrej/php 2>&1 && sudo apt update -qq 2>&1
    # fi
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

# Detect available PHP version
echo "Detecting available PHP versions..."
AVAILABLE_PHP_VERSIONS=$(apt-cache search "^php[0-9]\.[0-9]-fpm$" 2>/dev/null | grep -oP "php\K[0-9]\.[0-9]" | sort -V)

if [ -z "$AVAILABLE_PHP_VERSIONS" ]; then
    echo -e "${YELLOW}⚠ No specific PHP versions found, trying generic 'php' package${NC}"
    INSTALL_PHP_VERSION=""  # Will use 'php' instead of 'php8.3'
else
    echo "Available PHP versions:"
    echo "$AVAILABLE_PHP_VERSIONS" | sed 's/^/  - PHP /'

    # Try to use requested version first, then fallback to available versions
    if echo "$AVAILABLE_PHP_VERSIONS" | grep -q "^${DEFAULT_PHP}$"; then
        INSTALL_PHP_VERSION="$DEFAULT_PHP"
        echo -e "${GREEN}✓ Using PHP ${DEFAULT_PHP} (requested version)${NC}"
    else
        # Use the latest available version
        INSTALL_PHP_VERSION=$(echo "$AVAILABLE_PHP_VERSIONS" | tail -1)
        echo -e "${YELLOW}⚠ PHP ${DEFAULT_PHP} not available, using PHP ${INSTALL_PHP_VERSION} instead${NC}"
    fi
fi

# Install PHP core package
if [ -n "$INSTALL_PHP_VERSION" ]; then
    echo -e "${CYAN}Installing PHP ${INSTALL_PHP_VERSION}...${NC}"
    echo "Installing PHP ${INSTALL_PHP_VERSION} core packages..."

    if sudo apt install -y php${INSTALL_PHP_VERSION} php${INSTALL_PHP_VERSION}-cli php${INSTALL_PHP_VERSION}-fpm 2>&1; then
        echo -e "${GREEN}✓ PHP ${INSTALL_PHP_VERSION} core installed${NC}"
    else
        echo -e "${YELLOW}⚠ Failed to install PHP ${INSTALL_PHP_VERSION}, trying generic php package...${NC}"
        INSTALL_PHP_VERSION=""
    fi
fi

# Fallback to generic PHP package
if [ -z "$INSTALL_PHP_VERSION" ]; then
    echo -e "${CYAN}Installing system's default PHP...${NC}"
    if sudo apt install -y php php-cli php-fpm 2>&1; then
        INSTALLED_PHP_VERSION=$(php -v 2>/dev/null | head -1 | grep -oP "PHP \K[0-9]\.[0-9]" || echo "unknown")
        echo -e "${GREEN}✓ PHP ${INSTALLED_PHP_VERSION} installed (system default)${NC}"
        INSTALL_PHP_VERSION="$INSTALLED_PHP_VERSION"
    else
        echo -e "${RED}✗ Failed to install PHP${NC}"
        echo -e "${RED}Please check your network connection and repository configuration${NC}"
        exit 1
    fi
fi

# Update variables to use the actually installed version
DEFAULT_PHP="$INSTALL_PHP_VERSION"

# Install extensions one by one for better error handling
echo "Installing PHP ${DEFAULT_PHP} extensions..."
FAILED_EXTENSIONS=()

for ext in "${PHP_EXTENSIONS[@]}"; do
    # Skip already installed packages
    if [ "$ext" = "cli" ] || [ "$ext" = "fpm" ] || [ "$ext" = "common" ]; then
        continue
    fi

    # Try versioned package first, then generic
    if [ -n "$DEFAULT_PHP" ] && [ "$DEFAULT_PHP" != "unknown" ]; then
        package="php${DEFAULT_PHP}-${ext}"
    else
        package="php-${ext}"
    fi

    echo -n "  Installing $package... "

    if sudo apt install -y "$package" >> /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        # If versioned package failed, try generic package
        if [ "$package" != "php-${ext}" ]; then
            echo -n "(trying php-${ext}... "
            if sudo apt install -y "php-${ext}" >> /dev/null 2>&1; then
                echo -e "${GREEN}✓${NC})"
                continue
            fi
        fi
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

# Install PHP 8.4 (latest) - only if using Sury repository
if check_php_repo && apt-cache search "^php${LATEST_PHP}-fpm$" 2>/dev/null | grep -q .; then
    echo -e "${CYAN}Installing PHP ${LATEST_PHP}...${NC}"

    PHP_PACKAGES_LATEST=()
    for ext in "${PHP_EXTENSIONS[@]}"; do
        PHP_PACKAGES_LATEST+=("php${LATEST_PHP}-${ext}")
    done

    sudo apt install -y "${PHP_PACKAGES_LATEST[@]}" 2>&1 | grep -v "^Selecting" || {
        echo -e "${YELLOW}⚠ Warning: PHP ${LATEST_PHP} installation failed. Continuing with ${DEFAULT_PHP} only.${NC}"
    }

    if command -v php${LATEST_PHP} &> /dev/null; then
        echo -e "${GREEN}✓ PHP ${LATEST_PHP} installed with all extensions${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Skipping PHP ${LATEST_PHP} installation (only available via Sury repository)${NC}"
    echo -e "${YELLOW}Will use PHP ${DEFAULT_PHP} only${NC}"
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
