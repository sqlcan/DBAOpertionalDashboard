--     Purpose: Aggregated history of the databsae size information by month and year.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: ShortName was added in Oct. 3, 2020.  Therefore, if your database is older, recommend dropping the
--       table manually.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Oct. 3, 2020

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DatabaseSize' and schema_id = SCHEMA_ID('History'))
BEGIN
	CREATE TABLE [History].[DatabaseSize](
		[DatabaseSizeID] [bigint] IDENTITY(1,1) NOT NULL,
		[DatabaseID] [int] NOT NULL,
		[FileType] [char](4) NOT NULL,
		[YearMonth] [char](6) NOT NULL,
		[FileSize_mb] [bigint] NOT NULL,
	 CONSTRAINT [PK_DatabaseSize] PRIMARY KEY CLUSTERED 
	(
		[DatabaseSizeID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
	) ON [PRIMARY]

	ALTER TABLE [History].[DatabaseSize]  WITH CHECK ADD  CONSTRAINT [FK_DatabaseSize_Databases] FOREIGN KEY([DatabaseID])
	REFERENCES [dbo].[Databases] ([DatabaseID])

	ALTER TABLE [History].[DatabaseSize] CHECK CONSTRAINT [FK_DatabaseSize_Databases]
END