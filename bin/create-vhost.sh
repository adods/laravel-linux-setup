#!/bin/bash

# Auto Virtual Host Creator
# Monitors /media/adods/Data/Herd and creates vhosts automatically

PROJECT_DIR="$1"
PROJECT_NAME=$(basename "$PROJECT_DIR")
DOMAIN="${PROJECT_NAME}.test"

# Auto-detect available PHP version if not specified
if [ -z "$2" ]; then
    # Try to find installed PHP-FPM version
    if [ -S /run/php/php8.4-fpm.sock ]; then
        PHP_VERSION="8.4"
    elif [ -S /run/php/php8.3-fpm.sock ]; then
        PHP_VERSION="8.3"
    elif [ -S /run/php/php8.2-fpm.sock ]; then
        PHP_VERSION="8.2"
    elif [ -S /run/php/php8.1-fpm.sock ]; then
        PHP_VERSION="8.1"
    else
        # Fallback to system default PHP version
        PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;" 2>/dev/null || echo "8.3")
    fi
else
    PHP_VERSION="$2"
fi

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to detect document root
detect_document_root() {
    local project_path="$1"

    # Check if it's a Laravel project (has artisan file)
    if [ -f "$project_path/artisan" ]; then
        echo "$project_path/public"
        return
    fi

    # Check for public folder with index.php or index.html
    if [ -d "$project_path/public" ]; then
        if [ -f "$project_path/public/index.php" ] || [ -f "$project_path/public/index.html" ]; then
            echo "$project_path/public"
            return
        fi
    fi

    # Check for public_html folder
    if [ -d "$project_path/public_html" ]; then
        if [ -f "$project_path/public_html/index.php" ] || [ -f "$project_path/public_html/index.html" ]; then
            echo "$project_path/public_html"
            return
        fi
    fi

    # Check for index.php or index.html in root
    if [ -f "$project_path/index.php" ] || [ -f "$project_path/index.html" ]; then
        echo "$project_path"
        return
    fi

    # Default to project root
    echo "$project_path"
}

# Function to detect project type
detect_project_type() {
    local project_path="$1"

    if [ -f "$project_path/artisan" ]; then
        echo "Laravel"
    elif [ -f "$project_path/wp-config.php" ]; then
        echo "WordPress"
    elif [ -f "$project_path/composer.json" ]; then
        echo "PHP/Composer"
    else
        echo "Generic PHP"
    fi
}

# Check if project directory exists
if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}Error: Project directory does not exist: $PROJECT_DIR${NC}"
    exit 1
fi

# Detect document root
DOC_ROOT=$(detect_document_root "$PROJECT_DIR")
PROJECT_TYPE=$(detect_project_type "$PROJECT_DIR")

echo -e "${YELLOW}Creating vhost for: $PROJECT_NAME${NC}"
echo -e "  Type: $PROJECT_TYPE"
echo -e "  Domain: $DOMAIN"
echo -e "  Document Root: $DOC_ROOT"
echo -e "  PHP Version: $PHP_VERSION"

# Check if vhost already exists
VHOST_FILE="/etc/apache2/sites-available/${PROJECT_NAME}.test.conf"
if [ -f "$VHOST_FILE" ]; then
    echo -e "${YELLOW}Warning: Virtual host already exists: $VHOST_FILE${NC}"
    read -p "Do you want to overwrite it? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Aborted.${NC}"
        exit 1
    fi
fi

# Create vhost configuration
VHOST_CONF="<VirtualHost *:80>
    ServerName ${DOMAIN}
    ServerAdmin webmaster@localhost
    DocumentRoot ${DOC_ROOT}

    <Directory ${DOC_ROOT}>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch \.php$>
        SetHandler \"proxy:unix:/run/php/php${PHP_VERSION}-fpm.sock|fcgi://localhost/\"
    </FilesMatch>

    ErrorLog \${APACHE_LOG_DIR}/${PROJECT_NAME}-error.log
    CustomLog \${APACHE_LOG_DIR}/${PROJECT_NAME}-access.log combined
</VirtualHost>"

# Write vhost file (needs sudo)
echo "$VHOST_CONF" | sudo tee "$VHOST_FILE" > /dev/null

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to create vhost file${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Created vhost file: $VHOST_FILE${NC}"

# Add to /etc/hosts if not already present
if ! grep -q "127.0.0.1.*${DOMAIN}" /etc/hosts; then
    echo "127.0.0.1    ${DOMAIN}" | sudo tee -a /etc/hosts > /dev/null
    echo -e "${GREEN}✓ Added ${DOMAIN} to /etc/hosts${NC}"
else
    echo -e "${YELLOW}  ${DOMAIN} already in /etc/hosts${NC}"
fi

# Enable site
sudo a2ensite "${PROJECT_NAME}.test.conf" > /dev/null 2>&1
echo -e "${GREEN}✓ Enabled site${NC}"

# Test Apache configuration
if sudo apache2ctl configtest 2>&1 | grep -q "Syntax OK"; then
    # Reload Apache
    sudo systemctl reload apache2
    echo -e "${GREEN}✓ Apache reloaded${NC}"
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Success!${NC}"
    echo -e "Your site is now available at: ${GREEN}http://${DOMAIN}${NC}"
    echo -e "${GREEN}========================================${NC}"
else
    echo -e "${RED}Error: Apache configuration test failed${NC}"
    echo -e "${YELLOW}Run 'sudo apache2ctl configtest' for details${NC}"
    exit 1
fi
