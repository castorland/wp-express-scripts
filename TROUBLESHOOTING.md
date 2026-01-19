# Troubleshooting: Containers Won't Start

## Quick Diagnostic

Run this in your project directory:

```bash
cd clients/your-project
docker-compose ps
docker-compose logs
```

---

## Common Issues & Solutions

### 1. Port Conflicts

**Symptom:** Error about ports already in use

**Check:**
```bash
lsof -i :8000
lsof -i :3306
lsof -i :6379
```

**Solution:**
```bash
# Stop whatever is using the port, OR
# Change ports in docker-compose.yml:
# ports:
#   - "8001:80"  # Change 8000 to 8001
```

---

### 2. Docker Compose File Not Found

**Symptom:** `docker-compose.apple-silicon.yml` not found

**Check:**
```bash
ls -la docker-compose*.yml
```

**Solution:**
```bash
# Use the default file
docker-compose up -d

# Or use make command
make apple-silicon  # For M1/M2/M3
make intel         # For Intel
```

---

### 3. Missing .env File

**Symptom:** Database connection errors

**Check:**
```bash
ls -la .env
cat .env | grep DB_
```

**Solution:**
```bash
# Re-run the setup script
cd ../../scripts
./new-project.sh your-project
```

---

### 4. Composer Dependencies Missing

**Symptom:** WordPress core not found

**Check:**
```bash
ls -la web/wp
ls -la vendor
```

**Solution:**
```bash
# Install dependencies
composer install

# Or let Docker install them
make apple-silicon
```

---

### 5. Permission Issues

**Symptom:** Cannot write to directories

**Solution:**
```bash
# Fix permissions
chmod -R 755 web/app/uploads
chmod -R 755 web/app/plugins
chmod -R 755 web/app/themes
```

---

## Step-by-Step Debugging

### Step 1: Check Docker

```bash
# Is Docker running?
docker info

# If not, start Docker Desktop
```

### Step 2: Check Project Files

```bash
cd clients/your-project

# Required files exist?
ls -la .env
ls -la docker-compose*.yml

# Config is valid?
cat .env | grep DB_PASSWORD
```

### Step 3: Try Manual Start

```bash
# Try explicit docker-compose file
docker-compose -f docker-compose.apple-silicon.yml up -d

# Watch the logs in real-time
docker-compose -f docker-compose.apple-silicon.yml logs -f
```

### Step 4: Start Services One by One

```bash
# Start database first
docker-compose up -d database

# Wait 10 seconds
sleep 10

# Check database is running
docker-compose ps

# Start remaining services
docker-compose up -d nginx php
```

---

## Detailed Logs

### View All Logs
```bash
docker-compose logs
```

### View Specific Service
```bash
docker-compose logs database
docker-compose logs php
docker-compose logs nginx
```

### Follow Logs in Real-Time
```bash
docker-compose logs -f
```

---

## Nuclear Option: Complete Reset

If nothing works, start fresh:

```bash
# Stop everything
docker-compose down -v

# Remove containers and volumes
docker system prune -a --volumes

# Delete project
cd ../..
rm -rf clients/your-project

# Recreate
cd scripts
./new-project.sh your-project
```

---

## Still Having Issues?

### Check These:

1. **Docker Desktop Settings**
   - Resources > Memory: At least 4GB
   - Resources > Disk: At least 20GB free
   - File Sharing: Project directory is shared

2. **macOS Specific**
   - Security & Privacy: Docker has full disk access
   - No VPN interfering with localhost

3. **Network**
   - No firewall blocking Docker
   - No antivirus blocking containers

### Get More Info:

```bash
# System info
docker info
docker version
docker-compose version

# Architecture
uname -m

# Available memory
free -h  # Linux
vm_stat  # macOS

# Disk space
df -h
```

---

## Quick Tests

### Test 1: Can Docker Run Anything?

```bash
docker run --rm hello-world
```

If this fails, Docker itself has issues.

### Test 2: Can You Access Localhost?

```bash
curl http://localhost:8000
```

If connection refused, containers aren't listening.

### Test 3: Are Containers Actually Running?

```bash
docker ps
```

Should show nginx, php, database containers.

---

## Common Error Messages

### "Port is already allocated"
**Fix:** Stop the service using that port or change ports in docker-compose.yml

### "Cannot connect to Docker daemon"
**Fix:** Start Docker Desktop

### "Connection refused to database"
**Fix:** Wait 30 seconds for database to initialize, or check logs

### "Permission denied"
**Fix:** Check file permissions and Docker file sharing settings

---

## Need More Help?

1. Share full output of:
   ```bash
   docker-compose ps
   docker-compose logs
   cat .env
   ```

2. Include your system info:
   ```bash
   uname -a
   docker version
   ```

3. Run diagnostic script:
   ```bash
   cd ../../scripts
   ./diagnose.sh your-project
   ```
