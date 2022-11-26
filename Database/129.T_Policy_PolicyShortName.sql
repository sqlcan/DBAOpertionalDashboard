--     Purpose: Stores short-names for the policies, to make it easier to report.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: No change since initial release.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

USE [SQLOpsDB]
GO


SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Policy].[PolicyShortName](
	[Policy_ID] [int] NOT NULL,
	[Policy_ShortName] [varchar](255) NULL,
 CONSTRAINT [PK_policy.PolicyShortName] PRIMARY KEY CLUSTERED 
(
	[Policy_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]