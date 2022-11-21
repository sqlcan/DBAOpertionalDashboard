USE [SQLOpsDB]
GO

CREATE PROC [Expired].[ReportExpiredObjects]
@ObjectType VARCHAR(50),
@SortKey INT
AS
BEGIN
    CREATE TABLE #OldObjects
       (ObjectType VARCHAR(50),
        DaysOld INT,
        Location VARCHAR(255),
        ObjectName VARCHAR(255),
        LastUpdated DATE);

     WITH CTE AS (
           SELECT 'Databases' AS ObjectType,
                  DATEDIFF(DAY,D.LastUpdated,GETDATE()) AS DaysOld,
                  SI.SQLInstanceName,
                  CASE WHEN S.ServerID IS NULL THEN
                     SC.SQLClusterName
                  ELSE
                     S.ServerName
                  END AS ServerVCOName,
                  DatabaseName,
                  D.LastUpdated
             FROM dbo.Databases D
             JOIN dbo.SQLInstances SI
               ON D.SQLInstanceID = SI.SQLInstanceID
        LEFT JOIN dbo.Servers S
               ON SI.ServerID = S.ServerID
              AND SI.SQLClusterID IS NULL
        LEFT JOIN dbo.SQLClusters SC
               ON SI.SQLClusterID = SC.SQLClusterID
              AND SI.ServerID IS NULL
            WHERE D.LastUpdated <= DATEADD(DAY,-30,GetDate())
              AND D.IsMonitored = 1)
    INSERT INTO #OldObjects
    SELECT ObjectType,
           DaysOld,
           ServerVCOName + '\' + SQLInstanceName AS Location,
           DatabaseName AS ObjectName,
           LastUpdated
      FROM CTE;

     WITH CTE AS (
           SELECT 'Availability Groups' AS ObjectType,
                  DATEDIFF(DAY,AG.LastUpdated,GETDATE()) AS DaysOld,
                  SI.SQLInstanceName,
                  CASE WHEN S.ServerID IS NULL THEN
                     SC.SQLClusterName
                  ELSE
                     S.ServerName
                  END AS ServerVCOName,
                  AGName,
                  AG.LastUpdated
             FROM dbo.AGs AG
             JOIN dbo.AGInstances AGI
               ON AG.AGID = AGI.AGID
             JOIN dbo.SQLInstances SI
               ON AGI.SQLInstanceID = SI.SQLInstanceID
        LEFT JOIN dbo.Servers S
               ON SI.ServerID = S.ServerID
              AND SI.SQLClusterID IS NULL
        LEFT JOIN dbo.SQLClusters SC
               ON SI.SQLClusterID = SC.SQLClusterID
              AND SI.ServerID IS NULL
            WHERE AG.LastUpdated <= DATEADD(DAY,-30,GetDate()))
    INSERT INTO #OldObjects
    SELECT ObjectType,
           DaysOld,
           ServerVCOName + '\' + SQLInstanceName AS Location,
           AGName AS ObjectName,
           LastUpdated
      FROM CTE;


    WITH CTE AS (
           SELECT 'Disk Volumes' AS ObjectType,
                  DATEDIFF(DAY,DV.LastUpdated,GETDATE()) AS DaysOld,
                  CASE WHEN S.ServerID IS NULL THEN
                     SC.SQLClusterName
                  ELSE
                     S.ServerName
                  END AS ServerVCOName,
                  DV.DiskVolumeName,
                  DV.LastUpdated
             FROM dbo.DiskVolumes DV
        LEFT JOIN dbo.Servers S
               ON DV.ServerID = S.ServerID
              AND DV.SQLClusterID IS NULL
        LEFT JOIN dbo.SQLClusters SC
               ON DV.SQLClusterID = SC.SQLClusterID
              AND DV.ServerID IS NULL
            WHERE DV.LastUpdated <= DATEADD(DAY,-30,GetDate())
              AND DV.IsMonitored = 1)
    INSERT INTO #OldObjects
    SELECT ObjectType,
           DaysOld,
           ServerVCOName AS Location,
           DiskVolumeName AS ObjectName,
           LastUpdated
      FROM CTE;

    INSERT INTO #OldObjects
      SELECT 'SQL Clusters' AS ObjectType,
             DATEDIFF(DAY,SC.LastUpdated,GETDATE()) AS DaysOld,
             SC.SQLClusterName AS Location,
             SC.SQLClusterName AS ObjectName,
             SC.LastUpdated
        FROM dbo.SQLClusters SC
       WHERE SC.LastUpdated <= DATEADD(DAY,-30,GetDate())
         AND SC.IsMonitored = 1;

    WITH CTE AS (
           SELECT 'SQL Instances' AS ObjectType,
                  DATEDIFF(DAY,SI.LastUpdated,GETDATE()) AS DaysOld,
                  CASE WHEN S.ServerID IS NULL THEN
                     SC.SQLClusterName
                  ELSE
                     S.ServerName
                  END AS ServerVCOName,
                  SI.SQLInstanceName,
                  SI.LastUpdated
             FROM dbo.SQLInstances SI
        LEFT JOIN dbo.Servers S
               ON SI.ServerID = S.ServerID
              AND SI.SQLClusterID IS NULL
        LEFT JOIN dbo.SQLClusters SC
               ON SI.SQLClusterID = SC.SQLClusterID
              AND SI.ServerID IS NULL
            WHERE SI.LastUpdated <= DATEADD(DAY,-30,GetDate())
              AND SI.IsMonitored = 1)
    INSERT INTO #OldObjects
    SELECT ObjectType,
           DaysOld,
           ServerVCOName AS Location,
           SQLInstanceName AS ObjectName,
           LastUpdated
      FROM CTE;

    INSERT INTO #OldObjects
      SELECT 'Servers' AS ObjectType,
             DATEDIFF(DAY,S.LastUpdated,GETDATE()) AS DaysOld,
             S.ServerName AS Location,
             S.ServerName AS ObjectName,
             S.LastUpdated
        FROM dbo.Servers S
       WHERE S.LastUpdated <= DATEADD(DAY,-30,GetDate())
         AND S.IsMonitored = 1;


    SELECT CASE WHEN DaysOld <= 30 THEN 
              4
           WHEN DaysOld > 30 AND DaysOld <= 59 THEN
              3
           WHEN DaysOld >= 60 AND DaysOld <= 89 THEN
              2
           ELSE
              1
           END AS ReportSortKey,
           DaysOld, ObjectType, Location, ObjectName, LastUpdated
      FROM #OldObjects
     WHERE ((ObjectType = @ObjectType) OR (@ObjectType = '<ALL>'))
       AND ((@SortKey = -1) OR
            ((@SortKey = 1) AND (DaysOld >= 90)) OR
            ((@SortKey = 2) AND (DaysOld >= 60) AND (DaysOld < 90)) OR
            ((@SortKey = 3) AND (DaysOld >= 30) AND (DaysOld < 60)) OR
            ((@SortKey = 4) AND (DaysOld >= 1) AND (DaysOld < 30)))
    ORDER BY ReportSortKey, DaysOld DESC, ObjectType, Location, ObjectName

    DROP TABLE #OldObjects
END
GO