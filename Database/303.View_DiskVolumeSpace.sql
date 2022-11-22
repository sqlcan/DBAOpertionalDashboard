USE [SQLOpsDB]
GO

CREATE OR ALTER VIEW dbo.vDiskVolumeSpace
AS
WITH DiskVolumes AS
(  SELECT CASE WHEN DV.ServerID IS NULL THEN SC.SQLClusterName ELSE S.ServerName END AS ComputerName,
			DV.ServerID,
			DV.SQLClusterID,
			s.IsPhysical,
			DV.DiskVolumeName, 
			DV.DiskVolumeID, 
			DVS.DateCaptured,
			dv.IsMonitored
		FROM dbo.DiskVolumeSpace DVS
		JOIN dbo.DiskVolumes DV
  		ON DVS.DiskVolumeID = DV.DiskVolumeID
LEFT JOIN dbo.Servers S
		ON DV.ServerID = S.ServerID
		AND DV.SQLClusterID IS NULL
LEFT JOIN dbo.SQLClusters SC
		ON DV.SQLClusterID = SC.SQLClusterID
		AND DV.ServerID IS NULL),
DiskVolumeAgg AS 
( SELECT ComputerName,
			ServerID,
			SQLClusterID,
			IsPhysical,
			DiskVolumeName,
			DiskVolumeID, 
			MIN(DateCaptured) AS FirstDate, 
			MAX(DateCaptured) AS LastDate, 
			COUNT(*) AS NumberOfDaysHistory,
			IsMonitored
	FROM DiskVolumes
GROUP BY ComputerName,ServerID,SQLClusterID,
			IsPhysical,
			DiskVolumeName,
			DiskVolumeID,IsMonitored), 
DiskVolumeGrowthAgg AS (
	SELECT CTE.ComputerName, ServerID, SQLClusterID, DV_FD.DiskVolumeID, CTE.IsPhysical, CTE.IsMonitored,DiskVolumeName, (DV_LD.SpaceUsed_mb - DV_FD.SpaceUsed_mb + 1.0) / (DATEDIFF(DAY,CTE.FirstDate,CTE.LastDate)+1) AS AvgChange, DV_LD.SpaceUsed_mb, DV_LD.TotalSpace_mb, NumberOfDaysHistory
		FROM dbo.DiskVolumeSpace DV_FD
		JOIN DiskVolumeAgg AS CTE 
		ON DV_FD.DiskVolumeID = CTE.DiskVolumeID
		AND DV_FD.DateCaptured = CTE.FirstDate
		JOIN dbo.DiskVolumeSpace DV_LD
		ON DV_LD.DiskVolumeID = CTE.DiskVolumeID
		AND DV_LD.DateCaptured = CTE.LastDate)
SELECT ComputerName, ServerID, SQLClusterID, DiskVolumeID, IsPhysical,
		DiskVolumeName ,
		TotalSpace_mb/1024. as TotalSpace_gb,
		SpaceUsed_mb/1024. as SpaceUsed_gb,
		(TotalSpace_mb - SpaceUsed_mb)/1024. AS FreeSpace_gb,
		format((SpaceUsed_mb+1.0)/(TotalSpace_mb+1.0),'P') AS SpaceUsed_Percent,
		AvgChange as Daily_AvgChange_mb,
		NumberOfDaysHistory as DaysHistory,
		(AvgChange * 90)/1024. AS Est_90Days_gb,
		(AvgChange * 180)/1024. AS Est_180Days_gb,
		CASE WHEN AvgChange <= 0 THEN
			99999
		ELSE
			(TotalSpace_mb - SpaceUsed_mb)/AvgChange END AS DaysUntil_OutOfSpace
	FROM DiskVolumeGrowthAgg
	WHERE IsMonitored=1
GO