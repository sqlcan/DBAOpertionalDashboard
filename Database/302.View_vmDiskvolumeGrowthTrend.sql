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


CREATE OR ALTER VIEW [dbo].[vwDiskVolumeGrowthTrend]
AS
   WITH CTE
   AS (SELECT DiskVolumeID,
              DateCaptured,
			  SpaceUsed_mb,
			  ROW_NUMBER() OVER (ORDER BY DiskVolumeID ASC, DateCaptured ASC) AS RowNum
         FROM dbo.DiskVolumeSpace),
   CTE2
   AS (SELECT DBS1.DiskVolumeID,
              DBS1.DateCaptured,
              CAST(ROUND((1-(((DBS2.SpaceUsed_mb+1.0)*1.0)/(DBS1.SpaceUsed_mb+1.0))),4) AS decimal(9,4)) AS DataFile_GrowthInPercent
         FROM CTE DBS1 
         JOIN CTE DBS2
           ON DBS1.RowNum = DBS2.RowNum+1
          AND DBS1.DiskVolumeID = DBS2.DiskVolumeID)
   SELECT DiskVolumeID,
          DateCaptured,
		  DataFile_GrowthInPercent
     FROM CTE2

GO


