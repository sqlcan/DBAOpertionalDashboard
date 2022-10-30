USE [SQLOpsDB]
GO

/****** Object:  StoredProcedure [History].[AggregateDiskVolumes]    Script Date: 10/30/2022 5:07:09 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [History].[AggregateDiskVolumes]
   @Month INT,
   @Year INT
AS
BEGIN
    DECLARE @NextYear INT
    DECLARE @NextMonth INT

    SET @NextYear = @Year
    SET @NextMonth = @Month + 1

    if (@Month = 12)
    BEGIN
        SET @NextMonth = 1
        SET @NextYear = @NextYear + 1
    END

    IF (SELECT COUNT(*) FROM History.DiskVolumeSpace WHERE YearMonth = CONVERT(varchar(6),DATEFROMPARTS(@Year,@Month,1),112)) = 0
    BEGIN
         INSERT
           INTO History.DiskVolumeSpace (DiskVolumeID, YearMonth, SpaceUsed_mb, TotalSpace_mb)
         SELECT DiskVolumeID, CONVERT(varchar(6),DateCaptured,112), AVG(SpaceUsed_mb), AVG(TotalSpace_mb)
           FROM dbo.DiskVolumeSpace
          WHERE DateCaptured >= DATEFROMPARTS(@Year,@Month,1)
            AND DateCaptured <= DATEFROMPARTS(@Year,@Month,DATEPART(Day,DATEADD(DAY,-1,DATEFROMPARTS(@NextYear,@NextMonth,1))))
       GROUP BY DiskVolumeID, CONVERT(varchar(6),DateCaptured,112)
    END

END
GO


