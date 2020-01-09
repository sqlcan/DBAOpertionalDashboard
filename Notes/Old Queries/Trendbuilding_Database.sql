--SELECT MIN(DiscoveryOn)
--  FROM dbo.Servers

  --2015-01-22

--DECLARE @DateLowerBound DATE
--DECLARE @DateUpperBound DATE

--SET @DateLowerBound = '2016-10-31'
--SET @DateUpperBound = '2015-01-31'

--SELECT OS.OperatingSystemName, CAST(CONVERT(VARCHAR(6),@DateLowerBound,112) AS INT) AS YYYYMM, COUNT(*) AS ServerCount
--  FROM dbo.Servers S
--  JOIN dbo.OperatingSystems OS
--    ON S.OperatingSystemID = OS.OperatingSystemID
-- WHERE S.DiscoveryOn <= @DateLowerBound
--   AND S.LastUpdated >= DATEADD(Day,-30,@DateLowerBound)
--GROUP BY OS.OperatingSystemName

--WITH Years AS (
--   SELECT 2015 AS YearValue
--   UNION ALL
--   SELECT 2016
--),
--Months AS (
--   SELECT 1 AS MonthValue   UNION ALL   SELECT 2   UNION ALL   SELECT 3   UNION ALL
--   SELECT 4                 UNION ALL   SELECT 5   UNION ALL   SELECT 6   UNION ALL
--   SELECT 7                 UNION ALL   SELECT 8   UNION ALL   SELECT 9   UNION ALL
--   SELECT 10                UNION ALL   SELECT 11  UNION ALL   SELECT 12
--), WorkTable AS (
--SELECT YearValue,
--       MonthValue,
--       CASE WHEN (MonthValue=12) THEN YearValue + 1 ELSE YearValue END AS NextYearValue,
--       CASE WHEN (MonthValue=12) THEN 1 ELSE MonthValue + 1 END AS NextMonthValue
--  FROM Years Y
--  CROSS JOIN Months M),
--DateLowerBounds AS (
--SELECT DATEFROMPARTS(YearValue,MonthValue,DAY(DATEADD(DAY,-1,DATEFROMPARTS(NextYearValue,NextMonthValue,1)))) AS LowerBoundDate
--  FROM WorkTable)
--SELECT * INTO #DateLowerBounds FROM DateLowerBounds  Where LowerBoundDate <= GetDate()

DECLARE @LowerBoundDate DATE

DECLARE curDates CURSOR FORWARD_ONLY STATIC READ_ONLY
FOR SELECT LowerBoundDate FROM #DateLowerBounds

    OPEN curDates

        FETCH NEXT FROM curDates   
        INTO @LowerBoundDate 

        WHILE (@@FETCH_STATUS = 0)
        BEGIN

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
             GROUP BY SV.SQLVersionID, SI.SQLInstanceEnviornment

            FETCH NEXT FROM curDates   
            INTO @LowerBoundDate 
        END

    CLOSE curDates

DEALLOCATE curDates