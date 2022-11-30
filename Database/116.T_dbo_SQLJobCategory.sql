--     Purpose: Current job categories discovered accross the SQL infrastrcuture.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: No changes since release.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Oct. 3, 2020

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[SQLJobCategory](
	[SQLJobCategoryID] [int] IDENTITY(1,1) NOT NULL,
	[SQLJobCategoryName] [varchar](255) NOT NULL,
 CONSTRAINT [PK_SQLJobsCategory] PRIMARY KEY CLUSTERED 
(
	[SQLJobCategoryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]