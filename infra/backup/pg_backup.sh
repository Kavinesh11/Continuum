#!/usr/bin/env bash
set -euo pipefail

# PostgreSQL backup script for Continuum operational database.
# Intended for cron: 0 2 * * * /path/to/pg_backup.sh
#
# Required env vars: PG_HOST, PG_USER, PG_PASSWORD (or .pgpass), PG_DATABASE
# Optional: BACKUP_DIR (default: /var/backups/continuum/postgres), RETENTION_DAYS (default: 30)

BACKUP_DIR="${BACKUP_DIR:-/var/backups/continuum/postgres}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/continuum_pg_${TIMESTAMP}.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "[$(date -Iseconds)] Starting PostgreSQL backup → ${BACKUP_FILE}"

export PGPASSWORD="${PG_PASSWORD}"

pg_dump \
  -h "${PG_HOST:-localhost}" \
  -p "${PG_PORT:-5432}" \
  -U "${PG_USER:-postgres}" \
  -d "${PG_DATABASE:-continuum}" \
  --format=custom \
  --compress=6 \
  --no-owner \
  --verbose \
  2>>"${BACKUP_DIR}/backup.log" \
  | gzip > "$BACKUP_FILE"

FILESIZE=$(stat --printf="%s" "$BACKUP_FILE" 2>/dev/null || stat -f%z "$BACKUP_FILE")
echo "[$(date -Iseconds)] Backup complete: ${BACKUP_FILE} (${FILESIZE} bytes)"

echo "[$(date -Iseconds)] Pruning backups older than ${RETENTION_DAYS} days"
find "$BACKUP_DIR" -name "continuum_pg_*.sql.gz" -mtime +"$RETENTION_DAYS" -delete

echo "[$(date -Iseconds)] PostgreSQL backup finished"
