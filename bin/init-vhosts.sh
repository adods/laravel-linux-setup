#!/bin/bash

#######################################################
# Bulk VHost Initializer
#
# Scans an existing projects directory and creates
# Apache virtual hosts for any folder that doesn't
# already have one.
#
# Usage:
#   init-vhosts.sh <projects-dir> [php-version]
#
# Examples:
#   init-vhosts.sh ~/Projects
#   init-vhosts.sh ~/Projects 8.4
#######################################################

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECTS_DIR="${1%/}"   # strip trailing slash
PHP_VERSION="$2"

CREATE_VHOST_SCRIPT="/usr/local/bin/create-vhost.sh"
if [ ! -x "$CREATE_VHOST_SCRIPT" ]; then
    CREATE_VHOST_SCRIPT="$HOME/.local/bin/create-vhost.sh"
fi

#######################################################
# Validate inputs
#######################################################

if [ -z "$PROJECTS_DIR" ]; then
    echo -e "${RED}Error: No projects directory specified.${NC}"
    echo ""
    echo "Usage: $(basename "$0") <projects-dir> [php-version]"
    echo "  <projects-dir>   Directory containing project folders"
    echo "  [php-version]    Optional PHP version (e.g. 8.3, 8.4). Auto-detected if omitted."
    exit 1
fi

if [ ! -d "$PROJECTS_DIR" ]; then
    echo -e "${RED}Error: Directory does not exist: $PROJECTS_DIR${NC}"
    exit 1
fi

if [ ! -x "$CREATE_VHOST_SCRIPT" ]; then
    echo -e "${RED}Error: create-vhost.sh not found or not executable.${NC}"
    echo "Expected at /usr/local/bin/create-vhost.sh or $HOME/.local/bin/create-vhost.sh"
    exit 1
fi

#######################################################
# Scan and create vhosts
#######################################################

CREATED=0
SKIPPED=0
FAILED=0

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Bulk VHost Initializer${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}Projects directory:${NC} $PROJECTS_DIR"
if [ -n "$PHP_VERSION" ]; then
    echo -e "${CYAN}PHP version:${NC}        $PHP_VERSION (forced)"
else
    echo -e "${CYAN}PHP version:${NC}        auto-detect per project"
fi
echo ""

# Collect all immediate subdirectories, sorted
mapfile -t DIRS < <(find "$PROJECTS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

if [ ${#DIRS[@]} -eq 0 ]; then
    echo -e "${YELLOW}No subdirectories found in: $PROJECTS_DIR${NC}"
    exit 0
fi

echo -e "Found ${#DIRS[@]} folder(s) to evaluate...\n"

for DIR in "${DIRS[@]}"; do
    PROJECT_NAME=$(basename "$DIR")
    VHOST_FILE="/etc/apache2/sites-available/${PROJECT_NAME}.test.conf"

    # Skip hidden directories (e.g. .git, .cache)
    if [[ "$PROJECT_NAME" == .* ]]; then
        continue
    fi

    # Skip if vhost already exists, but still ensure /etc/hosts has the entry
    if [ -f "$VHOST_FILE" ]; then
        DOMAIN="${PROJECT_NAME}.test"
        if ! grep -qw "$DOMAIN" /etc/hosts; then
            echo "127.0.0.1    $DOMAIN" | sudo tee -a /etc/hosts > /dev/null
            echo -e "  ${YELLOW}SKIP${NC}  $PROJECT_NAME  (vhost exists, added missing /etc/hosts entry)"
        else
            echo -e "  ${YELLOW}SKIP${NC}  $PROJECT_NAME  (vhost already exists)"
        fi
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    echo -e "  ${CYAN}CREATE${NC} $PROJECT_NAME"

    # Call create-vhost.sh; pass PHP version only if specified
    if [ -n "$PHP_VERSION" ]; then
        "$CREATE_VHOST_SCRIPT" "$DIR" "$PHP_VERSION"
    else
        "$CREATE_VHOST_SCRIPT" "$DIR"
    fi

    if [ $? -eq 0 ]; then
        CREATED=$((CREATED + 1))
    else
        echo -e "  ${RED}FAILED${NC} $PROJECT_NAME"
        FAILED=$((FAILED + 1))
    fi

    echo ""
done

#######################################################
# Summary
#######################################################

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}Created:${NC} $CREATED"
echo -e "  ${YELLOW}Skipped:${NC} $SKIPPED  (already had a vhost)"
if [ "$FAILED" -gt 0 ]; then
    echo -e "  ${RED}Failed:${NC}  $FAILED"
fi
echo ""

if [ "$CREATED" -gt 0 ]; then
    echo -e "${GREEN}Done. $CREATED vhost(s) created.${NC}"
elif [ "$FAILED" -eq 0 ]; then
    echo -e "${YELLOW}Nothing to do — all projects already have vhosts.${NC}"
fi
echo ""
