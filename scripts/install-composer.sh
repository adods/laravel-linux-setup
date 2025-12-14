#!/bin/bash

#######################################################
# Composer Multiple Versions Installation Module
#
# Installs multiple Composer versions with version
# suffixes (e.g., composer2.2, composer1.10)
#######################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Installing Composer (Multiple Versions)...${NC}"

# Composer versions to install
# Format: "VERSION_NUMBER MAJOR.MINOR"
# Add or modify versions as needed
COMPOSER_VERSIONS=(
    "2.8.4 2.8"
    "2.7.7 2.7"
    "2.2.24 2.2"
    "1.10.27 1.10"
)

# Default version to symlink as 'composer'
DEFAULT_VERSION="2.8"

# Installation directory
INSTALL_DIR="/usr/local/bin"

# Temporary directory for downloads
TMP_DIR="/tmp/composer-install-$$"
mkdir -p "$TMP_DIR"

# Cleanup function
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Function to download and install a specific Composer version
install_composer_version() {
    local full_version="$1"
    local short_version="$2"
    local binary_name="composer${short_version}"
    local binary_path="${INSTALL_DIR}/${binary_name}"

    # Check if already installed
    if [ -f "$binary_path" ]; then
        local installed_version=$("$binary_path" --version 2>/dev/null | grep -oP "Composer version \K[0-9]+\.[0-9]+\.[0-9]+" || echo "unknown")
        if [ "$installed_version" = "$full_version" ]; then
            echo -e "${GREEN}✓ Composer ${short_version} (${full_version}) already installed${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠ Composer ${short_version} exists (${installed_version}), upgrading to ${full_version}...${NC}"
        fi
    fi

    echo -n "  Installing Composer ${short_version} (${full_version})... "

    # Download Composer installer
    local installer="${TMP_DIR}/composer-setup-${short_version}.php"
    local composer_phar="${TMP_DIR}/composer${short_version}.phar"

    # Download with specific version
    if curl -sS https://getcomposer.org/installer -o "$installer" 2>/dev/null; then
        # Install specific version
        if php "$installer" --version="$full_version" --filename="composer${short_version}.phar" --install-dir="$TMP_DIR" --quiet; then
            # Move to installation directory
            sudo mv "${TMP_DIR}/composer${short_version}.phar" "$binary_path"
            sudo chmod +x "$binary_path"

            # Verify installation
            local verify_version=$("$binary_path" --version 2>/dev/null | grep -oP "Composer version \K[0-9]+\.[0-9]+\.[0-9]+" || echo "unknown")
            if [ "$verify_version" = "$full_version" ]; then
                echo -e "${GREEN}✓${NC}"
                return 0
            else
                echo -e "${RED}✗ (verification failed)${NC}"
                return 1
            fi
        else
            echo -e "${RED}✗ (installation failed)${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ (download failed)${NC}"
        return 1
    fi
}

# Install all specified versions
echo -e "${CYAN}Installing Composer versions...${NC}"
INSTALLED_VERSIONS=()
FAILED_VERSIONS=()

for version_spec in "${COMPOSER_VERSIONS[@]}"; do
    read -r full_version short_version <<< "$version_spec"

    if install_composer_version "$full_version" "$short_version"; then
        INSTALLED_VERSIONS+=("$short_version")
    else
        FAILED_VERSIONS+=("$short_version")
    fi
done

echo ""

# Create default symlink
if [ ${#INSTALLED_VERSIONS[@]} -gt 0 ]; then
    echo -e "${CYAN}Setting up default Composer version...${NC}"

    # Check if default version was installed
    if [[ " ${INSTALLED_VERSIONS[*]} " =~ " ${DEFAULT_VERSION} " ]]; then
        echo -n "  Creating symlink: composer -> composer${DEFAULT_VERSION}... "
        sudo ln -sf "${INSTALL_DIR}/composer${DEFAULT_VERSION}" "${INSTALL_DIR}/composer"
        echo -e "${GREEN}✓${NC}"
    else
        # Use the first installed version as default
        DEFAULT_VERSION="${INSTALLED_VERSIONS[0]}"
        echo -e "${YELLOW}⚠ Preferred version ${DEFAULT_VERSION} not available, using ${DEFAULT_VERSION}${NC}"
        echo -n "  Creating symlink: composer -> composer${DEFAULT_VERSION}... "
        sudo ln -sf "${INSTALL_DIR}/composer${DEFAULT_VERSION}" "${INSTALL_DIR}/composer"
        echo -e "${GREEN}✓${NC}"
    fi
fi

# Display summary
echo ""
echo -e "${CYAN}Installation Summary:${NC}"
echo ""

if [ ${#INSTALLED_VERSIONS[@]} -gt 0 ]; then
    echo -e "${GREEN}Successfully installed:${NC}"
    for version in "${INSTALLED_VERSIONS[@]}"; do
        binary="${INSTALL_DIR}/composer${version}"
        full_ver=$("$binary" --version 2>/dev/null | grep -oP "Composer version \K[0-9]+\.[0-9]+\.[0-9]+" || echo "unknown")
        echo "  • composer${version} → Composer ${full_ver}"
    done
fi

if [ ${#FAILED_VERSIONS[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Failed installations:${NC}"
    for version in "${FAILED_VERSIONS[@]}"; do
        echo "  • composer${version}"
    done
fi

echo ""
echo -e "${CYAN}Default composer command:${NC}"
composer --version 2>/dev/null || echo -e "${RED}  ✗ Not available${NC}"

echo ""
echo -e "${CYAN}Usage examples:${NC}"
echo "  • composer install      # Uses default (composer${DEFAULT_VERSION})"
echo "  • composer2.8 install   # Uses Composer 2.8"
echo "  • composer2.2 install   # Uses Composer 2.2"
echo "  • composer1.10 install  # Uses Composer 1.x"

echo ""
if [ ${#INSTALLED_VERSIONS[@]} -eq ${#COMPOSER_VERSIONS[@]} ]; then
    echo -e "${GREEN}✓ All Composer versions installed successfully${NC}"
elif [ ${#INSTALLED_VERSIONS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠ Some Composer versions failed to install (${#FAILED_VERSIONS[@]} failures)${NC}"
else
    echo -e "${RED}✗ Composer installation failed${NC}"
    exit 1
fi
