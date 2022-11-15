--     Purpose: Store database details.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: No change since release.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Databases')
BEGIN
	CREATE TABLE [dbo].[Databases](
		[DatabaseID] [int] IDENTITY(1,1) NOT NULL,
		[SQLInstanceID] [int] NOT NULL,
		[DatabaseName] [varchar](255) NOT NULL,
		[DatabaseState] [varchar](60) NOT NULL,
		[ApplicationID] int NOT NULL,
		[IsMonitored] [bit] NOT NULL,
		[DiscoveryOn] [date] NOT NULL,
		[LastUpdated] [date] NOT NULL,
	 CONSTRAINT [PK_Databases] PRIMARY KEY CLUSTERED 
	(
		[DatabaseID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
	) ON [PRIMARY]

	ALTER TABLE [dbo].[Databases] ADD  CONSTRAINT [DF_Databases_DatabaseState]  DEFAULT ('Online') FOR [DatabaseState]

	ALTER TABLE [dbo].[Databases] ADD  CONSTRAINT [DF_Databases_IsMonitored]  DEFAULT ((1)) FOR [IsMonitored]

	ALTER TABLE [dbo].[Databases] ADD  CONSTRAINT [DF_Databases_DiscoveryOn]  DEFAULT (getdate()) FOR [DiscoveryOn]

	ALTER TABLE [dbo].[Databases] ADD  CONSTRAINT [DF_Databases_LastUpdated]  DEFAULT (getdate()) FOR [LastUpdated]

	ALTER TABLE [dbo].[Databases] ADD  CONSTRAINT [DF_Databases_ApplicationID]  DEFAULT (1) FOR [ApplicationID]

	ALTER TABLE [dbo].[Databases]  WITH CHECK ADD  CONSTRAINT [FK_Databases_SQLInstances] FOREIGN KEY([SQLInstanceID])
	REFERENCES [dbo].[SQLInstances] ([SQLInstanceID])

	ALTER TABLE [dbo].[Databases]  WITH CHECK ADD  CONSTRAINT [FK_Databases_Application] FOREIGN KEY([ApplicationID])
	REFERENCES [dbo].[Application] ([ApplicationID])

	ALTER TABLE [dbo].[Databases] CHECK CONSTRAINT [FK_Databases_Application]
	ALTER TABLE [dbo].[Databases] CHECK CONSTRAINT [FK_Databases_SQLInstances]
END