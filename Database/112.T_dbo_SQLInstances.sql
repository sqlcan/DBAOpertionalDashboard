--     Purpose: This table stores details for each instance.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: No changes since initial release.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 26, 2021


USE [SQLOpsDB]


SET ANSI_NULLS ON


SET QUOTED_IDENTIFIER ON


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
	[ErrorLog_LastDateTimeCaptured] DATETIME DEFAULT('1900-01-01 00:00:00'),
	[JobStats_LastDateTimeCaptured] DATETIME DEFAULT('1900-01-01 00:00:00'),
	[DiscoveryOn] [date] NOT NULL,
	[LastUpdated] [date] NOT NULL,
 CONSTRAINT [PK_SQLInstances] PRIMARY KEY CLUSTERED 
(
	[SQLInstanceID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

ALTER TABLE [dbo].[SQLInstances] ADD  CONSTRAINT [DF_SQLInstances_SQLInstanceName]  DEFAULT ('MSSQLServer') FOR [SQLInstanceName]

ALTER TABLE [dbo].[SQLInstances] ADD  CONSTRAINT [DF_SQLInstances_SQLInstanceVersion]  DEFAULT ((1)) FOR [SQLInstanceVersionID]

ALTER TABLE [dbo].[SQLInstances] ADD  CONSTRAINT [DF_SQLInstances_SQLServerBuild]  DEFAULT ((0)) FOR [SQLInstanceBuild]

ALTER TABLE [dbo].[SQLInstances] ADD  CONSTRAINT [DF_SQLInstances_SQLInstanceEdition]  DEFAULT ('Unknown') FOR [SQLInstanceEdition]

ALTER TABLE [dbo].[SQLInstances] ADD  CONSTRAINT [DF_SQLInstances_SQLInstanceType]  DEFAULT ('Unknown') FOR [SQLInstanceType]

ALTER TABLE [dbo].[SQLInstances] ADD  CONSTRAINT [DF_SQLInstances_SQLInstanceEnviornments]  DEFAULT ('Unknown') FOR [SQLInstanceEnviornment]

ALTER TABLE [dbo].[SQLInstances] ADD  CONSTRAINT [DF_SQLInstances_IsMonitored]  DEFAULT ((1)) FOR [IsMonitored]

ALTER TABLE [dbo].[SQLInstances] ADD  CONSTRAINT [DF_SQLInstances_DiscoveryOn]  DEFAULT (getdate()) FOR [DiscoveryOn]

ALTER TABLE [dbo].[SQLInstances] ADD  CONSTRAINT [DF_SQLInstances_LastUpdated]  DEFAULT (getdate()) FOR [LastUpdated]

ALTER TABLE [dbo].[SQLInstances]  WITH CHECK ADD  CONSTRAINT [FK_SQLInstances_SQLVersions] FOREIGN KEY([SQLInstanceVersionID])
REFERENCES [dbo].[SQLVersions] ([SQLVersionID])

ALTER TABLE [dbo].[SQLInstances] CHECK CONSTRAINT [FK_SQLInstances_SQLVersions]