# Laravel Linux Setup

Automated installation and configuration script for Laravel development environment on Ubuntu/Debian Linux.

## Features

- **Apache** - Latest stable version with required modules
- **PHP 8.3** (default) + **PHP 8.4** - With all Laravel required extensions
- **MariaDB** - Latest stable version with passwordless root access
- **Auto VHost Generation** - Automatically creates virtual hosts when you add projects
- **File Monitoring** - Systemd service watches your projects directory
- **Composer** - Latest version with Laravel installer included
- **Per-Project PHP Versions** - Each project can use different PHP versions (8.3 or 8.4)

## Quick Install

**Recommended method:**

```bash
git clone https://github.com/adods/laravel-linux-setup.git
cd laravel-linux-setup
./install.sh
```

> **Important:** Clone the repository instead of just downloading `install.sh` to ensure all required script modules are available.

## Requirements

- Ubuntu 20.04+ or Debian 11+
- Non-root user with sudo privileges
- Active internet connection

## What Gets Installed

### Apache
- Latest stable Apache2
- Enabled modules: rewrite, proxy, proxy_fcgi, ssl, headers

### PHP
- PHP 8.3 (set as default)
- PHP 8.4 (available for projects that need it)
- PHP-FPM for both versions
- Extensions: cli, fpm, mysql, pgsql, sqlite3, mbstring, xml, bcmath, curl, zip, gd, intl, soap, redis, memcached, imagick

### MariaDB
- Latest stable MariaDB server
- Configured for passwordless root access (unix_socket authentication)
- Secure installation applied
- Test database removed

### Auto VHost System
- Monitors your projects directory
- Automatically creates `<project-name>.test` domains
- Auto-detects Laravel projects (points to `/public`)
- Falls back to detecting `index.php`/`index.html` in standard locations
- Runs as systemd user service (starts on boot)

### Composer
- Latest stable version
- Installed globally
- Laravel installer included (`laravel new` command available)

## Usage

### After Installation

1. **Create or copy a Laravel project** to your projects directory:
   ```bash
   cd ~/Projects  # Or your custom path
   laravel new myapp
   ```

2. **Your site is automatically available** at:
   ```
   http://myapp.test
   ```

3. That's it! The vhost is created automatically.

### Manual VHost Creation

If you need to manually create a vhost:

```bash
# With default PHP 8.3
create-vhost.sh /path/to/project

# With PHP 8.4
create-vhost.sh /path/to/project 8.4
```

### Database Access

Connect to MariaDB without password:

```bash
sudo mysql
```

Or:

```bash
mysql -u root
```

### Managing the Watcher Service

```bash
# Check status
systemctl --user status herd-watcher

# View logs
journalctl --user -u herd-watcher -f

# Restart
systemctl --user restart herd-watcher

# Stop
systemctl --user stop herd-watcher
```

### Switching PHP CLI Version

```bash
# Interactive selection
sudo update-alternatives --config php

# Direct switch to PHP 8.3
sudo update-alternatives --set php /usr/bin/php8.3

# Direct switch to PHP 8.4
sudo update-alternatives --set php /usr/bin/php8.4
```

### Using Different PHP Versions Per Project

Each project can use a different PHP version. When creating a vhost manually, specify the PHP version:

```bash
# Project A uses PHP 8.3
create-vhost.sh ~/Projects/projectA 8.3

# Project B uses PHP 8.4
create-vhost.sh ~/Projects/projectB 8.4
```

The auto-watcher uses PHP 8.3 by default.

## Directory Structure

```
laravel-linux-setup/
├── install.sh              # Main installation script
├── bin/                    # VHost generation scripts
│   ├── create-vhost.sh
│   └── herd-watcher.sh
├── scripts/                # Installation modules
│   ├── install-apache.sh
│   ├── install-php.sh
│   ├── install-mariadb.sh
│   ├── setup-vhost.sh
│   └── setup-permissions.sh
├── config/                 # Configuration files
├── README.md
└── TODO.md
```

## Troubleshooting

### Site shows 500 error

**Cause:** Missing PHP extensions or Laravel not configured.

**Solution:**
```bash
cd /path/to/your/project
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate
```

### Site shows 403 Forbidden

**Cause:** Permission issues.

**Solution:**
```bash
# Fix permissions
sudo chown -R $USER:www-data /path/to/project
sudo chmod -R 775 /path/to/project
sudo find /path/to/project -type d -exec chmod g+s {} \;

# Ensure Apache can read the directory
sudo chmod 755 /path/to/project
```

### Watcher not detecting new projects

**Check service status:**
```bash
systemctl --user status herd-watcher
```

**View logs:**
```bash
journalctl --user -u herd-watcher -f
```

**Restart service:**
```bash
systemctl --user restart herd-watcher
```

### Group changes not taking effect

You need to **log out and log back in** for group membership changes to take effect.

Or run:
```bash
newgrp www-data
```

### Can't connect to MariaDB

**As root:**
```bash
sudo mysql
```

**Check if service is running:**
```bash
sudo systemctl status mariadb
```

## Configuration

### Change Monitored Directory

Edit the watcher script:
```bash
nano ~/.local/bin/herd-watcher.sh
```

Change the `WATCH_DIR` variable.

### Change Default PHP Version

Edit:
```bash
nano ~/.local/bin/herd-watcher.sh
```

Change `PHP_VERSION` variable.

### Add Custom Apache Configuration

Place your custom configs in:
```
/etc/apache2/conf-available/
```

Then enable:
```bash
sudo a2enconf your-config
sudo systemctl reload apache2
```

## Uninstallation

To remove everything:

```bash
# Stop services
systemctl --user stop herd-watcher
systemctl --user disable herd-watcher

# Remove packages (optional)
sudo apt remove --purge apache2 php8.* mariadb-server

# Remove configuration
rm -rf ~/.local/bin/herd-watcher.sh
rm -rf ~/.config/systemd/user/herd-watcher.service
sudo rm /usr/local/bin/create-vhost.sh
sudo rm /etc/sudoers.d/vhost-management

# Reload
systemctl --user daemon-reload
```

## FAQ

**Q: Can I use this on production servers?**
A: No. This is designed for local development only. The passwordless sudo and other configurations are insecure for production.

**Q: Can I use Nginx instead of Apache?**
A: Not yet. Support for Nginx may be added in the future.

**Q: What if I want PostgreSQL instead of MariaDB?**
A: You can manually install PostgreSQL after running the setup. Future versions may include this option.

**Q: Can I use custom TLDs (not .test)?**
A: Yes, edit the vhost creation script to change the domain suffix.

**Q: Does this work on WSL2?**
A: It should work, but hasn't been extensively tested. File permissions might need adjustment.

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - Feel free to use and modify as needed.

## Support

- Issues: [GitHub Issues](https://github.com/adods/laravel-linux-setup/issues)
- Discussions: [GitHub Discussions](https://github.com/adods/laravel-linux-setup/discussions)

## Credits

Created for Laravel developers who want a hassle-free local development setup on Linux.

---

**Happy coding! 🚀**
