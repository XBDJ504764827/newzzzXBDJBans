-- Super idempotent script for whitelist and player_cache
-- This version avoids 'AFTER' to prevent 'Unknown column' errors if columns are added in specific orders

-- 1. Handling whitelist table fields
-- Add steam_id_3 if missing
SET @dbname = DATABASE();
SET @tablename = "whitelist";
SET @columnname = "steam_id_3";
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
   WHERE (TABLE_NAME = @tablename)
   AND (COLUMN_NAME = @columnname)
   AND (TABLE_SCHEMA = @dbname)) > 0,
  "SELECT 1",
  "ALTER TABLE whitelist ADD COLUMN steam_id_3 VARCHAR(32)"
));
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Add steam_id_64 if missing
SET @columnname = "steam_id_64";
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
   WHERE (TABLE_NAME = @tablename)
   AND (COLUMN_NAME = @columnname)
   AND (TABLE_SCHEMA = @dbname)) > 0,
  "SELECT 1",
  "ALTER TABLE whitelist ADD COLUMN steam_id_64 VARCHAR(64)"
));
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 2. Ensure player_cache table exists
CREATE TABLE IF NOT EXISTS player_cache (
    steam_id VARCHAR(64) PRIMARY KEY,
    player_name VARCHAR(128),
    ip_address VARCHAR(45),
    status VARCHAR(32) DEFAULT 'pending',
    reason TEXT,
    steam_level INT,
    gokz_rating DECIMAL(10, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
