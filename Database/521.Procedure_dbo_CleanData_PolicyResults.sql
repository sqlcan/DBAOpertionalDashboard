USE [SQLOpsDB]
GO

/****** Object:  StoredProcedure [dbo].[CleanData_SQLOpLogs]    Script Date: 11/16/2022 4:37:22 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE OR ALTER PROC [dbo].[CleanData_PolicyResults]
   @NumberOfDaysToKeep INT
AS
BEGIN
    
	DECLARE @DateToDeleteTo AS DATE
	SET @NumberOfDaysToKeep = @NumberOfDaysToKeep * -1
	
	DELETE
	  FROM Policy.EvaluationErrorHistory
	 WHERE EvaluationDateTime <= DATEADD(Day,@NumberOfDaysToKeep,GETDATE())

	 DELETE
	   FROM Policy.PolicyHistory
	  WHERE EvaluationDateTime <= DATEADD(Day,@NumberOfDaysToKeep,GETDATE())

	 DELETE
	   FROM Policy.PolicyHistoryDetail
	  WHERE EvaluationDateTime <= DATEADD(Day,@NumberOfDaysToKeep,GETDATE())

END
GO


