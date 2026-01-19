# WP Express - Setup Guide

Complete setup guide for the new directory structure with git clone workflow.

---

## 📁 Directory Structure

```
workspace/                      (your main folder)
├── scripts/                    (management scripts)
│   ├── new-project.sh         (create new projects)
│   ├── manage-projects.sh     (manage existing projects)
│   ├── notion-sync.sh         (Notion integration)
│   └── diagnose.sh            (troubleshooting)
│
├── wp-express-skeleton/        (template repository)
│   ├── .git/                  (Git repo)
│   ├── docker/
│   ├── config/
│   ├── web/
│   ├── docker-compose*.yml
│   └── ...
│
└── clients/                    (generated projects)
    ├── acme-corp/
    ├── startup/
    └── bigclient/
```

---

## 🚀 Initial Setup

### Step 1: Create Workspace

```bash
# Create your workspace folder
mkdir wp-express
cd wp-express
```

### Step 2: Clone Skeleton Repository

```bash
# Clone the template
git clone https://github.com/castorland/wp-express-skeleton.git

# Verify it worked
ls wp-express-skeleton
```

### Step 3: Install Scripts

```bash
# Create scripts directory
mkdir scripts

# Copy the downloaded scripts into scripts/
# - new-project.sh
# - manage-projects.sh  
# - notion-sync.sh
# - diagnose.sh

# Make them executable
chmod +x scripts/*.sh
```

Your structure should now look like:
```
wp-express/
├── scripts/
│   ├── new-project.sh
│   ├── manage-projects.sh
│   ├── notion-sync.sh
│   └── diagnose.sh
└── wp-express-skeleton/
    └── (skeleton files)
```

---

## ✅ Verify Setup

```bash
# From wp-express directory
ls -la

# You should see:
# drwxr-xr-x  scripts/
# drwxr-xr-x  wp-express-skeleton/

# Test the script
./scripts/new-project.sh --help
```

---

## 🎯 Create Your First Project

```bash
# Make sure you're in the workspace directory
cd wp-express

# Create a test project
./scripts/new-project.sh test-client

# This will:
# 1. Clone wp-express-skeleton to clients/test-client
# 2. Remove old .git and create fresh repo
# 3. Generate unique .env with salts
# 4. Generate SSL certificates
# 5. Ask if you want to start containers
```

After successful creation:
```
wp-express/
├── scripts/
├── wp-express-skeleton/
└── clients/                    (NEW!)
    └── test-client/
        ├── .env               (unique config)
        ├── .credentials       (passwords)
        ├── .git/              (fresh repo)
        └── (all skeleton files)
```

---

## 🎨 How It Works

### The `new-project.sh` Script

```bash
./scripts/new-project.sh <client-name> [options]
```

**What it does:**

1. **Clones skeleton** using `git clone`
   ```bash
   git clone wp-express-skeleton/ clients/client-name/
   ```

2. **Resets Git history**
   ```bash
   rm -rf .git
   git init
   git add .
   git commit -m "Initial commit"
   ```

3. **Generates unique .env**
   - Fetches WordPress salts from WordPress.org
   - Creates random database passwords
   - Configures domains and settings

4. **Creates SSL certificates**
   ```bash
   cd docker/nginx/ssl
   ./generate-ssl.sh
   ```

5. **Optionally starts Docker**
   ```bash
   docker-compose -f docker-compose.apple-silicon.yml up -d
   # OR
   docker-compose -f docker-compose.intel.yml up -d
   ```

---

## 📋 Common Workflows

### Create a New Client Project

```bash
cd wp-express

# Basic project
./scripts/new-project.sh acme-corp

# With custom domain
./scripts/new-project.sh startup --domain startup.local

# Without auto-start
./scripts/new-project.sh bigclient --no-start

# With Redis enabled
./scripts/new-project.sh premium --redis
```

### List All Projects

```bash
./scripts/manage-projects.sh list
```

### Start an Existing Project

```bash
cd clients/acme-corp
make apple-silicon  # or make intel
```

### Check Project Health

```bash
./scripts/manage-projects.sh check acme-corp
```

### Backup a Project

```bash
./scripts/manage-projects.sh backup acme-corp
```

---

## 🔄 Update Skeleton Template

When there are updates to the skeleton:

```bash
cd wp-express-skeleton

# Pull latest changes
git pull origin main

# New projects will now use the updated template
```

---

## 🛠️ Troubleshooting

### Problem: Containers won't start

```bash
# Run diagnostics
./scripts/diagnose.sh test-client

# Check specific project
cd clients/test-client
docker-compose logs
```

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions.

### Problem: Script says "Skeleton not found"

```bash
# You're probably in the wrong directory
pwd  # Should show: /path/to/wp-express

# If you're inside scripts/ or wp-express-skeleton/, go up:
cd ..
```

### Problem: Permission denied

```bash
# Make scripts executable
chmod +x scripts/*.sh
```

---

## 📦 What Gets Created

For each project:

```
clients/acme-corp/
├── .env                        ✅ Unique (never in git)
├── .credentials                ✅ Unique (never in git)
├── .git/                       ✅ Fresh repo (no skeleton history)
├── .gitignore                  From skeleton
├── composer.json               From skeleton
├── docker-compose*.yml         From skeleton
├── Makefile                    From skeleton
├── config/                     From skeleton
├── docker/                     From skeleton
│   └── nginx/ssl/              ✅ Unique SSL certs
├── web/
│   ├── app/
│   │   ├── mu-plugins/         From skeleton
│   │   ├── plugins/            Empty (ready for installs)
│   │   ├── themes/             Empty (ready for themes)
│   │   └── uploads/            Empty (ready for media)
│   └── wp/                     WordPress core (Composer)
└── vendor/                     Composer dependencies
```

**Key Points:**
- ✅ Each project has **unique** .env with WordPress salts
- ✅ Each project has **separate** Git history
- ✅ Each project gets **fresh** SSL certificates
- ✅ Projects are **independent** - changes don't affect skeleton

---

## 🔐 Security Best Practices

### 1. Never Commit Secrets

The `.gitignore` already excludes:
- `.env`
- `.credentials`
- `vendor/`
- `web/wp/`

### 2. Store Passwords Safely

```bash
# Credentials are in .credentials file
cat clients/acme-corp/.credentials

# For production, use a password manager:
# - 1Password
# - LastPass
# - Bitwarden
```

### 3. Separate Repositories

Each client project can have its own Git remote:

```bash
cd clients/acme-corp

# Add remote
git remote add origin https://github.com/yourcompany/acme-corp.git

# Push
git push -u origin main
```

---

## 🎓 Tips & Best Practices

### 1. Keep Skeleton Updated

```bash
cd wp-express-skeleton
git pull origin main
```

### 2. Regular Backups

```bash
# Backup all projects weekly
./scripts/manage-projects.sh backup-all
```

### 3. Use Consistent Naming

Good names:
- `acme-corp`
- `startup-2025`
- `local-bakery`

Bad names:
- `ACME Corp` (spaces)
- `client!!!` (special chars)
- `Project #1` (special chars)

### 4. Document Client Projects

Each project gets a `CLIENT_README.md` with:
- Client information
- Setup instructions
- Common commands
- Deployment notes

---

## 📊 Workflow Example

Complete workflow for a new client:

```bash
# 1. Create project
cd wp-express
./scripts/new-project.sh acme-corp --redis

# 2. Navigate to project
cd clients/acme-corp

# 3. Complete WordPress installation
open http://localhost:8000

# 4. Install plugins
composer require wpackagist-plugin/elementor
composer require wpackagist-plugin/contact-form-7

# 5. Import Elementor template (when ready)
# make wp CMD="elementor import-template business-pack"

# 6. Development work
# ... build the site ...

# 7. Commit changes
git add .
git commit -m "Initial WordPress setup with plugins"

# 8. Create backup
cd ../../
./scripts/manage-projects.sh backup acme-corp

# 9. Push to client repo (if using separate repos)
cd clients/acme-corp
git remote add origin https://github.com/client/acme-corp.git
git push -u origin main
```

---

## 🚢 Production Deployment

When ready to deploy:

1. **Update environment:**
   ```bash
   # Edit .env
   WP_ENV='production'
   WP_HOME='https://acmecorp.com'
   REDIS_ENABLED='true'
   ```

2. **Push to production server:**
   ```bash
   rsync -avz --exclude 'node_modules' \
     clients/acme-corp/ user@server:/var/www/acmecorp/
   ```

3. **On production server:**
   ```bash
   composer install --no-dev --optimize-autoloader
   docker-compose -f docker-compose.production.yml up -d
   ```

---

## 🆘 Getting Help

### Run Diagnostics

```bash
# Check system
./scripts/diagnose.sh

# Check specific project
./scripts/diagnose.sh acme-corp
```

### Check Logs

```bash
cd clients/acme-corp
make logs
```

### Read Troubleshooting Guide

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues and solutions.

---

## ✨ Summary

**You've learned:**
- ✅ How to set up the workspace
- ✅ How to create new projects with git clone
- ✅ How the directory structure works
- ✅ How to manage multiple projects
- ✅ Best practices for security and backups

**Next steps:**
1. Create your first real client project
2. Build and customize it
3. Set up Notion integration (optional)
4. Deploy to production (when ready)

---

**Happy building! 🚀**
