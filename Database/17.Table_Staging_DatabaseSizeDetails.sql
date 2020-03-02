USE [SQLOpsDB]
GO

/****** Object:  Table [Staging].[DatabaseSizeDetails]    Script Date: 2/27/2020 12:49:33 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

DROP TABLE [Staging].[DatabaseSizeDetails]
GO

CREATE TABLE [Staging].[DatabaseSizeDetails](
	[SQLInstanceID] [int] NULL,
	[AGGuid] [uniqueidentifier] NULL,
	[DatabaseName] [varchar](255) NULL,
	[DatabaseState] [varchar](60) NULL,
	[FileType] [char](4) NULL,
	[FileSize_mb] [bigint] NULL
) ON [PRIMARY]
GO


