USE [SQLOpsDB]
GO

CREATE OR ALTER PROC [Expired].[ReportExpiredObjectsCount]
AS
BEGIN
    
    CREATE TABLE #ObjectsDetails
       (SortKey INT,
        DaysOld INT,
        ObjectType VARCHAR(50),
        Location VARCHAR(255),
        ObjectName VARCHAR(255),
        LastUpdated DATE);

   INSERT INTO #ObjectsDetails
   EXEC Expired.ReportExpiredObjects '<ALL>', -1;

    CREATE TABLE #EmptyResultset
       (SortKey INT,
        ObjectType VARCHAR(50),
        ObjectCount INT)

        INSERT INTO #EmptyResultset VALUES
          (1, 'Servers',0), (2, 'Servers',0),(3, 'Servers',0), (4, 'Servers',0),
          (1, 'SQL Instances',0), (2, 'SQL Instances',0), (3, 'SQL Instances',0), (4, 'SQL Instances',0),
          (1, 'SQL Clusters',0), (2, 'SQL Clusters',0), (3, 'SQL Clusters',0), (4, 'SQL Clusters',0),
          (1, 'Disk Volumes',0), (2, 'Disk Volumes',0), (3, 'Disk Volumes',0), (4, 'Disk Volumes',0),
          (1, 'Availability Groups',0), (2, 'Availability Groups',0), (3, 'Availability Groups',0), (4, 'Availability Groups',0),
          (1, 'Databases',0), (2, 'Databases',0), (3, 'Databases',0), (4, 'Databases',0)

    ;WITH CTE AS (
   SELECT SortKey, ObjectType, COUNT(*) AS ObjectCount
     FROM #ObjectsDetails
 GROUP BY SortKey, ObjectType)
 SELECT SortKey, ObjectType, ObjectCount
   FROM CTE

   UNION ALL

   SELECT SortKey, ObjectType, ObjectCount
   FROM #EmptyResultset ER
   WHERE NOT EXISTS (SELECT * FROM CTE WHERE CTE.SortKey = ER.SortKey AND CTE.ObjectType = ER.ObjectType)
   ORDER BY ObjectType, SortKey;

    DROP TABLE #ObjectsDetails;
    DROP TABLE #EmptyResultset;
END
GO
