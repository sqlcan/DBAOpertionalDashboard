--     Purpose: Summarized policy results for the current day.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: No changes since initial release.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'PolicyHistorySummary' AND schema_id = SCHEMA_ID('Policy'))
BEGIN
	CREATE TABLE [Policy].[PolicyHistorySummary](
		[CategoryName] [nvarchar](128) NULL,
		[PolicyName] [sysname] NOT NULL,
		[policy_id] [int] NULL,
		[EvaluatedServer] [nvarchar](256) NULL,
		[ObjectName] [nvarchar](256) NULL,
		[EvaluationDateTime] [datetime] NULL,
		[PolicyResult] [nvarchar](5) NOT NULL
	) ON [PRIMARY]
END
Go