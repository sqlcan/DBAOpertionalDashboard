USE [SQLOpsDB]
GO

/****** Object:  StoredProcedure [Trending].[SQLInstances_Monthly]    Script Date: 10/30/2022 2:23:07 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROC [Trending].[CreateTrendData]
    @LowerBoundDate DATE
AS
BEGIN

	DECLARE @YearMonth INT
	DECLARE @DateBoundary DATE

	SET @YearMonth = CAST(CONVERT(VARCHAR(6),@LowerBoundDate,112) AS INT)
	SET @DateBoundary = DATEADD(Day,-30,@LowerBoundDate)

	-- Only create the trend for the given LowerBoundDate if there is no trend data available.  This is to protect against
    -- someone accidently executing Trending builds multiple times.
    IF (SELECT COUNT(*) FROM Trending.Servers WHERE YearMonth = @YearMonth) = 0
    BEGIN
        INSERT INTO Trending.Servers (YearMonth,OperatingSystemID,ServerCount)
        SELECT CAST(CONVERT(VARCHAR(6),@LowerBoundDate,112) AS INT) AS YYYYMM, OS.OperatingSystemID, COUNT(*) AS ServerCount
            FROM dbo.Servers S
            JOIN dbo.OperatingSystems OS
            ON S.OperatingSystemID = OS.OperatingSystemID
            WHERE S.DiscoveryOn <= @LowerBoundDate
            AND S.LastUpdated >= @DateBoundary
            AND OS.OperatingSystemID <>  1 -- Unknown
        GROUP BY OS.OperatingSystemID;
    END

    -- Only create the trend for the given LowerBoundDate if there is no trend data available.  This is to protect against
    -- someone accidently executing Trending builds multiple times.
    IF (SELECT COUNT(*) FROM Trending.SQLInstances WHERE YearMonth = @YearMonth) = 0
    BEGIN
        INSERT INTO Trending.SQLInstances(YearMonth,ServerVersionID,Environment,InstanceCount)
        SELECT CAST(CONVERT(VARCHAR(6),@LowerBoundDate,112) AS INT) AS YYYYMM, SV.SQLVersionID, SI.SQLInstanceEnviornment, COUNT(*) AS InstanceCount
            FROM dbo.SQLInstances SI
            JOIN dbo.SQLVersions SV
            ON SI.SQLInstanceVersionID = SV.SQLVersionID
            WHERE SI.DiscoveryOn <= @LowerBoundDate
            AND SI.LastUpdated >= @DateBoundary
        GROUP BY SV.SQLVersionID, SI.SQLInstanceEnviornment;
    END

	-- Only create the trend for the given LowerBoundDate if there is no trend data available.  This is to protect against
    -- someone accidently executing Trending builds multiple times.
    IF (SELECT COUNT(*) FROM Trending.Databases WHERE YearMonth = @YearMonth) = 0
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
                AND D.LastUpdated >= @DateBoundary
            GROUP BY SV.SQLVersionID, SI.SQLInstanceEnviornment;
    END

END
GO


