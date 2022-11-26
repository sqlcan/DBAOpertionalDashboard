--     Purpose: Trending history by month and year for SQL instances.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: No change since initial implementation.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [Trending].[SQLInstances](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[YearMonth] [int] NOT NULL,
	[ServerVersionID] [int] NOT NULL,
	[Environment] [varchar](25) NOT NULL,
	[InstanceCount] [int] NOT NULL,
 CONSTRAINT [PK_SQLInstances_1] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]