#!/bin/bash

################################################################################
# WP Express — Production Database Backup
# Runs hourly via cron; uploads to Hetzner Object Storage via rclone
#
# Cron entry (added by bootstrap-vps.sh):
#   0 * * * * /opt/wp-express/backup/backup.sh >> /opt/wp-express/backup/backup.log 2>&1
################################################################################

set -euo pipefail

BACKUP_DIR="/opt/wp-express/backup/dumps"
SECRET_FILE="/opt/wp-express/mariadb-production/secrets/root_password"
TIMESTAMP=$(date +%Y%m%d-%H%M)
RCLONE_REMOTE="hetzner-s3:wp-express-backups/mariadb-prod"
RETAIN_DAYS=7

mkdir -p "$BACKUP_DIR"

if [ ! -f "$SECRET_FILE" ]; then
    echo "[$(date)] ERROR: MariaDB root password file not found: $SECRET_FILE"
    exit 1
fi

MARIADB_ROOT_PASS=$(cat "$SECRET_FILE")

echo "[$(date)] Starting production DB backup..."

# Dump all databases (--single-transaction = consistent snapshot without locking)
docker exec mariadb_prod mariadb-dump \
    -u root -p"${MARIADB_ROOT_PASS}" \
    --all-databases \
    --single-transaction \
    --quick \
    --skip-lock-tables \
    --events \
    --routines \
    | gzip > "${BACKUP_DIR}/prod-${TIMESTAMP}.sql.gz"

BACKUP_SIZE=$(du -sh "${BACKUP_DIR}/prod-${TIMESTAMP}.sql.gz" | cut -f1)
echo "[$(date)] Dump complete: prod-${TIMESTAMP}.sql.gz (${BACKUP_SIZE})"

# Upload to Hetzner Object Storage
if command -v rclone &>/dev/null; then
    rclone copy "${BACKUP_DIR}/prod-${TIMESTAMP}.sql.gz" "${RCLONE_REMOTE}/" \
        --s3-no-check-bucket \
        --retries 3
    echo "[$(date)] Uploaded to ${RCLONE_REMOTE}/prod-${TIMESTAMP}.sql.gz"
else
    echo "[$(date)] WARNING: rclone not installed — backup is local only"
fi

# Remove local dumps older than RETAIN_DAYS
find "$BACKUP_DIR" -name "prod-*.sql.gz" -mtime "+${RETAIN_DAYS}" -delete
echo "[$(date)] Pruned local dumps older than ${RETAIN_DAYS} days"

echo "[$(date)] Backup complete."
