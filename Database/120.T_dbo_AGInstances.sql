--     Purpose: Stores link between SQL instance and the AG.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: Added ReplicaRole and last updated and discovery on for clean up.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.01
-- Last Tested: Oct. 13, 2022

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[AGInstances](
	[AGInstanceID] [int] IDENTITY(1,1) NOT NULL,
	[AGID] [int] NOT NULL,
	[SQLInstanceID] [int] NOT NULL,
	[ReplicaRole] [varchar](25),
	[DiscoveryOn] [date] NOT NULL,
	[LastUpdated] [date] NOT NULL,
 CONSTRAINT [PK_AGInstances] PRIMARY KEY CLUSTERED 
(
	[AGInstanceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

ALTER TABLE [dbo].[AGInstances]  WITH CHECK ADD  CONSTRAINT [FK_AGInstance_AGID] FOREIGN KEY([AGID])
REFERENCES [dbo].[AGs] ([AGID])

ALTER TABLE [dbo].[AGInstances] CHECK CONSTRAINT [FK_AGInstance_AGID]

ALTER TABLE [dbo].[AGInstances]  WITH CHECK ADD  CONSTRAINT [FK_AGInstance_SQLInstancesID] FOREIGN KEY([SQLInstanceID])
REFERENCES [dbo].[SQLInstances] ([SQLInstanceID])

ALTER TABLE [dbo].[AGInstances] CHECK CONSTRAINT [FK_AGInstance_SQLInstancesID]

ALTER TABLE [dbo].[AGInstances] ADD  CONSTRAINT [DF_AGInstances_DiscoveryOn]  DEFAULT (getdate()) FOR [DiscoveryOn]

ALTER TABLE [dbo].[AGInstances] ADD  CONSTRAINT [DF_AGInstances_LastUpdated]  DEFAULT (getdate()) FOR [LastUpdated]