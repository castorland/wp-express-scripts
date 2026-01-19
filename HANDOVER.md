# WP Express Scripts - Handover Documentation

This document provides everything needed to hand over the WP Express project management scripts to a junior developer or subcontractor.

## 📦 What You're Receiving

A complete, production-ready automation system for creating WordPress projects with:
- HTTPS-first approach
- Automated Docker setup
- WordPress installation
- Plugin & theme configuration
- Professional development environment

## 🎯 Quick Start (5 Minutes)

### For the New Maintainer

```bash
# 1. Navigate to scripts directory
cd "/Users/hgabor/Projektek/WP Express/scripts"

# 2. Check git status
git status
git log --oneline -5

# 3. Read the documentation
cat README.md

# 4. Create a test project
./new-project.sh handover-test --use-localhost

# 5. Verify it works
open http://localhost:8000
```

## 📚 Documentation Structure

Read in this order:

1. **README.md** (Start here!)
   - Overview of all scripts
   - Quick start guide
   - Main features

2. **NEW-PROJECT-USAGE.md**
   - Detailed usage examples
   - All command-line options
   - Common use cases

3. **CONTRIBUTING.md**
   - Development workflow
   - Coding standards
   - How to make changes

4. **TROUBLESHOOTING.md**
   - Common issues
   - Solutions
   - Debug techniques

5. **CHANGELOG.md**
   - Version history
   - What changed when
   - Future plans

## 🗂️ File Structure

```
scripts/
├── 📄 README.md                 # START HERE - Main documentation
├── 📄 NEW-PROJECT-USAGE.md      # Detailed usage guide
├── 📄 CONTRIBUTING.md           # How to contribute
├── 📄 CHANGELOG.md              # Version history
├── 📄 HANDOVER.md               # This file
├── 📄 TROUBLESHOOTING.md        # Problem solving
├── 📄 IMPLEMENTATION.md         # Technical details
├── 📄 PROJECT_GENERATION.md     # Process documentation
├── 📄 SETUP_GUIDE.md            # Setup instructions
│
├── 🔧 new-project.sh            # MAIN SCRIPT - Project creation
├── 🔧 manage-projects.sh        # Project management
├── 🔧 diagnose.sh               # Diagnostics
├── 🔧 notion-sync.sh            # Notion integration
│
├── .gitignore                   # Git ignore rules
└── .git/                        # Git repository
```

## 🎓 Learning Path

### Week 1: Understanding

1. **Day 1-2**: Read all documentation
2. **Day 3**: Create 3-5 test projects with different options
3. **Day 4**: Study the `new-project.sh` script line by line
4. **Day 5**: Break something and fix it

### Week 2: Contributing

1. **Day 1**: Make a small documentation improvement
2. **Day 2**: Add a new command-line flag
3. **Day 3**: Fix a bug from the TROUBLESHOOTING.md
4. **Day 4**: Add a new feature (with approval)
5. **Day 5**: Review and refine your changes

## 🔑 Key Concepts

### 1. The Script Flow

```
User runs script
    ↓
Parse arguments
    ↓
Check dependencies
    ↓
Clone from GitHub
    ↓
Create .env file
    ↓
Run composer install
    ↓
Generate SSL certificates
    ↓
Start Docker containers
    ↓
Wait for database
    ↓
Install WordPress (WP-CLI)
    ↓
Activate plugins & theme
    ↓
Show credentials
    ↓
Done! 🎉
```

### 2. Important Functions

**In `new-project.sh`:**

| Function | What It Does |
|----------|-------------|
| `sanitize_name()` | Cleans up project names |
| `generate_password()` | Creates secure passwords |
| `generate_salts()` | Creates WordPress security keys |
| `check_dependencies()` | Verifies required tools |
| `add_hosts_entry()` | Adds domain to /etc/hosts |

### 3. Configuration Variables

```bash
GITHUB_REPO="..."           # Where to clone from
GITHUB_BRANCH="main"        # Which branch
CLIENTS_DIR="..."           # Where projects go
DOMAIN="${CLIENT_NAME}.local"  # Default domain
PORT="443"                  # HTTPS port
```

### 4. Docker Architecture

- **Apple Silicon**: Uses `docker-compose.apple-silicon.yml`
- **Intel**: Uses `docker-compose.intel.yml`
- Script auto-detects with: `uname -m`

### 5. WP-CLI Usage

```bash
# WP-CLI is installed via Composer at:
vendor/bin/wp

# Example commands:
docker-compose exec php vendor/bin/wp plugin list
docker-compose exec php vendor/bin/wp user list
```

## 🛠️ Common Tasks

### Creating a New Project

```bash
# Standard HTTPS project
./new-project.sh client-name

# With Redis
./new-project.sh client-name --redis

# Using localhost
./new-project.sh client-name --use-localhost
```

### Making Changes to the Script

```bash
# 1. Create a branch
git checkout -b feature/my-improvement

# 2. Edit the script
nano new-project.sh

# 3. Test thoroughly
./new-project.sh test-my-change --use-localhost

# 4. Commit
git add new-project.sh
git commit -m "feat: add my improvement"

# 5. Document
# Update README.md or relevant docs

# 6. Push
git push origin feature/my-improvement
```

### Testing Changes

```bash
# Always test these scenarios:
./new-project.sh test1 --use-localhost
./new-project.sh test2
./new-project.sh test3 --redis
./new-project.sh test4 --no-install

# Clean up
cd ../clients
rm -rf test1 test2 test3 test4
```

## 🚨 Critical Things to Know

### 1. Never Commit Credentials

`.gitignore` prevents this, but be aware:
- `.credentials` files contain passwords
- `.env` files contain database passwords
- Test projects may contain sensitive data

### 2. The /etc/hosts File

- Script modifies system files (requires sudo)
- Always backs up: `/etc/hosts.bak`
- Be careful with this functionality

### 3. Docker Volumes

- Contain actual WordPress data
- Use `docker-compose down -v` to remove
- Regular `down` keeps data intact

### 4. SSL Certificates

- Self-signed certificates in `docker/nginx/ssl/`
- Browser warnings are expected
- For production, use Let's Encrypt

### 5. WP-CLI Path

- Always use: `vendor/bin/wp`
- Not just `wp` (system-wide)
- Must be run inside PHP container

## 🆘 When Things Go Wrong

### Script Fails

1. Read the error message carefully
2. Check TROUBLESHOOTING.md
3. Run with verbose mode: `bash -x new-project.sh ...`
4. Check logs: Look at the output carefully

### Can't Access Site

```bash
# Check containers
docker ps

# Check hosts file
cat /etc/hosts | grep {client}.local

# Check nginx logs
cd clients/{client}
docker-compose logs nginx
```

### WordPress Won't Install

```bash
# Check database
docker-compose exec database mysql -u wordpress -p

# Try manual install
docker-compose exec php vendor/bin/wp core install \
  --url="https://test.local" \
  --title="Test" \
  --admin_user="admin" \
  --admin_password="password" \
  --admin_email="admin@test.local" \
  --allow-root
```

## 📞 Getting Support

### Resources

1. **Documentation** (scripts directory)
   - Start with README.md
   - Check TROUBLESHOOTING.md
   - Review NEW-PROJECT-USAGE.md

2. **Code Comments**
   - Script has inline comments
   - Explains complex sections

3. **Git History**
   ```bash
   git log --oneline
   git show <commit-hash>
   git blame new-project.sh
   ```

4. **Testing**
   - Create test projects
   - Break things safely
   - Learn by doing

### Contact Points

- **Original Developer**: Gábor (hodosg@gmail.com)
- **Documentation**: All in this repository
- **Issues**: Check git commit messages

## 🎯 Your First Tasks

### Task 1: Familiarization (Day 1)

- [ ] Read README.md completely
- [ ] Read NEW-PROJECT-USAGE.md
- [ ] Create 3 test projects
- [ ] Delete the test projects cleanly

### Task 2: Code Review (Day 2-3)

- [ ] Read through `new-project.sh` with comments
- [ ] Understand each function
- [ ] Try running individual functions
- [ ] Make notes of questions

### Task 3: Small Change (Day 4-5)

- [ ] Find something to improve
- [ ] Create a branch
- [ ] Make the change
- [ ] Test thoroughly
- [ ] Commit with proper message
- [ ] Update documentation

### Task 4: Troubleshooting (Week 2)

- [ ] Deliberately break something
- [ ] Fix it using TROUBLESHOOTING.md
- [ ] Document the solution if not covered
- [ ] Add to TROUBLESHOOTING.md if needed

## 🎓 Learning Resources

### Bash Scripting

- Google's Shell Style Guide
- ShellCheck (linting tool)
- `man bash` (local documentation)

### WordPress

- WordPress Codex
- WP-CLI Documentation
- Bedrock Documentation (Roots.io)

### Docker

- Docker Documentation
- Docker Compose Documentation
- Docker for Mac/Linux specifics

## 📈 Success Metrics

You'll know you're ready when you can:

- ✅ Create a project without looking at docs
- ✅ Explain what each function does
- ✅ Troubleshoot common issues
- ✅ Make a small improvement
- ✅ Write a proper commit message
- ✅ Help someone else understand the code

## 🎁 What Makes This Special

This isn't just a script—it's a complete automation system:

1. **Professional Setup**: HTTPS, SSL, proper domains
2. **Full Automation**: From GitHub to running WordPress
3. **Well Documented**: Everything is explained
4. **Production Ready**: Used for real client projects
5. **Maintainable**: Clean code, git history, comments
6. **Flexible**: Many options, easy to extend

## 📝 Final Notes

### For Juniors

- Don't be afraid to break things (in test projects!)
- Read the code, don't just run it
- Ask questions (document the answers)
- Test changes thoroughly
- Start small, grow gradually

### For Subcontractors

- Follow CONTRIBUTING.md guidelines
- Keep git history clean
- Document all changes
- Test on both architectures if possible
- Communicate clearly

### For Everyone

- This is a well-structured codebase
- Everything is documented for a reason
- When in doubt, check the docs
- When docs are unclear, improve them
- Leave it better than you found it

## 🚀 Ready to Start?

```bash
# Your first command
cd "/Users/hgabor/Projektek/WP Express/scripts"
./new-project.sh my-first-project --use-localhost

# Then visit
open http://localhost:8000

# Admin
open http://localhost:8000/wp/wp-admin

# Check credentials
cd ../clients/my-first-project
cat .credentials
```

**Welcome to WP Express! You've got this!** 💪

---

**Questions?** Re-read the docs, check git history, experiment safely. You'll be an expert soon! 🎓
