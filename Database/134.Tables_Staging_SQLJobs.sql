--     Purpose: Temp Tablesfor SQL Job details
--
--              If table already exists the table is ignored.
-- 
-- NOTE: ShortName was added in Oct. 3, 2020.  Therefore, if your database is older, recommend dropping the
--       table manually.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SQLJobs' and schema_id = SCHEMA_ID('Staging'))
BEGIN
	CREATE TABLE [Staging].[SQLJobs](
		[SQLInstanceID] [int] NULL,
		[ServerInstance] [varchar](255) NULL,
		[JobName] [varchar](255) NULL,
		[CategoryName] [varchar](255) NULL,
		[ExecutionDateTime] [datetime] NULL,
		[Duration] [int] NULL,
		[JobStatus] [varchar](25) NULL
	) ON [PRIMARY]
END