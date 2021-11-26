--     Purpose: Stores all the jobs discovered on the instances.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: Added SQLJobHash, to allow for later functionality to compare jobs against AG instances on Nov. 3, 2020.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SQLJobs')
BEGIN

	CREATE TABLE [dbo].[SQLJobs](
		[SQLJobID] [int] IDENTITY(1,1) NOT NULL,
		[SQLInstanceID] [int] NOT NULL,
		[SQLJobCategoryID] [int] NOT NULL,
		[SQLJobName] [varchar](255) NOT NULL,
		[SQLJobHash] [varbinary](8000) NULL, -- 2020.11.03 Unles PowerShell Scripts are updated to handle this it will default to NULL.
		[LastUpdated] [date] NOT NULL,
		[DiscoveredOn] [date] NOT NULL,
	 CONSTRAINT [PK_SQLJobs] PRIMARY KEY CLUSTERED 
	(
		[SQLJobID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]

	ALTER TABLE [dbo].[SQLJobs]  WITH CHECK ADD  CONSTRAINT [FK_SQLJobs_SQLInstances] FOREIGN KEY([SQLInstanceID])
	REFERENCES [dbo].[SQLInstances] ([SQLInstanceID])

	ALTER TABLE [dbo].[SQLJobs]  WITH CHECK ADD  CONSTRAINT [FK_SQLJobs_SQLJobsCategories] FOREIGN KEY([SQLJobCategoryID])
	REFERENCES [dbo].[SQLJobCategory] ([SQLJobCategoryID])

	ALTER TABLE [dbo].[SQLJobs] CHECK CONSTRAINT [FK_SQLJobs_SQLInstances]

	ALTER TABLE [dbo].[SQLJobs] CHECK CONSTRAINT [FK_SQLJobs_SQLJobsCategories]
END

