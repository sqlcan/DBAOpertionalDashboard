USE [SQLOpsDB]
GO

/****** Object:  Table [dbo].[SQLErrorLog]    Script Date: 2020-02-06 1:30:05 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[SQLErrorLog](
	[ErrorLogID] [bigint] IDENTITY(1,1) NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[DateTime] [datetime] NOT NULL,
	[ErrorMsg] [varchar](max) NOT NULL,
 CONSTRAINT [PK_SQLErrorLog] PRIMARY KEY CLUSTERED 
(
	[ErrorLogID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [dbo].[SQLErrorLog]  WITH CHECK ADD  CONSTRAINT [FK_SQLErrorLog_SQLInstances] FOREIGN KEY([SQLInstanceID])
REFERENCES [dbo].[SQLInstances] ([SQLInstanceID])
GO

ALTER TABLE [dbo].[SQLErrorLog] CHECK CONSTRAINT [FK_SQLErrorLog_SQLInstances]
GO

CREATE INDEX idx_SQLErrorLog_SQLInstanceID ON [dbo].[SQLErrorLog]([SQLInstanceID])
GO

CREATE INDEX idx_SQLErrorLog_DateTime ON [dbo].[SQLErrorLog]([DateTime])
GO