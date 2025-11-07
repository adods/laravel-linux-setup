#!/bin/bash

#######################################################
# Laravel Linux Setup - Automated Installation Script
#
# This script automatically installs and configures:
# - Apache (latest stable)
# - PHP (N-1 stable + latest)
# - MariaDB (latest stable)
# - Auto VHost generation with file watcher
#
# Author: Laravel Linux Setup Project
# License: MIT
#######################################################

set -e  # Exit on error

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
BIN_DIR="$SCRIPT_DIR/bin"
CONFIG_DIR="$SCRIPT_DIR/config"

# Log file
LOG_FILE="$SCRIPT_DIR/install.log"

# Configuration variables
PROJECT_DIR=""
CURRENT_USER="$USER"
DEFAULT_PHP_VERSION=""
LATEST_PHP_VERSION=""

#######################################################
# Helper Functions
#######################################################

log() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}✗ ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}⚠ WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script must NOT be run as root!"
        log_error "Please run as a regular user (the script will use sudo when needed)"
        exit 1
    fi
}

check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        log "This script requires sudo privileges. You may be prompted for your password."
        sudo -v
    fi
}

check_os() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot detect OS. /etc/os-release not found."
        exit 1
    fi

    . /etc/os-release

    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        log_error "This script only supports Ubuntu and Debian."
        log_error "Detected OS: $ID"
        exit 1
    fi

    log_success "OS detected: $PRETTY_NAME"
}

#######################################################
# User Input
#######################################################

get_user_input() {
    print_header "Laravel Linux Setup - Configuration"

    echo -e "${CYAN}This script will install and configure:${NC}"
    echo "  • Apache (latest stable version)"
    echo "  • PHP 8.3 (default) + PHP 8.4 (optional)"
    echo "  • MariaDB (latest stable version)"
    echo "  • Auto VHost generation system"
    echo ""

    # Get project directory
    while true; do
        echo -e "${YELLOW}Enter the directory path for your Laravel projects:${NC}"
        read -e -p "Project directory: " -i "$HOME/Projects" PROJECT_DIR

        # Expand ~ to home directory
        PROJECT_DIR="${PROJECT_DIR/#\~/$HOME}"

        if [[ -z "$PROJECT_DIR" ]]; then
            log_error "Project directory cannot be empty!"
            continue
        fi

        # Confirm or create directory
        if [[ -d "$PROJECT_DIR" ]]; then
            log_success "Directory exists: $PROJECT_DIR"
            break
        else
            echo -e "${YELLOW}Directory does not exist. Create it? (y/N)${NC}"
            read -p "> " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                mkdir -p "$PROJECT_DIR"
                log_success "Created directory: $PROJECT_DIR"
                break
            fi
        fi
    done

    echo ""
    echo -e "${CYAN}Installation Summary:${NC}"
    echo "  • Project Directory: $PROJECT_DIR"
    echo "  • Install User: $CURRENT_USER"
    echo "  • Default PHP: 8.3"
    echo "  • Also Install: PHP 8.4"
    echo "  • VHost Domain: <project-name>.test"
    echo ""

    echo -e "${YELLOW}Proceed with installation? (y/N)${NC}"
    read -p "> " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Installation cancelled by user."
        exit 0
    fi
}

#######################################################
# Installation Functions
#######################################################

update_system() {
    print_header "Updating System Packages"
    log "Updating package lists..."
    sudo apt update -qq
    log_success "System package lists updated"
}

install_dependencies() {
    print_header "Installing Dependencies"

    log "Installing required packages..."
    sudo apt install -y \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        curl \
        wget \
        git \
        gnupg \
        lsb-release \
        inotify-tools \
        >> "$LOG_FILE" 2>&1

    log_success "Dependencies installed"
}

install_apache() {
    if [[ -f "$SCRIPTS_DIR/install-apache.sh" ]]; then
        log "Running Apache installation module..."
        bash "$SCRIPTS_DIR/install-apache.sh" 2>&1 | tee -a "$LOG_FILE"
    else
        log_warning "Apache installation script not found. Skipping..."
    fi
}

install_php() {
    if [[ -f "$SCRIPTS_DIR/install-php.sh" ]]; then
        log "Running PHP installation module..."
        bash "$SCRIPTS_DIR/install-php.sh" 2>&1 | tee -a "$LOG_FILE"
    else
        log_warning "PHP installation script not found. Skipping..."
    fi
}

install_mariadb() {
    if [[ -f "$SCRIPTS_DIR/install-mariadb.sh" ]]; then
        log "Running MariaDB installation module..."
        bash "$SCRIPTS_DIR/install-mariadb.sh" 2>&1 | tee -a "$LOG_FILE"
    else
        log_warning "MariaDB installation script not found. Skipping..."
    fi
}

install_composer() {
    print_header "Installing Composer"

    if command -v composer &> /dev/null; then
        log_success "Composer already installed: $(composer --version)"
        return
    fi

    log "Downloading Composer..."
    cd /tmp
    curl -sS https://getcomposer.org/installer -o composer-setup.php

    log "Installing Composer globally..."
    sudo php composer-setup.php --install-dir=/usr/local/bin --filename=composer
    rm composer-setup.php

    log_success "Composer installed: $(composer --version)"
}

setup_vhost_system() {
    print_header "Setting Up Auto VHost System"

    if [[ -f "$SCRIPTS_DIR/setup-vhost.sh" ]]; then
        log "Running VHost setup module..."
        bash "$SCRIPTS_DIR/setup-vhost.sh" "$PROJECT_DIR" 2>&1 | tee -a "$LOG_FILE"
    else
        log_warning "VHost setup script not found. Skipping..."
    fi
}

setup_permissions() {
    if [[ -f "$SCRIPTS_DIR/setup-permissions.sh" ]]; then
        log "Running permissions setup module..."
        bash "$SCRIPTS_DIR/setup-permissions.sh" "$PROJECT_DIR" 2>&1 | tee -a "$LOG_FILE"
    else
        log_warning "Permissions setup script not found. Skipping..."
    fi
}

#######################################################
# Post-Installation
#######################################################

print_summary() {
    print_header "Installation Complete!"

    echo -e "${GREEN}✓ Apache installed and running${NC}"
    echo -e "${GREEN}✓ PHP 8.3 (default) + PHP 8.4 installed${NC}"
    echo -e "${GREEN}✓ MariaDB installed and configured${NC}"
    echo -e "${GREEN}✓ Composer installed${NC}"
    echo -e "${GREEN}✓ Auto VHost system configured${NC}"
    echo ""
    echo -e "${CYAN}Project Directory:${NC} $PROJECT_DIR"
    echo -e "${CYAN}VHost Monitoring:${NC} Active (systemd service)"
    echo ""
    echo -e "${YELLOW}How to use:${NC}"
    echo "  1. Create/copy a Laravel project to: $PROJECT_DIR/<project-name>"
    echo "  2. Your site will be automatically available at: http://<project-name>.test"
    echo ""
    echo -e "${YELLOW}Useful commands:${NC}"
    echo "  • Check watcher status: systemctl --user status herd-watcher"
    echo "  • View watcher logs: journalctl --user -u herd-watcher -f"
    echo "  • Manual vhost create: create-vhost.sh /path/to/project [php-version]"
    echo "  • Switch PHP CLI: sudo update-alternatives --config php"
    echo "  • Connect to MariaDB: mysql -u root"
    echo ""
    echo -e "${GREEN}Installation log saved to:${NC} $LOG_FILE"
    echo ""
    echo -e "${YELLOW}⚠ IMPORTANT: You may need to log out and log back in for group changes to take effect.${NC}"
}

#######################################################
# Main Execution
#######################################################

main() {
    # Clear log file
    > "$LOG_FILE"

    print_header "Laravel Linux Setup Installer"

    # Pre-checks
    check_root
    check_os
    check_sudo

    # Get user configuration
    get_user_input

    # Start installation
    log "Starting installation at $(date)"
    log "Installation log: $LOG_FILE"

    update_system
    install_dependencies
    install_apache
    install_php
    install_mariadb
    install_composer
    setup_vhost_system
    setup_permissions

    # Completion
    print_summary

    log "Installation completed successfully at $(date)"
}

# Run main function
main "$@"
