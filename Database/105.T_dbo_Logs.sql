--     Purpose: SQLOpsDB Execution Logs
--
--              If table already exists the table is ignored.
-- 
-- NOTE: No change since release.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Oct. 3, 2020

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Logs')
BEGIN
	CREATE TABLE [dbo].[Logs](
		[LogID] [bigint] IDENTITY(1,1) NOT NULL,
		[DateTimeCaptured] [datetime] NOT NULL,
		[ProcessID] [int] NOT NULL,
		[Description] [varchar](512) NULL,
	 CONSTRAINT [PK_Logs] PRIMARY KEY CLUSTERED 
	(
		[LogID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	) ON [PRIMARY]

	ALTER TABLE [dbo].[Logs] ADD  CONSTRAINT [DF_Logs_DateTimeCaptured]  DEFAULT (getdate()) FOR [DateTimeCaptured]

	ALTER TABLE [dbo].[Logs] ADD  CONSTRAINT [DF_Logs_ProcessID]  DEFAULT ((-1)) FOR [ProcessID]
END