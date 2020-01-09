DECLARE @LowerBoundDate DATE

SET @LowerBoundDate =  '2016-11-30';

INSERT INTO Trending.Servers (YearMonth,OperatingSystemID,ServerCount)
SELECT CAST(CONVERT(VARCHAR(6),@LowerBoundDate,112) AS INT) AS YYYYMM, OS.OperatingSystemID, COUNT(*) AS ServerCount
    FROM dbo.Servers S
    JOIN dbo.OperatingSystems OS
    ON S.OperatingSystemID = OS.OperatingSystemID
    WHERE S.DiscoveryOn <= @LowerBoundDate
    AND S.LastUpdated >= DATEADD(Day,-30,@LowerBoundDate)
    AND OS.OperatingSystemID <>  1 -- Unknown
GROUP BY OS.OperatingSystemID;

INSERT INTO Trending.SQLInstances(YearMonth,ServerVersionID,Environment,InstanceCount)
SELECT CAST(CONVERT(VARCHAR(6),@LowerBoundDate,112) AS INT) AS YYYYMM, SV.SQLVersionID, SI.SQLInstanceEnviornment, COUNT(*) AS InstanceCount
    FROM dbo.SQLInstances SI
    JOIN dbo.SQLVersions SV
    ON SI.SQLInstanceVersionID = SV.SQLVersionID
    WHERE SI.DiscoveryOn <= @LowerBoundDate
    AND SI.LastUpdated >= DATEADD(Day,-30,@LowerBoundDate)
GROUP BY SV.SQLVersionID, SI.SQLInstanceEnviornment;

WITH AGInstancesByRowNumber AS (
    SELECT AGI.AGID,
        AGI.SQLInstanceID,
        ROW_NUMBER () OVER (PARTITION BY AGI.AGID ORDER BY AGI.SQLInstanceID) AS InstanceNumber
    FROM dbo.AGInstances AGI)
    INSERT INTO Trending.Databases (YearMonth, SQLVersionID, Environment, DatabaseCount, DatabaseTotalSize)
SELECT CAST(CONVERT(VARCHAR(6),@LowerBoundDate,112) AS INT) AS YYYYMM, SV.SQLVersionID, SI.SQLInstanceEnviornment,
            COUNT(*) DBCount,
            SUM(DBSize.TotalSIze) AS TotalSize
        FROM dbo.Databases D
        JOIN dbo.SQLInstances SI
        ON D.SQLInstanceID = SI.SQLInstanceID
        JOIN dbo.SQLVersions SV
        ON SI.SQLInstanceVersionID = SV.SQLVersionID
CROSS APPLY (SELECT TOP 1 SUM(DS.FileSize_mb) AS TotalSIze FROM dbo.DatabaseSize DS WHERE DS.DatabaseID = D.DatabaseID GROUP BY DS.DateCaptured ORDER BY DS.DateCaptured DESC) DBSize
    WHERE (D.DatabaseID NOT IN (SELECT DatabaseID FROM dbo.AGDatabases)
        OR D.SQLInstanceID IN (SELECT SQLInstanceID FROM AGInstancesByRowNumber WHERE InstanceNumber = 1))
        AND D.IsMonitored = 1
        AND D.DiscoveryOn <= @LowerBoundDate
        AND D.LastUpdated >= DATEADD(Day,-30,@LowerBoundDate)
    GROUP BY SV.SQLVersionID, SI.SQLInstanceEnviornment;