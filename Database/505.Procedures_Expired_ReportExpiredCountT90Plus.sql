--     Purpose: Get a list of servers to scan using SQLOpsDB Script.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE OR ALTER PROC [Expired].[ReportExpiredCountT90Plus]
AS
BEGIN
    CREATE TABLE #OldObjects
       (ObjectType VARCHAR(50),
        DaysOld INT);

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
            WHERE D.LastUpdated <= DATEADD(DAY,-83,GetDate())
              AND D.IsMonitored = 1)
    INSERT INTO #OldObjects
    SELECT ObjectType,
           DaysOld
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
            WHERE AG.LastUpdated <= DATEADD(DAY,-83,GetDate()))
    INSERT INTO #OldObjects
    SELECT ObjectType,
           DaysOld
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
            WHERE DV.LastUpdated <= DATEADD(DAY,-83,GetDate())
              AND DV.IsMonitored = 1)
    INSERT INTO #OldObjects
    SELECT ObjectType,
           DaysOld
      FROM CTE;

    INSERT INTO #OldObjects
      SELECT 'SQL Clusters' AS ObjectType,
             DATEDIFF(DAY,SC.LastUpdated,GETDATE()) AS DaysOld
        FROM dbo.SQLClusters SC
       WHERE SC.LastUpdated <= DATEADD(DAY,-83,GetDate())
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
            WHERE SI.LastUpdated <= DATEADD(DAY,-83,GetDate())
              AND SI.IsMonitored = 1)
    INSERT INTO #OldObjects
    SELECT ObjectType,
           DaysOld
      FROM CTE;

    INSERT INTO #OldObjects
      SELECT 'Servers' AS ObjectType,
             DATEDIFF(DAY,S.LastUpdated,GETDATE()) AS DaysOld
        FROM dbo.Servers S
       WHERE S.LastUpdated <= DATEADD(DAY,-83,GetDate())
         AND S.IsMonitored = 1;


    SELECT COUNT(*) AS ObjectsToBeDeleted
      FROM #OldObjects

    DROP TABLE #OldObjects
END
GO


