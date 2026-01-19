# WP Express - Project Generation System
## Implementation Guide & Testing

---

## 📦 What You Just Received

Three powerful scripts to manage your WP Express client projects:

### 1. **`new-project.sh`** - Project Generator
Creates new client projects from your skeleton template

### 2. **`manage-projects.sh`** - Project Manager  
Lists, monitors, backs up, and manages all projects

### 3. **`notion-sync.sh`** - Notion Integration
Syncs projects with your Notion databases

---

## 🚀 Quick Start (5 Minutes)

### Step 1: Install Scripts in Your Repository

```bash
# Navigate to your wp-express-skeleton repo
cd ~/path/to/wp-express-skeleton

# Copy the scripts folder
cp -r /path/to/downloaded/scripts ./

# Make them executable
chmod +x scripts/*.sh
```

### Step 2: Test Create Your First Project

```bash
# Create a test project
./scripts/new-project.sh test-client

# This will:
# ✓ Create ../clients/test-client directory
# ✓ Copy skeleton files
# ✓ Generate unique .env with WordPress salts
# ✓ Create SSL certificates
# ✓ Initialize Git repository
# ✓ Optionally start Docker containers
```

### Step 3: Verify It Works

```bash
# Check if project was created
ls -la ../clients/test-client

# See what containers are running
cd ../clients/test-client
docker-compose ps

# Access WordPress
open http://test-client.local:8000
```

---

## 🎯 Real-World Usage Examples

### Example 1: Basic Client Project

```bash
./scripts/new-project.sh acme-corp
```

**Result:** Project created at `../clients/acme-corp`  
**URL:** http://acme-corp.local:8000

### Example 2: Custom Domain

```bash
./scripts/new-project.sh startup startup.com
```

**Result:** Project with custom domain  
**URL:** http://startup.com:8000 (in development)

### Example 3: Auto-Start Containers

```bash
./scripts/new-project.sh bigclient bigclient.local --start
```

**Result:** Project created and Docker started immediately

### Example 4: Create Multiple Projects

```bash
# Create batch setup
./scripts/new-project.sh client1 --no-start
./scripts/new-project.sh client2 --no-start
./scripts/new-project.sh client3 --no-start

# Then start them individually as needed
cd ../clients/client1 && make apple-silicon
```

---

## 📊 Project Management

### List All Projects

```bash
./scripts/manage-projects.sh list
```

**Output:**
```
PROJECT        STATUS     CONTAINERS  ENVIRONMENT  CREATED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
acme-corp      running    5          development  2025-01-18
startup        stopped    0          development  2025-01-17
test-client    running    5          development  2025-01-18
```

### Check Project Health

```bash
./scripts/manage-projects.sh check acme-corp
```

**Checks:**
- ✓ .env file exists
- ✓ Docker containers running
- ✓ WordPress accessible
- ✓ Git status
- ✓ Disk usage

### Backup Project

```bash
# Backup single project
./scripts/manage-projects.sh backup acme-corp

# Backup all projects
./scripts/manage-projects.sh backup-all
```

**Creates:**
- `db_TIMESTAMP.sql` - Database dump
- `uploads_TIMESTAMP.tar.gz` - Media files
- `env_TIMESTAMP.backup` - Configuration backup

### Stop Projects

```bash
# Stop one project
./scripts/manage-projects.sh stop acme-corp

# Stop all projects
./scripts/manage-projects.sh stop-all
```

---

## 🔗 Notion Integration

### Sync New Project to Notion

```bash
# Generate Notion import data
./scripts/notion-sync.sh create acme-corp
```

**This creates** `.notion-export.json` with:
- Project data for Projects database
- Client data for Clients database

**Then use Claude to import:**
1. Open Claude with Notion MCP enabled
2. Share the .notion-export.json file
3. Ask Claude to create the entries

### Update Project Status

```bash
./scripts/notion-sync.sh update acme-corp
```

**Updates:**
- Pipeline status (based on Docker/WordPress state)
- Estimated hours (from commit count)
- Documentation

### Batch Sync All Projects

```bash
./scripts/notion-sync.sh sync-all
```

Creates batch import file for all projects.

---

## 🧪 Testing Checklist

Use this to verify everything works:

### ✅ Basic Functionality

```bash
# 1. Create test project
./scripts/new-project.sh test-1 --start

# 2. Verify directory exists
[ -d ../clients/test-1 ] && echo "✓ Directory created"

# 3. Verify .env has unique salts
grep "AUTH_KEY" ../clients/test-1/.env && echo "✓ Salts generated"

# 4. Verify Git initialized
cd ../clients/test-1 && git log && echo "✓ Git initialized"

# 5. Verify Docker running
docker-compose ps | grep "Up" && echo "✓ Docker running"

# 6. Verify WordPress accessible
curl -s http://localhost:8000 | grep "WordPress" && echo "✓ WordPress accessible"

# 7. Create backup
cd ../../wp-express-skeleton
./scripts/manage-projects.sh backup test-1
[ -d ../clients/test-1/backups ] && echo "✓ Backup created"

# 8. List projects
./scripts/manage-projects.sh list

# 9. Clean up
./scripts/manage-projects.sh stop test-1
rm -rf ../clients/test-1
echo "✓ Test complete"
```

### ✅ Advanced Testing

```bash
# Test multiple projects
for i in {1..3}; do
    ./scripts/new-project.sh test-$i --no-start
done

# List them
./scripts/manage-projects.sh list

# Start one
cd ../clients/test-2
make apple-silicon

# Check status
cd ../../wp-express-skeleton
./scripts/manage-projects.sh status

# Backup all
./scripts/manage-projects.sh backup-all

# Clean up
./scripts/manage-projects.sh stop-all
rm -rf ../clients/test-*
```

---

## 📁 What Gets Created

For each project, this structure is generated:

```
clients/
└── acme-corp/
    ├── .env                    # ✅ Unique configuration & salts
    ├── .credentials            # ✅ Database passwords (SECURE!)
    ├── .wp-express-project     # ✅ Project metadata (JSON)
    ├── .git/                   # ✅ Fresh Git repository
    ├── PROJECT_README.md       # ✅ Client-specific docs
    ├── composer.json           # From skeleton
    ├── docker-compose.*.yml    # From skeleton
    ├── config/                 # WordPress config
    ├── docker/                 # Docker configs
    │   └── nginx/ssl/          # ✅ Unique SSL certificates
    ├── web/
    │   ├── app/
    │   │   ├── mu-plugins/     # From skeleton
    │   │   ├── plugins/        # Empty (ready for installs)
    │   │   ├── themes/         # Empty (ready for installs)
    │   │   └── uploads/        # Empty (ready for media)
    │   └── wp/                 # WordPress core (Composer managed)
    └── backups/                # ✅ Ready for backups
```

**Key Points:**
- ✅ Every `.env` has **unique** WordPress salts
- ✅ Every database has **unique** password
- ✅ Every project has **separate** Git history
- ✅ SSL certificates are **unique** per project
- ⚠️ `.credentials` file contains sensitive data - **keep secure!**

---

## 🔐 Security Notes

### What Gets Auto-Generated

Each project receives:

1. **Unique WordPress Salts** (from WordPress.org API)
2. **Random Database Password** (32 characters)
3. **Separate `.env` file** (never committed)
4. **Project-specific SSL certificates**

### Important Files to Protect

**Never commit these to Git:**
- ✅ `.env` (already in .gitignore)
- ✅ `.credentials` (already in .gitignore)
- ✅ Any production passwords

**Store production credentials in:**
- Password manager (1Password, LastPass)
- Encrypted vault (Ansible Vault, SOPS)
- Secrets manager (AWS Secrets Manager, HashiCorp Vault)

---

## 🎬 Complete Workflow Example

### Scenario: New Client "Acme Corp"

```bash
# 1. Create project
./scripts/new-project.sh acme-corp acme.local --start

# 2. Wait for containers
sleep 10

# 3. Complete WordPress installation
open http://acme.local:8000
# - Site Title: Acme Corp
# - Admin User: admin
# - Admin Email: hello@acme.com

# 4. Install required plugins
cd ../clients/acme-corp
composer require wpackagist-plugin/elementor
composer require wpackagist-plugin/contact-form-7

# 5. Import Elementor template (once you have them)
# make wp CMD="elementor import-template business-pack"

# 6. Create initial backup
cd ../../wp-express-skeleton
./scripts/manage-projects.sh backup acme-corp

# 7. Sync to Notion
./scripts/notion-sync.sh create acme-corp
# (Then use Claude with Notion MCP to import)

# 8. Commit initial state
cd ../clients/acme-corp
git add .
git commit -m "Initial WordPress installation with plugins"

# 9. Push to GitHub (optional)
# git remote add origin https://github.com/yourorg/acme-corp.git
# git push -u origin main
```

---

## 🐛 Troubleshooting

### Problem: Script says "Permission denied"

**Solution:**
```bash
chmod +x scripts/*.sh
```

### Problem: "Client name invalid"

**Solution:**
- Use only: letters, numbers, hyphens, underscores
- No spaces or special characters
- Valid: `acme-corp`, `client_1`, `startup2025`
- Invalid: `Acme Corp`, `client!`, `#client`

### Problem: "Docker containers won't start"

**Solution:**
```bash
# Check Docker is running
docker info

# Check ports aren't in use
lsof -i :8000
lsof -i :3306

# View logs
cd ../clients/project-name
make logs
```

### Problem: "WordPress installation fails"

**Solution:**
```bash
# Wait for database to initialize (30 seconds)
sleep 30

# Check database is ready
docker-compose exec database mysql -uwordpress -p

# Restart containers
make down
make apple-silicon
```

### Problem: "Can't access http://client.local:8000"

**Solution:**
```bash
# Use localhost instead
http://localhost:8000

# Or add to /etc/hosts
echo "127.0.0.1 client.local" | sudo tee -a /etc/hosts
```

---

## 📈 Next Steps

### Now That You Have Project Generation:

1. **Test it thoroughly** ✅ (use testing checklist above)

2. **Create your first real client** 🎯
   ```bash
   ./scripts/new-project.sh your-first-client
   ```

3. **Set up Notion integration** 🔗
   - Test `notion-sync.sh create`
   - Use Claude to import to Notion
   - Verify project appears in Projects database

4. **Build Elementor templates** 🎨 (Option C)
   - Create one Express Pack
   - Export as .json
   - Add import script

5. **Document your workflow** 📝
   - Create internal team guide
   - Add screenshots
   - Record video walkthrough

6. **Production deployment** 🚀
   - Test on staging server
   - Set up CI/CD pipeline
   - Document deployment process

---

## 🆘 Getting Help

**Issues with scripts?**
1. Check the error message
2. Verify Docker is running: `docker info`
3. Check disk space: `df -h`
4. View detailed logs: `make logs`

**Feature requests?**
- Document what you need
- Share with me (Claude)
- I can enhance the scripts

**Questions about workflow?**
- Ask me specific questions
- I can create custom scripts
- I can explain any part

---

## 📚 Documentation Files

You received these files:

1. **`scripts/new-project.sh`** - Main project generator
2. **`scripts/manage-projects.sh`** - Project management
3. **`scripts/notion-sync.sh`** - Notion integration
4. **`PROJECT_GENERATION.md`** - Complete guide
5. **`IMPLEMENTATION.md`** - This file

---

## ✨ What's Next?

You've completed **Option A: Project Generation System** ✅

**Ready for:**

- **Option B:** Notion Integration (enhance automation)
- **Option C:** Elementor Templates (8 Express Packs)
- **Option D:** Production Deployment (live server setup)

**Which would you like to tackle next?**

---

**WP Express - Project Generation System v1.0.0**  
Created: 2025-01-18
