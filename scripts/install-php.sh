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

            # Test connectivity to sury.org first
            echo "Testing connectivity to packages.sury.org..."
            SURY_AVAILABLE=false

            # Try with user-agent header to avoid bot detection (418 I'm a teapot error)
            TEST_RESPONSE=$(curl -s -A "Mozilla/5.0 (compatible; apt/2.0)" --connect-timeout 5 --max-time 10 -w "%{http_code}" https://packages.sury.org/ -o /dev/null 2>&1)

            if [ "$TEST_RESPONSE" = "200" ] || [ "$TEST_RESPONSE" = "301" ] || [ "$TEST_RESPONSE" = "302" ]; then
                echo -e "${GREEN}✓ Sury repository is accessible${NC}"
                SURY_AVAILABLE=true
            elif [ "$TEST_RESPONSE" = "418" ]; then
                echo -e "${YELLOW}⚠ Sury repository blocking requests (HTTP 418 - I'm a teapot)${NC}"
                echo -e "${YELLOW}This usually means IP-based restrictions or rate limiting${NC}"
                echo -e "${YELLOW}Will use system's default PHP packages instead${NC}"
                SURY_AVAILABLE=false
            else
                echo -e "${YELLOW}⚠ Cannot reach packages.sury.org (HTTP $TEST_RESPONSE)${NC}"
                echo -e "${YELLOW}This could be due to network issues, DNS problems, or firewall restrictions${NC}"
                SURY_AVAILABLE=false
            fi

            if [ "$SURY_AVAILABLE" = true ]; then
                # Add GPG key with user-agent header
                sudo mkdir -p /etc/apt/keyrings
                echo "Downloading Sury PHP repository GPG key..."

                # Use wget if available (apt uses wget internally), otherwise curl with user-agent
                if command -v wget &> /dev/null; then
                    if wget -q --timeout=10 -O /tmp/php-sury.gpg https://packages.sury.org/php/apt.gpg 2>&1; then
                        sudo gpg --dearmor -o /etc/apt/keyrings/php-sury.gpg /tmp/php-sury.gpg 2>/dev/null
                        rm -f /tmp/php-sury.gpg
                        echo -e "${GREEN}✓ GPG key added${NC}"
                    else
                        echo -e "${YELLOW}⚠ Failed to download GPG key via wget${NC}"
                        SURY_AVAILABLE=false
                    fi
                else
                    if curl -fsSL -A "Mozilla/5.0 (compatible; apt/2.0)" --max-time 10 https://packages.sury.org/php/apt.gpg -o /tmp/php-sury.gpg 2>&1; then
                        sudo gpg --dearmor -o /etc/apt/keyrings/php-sury.gpg /tmp/php-sury.gpg 2>/dev/null
                        rm -f /tmp/php-sury.gpg
                        echo -e "${GREEN}✓ GPG key added${NC}"
                    else
                        echo -e "${YELLOW}⚠ Failed to download GPG key via curl${NC}"
                        SURY_AVAILABLE=false
                    fi
                fi
            fi

            if [ "$SURY_AVAILABLE" = true ]; then
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
                UPDATE_OUTPUT=$(sudo apt update 2>&1)
                UPDATE_EXIT=$?

                # Check for specific Sury errors (418, fetch failures, etc.)
                if echo "$UPDATE_OUTPUT" | grep -qi "sury" && echo "$UPDATE_OUTPUT" | grep -qiE "(418|failed|error|unable to fetch)"; then
                    echo -e "${YELLOW}⚠ Repository update failed for Sury (likely HTTP 418 or fetch error)${NC}"
                    echo -e "${YELLOW}Removing Sury repository and using system packages${NC}"
                    SURY_AVAILABLE=false
                    # Remove the broken repository
                    sudo rm -f /etc/apt/sources.list.d/php-sury.list
                    sudo rm -f /etc/apt/keyrings/php-sury.gpg
                    sudo apt update -qq 2>&1
                elif [ $UPDATE_EXIT -eq 0 ]; then
                    echo -e "${GREEN}✓ PHP repository added manually${NC}"
                else
                    echo -e "${YELLOW}⚠ Repository update had warnings, will try system packages${NC}"
                    SURY_AVAILABLE=false
                    sudo rm -f /etc/apt/sources.list.d/php-sury.list
                    sudo apt update -qq 2>&1
                fi
            fi

            if [ "$SURY_AVAILABLE" = false ]; then
                echo -e "${YELLOW}⚠ Sury repository unavailable, will use system's default PHP packages${NC}"
                echo -e "${YELLOW}Note: System PHP version may differ from 8.3/8.4${NC}"
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
