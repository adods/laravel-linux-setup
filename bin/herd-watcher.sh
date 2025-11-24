#!/bin/bash

# Herd Directory Watcher
# Monitors /media/adods/Data/Herd for new directories and auto-creates vhosts

WATCH_DIR="/media/adods/Data/Herd"
CREATE_VHOST_SCRIPT="$HOME/.local/bin/create-vhost.sh"
LOG_FILE="$HOME/.local/log/herd-watcher.log"

# Auto-detect available PHP version
if [ -S /run/php/php8.4-fpm.sock ]; then
    PHP_VERSION="8.4"
elif [ -S /run/php/php8.3-fpm.sock ]; then
    PHP_VERSION="8.3"
elif [ -S /run/php/php8.2-fpm.sock ]; then
    PHP_VERSION="8.2"
elif [ -S /run/php/php8.1-fpm.sock ]; then
    PHP_VERSION="8.1"
else
    # Fallback to detecting from php command
    PHP_VERSION=$(php -r "echo PHP_MAJOR_VERSION.'.'.PHP_MINOR_VERSION;" 2>/dev/null || echo "8.3")
fi

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if inotify-tools is installed
if ! command -v inotifywait &> /dev/null; then
    echo -e "${RED}Error: inotifywait not found. Please install inotify-tools:${NC}"
    echo "  sudo apt install inotify-tools"
    exit 1
fi

# Check if watch directory exists
if [ ! -d "$WATCH_DIR" ]; then
    echo -e "${RED}Error: Watch directory does not exist: $WATCH_DIR${NC}"
    exit 1
fi

# Check if create-vhost script exists
if [ ! -f "$CREATE_VHOST_SCRIPT" ]; then
    echo -e "${RED}Error: create-vhost script not found: $CREATE_VHOST_SCRIPT${NC}"
    exit 1
fi

log "Herd Watcher started"
log "Watching directory: $WATCH_DIR"
echo -e "${GREEN}Herd Watcher is now monitoring: $WATCH_DIR${NC}"
echo -e "${BLUE}Waiting for new directories...${NC}"
echo ""

# Create vhost for existing directories (optional, run once on start)
if [ "$1" == "--init" ]; then
    log "Initializing vhosts for existing directories..."
    for dir in "$WATCH_DIR"/*/ ; do
        if [ -d "$dir" ]; then
            PROJECT_NAME=$(basename "$dir")
            # Check if vhost doesn't already exist
            if [ ! -f "/etc/apache2/sites-available/${PROJECT_NAME}.test.conf" ]; then
                log "Creating vhost for existing project: $PROJECT_NAME"
                "$CREATE_VHOST_SCRIPT" "$dir" "$PHP_VERSION"
            fi
        fi
    done
    log "Initialization complete"
    echo ""
fi

# Monitor for new directories
inotifywait -m -e create,moved_to --format '%f' "$WATCH_DIR" | while read NEW_DIR
do
    # Full path to the new directory
    FULL_PATH="$WATCH_DIR/$NEW_DIR"

    # Check if it's actually a directory (not a file)
    if [ -d "$FULL_PATH" ]; then
        log "New directory detected: $NEW_DIR"
        echo -e "${YELLOW}New project detected: $NEW_DIR${NC}"

        # Wait a moment for the directory to be fully created
        sleep 2

        # Check if vhost already exists
        if [ -f "/etc/apache2/sites-available/${NEW_DIR}.test.conf" ]; then
            log "Vhost already exists for: $NEW_DIR"
            echo -e "${YELLOW}Vhost already exists for: $NEW_DIR${NC}"
        else
            # Create the vhost
            log "Creating vhost for: $NEW_DIR"
            "$CREATE_VHOST_SCRIPT" "$FULL_PATH" "$PHP_VERSION"

            if [ $? -eq 0 ]; then
                log "Successfully created vhost for: $NEW_DIR"
                echo -e "${GREEN}✓ Vhost created successfully!${NC}"
            else
                log "Failed to create vhost for: $NEW_DIR"
                echo -e "${RED}✗ Failed to create vhost${NC}"
            fi
        fi
        echo ""
    fi
done
