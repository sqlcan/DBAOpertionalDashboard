--     Purpose: Stores disk volume space history aggregated by month and year.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: no change since release.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [History].[DiskVolumeSpace](
	[SpaceHistoryID] [bigint] IDENTITY(1,1) NOT NULL,
	[DiskVolumeID] [int] NOT NULL,
	[YearMonth] [char](6) NOT NULL,
	[SpaceUsed_mb] [bigint] NOT NULL,
	[TotalSpace_mb] [bigint] NOT NULL,
 CONSTRAINT [PK_DiskVolumeSpaceHistory_Monthly] PRIMARY KEY CLUSTERED 
(
	[SpaceHistoryID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]

ALTER TABLE [History].[DiskVolumeSpace]  WITH CHECK ADD  CONSTRAINT [FK_DiskVolumeSpace_DiskVolumeID] FOREIGN KEY([DiskVolumeID])
REFERENCES [dbo].[DiskVolumes] ([DiskVolumeID])

ALTER TABLE [History].[DiskVolumeSpace] CHECK CONSTRAINT [FK_DiskVolumeSpace_DiskVolumeID]