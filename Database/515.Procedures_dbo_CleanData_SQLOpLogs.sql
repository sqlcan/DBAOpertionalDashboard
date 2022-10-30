USE [SQLOpsDB]
GO

/****** Object:  StoredProcedure [History].[CleanData_RawData]    Script Date: 10/30/2022 12:51:06 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROC [dbo].[CleanData_SQLOpLogs]
   @NumberOfDaysToKeep INT
AS
BEGIN
    
	DECLARE @DateToDeleteTo AS DATE
	SET @NumberOfDaysToKeep = @NumberOfDaysToKeep * -1
	
	SELECT TOP 1 DateTimeCaptured
	  FROM dbo.Logs
     WHERE Description = 'SQLOpsDB - Collection End'
       AND DateTimeCaptured <= DATEADD(Day,@NumberOfDaysToKeep,GETDATE())
  ORDER BY DateTimeCaptured DESC

	DELETE
      FROM dbo.Logs
     WHERE DateTimeCaptured <= @DateToDeleteTo

END
GO


