CREATE OR ALTER PROC Snapshot.CreateDashboardSnapshot
AS
BEGIN

	IF (SELECT OBJECT_ID('Snapshot.SQLServices')) IS NOT NULL
		DROP TABLE Snapshot.SQLServices;

	IF (SELECT OBJECT_ID('Snapshot.Top15OffendingDisk')) IS NOT NULL
		DROP TABLE Snapshot.Top15OffendingDisk;

	IF (SELECT OBJECT_ID('Snapshot.SQLJobOverview')) IS NOT NULL
		DROP TABLE Snapshot.SQLJobOverview;

	IF (SELECT OBJECT_ID('Snapshot.SQLErrors')) IS NOT NULL
		DROP TABLE Snapshot.SQLErrors;

	IF (SELECT OBJECT_ID('Snapshot.PolicyOverview')) IS NOT NULL
		DROP TABLE Snapshot.PolicyOverview;

	IF (SELECT OBJECT_ID('Snapshot.DiskVolumes')) IS NOT NULL
		DROP TABLE Snapshot.DiskVolumes;	

	IF (SELECT OBJECT_ID('Snapshot.Databases')) IS NOT NULL
		DROP TABLE Snapshot.Databases;	

	SELECT DatabaseState, COUNT(*) AS RwCount
	  INTO Snapshot.Databases
	  FROM dbo.Databases DB
	 WHERE LastUpdated >= DATEADD(DAY,-1,GETDATE())
	   AND NOT EXISTS (SELECT *
						 FROM dbo.Databases_Exclusions DE
						WHERE DB.DatabaseID = DE.DatabaseID
						  AND DB.SQLInstanceID = DE.SQLInstanceID
						  AND DB.DatabaseName = DE.DatabaseName)
	GROUP BY DatabaseState;

	WITH CTE AS (SELECT ServiceType, ISNULL(Status,'Unknown') AS Status, Count(*) AS OverAllCount
	  FROM dbo.SQLService SC
	 WHERE StartMode = 'Auto' and  LastUpdated >= DATEADD(DAY,-1,GETDATE())
	 GROUP BY ServiceType, Status)
	 SELECT ServiceType, Status, SUM(OverAllCount) As SvcCount
	   INTO Snapshot.SQLServices
	   FROM CTE
	GROUP BY ServiceType, Status 
	ORDER BY ServiceType;

	WITH CTE
	AS (SELECT DiskVolumeID,
			   SpaceUsed_mb AS LastSpaceUsed_mb,
			   TotalSpace_mb AS LastTotalSpace_mb
		  FROM dbo.DiskVolumeSpace DVS1
		 WHERE SpaceHistoryID = (SELECT MAX(SpaceHistoryID) FROM dbo.DiskVolumeSpace DVS2 WHERE DVS1.DiskVolumeID = DVS2.DiskVolumeID))

	   SELECT TOP 15 CASE WHEN S.ServerName IS NULL THEN SC.SQLClusterName ELSE S.ServerName END AS ServerVCOName,
			  DV.DiskVolumeID, 
			  DV.DiskVolumeName,
			  DVSA.SpaceUsed_mb AS AvgSpaceUsed_mb,
			  DVSA.TotalSpace_mb AS AvgTotalSpace_mb,
			  LastSpaceUsed_mb,
			  LastTotalSpace_mb,
			  (LastTotalSpace_mb-LastSpaceUsed_mb) As FreeSpace_mb,
			  (LastSpaceUsed_mb + 1.0)/(LastTotalSpace_mb + 1.0) AS SpaceUsedInPercent,
			  AvgGrowthInPercent,
			  CASE WHEN AvgGrowthInPercent > 0 AND LOG(1+AvgGrowthInPercent) > 0.0 THEN
				  LOG((LastTotalSpace_mb + 1.0)/(LastSpaceUsed_mb + 1.0)) / LOG(1+AvgGrowthInPercent)
			  ELSE
   				  9999999
			  END AS DaysUntilOutOfSpace
		 INTO Snapshot.Top15OffendingDisk
		 FROM dbo.DiskVolumes DV
		 JOIN dbo.vwDiskVolumeSpaceAverage DVSA
		   ON DV.DiskVolumeID = DVSA.DiskVolumeID
		 JOIN CTE DVSL
		   ON DV.DiskVolumeID = DVSL.DiskVolumeID
	LEFT JOIN dbo.Servers S
		   ON DV.ServerID = S.ServerID
		  AND DV.SQLClusterID IS NULL
	LEFT JOIN dbo.SQLClusters SC
		   ON DV.SQLClusterID = SC.SQLClusterID
		  AND DV.ServerID IS NULL
		WHERE DV.IsMonitored = 1
	 ORDER BY DaysUntilOutOfSpace, ServerVCOName, DiskVolumeName;

	WITH CTE AS (
	  SELECT SQLJobID, Max(ExecutionDateTime) AS LastExecution
		FROM dbo.SQLJobHistory
	GROUP BY SQLJobID),
	CTE2 AS (
	SELECT JH.SQLJObID, JobStatus 
	  FROM dbo.SQLJobHistory JH
	  JOIN CTE
		ON JH.SQLJobID = CTE.SQLJobID
	   AND JH.ExecutionDateTime = CTE.LastExecution
	   inner join dbo.SQLJobs J on j.SQLJobID=jh.SQLJobID
	WHERE JH.ExecutionDateTime >= DATEADD(Day,-1,GETDATE())
		  and j.SQLJobCategoryID <> 10
	)
	SELECT JobStatus, COUNT(*) AS TotalCount
	  INTO Snapshot.SQLJobOverview
	  FROM CTE2
	GROUP BY JobStatus;

	WITH CTE AS (
	  SELECT SQLInstanceID, count(*) TotalErrors
		FROM dbo.SQLErrorLog
	   WHERE DateTime >= dateadd(day,-1,cast(GetDate() as date))
	GROUP BY SQLInstanceID), CTE2 AS (
	   SELECT SI.SQLInstanceEnviornment,
			  CASE WHEN CTE.TotalErrors IS NULL THEN
				  'No Errors'
			  ELSE
				  'Errors'
			  END AS ErrorStatus,
			  ISNULL(TotalErrors,0) AS TotalErrors
		 FROM dbo.SQLInstances SI
	LEFT JOIN CTE 
		   ON SI.SQLInstanceID = CTE.SQLInstanceID)
	SELECT SQLInstanceEnviornment, ErrorStatus, COUNT(*) AS InstanceCount, SUM(TotalErrors) AS TotalErrors
	  INTO Snapshot.SQLErrors
	  FROM CTE2
	GROUP BY SQLInstanceEnviornment, ErrorStatus;
	SELECT   REPLACE(REPLACE(PHS.CategoryName,'AHS Best Practices: ',''),'Microsoft Best Practices: ','') AS CategoryName
		   , PHS.PolicyResult
		   , COUNT(*) AS ObjCount
	  INTO Snapshot.PolicyOverview
	  FROM Policy.PolicyHistorySummary PHS
	  JOIN Policy.PolicyShortName PSN
		ON PHS.policy_id = PSN.policy_id
	 WHERE NOT EXISTS (SELECT *
						 FROM Policy.PolicyExclusions PE
						WHERE PHS.EvaluatedServer LIKE PE.EvaluatedServer
						  AND PHS.ObjectName LIKE PE.ObjectName
						  AND PHS.policy_id = PE.Policy_ID)
	GROUP BY PHS.CategoryName, PHS.PolicyResult
	ORDER BY 1,2,3;

	WITH DBSizeData AS (
	SELECT SI.SQLInstanceID, DS.DateCaptured, SUM(DS.FileSize_MB/1.0) AS TotalDBSize_mb
	  FROM dbo.vSQLInstances SI
	  JOIN dbo.Databases D
		ON SI.SQLInstanceID = D.SQLInstanceID
	  JOIN dbo.DatabaseSize DS
		ON D.DatabaseID = DS.DatabaseID
	   AND DS.DateCaptured >= CAST(DATEADD(Day,-1,GETDATE()) AS DATE)
	GROUP BY SI.SQLInstanceID, DS.DateCaptured),
	SQLInstanceVolumeChange AS (
	SELECT D1.SQLInstanceID, ABS((D2.TotalDBSize_mb - D1.TotalDBSize_mb)/1024.) AS ChangeDoD_GB
	  FROM DBSizeData D1
	  JOIN DBSizeData D2
		ON D1.SQLInstanceID = D2.SQLInstanceID
	   AND D2.DateCaptured = CAST(GETDATE() AS DATE)
	 WHERE D1.DateCaptured = CAST(DATEADD(Day,-1,GETDATE()) AS DATE)),
	ChangeGrouping AS (
	SELECT CASE WHEN ChangeDoD_GB > 50 THEN '50GB+ Change'
				WHEN ChangeDoD_GB > 25 AND ChangeDoD_GB <=50 THEN '25GB to 50GB Change'
				WHEN ChangeDoD_GB > 15 AND ChangeDoD_GB <=25 THEN '15GB to 25GB Change'
				WHEN ChangeDoD_GB > 10 AND ChangeDoD_GB <=15 THEN '10GB to 15GB Change'
				WHEN ChangeDoD_GB > 5 AND ChangeDoD_GB <=10 THEN '5GB to 10GB Change'
				ELSE 'Less Than 5GB Change' END AS VolumeOfChangeCategory,
		   CASE WHEN ChangeDoD_GB > 50 THEN 6
				WHEN ChangeDoD_GB > 25 AND ChangeDoD_GB <=50 THEN 5
				WHEN ChangeDoD_GB > 15 AND ChangeDoD_GB <=25 THEN 4
				WHEN ChangeDoD_GB > 10 AND ChangeDoD_GB <=15 THEN 3
				WHEN ChangeDoD_GB > 5 AND ChangeDoD_GB <=10 THEN 2
				ELSE 1 END AS SortKey,
				*FROM SQLInstanceVolumeChange
	WHERE ChangeDoD_GB > 0)
	SELECT VolumeOfChangeCategory, SortKey, COUNT(*) AS TotalInstances
	  INTO Snapshot.DiskVolumes
	  FROM ChangeGrouping
	GROUP BY VolumeOfChangeCategory, SortKey
	ORDER BY SortKey DESC

END
GO