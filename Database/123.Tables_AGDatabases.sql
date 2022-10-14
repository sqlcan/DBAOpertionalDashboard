--     Purpose: Databases belonging to AG.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: Added last updated / discovery date for clean up.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.01
-- Last Tested: Oct. 13, 2022

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'AGDatabases')
BEGIN
	CREATE TABLE [dbo].[AGDatabases](
		[AGDatabaseID] [int] IDENTITY(1,1) NOT NULL,
		[AGInstanceID] [int] NOT NULL,
		[DatabaseID] [int] NOT NULL,
		[DiscoveryOn] [date] NOT NULL,
		[LastUpdated] [date] NOT NULL,
	 CONSTRAINT [PK_AGDatabases] PRIMARY KEY CLUSTERED 
	(
		[AGDatabaseID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
	) ON [PRIMARY]

	ALTER TABLE [dbo].[AGDatabases]  WITH CHECK ADD  CONSTRAINT [FK_AGDatabases_AGInstanceID] FOREIGN KEY([AGInstanceID])
	REFERENCES [dbo].[AGInstances] ([AGInstanceID])

	ALTER TABLE [dbo].[AGDatabases] CHECK CONSTRAINT [FK_AGDatabases_AGInstanceID]

	ALTER TABLE [dbo].[AGDatabases]  WITH CHECK ADD  CONSTRAINT [FK_AGDatabases_DatabaseID] FOREIGN KEY([DatabaseID])
	REFERENCES [dbo].[Databases] ([DatabaseID])

	ALTER TABLE [dbo].[AGDatabases] CHECK CONSTRAINT [FK_AGDatabases_DatabaseID]

	ALTER TABLE [dbo].[AGDatabases] ADD  CONSTRAINT [DF_AGDatabases_DiscoveryOn]  DEFAULT (getdate()) FOR [DiscoveryOn]
	ALTER TABLE [dbo].[AGDatabases] ADD  CONSTRAINT [DF_AGDatabases_LastUpdated]  DEFAULT (getdate()) FOR [LastUpdated]
END

