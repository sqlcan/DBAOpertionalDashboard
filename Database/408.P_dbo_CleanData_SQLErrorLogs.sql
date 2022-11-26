USE [SQLOpsDB]
GO

/****** Object:  StoredProcedure [dbo].[CleanData_SQLErrorLogs]    Script Date: 10/30/2022 1:51:08 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER PROC [dbo].[CleanData_SQLErrorLogs]
   @NumberOfDaysToKeep INT
AS
BEGIN
    SET @NumberOfDaysToKeep = @NumberOfDaysToKeep * -1

    DELETE
      FROM dbo.SQLErrorLog
     WHERE DateTime <= DATEADD(MONTH,@NumberOfDaysToKeep,GETDATE())
END
GO


