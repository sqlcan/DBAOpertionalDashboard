USE [SQLOpsDB]
GO

/****** Object:  Table [dbo].[Servers]    Script Date: 2020-02-05 10:04:01 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Servers](
	[ServerID] [int] IDENTITY(1,1) NOT NULL,
	[OperatingSystemID] [int] NOT NULL,
	[ServerName] [varchar](255) NOT NULL,
	[ProcessorName] [varchar](255) NOT NULL,
	[NumberOfCores] [int] NOT NULL,
	[NumberOfLogicalCores] [int] NOT NULL,
	[IsPhysical] [bit] NOT NULL,
	[IsMonitored] [bit] NOT NULL,
	[DiscoveryOn] [date] NOT NULL,
	[LastUpdated] [date] NOT NULL,
 CONSTRAINT [PK_Servers] PRIMARY KEY CLUSTERED 
(
	[ServerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[Servers] ADD  CONSTRAINT [DF_Servers_OpeartingSystemID]  DEFAULT ((1)) FOR [OperatingSystemID]
GO

ALTER TABLE [dbo].[Servers] ADD  CONSTRAINT [DF_Servers_ProcessorName]  DEFAULT ('Unknown') FOR [ProcessorName]
GO

ALTER TABLE [dbo].[Servers] ADD  CONSTRAINT [DF_Servers_NumberOfCores]  DEFAULT ((0)) FOR [NumberOfCores]
GO

ALTER TABLE [dbo].[Servers] ADD  CONSTRAINT [DF_Servers_NumberOfLogicalCores]  DEFAULT ((0)) FOR [NumberOfLogicalCores]
GO

ALTER TABLE [dbo].[Servers] ADD  CONSTRAINT [DF_Servers_IsPhysical]  DEFAULT ((1)) FOR [IsPhysical]
GO

ALTER TABLE [dbo].[Servers] ADD  CONSTRAINT [DF_Servers_IsMonitored]  DEFAULT ((1)) FOR [IsMonitored]
GO

ALTER TABLE [dbo].[Servers] ADD  CONSTRAINT [DF_Servers_DiscoveryDate]  DEFAULT (getdate()) FOR [DiscoveryOn]
GO

ALTER TABLE [dbo].[Servers] ADD  CONSTRAINT [DF_Servers_LastUpdated]  DEFAULT (getdate()) FOR [LastUpdated]
GO

ALTER TABLE [dbo].[Servers]  WITH CHECK ADD  CONSTRAINT [FK_Servers_OperatingSystems] FOREIGN KEY([OperatingSystemID])
REFERENCES [dbo].[OperatingSystems] ([OperatingSystemID])
GO

ALTER TABLE [dbo].[Servers] CHECK CONSTRAINT [FK_Servers_OperatingSystems]
GO

/****** Object:  Index [idx_Servers_LastUpdated]    Script Date: 2020-02-05 10:04:38 AM ******/
CREATE NONCLUSTERED INDEX [idx_Servers_LastUpdated] ON [dbo].[Servers]
(
	[LastUpdated] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO

/****** Object:  Index [UQ_Servers]    Script Date: 2020-02-05 10:04:51 AM ******/
CREATE UNIQUE NONCLUSTERED INDEX [idx_uServers_ServerName] ON [dbo].[Servers]
(
	[ServerName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO



