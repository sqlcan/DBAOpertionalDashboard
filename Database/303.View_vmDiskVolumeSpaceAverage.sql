--     Purpose: Disk Volume Space Growth Details.
--
-- NOTE: No change since initial implementation.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER VIEW [dbo].[vwDiskVolumeSpaceAverage]
AS
  SELECT DV.DiskVolumeID, 
         AVG(SpaceUsed_mb) AS SpaceUsed_mb,
	     AVG(TotalSpace_mb) AS TotalSpace_mb,
	     AVG(DataFile_GrowthInPercent) AS AvgGrowthInPercent
    FROM dbo.DiskVolumes DV
    JOIN dbo.DiskVolumeSpace DVS
      ON DV.DiskVolumeID = DVS.DiskVolumeID
    JOIN vwDiskVolumeGrowthTrend DGT 
      ON DVS.DiskVolumeID = DGT.DiskVolumeID
     AND DVS.DateCaptured = DGT.DateCaptured
   WHERE DV.IsMonitored = 1
GROUP BY DV.DiskVolumeID,  DV.DiskVolumeName
GO


