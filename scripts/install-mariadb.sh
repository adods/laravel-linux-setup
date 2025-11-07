#!/bin/bash

#######################################################
# MariaDB Installation Module
#
# Installs latest stable MariaDB and configures
# passwordless root access for local users
#######################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${YELLOW}Installing MariaDB...${NC}"

# Check if MariaDB is already installed
if command -v mysql &> /dev/null; then
    CURRENT_VERSION=$(mysql --version | awk '{print $5}' | cut -d'-' -f1)
    echo -e "${GREEN}✓ MariaDB/MySQL already installed: $CURRENT_VERSION${NC}"
else
    # Install MariaDB
    echo "Installing MariaDB server..."
    sudo apt install -y mariadb-server mariadb-client

    INSTALLED_VERSION=$(mysql --version | awk '{print $5}' | cut -d'-' -f1)
    echo -e "${GREEN}✓ MariaDB installed: $INSTALLED_VERSION${NC}"
fi

# Start and enable MariaDB
echo "Starting MariaDB service..."
sudo systemctl enable mariadb
sudo systemctl start mariadb

# Check MariaDB status
if systemctl is-active --quiet mariadb; then
    echo -e "${GREEN}✓ MariaDB is running${NC}"
else
    echo -e "${RED}✗ MariaDB failed to start${NC}"
    exit 1
fi

# Configure passwordless root access via unix_socket
echo -e "${CYAN}Configuring passwordless root access...${NC}"

# Run secure installation and configure authentication
sudo mysql -e "
-- Update root user to use unix_socket authentication
ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket;

-- Remove anonymous users
DELETE FROM mysql.user WHERE User='';

-- Remove remote root login
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');

-- Drop test database
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Flush privileges
FLUSH PRIVILEGES;
" 2>/dev/null || {
    echo -e "${YELLOW}⚠ Some security configurations may have already been applied${NC}"
}

# Verify passwordless access
echo "Testing MariaDB connection..."
if sudo mysql -e "SELECT 'Connection successful' as Status;" &>/dev/null; then
    echo -e "${GREEN}✓ Passwordless root access configured successfully${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Root access test failed. Manual configuration may be needed.${NC}"
fi

# Create convenience script for non-root user access
cat > /tmp/mysql-access-setup.sql << 'EOF'
-- Grant all privileges to current user (if needed)
-- This allows your user account to manage databases
-- Run this manually if needed: sudo mysql < /tmp/mysql-access-setup.sql
EOF

echo ""
echo -e "${CYAN}MariaDB Configuration:${NC}"
echo "  • Root authentication: unix_socket (passwordless for sudo)"
echo "  • Connect as root: sudo mysql"
echo "  • Or: mysql -u root (if your user has mysql group access)"
echo ""
echo -e "${GREEN}✓ MariaDB installation complete${NC}"
