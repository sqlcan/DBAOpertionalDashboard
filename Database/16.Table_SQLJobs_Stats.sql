USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[SQLJobs_Stats](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[LastDateTimeCaptured] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[SQLJobs_Stats] ADD  DEFAULT ('1900-01-01 00:00:00') FOR [LastDateTimeCaptured]
GO


