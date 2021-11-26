USE [SQLOpsDB]
GO

--     Purpose: This table stores names of each version of SQL Server with their respective end date for support.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: Updated on Nov. 3rd to introduce SQLVersionShortName.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SQLVersions')
BEGIN

	CREATE TABLE [dbo].[SQLVersions](
		[SQLVersionID] [int] IDENTITY(1,1) NOT NULL,
		[SQLVersion] [varchar](50) NOT NULL,
		[SQLVersionShortName] [varchar](50) NOT NULL,
		[SQLMajorVersion] [int] NOT NULL,
		[SQLMinorVersion] [int] NOT NULL,
		[SQLBuild] [int] NOT NULL,
		[SQLVersionSupportEndDate] [date] NULL,
	 CONSTRAINT [PK_SQLVersions] PRIMARY KEY CLUSTERED 
	(
		[SQLVersionID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]

	ALTER TABLE [dbo].[SQLVersions] ADD  CONSTRAINT [DF_SQLVersions_SQLMajorVersion]  DEFAULT ((0)) FOR [SQLMajorVersion]

	ALTER TABLE [dbo].[SQLVersions] ADD  CONSTRAINT [DF_SQLVersions_SQLMinorVersion]  DEFAULT ((0)) FOR [SQLMinorVersion]

	ALTER TABLE [dbo].[SQLVersions] ADD  CONSTRAINT [DF_SQLVersions_SQLBuild]  DEFAULT ((0)) FOR [SQLBuild]

	ALTER TABLE [dbo].[SQLVersions] ADD  CONSTRAINT [DF_SQLVersions_SQLVersionSupportEndDate]  DEFAULT ('1999/01/01') FOR [SQLVersionSupportEndDate]

END