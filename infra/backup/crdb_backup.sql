-- CockroachDB scheduled backup for Continuum financial ledger.
-- Run once against the CockroachDB cluster to create recurring backups.
--
-- Prerequisites:
--   - An external storage location (S3, GCS, or local nodelocal)
--   - Appropriate BACKUP privileges for the executing user
--
-- Adjust the storage URI to your production bucket before running.

-- Daily full backup with 30-day retention
CREATE SCHEDULE IF NOT EXISTS continuum_ledger_daily_backup
  FOR BACKUP DATABASE continuum
  INTO 'nodelocal://1/backups/continuum/daily'
  RECURRING '@daily'
  WITH SCHEDULE OPTIONS first_run = 'now',
  FULL BACKUP ALWAYS;

-- To use S3 instead, replace the INTO clause:
-- INTO 's3://your-bucket/backups/continuum/daily?AUTH=implicit'

-- Verify the schedule was created
SHOW SCHEDULES;
