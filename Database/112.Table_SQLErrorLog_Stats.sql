--     Purpose: Last error log connection details for an instnace.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: Changed non-clustered index to unique.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

/*

Single Column Moved to dbo.SQLInstances.

USE [SQLOpsDB]
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SQLErrorLog_Stats')
BEGIN
	CREATE TABLE dbo.SQLErrorLog_Stats
	 (ID INT IDENTITY(1,1) PRIMARY KEY,
	  SQLInstanceID INT NOT NULL,
	  LastDateTimeCaptured DATETIME DEFAULT('1900-01-01 00:00:00'))

	CREATE UNIQUE INDEX ui_SQLErrorLog_Stats_SQLInstanceID ON dbo.SQLErrorLog_Stats(SQLInstanceID)
END
GO
*/