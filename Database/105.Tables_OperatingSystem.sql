--     Purpose: This table stores names of each operation system as full discription and their short names.
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

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'OperatingSystems')
BEGIN

	CREATE TABLE [dbo].[OperatingSystems](
		[OperatingSystemID] [int] IDENTITY(1,1) NOT NULL,
		[OperatingSystemName] [varchar](255) NOT NULL,
		[OperatingSystemShortName] [varchar](128) NOT NULL,
	 CONSTRAINT [PK_OperatingSystems] PRIMARY KEY CLUSTERED 
	(
		[OperatingSystemID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]

END