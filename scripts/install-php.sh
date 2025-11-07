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
if [ ! -f /etc/apt/sources.list.d/ondrej-ubuntu-php-*.list ]; then
    sudo add-apt-repository -y ppa:ondrej/php
    sudo apt update -qq
    echo -e "${GREEN}✓ PHP repository added${NC}"
else
    echo -e "${GREEN}✓ PHP repository already exists${NC}"
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

PHP_PACKAGES=()
for ext in "${PHP_EXTENSIONS[@]}"; do
    PHP_PACKAGES+=("php${DEFAULT_PHP}-${ext}")
done

sudo apt install -y "${PHP_PACKAGES[@]}"

echo -e "${GREEN}✓ PHP ${DEFAULT_PHP} installed with all extensions${NC}"

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
