--     Purpose: This is the first critical table.  It stores each server discoverd.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: No changes in this table in recent release.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Oct. 3, 2020

USE [SQLOpsDB]
GO

/****** Object:  Table [dbo].[Servers]    Script Date: 2020-02-05 10:04:01 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Servers')
BEGIN

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

	ALTER TABLE [dbo].[Servers] ADD  CONSTRAINT [DF_Servers_OpeartingSystemID]  DEFAULT ((1)) FOR [OperatingSystemID]

	ALTER TABLE [dbo].[Servers] ADD  CONSTRAINT [DF_Servers_ProcessorName]  DEFAULT ('Unknown') FOR [ProcessorName]

	ALTER TABLE [dbo].[Servers] ADD  CONSTRAINT [DF_Servers_NumberOfCores]  DEFAULT ((0)) FOR [NumberOfCores]

	ALTER TABLE [dbo].[Servers] ADD  CONSTRAINT [DF_Servers_NumberOfLogicalCores]  DEFAULT ((0)) FOR [NumberOfLogicalCores]

	ALTER TABLE [dbo].[Servers] ADD  CONSTRAINT [DF_Servers_IsPhysical]  DEFAULT ((1)) FOR [IsPhysical]

	ALTER TABLE [dbo].[Servers] ADD  CONSTRAINT [DF_Servers_IsMonitored]  DEFAULT ((1)) FOR [IsMonitored]

	ALTER TABLE [dbo].[Servers] ADD  CONSTRAINT [DF_Servers_DiscoveryDate]  DEFAULT (getdate()) FOR [DiscoveryOn]

	ALTER TABLE [dbo].[Servers] ADD  CONSTRAINT [DF_Servers_LastUpdated]  DEFAULT (getdate()) FOR [LastUpdated]

	ALTER TABLE [dbo].[Servers]  WITH CHECK ADD  CONSTRAINT [FK_Servers_OperatingSystems] FOREIGN KEY([OperatingSystemID])
	REFERENCES [dbo].[OperatingSystems] ([OperatingSystemID])

	ALTER TABLE [dbo].[Servers] CHECK CONSTRAINT [FK_Servers_OperatingSystems]

	CREATE NONCLUSTERED INDEX [idx_Servers_LastUpdated] ON [dbo].[Servers]
	(
		[LastUpdated] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]

	CREATE UNIQUE NONCLUSTERED INDEX [idx_uServers_ServerName] ON [dbo].[Servers]
	(
		[ServerName] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

END