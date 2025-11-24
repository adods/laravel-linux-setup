# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Laravel Linux Setup** is an automated installation system for Laravel development environments on Debian-based Linux distributions. It installs Apache, PHP (8.3 + 8.4), MariaDB, Node.js, and sets up automatic virtual host generation. The installer checks for required system commands (apt, systemctl, etc.) rather than restricting to specific distro versions, making it compatible with Ubuntu, Debian, Linux Mint, Pop!_OS, and other Debian derivatives.

## Key Architecture

### Modular Installation System

The installation is split into separate, independent modules in `scripts/`:

- `install-apache.sh` - Apache with required modules (rewrite, proxy_fcgi, ssl, headers)
- `install-php.sh` - PHP 8.3 (default) + PHP 8.4 with all Laravel extensions
- `install-mariadb.sh` - MariaDB with passwordless root access via unix_socket
- `install-nodejs.sh` - Node.js LTS via NVM
- `setup-vhost.sh` - Virtual host auto-generation system
- `setup-permissions.sh` - User permissions and www-data group setup

Each module is sourced by `install.sh` and runs independently with its own error handling.

### Auto VHost System

The core feature is automatic virtual host creation when new projects are added:

1. **create-vhost.sh** (`bin/create-vhost.sh`):
   - Detects project type (Laravel, WordPress, generic PHP)
   - Auto-discovers document root (checks for `artisan` → `public/`, `public_html/`, root)
   - Creates Apache vhost config with PHP-FPM proxy
   - Supports per-project PHP versions (8.3 or 8.4)
   - Updates `/etc/hosts` and enables site

2. **herd-watcher.sh** (`bin/herd-watcher.sh`):
   - Uses `inotifywait` to monitor project directory
   - Triggers `create-vhost.sh` when new directories are detected
   - Runs as systemd user service (created by `setup-vhost.sh`)
   - Configurable watch directory and default PHP version

3. **Systemd Integration** (`setup-vhost.sh`):
   - Creates `~/.config/systemd/user/herd-watcher.service`
   - Enables user lingering for boot-time startup
   - Provides passwordless sudo for vhost management via `/etc/sudoers.d/vhost-management`

### Installation Flow

1. Pre-checks (non-root user, system command availability check, sudo)
2. User input (project directory path)
3. System update and dependencies
4. Parallel-safe module execution (Apache → PHP → MariaDB → Node.js → Composer)
5. VHost system setup with user-specific project path
6. Permissions configuration (www-data group, setgid bit)

**System Check Logic**: Instead of checking for specific distro names, the installer verifies:
- Presence of `apt` and `apt-get` (package manager)
- Essential commands: `bash`, `sudo`, `systemctl`, `chmod`, `chown`
- This approach supports any Debian-based distribution with systemd

**Dependency Handling**:
- Core dependencies are required and will fail installation if missing
- Optional dependencies (like `software-properties-common`) are installed if available
- PHP repository: Falls back to manual configuration if `add-apt-repository` unavailable
- Uses Sury PHP repository directly when PPA tools not present (Kali Linux, etc.)

## Development Commands

### Testing Installation

```bash
# Full installation (prompts for project directory)
./install.sh

# Test individual modules
bash scripts/install-apache.sh
bash scripts/install-php.sh
bash scripts/install-mariadb.sh
bash scripts/install-nodejs.sh

# Test vhost creation
bash scripts/setup-vhost.sh ~/Projects
```

### Testing VHost System

```bash
# Manual vhost creation with default PHP 8.3
create-vhost.sh /path/to/project

# With specific PHP version
create-vhost.sh /path/to/project 8.4

# Test watcher service
systemctl --user status herd-watcher
journalctl --user -u herd-watcher -f

# Restart watcher
systemctl --user restart herd-watcher
```

### Database Access

```bash
# Passwordless root access (unix_socket auth)
sudo mysql
# or
mysql -u root
```

## Important Implementation Details

### PHP Version Management

- **Default CLI version**: PHP 8.3 (set via `update-alternatives`)
- **Both versions available**: 8.3 and 8.4 with separate PHP-FPM sockets
- **Per-project versions**: VHost configs specify FPM socket path (`/run/php/php{VERSION}-fpm.sock`)
- **Switching CLI**: `sudo update-alternatives --config php`

### Document Root Detection Logic

The `create-vhost.sh` script uses this priority order:

1. If `artisan` exists → Laravel project → use `/public`
2. If `public/index.php` or `public/index.html` exists → use `/public`
3. If `public_html/index.php` or `public_html/index.html` exists → use `/public_html`
4. If root `index.php` or `index.html` exists → use root
5. Default: use project root

### Permissions Strategy

- User added to `www-data` group
- Project directory: `$USER:www-data` with `775` permissions
- Setgid bit applied to directories (new files inherit `www-data` group)
- Home directory: `755` (traversable by Apache)

### Security Considerations

- **Development only**: Passwordless sudo and unix_socket MariaDB are NOT production-safe
- **Sudoers file**: `/etc/sudoers.d/vhost-management` allows specific vhost commands without password
- **Apache security**: Basic hardening applied in install-apache.sh

## File Structure Patterns

```
laravel-linux-setup/
├── install.sh              # Main orchestrator, handles user input and module execution
├── bin/                    # User-facing executables
│   ├── create-vhost.sh    # VHost creator (copied to /usr/local/bin and ~/.local/bin)
│   └── herd-watcher.sh    # File watcher template (customized per installation)
├── scripts/                # Installation modules (sourced by install.sh)
│   ├── install-*.sh       # Component installers
│   ├── setup-vhost.sh     # Systemd service creator
│   └── setup-permissions.sh
└── config/                 # Future: optional Apache/PHP configs
```

## Modifying Core Behavior

### Change Default PHP Version

Edit `scripts/install-php.sh`:
```bash
DEFAULT_PHP="8.3"  # Change to "8.4" or other version
LATEST_PHP="8.4"
```

### Change VHost Domain Suffix

Edit `bin/create-vhost.sh`:
```bash
DOMAIN="${PROJECT_NAME}.test"  # Change ".test" to ".local" or other TLD
```

### Add PHP Extensions

Edit `scripts/install-php.sh`, add to `PHP_EXTENSIONS` array:
```bash
PHP_EXTENSIONS=(
    "cli"
    "fpm"
    # ... existing extensions
    "your-extension"  # Add here
)
```

### Change Watcher Default PHP

After installation, edit `~/.local/bin/herd-watcher.sh`:
```bash
PHP_VERSION="8.3"  # Change to "8.4"
```

## Common Issues

### Watcher Not Detecting Projects

- Check service: `systemctl --user status herd-watcher`
- View logs: `journalctl --user -u herd-watcher -f`
- Verify watch directory path in `~/.local/bin/herd-watcher.sh`

### 403 Forbidden Errors

- Ensure home directory is traversable: `chmod 755 ~`
- Check project permissions: `sudo chown -R $USER:www-data /path/to/project`
- Verify setgid bit: `sudo find /path/to/project -type d -exec chmod g+s {} \;`

### Group Changes Not Applied

- Log out and back in, or run: `newgrp www-data`
- Verify group membership: `groups`

### VHost Already Exists

- Watcher skips existing vhosts
- Manual creation prompts for overwrite confirmation
- Check existing vhosts: `ls /etc/apache2/sites-available/*.test.conf`

## Testing Strategy

When making changes:

1. Test individual modules in isolation before running full install
2. Use a VM or container for full installation tests
3. Verify systemd service creation: `systemctl --user list-units | grep herd`
4. Test vhost auto-creation by adding a directory to watched folder
5. Check Apache config: `sudo apache2ctl configtest`
6. Verify PHP-FPM sockets: `ls /run/php/php*-fpm.sock`

## Version Release Process

When creating releases:

1. Update version info in README.md if needed
2. Update TODO.md progress tracking
3. Test on clean Ubuntu 22.04 LTS and 24.04 LTS
4. Tag release: `git tag -a v1.x.x -m "Release version 1.x.x"`
5. Push with tags: `git push origin master --tags`
