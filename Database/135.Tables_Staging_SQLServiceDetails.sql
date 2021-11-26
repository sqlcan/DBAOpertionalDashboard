--     Purpose: Staging table to store temp results before merging.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: No change since initial release.
--
--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SQLServiceDetails' and schema_id = SCHEMA_ID('Staging'))
BEGIN

	CREATE TABLE [Staging].[SQLServiceDetails](
		[ServerName] [varchar](255) NULL,
		[ServiceName] [varchar](255) NULL,
		[InstanceName] [varchar](255) NULL,
		[DisplayName] [varchar](255) NULL,
		[FilePath] [varchar](512) NULL,
		[ServiceType] [varchar](25) NULL,
		[StartMode] [varchar](25) NULL,
		[ServiceAccount] [varchar](50) NULL,
		[ServiceVersion] [int] NULL,
		[ServiceBuild] [varchar](25) NULL
	) ON [PRIMARY]

END


