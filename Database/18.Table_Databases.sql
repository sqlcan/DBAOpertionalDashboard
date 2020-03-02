USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Databases](
	[DatabaseID] [int] IDENTITY(1,1) NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[DatabaseName] [varchar](255) NOT NULL,
	[DatabaseState] [varchar](60) NOT NULL,
	[IsMonitored] [bit] NOT NULL,
	[DiscoveryOn] [date] NOT NULL,
	[LastUpdated] [date] NOT NULL,
 CONSTRAINT [PK_Databases] PRIMARY KEY CLUSTERED 
(
	[DatabaseID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[Databases] ADD  CONSTRAINT [DF_Databases_DatabaseState]  DEFAULT ('Online') FOR [DatabaseState]
GO

ALTER TABLE [dbo].[Databases] ADD  CONSTRAINT [DF_Databases_IsMonitored]  DEFAULT ((1)) FOR [IsMonitored]
GO

ALTER TABLE [dbo].[Databases] ADD  CONSTRAINT [DF_Databases_DiscoveryOn]  DEFAULT (getdate()) FOR [DiscoveryOn]
GO

ALTER TABLE [dbo].[Databases] ADD  CONSTRAINT [DF_Databases_LastUpdated]  DEFAULT (getdate()) FOR [LastUpdated]
GO

ALTER TABLE [dbo].[Databases]  WITH CHECK ADD  CONSTRAINT [FK_Databases_SQLInstances] FOREIGN KEY([SQLInstanceID])
REFERENCES [dbo].[SQLInstances] ([SQLInstanceID])
GO

ALTER TABLE [dbo].[Databases] CHECK CONSTRAINT [FK_Databases_SQLInstances]
GO


