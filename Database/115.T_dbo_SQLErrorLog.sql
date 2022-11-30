--     Purpose: Stores all the error logs in SQL Server instance to-date.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: Introduced new column stored index to improve the compression on Nov. 3, 2020.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020


USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[SQLErrorLog](
	[ErrorLogID] [bigint] IDENTITY(1,1) NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[DateTime] [datetime] NOT NULL,
	[ErrorMsg] [varchar](max) NOT NULL,
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

CREATE CLUSTERED COLUMNSTORE INDEX cciSQLErrorLog ON dbo.SQLErrorLog

ALTER TABLE [dbo].[SQLErrorLog]  WITH CHECK ADD  CONSTRAINT [FK_SQLErrorLog_SQLInstances] FOREIGN KEY([SQLInstanceID])
REFERENCES [dbo].[SQLInstances] ([SQLInstanceID])

ALTER TABLE [dbo].[SQLErrorLog] CHECK CONSTRAINT [FK_SQLErrorLog_SQLInstances]