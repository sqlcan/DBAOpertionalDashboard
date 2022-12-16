USE [SQLOpsDB]
GO

/****** Object:  StoredProcedure [History].[CreateAggregate]    Script Date: 12/16/2022 10:51:04 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER   PROC [History].[CreateAggregate]
   @Month INT,
   @Year INT
AS
BEGIN
    
	DECLARE @StartDate DATE
	DECLARE @EndDate DATE
	DECLARE @NextYear INT
    DECLARE @NextMonth INT
	DECLARE @YearMonth VARCHAR(6)

	-- PowerShell will give me Previous Month and Year from current date.
	SET @StartDate = DATEFROMPARTS(@Year,@Month,1)
	
    SET @NextMonth = @Month + 1
	SET @NextYear = @Year

	IF (@NextMonth = 13)
	BEGIN
		SET @NextMonth = 1
		SET @NextYear = @Year+1
	END

	SET @EndDate = DATEADD(Day,-1,DATEFROMPARTS(@NextYear,@NextMonth,1))
	SET @YearMonth = CONVERT(varchar(6),@StartDate,112)
    
    IF (SELECT COUNT(*) FROM History.DatabaseSize WHERE YearMonth = @YearMonth) = 0
    BEGIN
         INSERT
           INTO History.DatabaseSize (DatabaseID, YearMonth, FileType, FileSize_mb)
         SELECT DatabaseID, @YearMonth, FileType, AVG(FileSize_mb)
           FROM dbo.DatabaseSize
          WHERE DateCaptured >= @StartDate
            AND DateCaptured <= @EndDate
       GROUP BY DatabaseID, FileType
    END

    IF (SELECT COUNT(*) FROM History.DiskVolumeSpace WHERE YearMonth = @YearMonth) = 0
    BEGIN
         INSERT
           INTO History.DiskVolumeSpace (DiskVolumeID, YearMonth, SpaceUsed_mb, TotalSpace_mb)
         SELECT DiskVolumeID, @YearMonth, AVG(SpaceUsed_mb), AVG(TotalSpace_mb)
           FROM dbo.DiskVolumeSpace
          WHERE DateCaptured >= @StartDate
            AND DateCaptured <= @EndDate
       GROUP BY DiskVolumeID
    END

END
GO


