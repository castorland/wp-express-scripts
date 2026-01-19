# Changelog

All notable changes to WP Express project management scripts will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2024-01-19

### Fixed
- 🐛 Fixed database connection error when creating new projects with HTTPS `.local` domains
- 🔧 Changed database connection test from `mysql` to `mariadb` client command
- 📝 Added explicit `--env-file .env` flag to all docker-compose commands to ensure environment variables are properly loaded
- ⏱️ Increased database initialization timeout from 30 to 40 attempts
- 🕐 Added 5-second initial wait before testing database connection to allow container startup
- 📊 Improved error messages and diagnostics for database connection failures
- ✅ Better feedback during database initialization process

### Technical Details
- The MariaDB 11.8 image uses `mariadb` command instead of `mysql`
- Docker Compose now explicitly loads `.env` file for all operations
- Database initialization properly waits for container to be fully ready
- Root cause: Environment variables weren't being passed correctly to database container during initialization

## [1.0.0] - 2024-01-19

### Added
- 🎉 Initial release of automated project creation script
- ✨ HTTPS by default with `.local` domain configuration
- 🔐 Automatic `/etc/hosts` entry management with sudo prompt
- 🐙 GitHub-based project cloning from wp-express-skeleton
- 📦 Composer automation for WordPress + plugins + theme installation
- 🐳 Architecture-aware Docker setup (Apple Silicon / Intel)
- 🔧 WP-CLI integration via `vendor/bin/wp`
- 🔒 Secure credential generation (database, Redis, admin passwords)
- 🎨 Automatic plugin activation (Elementor, Rank Math, Redis Cache, etc.)
- 🖼️ Automatic theme activation (Hello Elementor)
- 📝 WordPress salts generation in proper `.env` format
- 🔗 Permalink configuration
- 📋 Comprehensive usage documentation
- 🆘 Troubleshooting guide
- ✅ Detailed error handling and progress indicators
- 🎯 Support for custom domains, ports, and options

### Features
- **Default HTTPS Setup**: Projects use `https://{client}.local` by default
- **Localhost Fallback**: `--use-localhost` flag for `http://localhost:8000`
- **Redis Support**: Optional Redis cache with `--redis` flag
- **Custom Configuration**: Full control over domain, port, credentials, etc.
- **Git Integration**: Each project initialized as git repository
- **SSL Certificates**: Self-signed certificates generated automatically
- **Credential Storage**: Secure storage in `.credentials` file (600 permissions)
- **Progress Tracking**: Color-coded output with step indicators
- **Validation**: Pre-flight checks for dependencies and GitHub access
- **Database Readiness**: Smart waiting for database initialization
- **Failed Installation Recovery**: Helpful error messages with manual steps

### Technical Details
- Bash script with proper error handling (`set -eo pipefail`)
- WP-CLI installed via Composer (wp-cli/wp-cli-bundle v2.10+)
- WordPress salts generated locally with OpenSSL (64 bytes base64)
- Docker Compose architecture detection (arm64/aarch64 vs x86_64)
- Automatic port mapping configuration
- GitHub repository validation before cloning
- Support for custom GitHub branches

### Documentation
- `README.md` - Main documentation
- `NEW-PROJECT-USAGE.md` - Detailed usage guide
- `CHANGELOG.md` - This file
- Inline code comments for maintainability

### Scripts Included
- `new-project.sh` - Main project creation script
- `manage-projects.sh` - Project management utilities (existing)
- `diagnose.sh` - Diagnostic tools (existing)
- `notion-sync.sh` - Notion integration (existing)

### Requirements
- Docker & Docker Compose
- Composer
- Git
- OpenSSL
- Sudo access (for /etc/hosts)
- macOS or Linux

### Known Issues
- SSL certificate browser warnings (expected for self-signed certs)
- Permalink configuration may timeout on slower systems (non-critical)
- Manual /etc/hosts entry required if sudo fails

### Breaking Changes
None - initial release

---

## [Unreleased]

### Planned Features
- [ ] Production deployment automation
- [ ] Staging environment setup
- [ ] Automated backup scheduling
- [ ] Multi-site WordPress support
- [ ] Interactive CLI mode with prompts
- [ ] Project templates (e-commerce, blog, portfolio)
- [ ] Performance monitoring integration
- [ ] Automated WordPress & plugin updates
- [ ] Project cloning/duplication
- [ ] Database migration tools
- [ ] Import/export functionality
- [ ] CI/CD pipeline integration

---

## Version History

**v1.0.0** - Initial release (2026-01-19)
- Complete automation of WordPress project creation
- HTTPS-first approach with .local domains
- Professional development environment setup

---

[1.0.1]: https://github.com/castorland/wp-express-scripts/releases/tag/v1.0.1
[1.0.0]: https://github.com/castorland/wp-express-scripts/releases/tag/v1.0.0
