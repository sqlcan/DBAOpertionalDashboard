--     Purpose: Current database size details.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: No change since release.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

USE [SQLOpsDB]
GO


/****** Object:  Table [dbo].[DatabaseSize]    Script Date: 11/3/2020 10:34:16 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[DatabaseSize](
	[DatabaseSizeID] [bigint] IDENTITY(1,1) NOT NULL,
	[DatabaseID] [int] NOT NULL,
	[FileType] [char](4) NOT NULL,
	[DateCaptured] [date] NOT NULL,
	[FileSize_mb] [bigint] NOT NULL,
 CONSTRAINT [PK_DatabaseSize] PRIMARY KEY CLUSTERED 
(
	[DatabaseSizeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

ALTER TABLE [dbo].[DatabaseSize] ADD  CONSTRAINT [DF_DatabaseSize_DateCaptured]  DEFAULT (getdate()) FOR [DateCaptured]

ALTER TABLE [dbo].[DatabaseSize]  WITH CHECK ADD  CONSTRAINT [FK_DatabaseSize_Databases] FOREIGN KEY([DatabaseID])
REFERENCES [dbo].[Databases] ([DatabaseID])

ALTER TABLE [dbo].[DatabaseSize] CHECK CONSTRAINT [FK_DatabaseSize_Databases]