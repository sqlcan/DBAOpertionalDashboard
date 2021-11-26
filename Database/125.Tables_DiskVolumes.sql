--     Purpose: Disk volumes belonging to a server or cluster.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: No changes since release.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DiskVolumes')
BEGIN
	CREATE TABLE [dbo].[DiskVolumes](
		[DiskVolumeID] [int] IDENTITY(1,1) NOT NULL,
		[DiskVolumeName] [varchar](255) NOT NULL,
		[ServerID] [int] NULL,
		[SQLClusterID] [int] NULL,
		[IsMonitored] [bit] NOT NULL,
		[DiscoveryOn] [date] NOT NULL,
		[LastUpdated] [date] NOT NULL,
	 CONSTRAINT [PK_DiskVolumes] PRIMARY KEY CLUSTERED 
	(
		[DiskVolumeID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
	) ON [PRIMARY]

	ALTER TABLE [dbo].[DiskVolumes] ADD  CONSTRAINT [DF_DiskVolumes_DiskVolumeName]  DEFAULT ('Unknown') FOR [DiskVolumeName]

	ALTER TABLE [dbo].[DiskVolumes] ADD  CONSTRAINT [DF_DiskVolumes_IsMonitored]  DEFAULT ((1)) FOR [IsMonitored]

	ALTER TABLE [dbo].[DiskVolumes] ADD  CONSTRAINT [DF_DiskVolumes_DiscoveryOn]  DEFAULT (getdate()) FOR [DiscoveryOn]

	ALTER TABLE [dbo].[DiskVolumes] ADD  CONSTRAINT [DF_DiskVolumes_LastUpdated]  DEFAULT (getdate()) FOR [LastUpdated]
END


