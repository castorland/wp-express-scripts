# WP Express - Project Management Scripts

Automated WordPress project creation and management scripts for the WP Express service.

## 📁 Repository Structure

```
scripts/
├── README.md                    # This file
├── new-project.sh              # Main project creation script
├── NEW-PROJECT-USAGE.md        # Detailed usage guide
├── manage-projects.sh          # Project management utilities
├── diagnose.sh                 # Diagnostic tools
├── notion-sync.sh              # Notion integration
├── IMPLEMENTATION.md           # Implementation details
├── PROJECT_GENERATION.md       # Project generation docs
├── SETUP_GUIDE.md             # Setup instructions
└── TROUBLESHOOTING.md         # Common issues and solutions
```

## 🚀 Quick Start

### Create a New Project

```bash
# HTTPS with .local domain (recommended)
./new-project.sh acme-corp

# HTTP with localhost
./new-project.sh test-site --use-localhost

# With Redis enabled
./new-project.sh client-name --redis
```

### Result

- **URL:** `https://{client-name}.local` or `http://localhost:8000`
- **Admin:** Auto-generated credentials in `.credentials` file
- **Stack:** WordPress 6.9 + Bedrock + Docker
- **Plugins:** Elementor, Rank Math SEO, Redis Cache, Wordfence, etc.
- **Theme:** Hello Elementor

## 📋 Main Scripts

### `new-project.sh` - Project Creation

Automated project creation from wp-express-skeleton GitHub repository.

**Features:**
- ✅ HTTPS by default with self-signed SSL
- ✅ Automatic /etc/hosts configuration
- ✅ GitHub clone (fresh from repo)
- ✅ Composer install (WordPress + plugins + theme)
- ✅ Docker containers (architecture-aware)
- ✅ WordPress installation via WP-CLI
- ✅ Plugin & theme activation
- ✅ Secure credential generation

**Usage:**
```bash
./new-project.sh <client-name> [options]

Options:
  --domain <domain>       Custom domain (default: {client}.local)
  --port <port>           Custom port (default: 443 for HTTPS, 8000 for HTTP)
  --email <email>         Admin email
  --admin-user <user>     Admin username (default: admin)
  --admin-pass <pass>     Admin password (auto-generated)
  --redis                 Enable Redis cache
  --use-localhost         Use localhost:8000 instead of .local
  --no-start              Don't start containers
  --no-install            Skip WordPress installation
  --branch <branch>       GitHub branch (default: main)
```

**Examples:**
```bash
# Production-like setup
./new-project.sh acme-corp --redis --email info@acme.com

# Development
./new-project.sh dev-site --use-localhost

# Custom domain
./new-project.sh project --domain mysite.local
```

See [NEW-PROJECT-USAGE.md](NEW-PROJECT-USAGE.md) for detailed documentation.

### `manage-projects.sh` - Project Management

Utilities for managing existing projects (backup, restore, cleanup, etc.)

### `diagnose.sh` - Diagnostics

Diagnostic tools for troubleshooting project issues.

### `notion-sync.sh` - Notion Integration

Sync project information with Notion workspace.

## 🔧 Requirements

- **Docker** & Docker Compose
- **Composer** (PHP dependency manager)
- **Git**
- **OpenSSL** (for SSL certificates)
- **Sudo access** (for /etc/hosts modification)
- **macOS or Linux** (tested on macOS with Apple Silicon & Intel)

### Installation

```bash
# Check requirements
docker --version
docker-compose --version
composer --version
git --version
openssl version
```

## 📁 Project Structure

Created projects follow this structure:

```
clients/
└── {client-name}/
    ├── .env                    # Environment variables
    ├── .credentials            # Generated credentials (keep secure!)
    ├── .gitignore
    ├── composer.json           # PHP dependencies
    ├── composer.lock
    ├── vendor/                 # Composer packages
    │   └── bin/wp             # WP-CLI
    ├── web/                    # WordPress root
    │   ├── wp/                # WordPress core
    │   ├── app/               # Themes & plugins
    │   │   ├── plugins/
    │   │   └── themes/
    │   └── index.php
    ├── config/                 # Bedrock config
    │   ├── application.php
    │   └── environments/
    └── docker/                 # Docker configuration
        ├── nginx/
        │   ├── ssl/           # SSL certificates
        │   └── nginx.conf
        ├── php/
        └── mysql/
```

## 🌐 Accessing Projects

### Frontend
```bash
open https://{client-name}.local
# or
open http://localhost:8000
```

### Admin Panel
```bash
open https://{client-name}.local/wp/wp-admin
# or
open http://localhost:8000/wp/wp-admin
```

### Credentials
```bash
cd ../clients/{client-name}
cat .credentials
```

## 🔐 Security

### Credentials Storage

All sensitive credentials are stored in `.credentials` file with restricted permissions (600).

**Never commit `.credentials` to git!**

### SSL Certificates

Self-signed SSL certificates are generated automatically for each project. These are suitable for local development but should be replaced with proper certificates for production.

### Generated Passwords

All passwords are generated using OpenSSL with cryptographic randomness:
- Database passwords: 20 characters
- Redis passwords: 20 characters
- Admin passwords: 20 characters
- WordPress salts: 64 bytes base64-encoded

## 🐳 Docker Configuration

### Architecture Support

Scripts automatically detect system architecture:
- **Apple Silicon (M1/M2/M3):** Uses `docker-compose.apple-silicon.yml`
- **Intel (x86_64):** Uses `docker-compose.intel.yml`

### Services

Each project includes:
- **Nginx:** Web server with SSL support
- **PHP-FPM:** PHP 8.4 with all required extensions
- **MySQL:** Database server
- **Redis:** (optional) Cache server

### Ports

**Default HTTPS (.local domains):**
- 443 → Nginx HTTPS

**Default HTTP (localhost):**
- 8000 → Nginx HTTP
- 3306 → MySQL (internal)
- 6379 → Redis (internal, if enabled)

## 📚 Documentation

- **[NEW-PROJECT-USAGE.md](NEW-PROJECT-USAGE.md)** - Detailed usage guide
- **[IMPLEMENTATION.md](IMPLEMENTATION.md)** - Implementation details
- **[PROJECT_GENERATION.md](PROJECT_GENERATION.md)** - Project generation process
- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Initial setup instructions
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Common issues and solutions

## 🆘 Troubleshooting

### Domain Not Accessible

Check /etc/hosts:
```bash
cat /etc/hosts | grep {client-name}.local
```

Add manually if missing:
```bash
echo "127.0.0.1 {client-name}.local" | sudo tee -a /etc/hosts
```

### SSL Certificate Warning

This is normal for self-signed certificates. Click through the browser warning:
- Chrome: "Advanced" → "Proceed"
- Safari: "Show Details" → "visit this website"
- Firefox: "Advanced" → "Accept the Risk"

### Port Already in Use

Check what's using the port:
```bash
lsof -i :443  # or :8000
```

Use a different port:
```bash
./new-project.sh client --port 8443
```

### WP-CLI Not Found

Run composer install:
```bash
cd ../clients/{client-name}
composer install
```

### Docker Not Running

Start Docker Desktop and try again:
```bash
docker info
```

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for more solutions.

## 🔄 Common Tasks

### Start Project Containers
```bash
cd ../clients/{client-name}
make apple-silicon  # or make intel
```

### Stop Containers
```bash
make down
```

### View Logs
```bash
make logs
```

### Backup Database
```bash
make backup
```

### Access WP-CLI
```bash
docker-compose -f docker-compose.apple-silicon.yml exec php vendor/bin/wp --info
```

### Update Plugins
```bash
docker-compose -f docker-compose.apple-silicon.yml exec php vendor/bin/wp plugin update --all
```

## 🔄 Version History

This repository uses semantic versioning (v1.0.0, v1.1.0, etc.)

### Current Version: v1.0.0

**Features:**
- HTTPS by default with .local domains
- Automatic /etc/hosts configuration
- GitHub-based project cloning
- Full WordPress automation
- Architecture-aware Docker setup
- Comprehensive error handling

## 🤝 Contributing

### For Team Members

1. **Clone this repository**
   ```bash
   git clone <repository-url>
   cd scripts
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make changes and test**
   ```bash
   # Test your changes
   ./new-project.sh test-project
   ```

4. **Commit with clear messages**
   ```bash
   git add .
   git commit -m "feat: add new feature"
   ```

5. **Push and create pull request**
   ```bash
   git push origin feature/your-feature-name
   ```

### Commit Message Convention

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `refactor:` Code refactoring
- `test:` Test additions/changes
- `chore:` Maintenance tasks

## 📞 Support

For issues or questions:
1. Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. Review existing documentation
3. Contact the development team

## 📄 License

Internal use only - WP Express service.

## 🎯 Future Enhancements

- [ ] Production deployment script
- [ ] Staging environment setup
- [ ] Backup automation
- [ ] Multi-site support
- [ ] CLI interactive mode
- [ ] Project templates
- [ ] Performance monitoring
- [ ] Automated updates

---

**WP Express** - Professional WordPress hosting made simple.
