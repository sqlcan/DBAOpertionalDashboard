USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[SQLJobs](
	[JobID] [int] IDENTITY(1,1) NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[SQLJobCategoryID] [int] NOT NULL,
	[JobName] [varchar](max) NOT NULL,
	[LastUpdated] [date] NOT NULL,
	[DiscoveredOn] [date] NOT NULL,
 CONSTRAINT [PK_SQLJobs] PRIMARY KEY CLUSTERED 
(
	[JobID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

ALTER TABLE [dbo].[SQLJobs]  WITH CHECK ADD  CONSTRAINT [FK_SQLJobs_SQLInstances] FOREIGN KEY([SQLInstanceID])
REFERENCES [dbo].[SQLInstances] ([SQLInstanceID])
GO

ALTER TABLE [dbo].[SQLJobs]  WITH CHECK ADD  CONSTRAINT [FK_SQLJobs_SQLJobsCategories] FOREIGN KEY([SQLJobCategoryID])
REFERENCES [dbo].[SQLJobCategory] ([SQLJobCategoryID])
GO

ALTER TABLE [dbo].[SQLJobs] CHECK CONSTRAINT [FK_SQLJobs_SQLInstances]
GO

ALTER TABLE [dbo].[SQLJobs] CHECK CONSTRAINT [FK_SQLJobs_SQLJobsCategories]
GO

