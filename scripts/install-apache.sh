#!/bin/bash

#######################################################
# Apache Installation Module
#
# Installs latest stable Apache2 and configures it
# for Laravel development
#######################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Installing Apache2...${NC}"

# Check if Apache is already installed
if command -v apache2 &> /dev/null; then
    CURRENT_VERSION=$(apache2 -v | head -n1 | awk '{print $3}' | cut -d'/' -f2)
    echo -e "${GREEN}✓ Apache already installed: $CURRENT_VERSION${NC}"
else
    # Install Apache2
    echo "Installing Apache2..."
    sudo apt install -y apache2

    INSTALLED_VERSION=$(apache2 -v | head -n1 | awk '{print $3}' | cut -d'/' -f2)
    echo -e "${GREEN}✓ Apache installed: $INSTALLED_VERSION${NC}"
fi

# Enable required Apache modules
echo "Enabling required Apache modules..."
sudo a2enmod rewrite proxy proxy_fcgi ssl headers

# Start and enable Apache
echo "Starting Apache service..."
sudo systemctl enable apache2
sudo systemctl start apache2

# Check Apache status
if systemctl is-active --quiet apache2; then
    echo -e "${GREEN}✓ Apache is running${NC}"
else
    echo -e "${RED}✗ Apache failed to start${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Apache installation complete${NC}"
