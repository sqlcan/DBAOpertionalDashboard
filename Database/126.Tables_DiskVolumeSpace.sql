--     Purpose: Volume space history.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: No changes since release.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Oct. 3, 2020

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'DiskVolumeSpace')
BEGIN
	CREATE TABLE [dbo].[DiskVolumeSpace](
		[SpaceHistoryID] [bigint] IDENTITY(1,1) NOT NULL,
		[DiskVolumeID] [int] NOT NULL,
		[DateCaptured] [date] NOT NULL,
		[SpaceUsed_mb] [bigint] NOT NULL,
		[TotalSpace_mb] [bigint] NOT NULL,
	 CONSTRAINT [PK_DiskVolumeSpaceHistory] PRIMARY KEY CLUSTERED 
	(
		[SpaceHistoryID] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
	) ON [PRIMARY]

	ALTER TABLE [dbo].[DiskVolumeSpace] ADD  CONSTRAINT [DF_DiskVolumeSpaceHistory_DateCaptured]  DEFAULT (getdate()) FOR [DateCaptured]

	ALTER TABLE [dbo].[DiskVolumeSpace] ADD  CONSTRAINT [DF_DiskVolumeSpaceHistory_SpaceUsed]  DEFAULT ((0)) FOR [SpaceUsed_mb]

	ALTER TABLE [dbo].[DiskVolumeSpace] ADD  CONSTRAINT [DF_DiskVolumeSpaceHistory_TotalSpace]  DEFAULT ((0)) FOR [TotalSpace_mb]
END
GO