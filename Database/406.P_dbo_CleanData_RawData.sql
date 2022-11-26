USE [SQLOpsDB]
GO

/****** Object:  StoredProcedure [History].[TruncateRawDataForDatabases]    Script Date: 10/30/2022 12:43:18 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROC [dbo].[CleanData_RawData]
   @NumberOfDaysToKeep INT
AS
BEGIN
    SET @NumberOfDaysToKeep = @NumberOfDaysToKeep * -1
	
    DELETE
      FROM dbo.DatabaseSize
     WHERE DateCaptured <= CAST(DATEADD(Day,@NumberOfDaysToKeep,GETDATE()) AS DATE)

	DELETE
      FROM dbo.DiskVolumeSpace
     WHERE DateCaptured <= CAST(DATEADD(Day,@NumberOfDaysToKeep,GETDATE()) AS DATE)
END
GO


