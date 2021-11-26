--     Purpose: Only used for storing error log data for an instance.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: No change since implementation.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SQLErrLog' and schema_id = SCHEMA_ID('Staging'))
BEGIN

	CREATE TABLE [Staging].[SQLErrLog](
		[SQLInstanceID] [int] NULL,
		[ServerInstance] [varchar](255) NULL,
		[DateTimeCaptured] [datetime] NULL,
		[Message] [varchar](max) NULL
	) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

END
GO