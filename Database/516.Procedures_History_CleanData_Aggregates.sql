USE [SQLOpsDB]
GO

/****** Object:  StoredProcedure [History].[CleanUp_Aggregates]    Script Date: 10/30/2022 1:36:43 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROC [History].[CleanData_Aggregates]
   @NumberOfMonthsToKeep INT
AS
BEGIN
    SET @NumberOfMonthsToKeep = @NumberOfMonthsToKeep * -1

    DELETE
      FROM History.DiskVolumeSpace
     WHERE YearMonth < CONVERT(VARCHAR(6),DATEADD(MONTH,@NumberOfMonthsToKeep,GETDATE()),112)

    DELETE
      FROM History.DatabaseSize
     WHERE YearMonth < CONVERT(VARCHAR(6),DATEADD(MONTH,@NumberOfMonthsToKeep,GETDATE()),112)

END
GO



