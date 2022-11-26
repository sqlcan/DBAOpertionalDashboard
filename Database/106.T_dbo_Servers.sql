USE [SQLOpsDB]
GO

/****** Object:  Table [dbo].[Servers]    Script Date: 10/31/2022 9:48:17 PM ******/
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
	[Memory_mb] [int] NOT NULL,
	[PageFile_mb] [int] NOT NULL,
	[IsPhysical] [bit] NOT NULL,
	[IsMonitored] [bit] NOT NULL,
	[DiscoveryOn] [date] NOT NULL,
	[LastUpdated] [date] NOT NULL,
 CONSTRAINT [PK_Servers] PRIMARY KEY CLUSTERED 
(
	[ServerID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
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

ALTER TABLE [dbo].[Servers] ADD  CONSTRAINT [DF_Servers_Memory_mb]  DEFAULT ((0)) FOR [Memory_mb]
GO

ALTER TABLE [dbo].[Servers] ADD  CONSTRAINT [DF_Servers_PageFile_mb]  DEFAULT ((0)) FOR [PageFile_mb]
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


