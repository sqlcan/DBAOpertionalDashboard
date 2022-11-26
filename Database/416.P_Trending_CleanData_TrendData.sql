USE [SQLOpsDB]
GO

/****** Object:  StoredProcedure [Trending].[TruncateMonthlyData]    Script Date: 10/30/2022 1:26:39 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


create proc [Trending].[CleanData_TrendData]
   @NumberOfMonthsToKeep INT
AS
BEGIN

    SET @NumberOfMonthsToKeep = @NumberOfMonthsToKeep * -1

    DELETE
      FROM Trending.Servers
     WHERE YearMonth < CONVERT(VARCHAR(6),DATEADD(MONTH,@NumberOfMonthsToKeep,GETDATE()),112)

    DELETE
      FROM Trending.SQLInstances
     WHERE YearMonth < CONVERT(VARCHAR(6),DATEADD(MONTH,@NumberOfMonthsToKeep,GETDATE()),112)

    DELETE
      FROM Trending.Databases
     WHERE YearMonth < CONVERT(VARCHAR(6),DATEADD(MONTH,@NumberOfMonthsToKeep,GETDATE()),112)
END
GO


