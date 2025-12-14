# Installing Multiple Composer Versions

This guide explains how to install and manage multiple Composer versions side-by-side on your system.

## Quick Start

Run the installation script:

```bash
bash scripts/install-composer.sh
```

This will install multiple Composer versions with version suffixes:
- `composer2.8` - Composer 2.8.4 (Latest stable)
- `composer2.7` - Composer 2.7.7
- `composer2.2` - Composer 2.2.24
- `composer1.10` - Composer 1.10.27 (Last 1.x version)

The default `composer` command will point to Composer 2.8.

## Usage

### Using Default Composer (2.8)

```bash
composer install
composer require vendor/package
```

### Using Specific Versions

```bash
# Use Composer 2.8
composer2.8 install

# Use Composer 2.7
composer2.7 install

# Use Composer 2.2 (for older Laravel projects)
composer2.2 install

# Use Composer 1.10 (for legacy projects)
composer1.10 install
```

### Project-Specific Composer

You can use different Composer versions for different projects:

```bash
# Legacy project (requires Composer 1.x)
cd /path/to/legacy-project
composer1.10 install

# Modern Laravel project
cd /path/to/laravel-project
composer2.8 install
```

## Customizing Versions

To install different versions, edit `scripts/install-composer.sh`:

```bash
# Composer versions to install
# Format: "FULL_VERSION SHORT_VERSION"
COMPOSER_VERSIONS=(
    "2.8.4 2.8"      # Latest stable
    "2.7.7 2.7"      # Previous minor
    "2.2.24 2.2"     # Older version
    "1.10.27 1.10"   # Composer 1.x
    # Add more versions here:
    # "2.6.6 2.6"
    # "2.5.8 2.5"
)

# Default version for 'composer' command
DEFAULT_VERSION="2.8"
```

Then run the script again:

```bash
bash scripts/install-composer.sh
```

## Changing Default Version

To change which version the `composer` command uses:

```bash
# Switch to Composer 2.7 as default
sudo ln -sf /usr/local/bin/composer2.7 /usr/local/bin/composer

# Verify
composer --version
```

## Available Composer Versions

You can find available Composer versions at:
- https://github.com/composer/composer/releases
- https://getcomposer.org/download/

## Why Multiple Versions?

### Composer 1.x vs 2.x

Composer 2.x introduced breaking changes and significant performance improvements. Some legacy projects may still require Composer 1.x.

### Different Minor Versions

Different Laravel/PHP versions may have specific Composer version requirements:

- **Laravel 11+**: Requires Composer 2.2+
- **Laravel 10**: Works with Composer 2.0+
- **Laravel 8-9**: Compatible with Composer 1.x or 2.x
- **Legacy projects**: May require Composer 1.10.x

### Bug Workarounds

Specific Composer versions may have bugs that affect certain workflows. Having multiple versions lets you switch when needed.

## Uninstalling a Version

To remove a specific version:

```bash
sudo rm /usr/local/bin/composer2.7
```

To remove all versions:

```bash
sudo rm /usr/local/bin/composer*
```

## Integration with Main Installer

The main `install.sh` script installs only the latest Composer version. To install multiple versions:

1. Run the main installer first (if needed):
   ```bash
   ./install.sh
   ```

2. Then run the multi-version installer:
   ```bash
   bash scripts/install-composer.sh
   ```

This will add additional Composer versions alongside the existing installation.

## Troubleshooting

### Version Not Found

If a specific version fails to install:

1. Check if the version exists: https://github.com/composer/composer/releases
2. Verify the version number format (must be exact: "2.8.4", not "2.8")
3. Check your internet connection

### Permission Denied

If you get permission errors:

```bash
# Ensure script is executable
chmod +x scripts/install-composer.sh

# Run with appropriate permissions
bash scripts/install-composer.sh
```

### Verification Failed

If a version installs but verification fails:

1. Manually check the version:
   ```bash
   /usr/local/bin/composer2.8 --version
   ```

2. Re-run the installer to fix any issues:
   ```bash
   bash scripts/install-composer.sh
   ```

## Checking Installed Versions

List all installed Composer versions:

```bash
ls -la /usr/local/bin/composer*
```

Check each version:

```bash
composer --version
composer2.8 --version
composer2.7 --version
composer2.2 --version
composer1.10 --version
```
