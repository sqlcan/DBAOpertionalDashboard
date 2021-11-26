--     Purpose: History of every job execution and its status and duration.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: No changes since release.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SQLJobHistory')
BEGIN
	CREATE TABLE [dbo].[SQLJobHistory](
		[SQLJobHistoryID] [bigint] IDENTITY(1,1) NOT NULL,
		[SQLJobID] [int] NOT NULL,
		[ExecutionDateTime] [datetime] NOT NULL,
		[Duration] [int] NOT NULL,
		[JobStatus] varchar(25) NOT NULL
	 CONSTRAINT [PK_SQLJobHistory] PRIMARY KEY CLUSTERED 
	(
		[SQLJobHistoryID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]

	ALTER TABLE [dbo].[SQLJobHistory]  WITH CHECK ADD  CONSTRAINT [FK_SQLJobHistory_SQLJobs] FOREIGN KEY([SQLJobID])
	REFERENCES [dbo].[SQLJobs] ([SQLJobID])

	ALTER TABLE [dbo].[SQLJobHistory] CHECK CONSTRAINT [FK_SQLJobHistory_SQLJobs]
END
GO