--     Purpose: Metadata on when the job collect last completed.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: No changes since initial release.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

/*

Removed.  Moved to dbo.SQLInstances.

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SQLJobs_Stats')
BEGIN
	CREATE TABLE [dbo].[SQLJobs_Stats](
		[ID] [int] IDENTITY(1,1) NOT NULL,
		[SQLInstanceID] [int] NOT NULL,
		[LastDateTimeCaptured] [datetime] NULL,
	PRIMARY KEY CLUSTERED 
	(
		[ID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	) ON [PRIMARY]

	ALTER TABLE [dbo].[SQLJobs_Stats] ADD  DEFAULT ('1900-01-01 00:00:00') FOR [LastDateTimeCaptured]
END

*/