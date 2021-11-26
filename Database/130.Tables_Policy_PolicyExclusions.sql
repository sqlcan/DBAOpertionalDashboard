--     Purpose: Provides DBA team with doing bulk exclusions for Policy Results.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: No changes since initial relesae.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

USE [SQLOpsDB]
GO
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'PolicyExclusions' and schema_id = SCHEMA_ID('Policy'))
BEGIN
	CREATE TABLE [Policy].[PolicyExclusions](
		[Policy_ID] [int] NOT NULL,
		[EvaluatedServer] [varchar](255) NOT NULL,
		[ObjectName] [varchar](255) NOT NULL,
		[ReasonForExclusion] [varchar](255) NULL,
	 CONSTRAINT [PK_PolicyExclusions] PRIMARY KEY CLUSTERED 
	(
		[Policy_ID] ASC,
		[EvaluatedServer] ASC,
		[ObjectName] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
	) ON [PRIMARY]
END