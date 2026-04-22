-- Restore old backup to a side database so we can pull reference data without touching luma_db
USE master;
GO

IF DB_ID('luma_db_old') IS NOT NULL
BEGIN
    ALTER DATABASE luma_db_old SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE luma_db_old;
END
GO

RESTORE DATABASE luma_db_old
  FROM DISK = N'C:\Temp\luma_db_old.bak'
  WITH
    MOVE N'luma_db'     TO N'C:\Temp\luma_db_old.mdf',
    MOVE N'luma_db_log' TO N'C:\Temp\luma_db_old_log.ldf',
    REPLACE,
    STATS = 10;
GO

USE luma_db_old;
GO

SELECT name FROM sys.tables ORDER BY name;
SELECT 'cities' AS tbl, COUNT(*) AS rows FROM cities
UNION ALL SELECT 'events', COUNT(*) FROM events
UNION ALL SELECT 'users', COUNT(*) FROM users;
GO
