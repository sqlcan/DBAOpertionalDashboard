USE [SQLOpsDB]
GO

/****** Object:  StoredProcedure [dbo].[CleanData_SQLOpLogs]    Script Date: 11/18/2022 5:44:29 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE OR ALTER PROC [dbo].[CleanData_SQLOpLogs]
   @NumberOfDaysToKeep INT
AS
BEGIN
    
	DECLARE @DateToDeleteTo AS DATE
	SET @NumberOfDaysToKeep = @NumberOfDaysToKeep * -1
	
	SELECT TOP 1 @DateToDeleteTo = DateTimeCaptured
	  FROM dbo.Logs
     WHERE Description = 'SQLOpsDB - Collection End'
       AND DateTimeCaptured <= DATEADD(Day,@NumberOfDaysToKeep,GETDATE())
  ORDER BY DateTimeCaptured DESC

	DELETE
      FROM dbo.Logs
     WHERE DateTimeCaptured <= @DateToDeleteTo

END
GO


