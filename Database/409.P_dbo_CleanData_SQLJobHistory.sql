USE [SQLOpsDB]
GO

/****** Object:  StoredProcedure [dbo].[CleanData_SQLJobHistory]    Script Date: 10/30/2022 1:52:13 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE OR ALTER PROC [dbo].[CleanData_SQLJobHistory]
   @NumberOfDaysToKeep INT
AS
BEGIN
    SET @NumberOfDaysToKeep = @NumberOfDaysToKeep * -1

    DELETE
      FROM dbo.SQLJobHistory
     WHERE ExecutionDateTime <= DATEADD(MONTH,@NumberOfDaysToKeep,GETDATE())
END
GO


