# WP Express - New Project Script

Automated WordPress project creation using wp-express-skeleton from GitHub.

## 🚀 Quick Start

```bash
# Create a new project with HTTPS
./scripts/new-project.sh acme-corp

# Result: https://acme-corp.local
```

## 📋 Features

✅ **HTTPS by Default** - Uses `{client-name}.local` with self-signed SSL  
✅ **Automatic /etc/hosts** - Adds domain entry with sudo prompt  
✅ **GitHub Clone** - Fresh clone from GitHub repository  
✅ **Composer Install** - Installs WordPress, plugins, and theme  
✅ **Docker Containers** - Architecture-aware (Apple Silicon/Intel)  
✅ **WordPress Installation** - Complete WP-CLI automation  
✅ **Plugin Activation** - All plugins activated automatically  
✅ **Theme Activation** - Hello Elementor theme ready  
✅ **Secure Credentials** - Generated and saved to `.credentials`

## 🎯 Usage

### Basic (HTTPS with .local domain)
```bash
./scripts/new-project.sh my-client
# → https://my-client.local
```

### With Redis
```bash
./scripts/new-project.sh client-name --redis
# → https://client-name.local with Redis cache
```

### Using localhost (no hosts file)
```bash
./scripts/new-project.sh test-site --use-localhost
# → http://localhost:8000
```

### Custom domain
```bash
./scripts/new-project.sh project --domain myproject.local
# → https://myproject.local
```

### Custom port
```bash
./scripts/new-project.sh client --port 8443
# → https://client.local:8443
```

## 📁 What Gets Created

```
clients/
└── {client-name}/
    ├── .env                    # Environment configuration
    ├── .credentials            # Admin passwords (keep secure!)
    ├── composer.json           # Dependencies
    ├── vendor/                 # Composer packages
    ├── web/                    # WordPress root
    │   ├── wp/                # WordPress core
    │   ├── app/               # Plugins & themes
    │   └── index.php
    └── docker/                 # Docker configuration
```

## 🔐 Credentials

After installation, find your credentials in `.credentials`:

```bash
cd clients/{client-name}
cat .credentials
```

Contains:
- Database password
- Redis password (if enabled)
- WordPress admin username & password
- Admin email

## 🌐 Accessing Your Site

### Frontend
```bash
open https://{client-name}.local
```

### Admin Panel
```bash
open https://{client-name}.local/wp/wp-admin
```

## 📦 What Gets Installed

**WordPress:** 6.9  
**Theme:** Hello Elementor  
**Plugins:**
- Elementor
- Rank Math SEO
- Redis Cache
- Wordfence Security
- WP Super Cache
- Fluent SMTP
- UpdraftPlus Backup

## 🔧 Common Commands

```bash
# Navigate to project
cd clients/{client-name}

# View logs
make logs

# Restart containers
make restart

# Stop containers
make down

# Start containers
make apple-silicon  # or make intel

# Backup database
make backup

# Access WP-CLI
docker-compose -f docker-compose.apple-silicon.yml exec php vendor/bin/wp --info
```

## ⚠️ Requirements

- Docker & Docker Compose
- Composer
- Git
- OpenSSL
- Sudo access (for /etc/hosts modification)

## 🆘 Troubleshooting

### "Domain not accessible"
Check if domain was added to /etc/hosts:
```bash
grep {client-name}.local /etc/hosts
```

Add manually if needed:
```bash
echo "127.0.0.1 {client-name}.local" | sudo tee -a /etc/hosts
```

### "SSL Certificate Error"
This is normal for self-signed certificates. In your browser:
- Chrome: Click "Advanced" → "Proceed to {domain}"
- Safari: Click "Show Details" → "visit this website"
- Firefox: Click "Advanced" → "Accept the Risk and Continue"

### "Port already in use"
Use a different port:
```bash
./scripts/new-project.sh client --port 8443
```

Or stop other containers:
```bash
docker ps  # List running containers
docker stop {container-id}
```

### "WP-CLI not found"
Make sure composer install completed successfully:
```bash
cd clients/{client-name}
composer install
```

## 🔄 Starting Over

```bash
# Stop containers
cd clients/{client-name}
docker-compose down -v

# Remove project
cd ../..
rm -rf clients/{client-name}

# Remove from hosts file
sudo sed -i.bak '/{client-name}.local/d' /etc/hosts
```

## 📚 Additional Options

```
--email <email>         Admin email (default: admin@example.com)
--admin-user <user>     Admin username (default: admin)
--admin-pass <pass>     Admin password (auto-generated if not provided)
--site-title <title>    Site title (defaults to client name)
--no-start              Don't start Docker containers
--no-install            Skip WordPress installation
--redis                 Enable Redis cache
--branch <branch>       GitHub branch to clone (default: main)
```

## 🎓 Examples

```bash
# Production-like setup
./scripts/new-project.sh acme-corp --redis --email info@acme-corp.com

# Development with custom credentials
./scripts/new-project.sh dev-site --admin-user developer --admin-pass DevPass123

# Quick test (HTTP, no WP install)
./scripts/new-project.sh quick-test --use-localhost --no-install

# Clone from specific branch
./scripts/new-project.sh feature-test --branch develop
```

## 🚀 Happy Building!
