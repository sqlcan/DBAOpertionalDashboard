--     Purpose: Staging table to store results from collection. To minimize RBAR operations when updating
--              SQLOpsDB.
--
--              If table already exists drop it.
-- 
-- NOTE: No updates since last release

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

USE [SQLOpsDB]
GO

/****** Object:  Table [Staging].[DatabaseSizeDetails]    Script Date: 2/27/2020 12:49:33 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'DatabaseSizeDetails' AND schema_id = SCHEMA_ID('Staging'))
BEGIN
	DROP TABLE [Staging].[DatabaseSizeDetails]
END

CREATE TABLE [Staging].[DatabaseSizeDetails](
	[SQLInstanceID] [int] NULL,
	[AGGuid] [uniqueidentifier] NULL,
	[DatabaseName] [varchar](255) NULL,
	[DatabaseState] [varchar](60) NULL,
	[FileType] [char](4) NULL,
	[FileSize_mb] [bigint] NULL
) ON [PRIMARY]
GO


