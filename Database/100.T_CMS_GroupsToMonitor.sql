--     Purpose: This table stores group ID for each group the DBOps solution should be monitoring.
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

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'GroupsToMonitor' AND schema_id = SCHEMA_ID('CMS'))
BEGIN
	CREATE TABLE [CMS].[GroupsToMonitor](
		[ID] [int] IDENTITY(1,1) NOT NULL,
		[GroupID] [int] NOT NULL,
		[IsMonitored] [bit] NOT NULL,
	 CONSTRAINT [PK_CMSGroups] PRIMARY KEY CLUSTERED 
	(
		[ID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
	) ON [PRIMARY]

	ALTER TABLE [CMS].[GroupsToMonitor] ADD  CONSTRAINT [DF_CMSGroups_IsMonitored]  DEFAULT ((0)) FOR [IsMonitored]
END