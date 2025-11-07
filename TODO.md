# Laravel Linux Setup - TODO

Project to automatically set up Apache, PHP, MariaDB, and auto-vhost generation for Laravel development on Ubuntu/Debian Linux.

## Installation Scripts

- [x] Create project directory structure
- [ ] Create main install.sh script
  - [ ] Add user input for project directory path
  - [ ] Add system requirements check
  - [ ] Add confirmation prompts
  - [ ] Add progress indicators
  - [ ] Add error handling and rollback

## Apache Module

- [ ] Create scripts/install-apache.sh
  - [ ] Detect latest stable Apache version
  - [ ] Install Apache2
  - [ ] Enable required modules (rewrite, proxy_fcgi, ssl, headers)
  - [ ] Configure basic security settings
  - [ ] Test Apache installation

## PHP Module

- [ ] Create scripts/install-php.sh
  - [ ] Detect latest stable PHP version
  - [ ] Calculate N-1 version (e.g., if 8.4 is latest, install 8.3 as default)
  - [ ] Add PHP repository (ondrej/php)
  - [ ] Install PHP N-1 version as default
  - [ ] Install latest PHP version as optional
  - [ ] Install PHP-FPM for both versions
  - [ ] Install Laravel required extensions:
    - [ ] php-cli
    - [ ] php-fpm
    - [ ] php-mysql
    - [ ] php-mbstring
    - [ ] php-xml
    - [ ] php-bcmath
    - [ ] php-curl
    - [ ] php-zip
    - [ ] php-gd
    - [ ] php-intl
    - [ ] php-soap
    - [ ] php-sqlite3
    - [ ] php-redis
    - [ ] php-memcached
  - [ ] Configure PHP-FPM for both versions
  - [ ] Set default PHP version via update-alternatives
  - [ ] Test PHP installation

## MariaDB Module

- [ ] Create scripts/install-mariadb.sh
  - [ ] Detect latest stable MariaDB version
  - [ ] Install MariaDB server
  - [ ] Configure passwordless root access for local users
  - [ ] Create auth socket configuration
  - [ ] Secure installation (remove test database, etc.)
  - [ ] Test MariaDB connection

## VHost Auto-Generation

- [ ] Copy existing vhost scripts to bin/
  - [ ] bin/create-vhost.sh (from ~/.local/bin/create-vhost.sh)
  - [ ] bin/herd-watcher.sh (from ~/.local/bin/herd-watcher.sh)
- [ ] Update scripts to use configurable project path
- [ ] Make scripts accept PROJECT_DIR as parameter

## Systemd Service

- [ ] Create scripts/setup-watcher-service.sh
  - [ ] Generate systemd user service file dynamically
  - [ ] Use user-provided project directory path
  - [ ] Enable and start the service
  - [ ] Enable user lingering
  - [ ] Test service status

## Permissions & Security

- [ ] Create scripts/setup-permissions.sh
  - [ ] Add user to www-data group
  - [ ] Set proper ownership on project directory
  - [ ] Apply setgid bit to project directory
  - [ ] Set proper file/directory permissions

## Dependencies

- [ ] Create scripts/install-dependencies.sh
  - [ ] Install inotify-tools
  - [ ] Install curl, wget, git
  - [ ] Install composer
  - [ ] Install Node.js & npm (optional)

## Configuration Files

- [ ] Create config/sudoers-vhost
  - [ ] Sudoers rules for passwordless vhost management
- [ ] Create config/apache-security.conf (optional hardening)
- [ ] Create config/php-optimization.ini (optional PHP settings)

## Documentation

- [ ] Create README.md
  - [ ] Project description
  - [ ] Features list
  - [ ] Requirements (Ubuntu 20.04+/Debian 11+)
  - [ ] Quick install (one-liner from GitHub)
  - [ ] Manual installation steps
  - [ ] Usage instructions
  - [ ] Configuration options
  - [ ] Troubleshooting section
  - [ ] FAQ
  - [ ] Contributing guidelines
- [ ] Create INSTALL.md (detailed installation guide)
- [ ] Create USAGE.md (usage examples)

## Git Repository

- [ ] Initialize git repository
- [ ] Create .gitignore
- [ ] Create initial commit
- [ ] Add MIT License (or choose another)
- [ ] Create GitHub repository (optional)
- [ ] Push to GitHub (optional)

## Testing

- [ ] Test on clean Ubuntu 22.04 LTS
- [ ] Test on clean Ubuntu 24.04 LTS
- [ ] Test on Debian 12
- [ ] Test with different project paths
- [ ] Test vhost auto-generation
- [ ] Test PHP version switching
- [ ] Test MariaDB connection
- [ ] Create test script for validation

## Additional Features (Future)

- [ ] Add uninstall script
- [ ] Add update script
- [ ] Support for Nginx option
- [ ] Support for PostgreSQL option
- [ ] Add SSL/TLS certificate generation (mkcert)
- [ ] Add phpMyAdmin installation option
- [ ] Add Redis installation option
- [ ] Add Mailhog/MailCatcher for email testing
- [ ] Support for custom PHP versions
- [ ] Configuration backup/restore

---

## Progress Tracking

**Last Updated:** 2025-11-07 15:37:00

**Completed:** 1/75+ tasks

**Current Status:** Project structure created, starting script development

**Next Steps:**
1. Create main install.sh script
2. Build Apache installation module
3. Build PHP installation module
