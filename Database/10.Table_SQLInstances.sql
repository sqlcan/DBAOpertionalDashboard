USE [SQLOpsDB]
GO

/****** Object:  Table [dbo].[SQLInstances]    Script Date: 2020-02-06 1:15:21 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[SQLInstances](
	[SQLInstanceID] [int] IDENTITY(1,1) NOT NULL,
	[ServerID] [int] NULL,
	[SQLClusterID] [int] NULL,
	[SQLInstanceName] [varchar](255) NOT NULL,
	[SQLInstanceVersionID] [int] NOT NULL,
	[SQLInstanceBuild] [int] NOT NULL,
	[SQLInstanceEdition] [varchar](50) NOT NULL,
	[SQLInstanceType] [varchar](50) NOT NULL,
	[SQLInstanceEnviornment] [varchar](25) NOT NULL,
	[IsMonitored] [bit] NOT NULL,
	[DiscoveryOn] [date] NOT NULL,
	[LastUpdated] [date] NOT NULL,
 CONSTRAINT [PK_SQLInstances] PRIMARY KEY CLUSTERED 
(
	[SQLInstanceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[SQLInstances] ADD  CONSTRAINT [DF_SQLInstances_SQLInstanceName]  DEFAULT ('MSSQLServer') FOR [SQLInstanceName]
GO

ALTER TABLE [dbo].[SQLInstances] ADD  CONSTRAINT [DF_SQLInstances_SQLInstanceVersion]  DEFAULT ((1)) FOR [SQLInstanceVersionID]
GO

ALTER TABLE [dbo].[SQLInstances] ADD  CONSTRAINT [DF_SQLInstances_SQLServerBuild]  DEFAULT ((0)) FOR [SQLInstanceBuild]
GO

ALTER TABLE [dbo].[SQLInstances] ADD  CONSTRAINT [DF_SQLInstances_SQLInstanceEdition]  DEFAULT ('Unknown') FOR [SQLInstanceEdition]
GO

ALTER TABLE [dbo].[SQLInstances] ADD  CONSTRAINT [DF_SQLInstances_SQLInstanceType]  DEFAULT ('Unknown') FOR [SQLInstanceType]
GO

ALTER TABLE [dbo].[SQLInstances] ADD  CONSTRAINT [DF_SQLInstances_SQLInstanceEnviornments]  DEFAULT ('Unknown') FOR [SQLInstanceEnviornment]
GO

ALTER TABLE [dbo].[SQLInstances] ADD  CONSTRAINT [DF_SQLInstances_IsMonitored]  DEFAULT ((1)) FOR [IsMonitored]
GO

ALTER TABLE [dbo].[SQLInstances] ADD  CONSTRAINT [DF_SQLInstances_DiscoveryOn]  DEFAULT (getdate()) FOR [DiscoveryOn]
GO

ALTER TABLE [dbo].[SQLInstances] ADD  CONSTRAINT [DF_SQLInstances_LastUpdated]  DEFAULT (getdate()) FOR [LastUpdated]
GO

ALTER TABLE [dbo].[SQLInstances]  WITH CHECK ADD  CONSTRAINT [FK_SQLInstances_SQLVersions] FOREIGN KEY([SQLInstanceVersionID])
REFERENCES [dbo].[SQLVersions] ([SQLVersionID])
GO

ALTER TABLE [dbo].[SQLInstances] CHECK CONSTRAINT [FK_SQLInstances_SQLVersions]
GO

CREATE NONCLUSTERED INDEX [idx_SQLInstances_LastUpdated] ON [dbo].[SQLInstances]
(
	[LastUpdated] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [idx_SQLInstances_ServerID] ON [dbo].[SQLInstances]
(
	[ServerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [idx_SQLInstances_SQLClusterID] ON [dbo].[SQLInstances]
(
	[SQLClusterID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO




