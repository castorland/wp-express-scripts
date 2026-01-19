# Project Generation Guide

Complete guide for creating and managing client projects using the WP Express Skeleton.

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Project Generation](#project-generation)
- [Project Management](#project-management)
- [Notion Integration](#notion-integration)
- [Workflow Examples](#workflow-examples)
- [Troubleshooting](#troubleshooting)

---

## 🚀 Quick Start

### Generate Your First Project

```bash
# Basic project creation
./scripts/new-project.sh acme-corp

# With custom domain and email
./scripts/new-project.sh startup --domain startup.com --email hello@startup.com

# Production-ready project
./scripts/new-project.sh bigclient --production --redis
```

### What Happens?

1. ✅ Creates new project directory
2. ✅ Copies skeleton template
3. ✅ Generates unique credentials
4. ✅ Creates WordPress salts
5. ✅ Initializes Git repository
6. ✅ Starts Docker containers
7. ✅ Creates project documentation

---

## 📦 Project Generation

### Command Syntax

```bash
./scripts/new-project.sh <client-name> [options]
```

### Available Options

| Option | Description | Example |
|--------|-------------|---------|
| `--domain <domain>` | Custom domain | `--domain example.com` |
| `--email <email>` | Client email | `--email client@example.com` |
| `--path <path>` | Custom project path | `--path /opt/projects` |
| `--no-start` | Don't start Docker | For manual startup |
| `--production` | Production environment | Sets WP_ENV=production |
| `--redis` | Enable Redis cache | Starts with Redis enabled |

### What Gets Created

```
wp-express-projects/
└── client-name/
    ├── .env                    # Unique configuration
    ├── .credentials            # Database passwords (keep secure!)
    ├── .wp-express-project     # Project metadata
    ├── .gitignore              # Git ignore rules
    ├── README.md               # Project-specific docs
    ├── composer.json           # PHP dependencies
    ├── docker-compose.yml      # Docker configuration
    ├── config/                 # WordPress config
    ├── docker/                 # Docker configs
    ├── web/                    # WordPress root
    └── scripts/                # Helper scripts
```

### Generated Credentials

Each project gets unique:
- ✅ Database password (auto-generated)
- ✅ Redis password (auto-generated)
- ✅ WordPress salts (from WordPress.org API)
- ✅ Root password (for production backups)

**⚠️ Important:** Credentials are saved in `.credentials` file - **keep it secure!**

---

## 🎛️ Project Management

### List All Projects

```bash
./scripts/manage-projects.sh list
```

**Output:**
```
PROJECT                   STATUS     CONTAINERS  ENVIRONMENT     CREATED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
acme-corp                 running    5          development     2025-01-15
startup                   stopped    0          production      2025-01-14
bigclient                 running    6          production      2025-01-13
```

### Check Project Health

```bash
./scripts/manage-projects.sh check acme-corp
```

**Checks:**
- ✅ `.env` file exists
- ✅ Docker containers running
- ✅ Services healthy
- ✅ WordPress accessible
- ✅ Disk usage
- ✅ Git status

### Backup Project

```bash
# Backup specific project
./scripts/manage-projects.sh backup acme-corp

# Backup all projects
./scripts/manage-projects.sh backup-all
```

**Creates:**
- Database dump (`db_TIMESTAMP.sql`)
- Uploads archive (`uploads_TIMESTAMP.tar.gz`)
- Configuration backup (`env_TIMESTAMP.backup`)
- Backup manifest

### Stop Projects

```bash
# Stop specific project
./scripts/manage-projects.sh stop acme-corp

# Stop all projects
./scripts/manage-projects.sh stop-all
```

---

## 🔗 Notion Integration

### Why Integrate?

- ✅ Track all projects in one place
- ✅ Link projects to clients
- ✅ Update status automatically
- ✅ Generate reports
- ✅ Share with team

### Create Notion Entry

```bash
./scripts/notion-sync.sh create acme-corp
```

**Generates JSON for:**
- Project entry (Projects database)
- Client entry (Clients database)

**Then use Claude with Notion MCP to:**
1. Create the project in Notion
2. Link to client
3. Set initial status

### Update Project Status

```bash
./scripts/notion-sync.sh update acme-corp
```

**Updates:**
- Pipeline status (based on Docker status)
- Spent hours (estimated from commits)
- Documentation
- Last activity

### Sync All Projects

```bash
./scripts/notion-sync.sh sync-all
```

Creates batch file for importing multiple projects to Notion.

### Export Clients List

```bash
./scripts/notion-sync.sh export-clients
```

Creates CSV file for reporting or import to other systems.

---

## 💼 Workflow Examples

### Example 1: New Client Onboarding

**Scenario:** New client "Acme Corp" signs up for WP Express 72 service.

**Steps:**

```bash
# 1. Create project from skeleton
./scripts/new-project.sh acme-corp \
  --domain acme.com \
  --email hello@acme.com \
  --redis

# 2. Navigate to project
cd ../wp-express-projects/acme-corp

# 3. Complete WordPress installation
open http://localhost:8000

# 4. Import Elementor template (once available)
# make wp CMD="elementor import-template agency-pack"

# 5. Sync to Notion
cd ../../wp-express-skeleton
./scripts/notion-sync.sh create acme-corp

# 6. Start development
cd ../wp-express-projects/acme-corp
make logs
```

### Example 2: Production Deployment

**Scenario:** Ready to deploy "Startup" project to production.

**Steps:**

```bash
# 1. Create production project
./scripts/new-project.sh startup \
  --domain startup.com \
  --email hello@startup.com \
  --production \
  --redis

# 2. Configure production settings
cd ../wp-express-projects/startup
nano .env  # Update WP_HOME to https://startup.com

# 3. Copy to production server
rsync -avz --exclude 'vendor' --exclude 'web/wp' \
  . user@production-server:/var/www/startup/

# 4. On production server
ssh user@production-server
cd /var/www/startup
composer install --no-dev --optimize-autoloader
make production

# 5. Configure SSL certificates
# (See SETUP.md for Let's Encrypt setup)

# 6. Update Notion
./scripts/notion-sync.sh update startup
```

### Example 3: Batch Client Setup

**Scenario:** Setting up 5 new clients from intake form submissions.

**Create batch script:**

```bash
#!/bin/bash
# batch-setup.sh

clients=(
  "acme-corp:acme.com:hello@acme.com"
  "startup:startup.com:info@startup.com"
  "bigclient:bigclient.com:contact@bigclient.com"
  "local-biz:localbiz.local:owner@localbiz.com"
  "coach:coach.com:hey@coach.com"
)

for client_data in "${clients[@]}"; do
  IFS=':' read -r name domain email <<< "$client_data"
  
  echo "Setting up: $name"
  ./scripts/new-project.sh "$name" \
    --domain "$domain" \
    --email "$email" \
    --no-start
  
  echo "✓ $name ready"
  echo ""
done

echo "All projects created!"
echo "Syncing to Notion..."
./scripts/notion-sync.sh sync-all
```

**Run:**
```bash
chmod +x batch-setup.sh
./batch-setup.sh
```

---

## 🔧 Troubleshooting

### Problem: Project Won't Start

**Symptoms:**
- Docker containers fail to start
- Port conflicts
- Database connection errors

**Solutions:**

```bash
# Check Docker
docker info

# Check port availability
lsof -i :8000
lsof -i :3306

# View logs
cd ../wp-express-projects/project-name
make logs

# Rebuild containers
make down
make build
make apple-silicon  # or make intel
```

### Problem: Credentials Not Working

**Symptoms:**
- Can't access WordPress admin
- Database connection fails

**Solutions:**

```bash
# Check .env file
cat .env | grep DB_

# Verify credentials
cat .credentials

# Reset database password
cd ../wp-express-projects/project-name
# Edit .env with new password
make down
make up
```

### Problem: Notion Sync Fails

**Symptoms:**
- Can't create project in Notion
- Fields not mapping correctly

**Solutions:**

```bash
# Regenerate export file
./scripts/notion-sync.sh create project-name

# Check project info
cat ../wp-express-projects/project-name/.wp-express-project

# Manual sync via Claude
# Share the .notion-export.json with Claude
```

### Problem: Git Issues

**Symptoms:**
- Can't commit changes
- Merge conflicts
- Lost commits

**Solutions:**

```bash
cd ../wp-express-projects/project-name

# Check status
git status

# Check log
git log --oneline

# Create backup before fixing
cp -r . ../project-name-backup

# Reset to last working commit
git reset --hard HEAD~1
```

---

## 📊 Project Metrics

### Track Project Progress

```bash
# Get project stats
cd ../wp-express-projects/project-name

# Number of commits
git rev-list --count HEAD

# Lines of code
find web/app/themes web/app/plugins -name "*.php" | xargs wc -l

# Database size
docker-compose exec database mysql -e "
  SELECT 
    table_schema AS 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
  FROM information_schema.tables
  WHERE table_schema = 'wordpress'
  GROUP BY table_schema;
"

# Uploads size
du -sh web/app/uploads
```

---

## 🎯 Best Practices

### 1. **Naming Conventions**

✅ **Good:**
- `acme-corp`
- `startup-2025`
- `local-bakery`

❌ **Bad:**
- `ACME Corp` (spaces)
- `startup!!!` (special chars)
- `Client #123` (special chars)

### 2. **Before Creating Project**

- [ ] Verify client name
- [ ] Confirm domain
- [ ] Have client email
- [ ] Know environment (dev/prod)
- [ ] Decide on Redis

### 3. **After Creating Project**

- [ ] Test WordPress installation
- [ ] Create first admin user
- [ ] Install required plugins
- [ ] Import theme/template
- [ ] Create initial backup
- [ ] Sync to Notion
- [ ] Commit initial state

### 4. **Regular Maintenance**

```bash
# Weekly
./scripts/manage-projects.sh backup-all
./scripts/manage-projects.sh status

# Monthly
# Update WordPress core and plugins
cd ../wp-express-projects/each-project
make update

# Quarterly
# Clean up old projects
./scripts/manage-projects.sh list
# Archive inactive projects
```

---

## 🔐 Security Notes

### Credentials Management

1. **Never commit `.env` or `.credentials` files**
2. **Use unique passwords for each project**
3. **Store production credentials in secure vault**
4. **Rotate credentials quarterly**

### Backup Strategy

1. **Daily:** Database backups
2. **Weekly:** Full backups (DB + uploads)
3. **Monthly:** Archive to S3/cloud storage
4. **Keep:** 7 daily, 4 weekly, 12 monthly

### Access Control

1. **Development:** Open (localhost)
2. **Staging:** Password protected
3. **Production:** SSL + Fail2Ban + strong passwords

---

## 📚 Additional Resources

- [Main README](../README.md) - Full skeleton documentation
- [SETUP.md](../SETUP.md) - Detailed setup guide
- [SECURITY.md](../SECURITY.md) - Security guidelines
- [ARCHITECTURE.md](../ARCHITECTURE.md) - Technical architecture

---

## 🆘 Getting Help

### Issues with Project Generation?

1. Check script output for errors
2. Verify Docker is running
3. Check available disk space
4. Review logs: `make logs`

### Need Support?

- **GitHub Issues:** Report bugs
- **Documentation:** Check guides above
- **Claude AI:** Ask questions about the system

---

**WP Express Skeleton - Project Generation System v1.0.0**
