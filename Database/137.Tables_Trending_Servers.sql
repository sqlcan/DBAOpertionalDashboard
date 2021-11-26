--     Purpose: Trending history for servers by month and year.
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

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Servers' and schema_id = SCHEMA_ID('Trending'))
BEGIN
	CREATE TABLE [Trending].[Servers](
		[ID] [int] IDENTITY(1,1) NOT NULL,
		[YearMonth] [int] NOT NULL,
		[OperatingSystemID] [int] NOT NULL,
		[ServerCount] [int] NOT NULL,
	 CONSTRAINT [PK_Servers_1] PRIMARY KEY CLUSTERED 
	(
		[ID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
	) ON [PRIMARY]
END


