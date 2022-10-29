--     Purpose: Staging table to store temp results before merging.
--
--              If table already exists the table is dropped.
-- 
-- NOTE: No change since initial release.
--
--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Oct. 28, 2022

USE [SQLOpsDB]
GO

/****** Object:  Table [Staging].[DatabaseSizeDetails]    Script Date: 10/29/2022 4:19:28 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Databases' and schema_id = SCHEMA_ID('Staging'))
BEGIN
	DROP TABLE [Staging].[Databases]
END

CREATE TABLE [Staging].[Databases](
	[ProcessID] [int] NULL,
	[SQLInstanceID] [int] NULL,
	[AGGuid] [uniqueidentifier] NULL,
	[DatabaseName] [varchar](255) NULL,
	[DatabaseState] [varchar](60) NULL,
	[FileType] [char](4) NULL,
	[FileSize_mb] [bigint] NULL
) ON [PRIMARY]
GO


