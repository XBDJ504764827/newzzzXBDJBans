-- Add migration script here
-- Add migration script here
-- Using a trick to add column if not exists in MySQL
SET @dbname = DATABASE();
SET @tablename = "bans";
SET @columnname = "steam_id_64";
SET @preparedStatement = (SELECT IF(
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
   WHERE (TABLE_NAME = @tablename)
   AND (COLUMN_NAME = @columnname)
   AND (TABLE_SCHEMA = @dbname)) > 0,
  "SELECT 1",
  "ALTER TABLE bans ADD COLUMN steam_id_64 VARCHAR(64) AFTER steam_id"
));
PREPARE stmt FROM @preparedStatement;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
