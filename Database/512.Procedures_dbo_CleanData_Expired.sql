USE [SQLOpsDB]
GO

/****** Object:  StoredProcedure [Expired].[CleanUp_SQLInstance]    Script Date: 10/30/2022 1:00:59 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[CleanData_Expired]
   @NumberOfDaysToKeep INT
AS
BEGIN

	DECLARE @DeleteToDate DATE
    SET @NumberOfDaysToKeep = @NumberOfDaysToKeep * -1
	SET @DeleteToDate = CAST(DATEADD(Day,@NumberOfDaysToKeep,GetDate()) AS DATE)

	-- Database Clean Up --
	DELETE
	  FROM History.DatabaseSize
	 WHERE DatabaseID IN (SELECT DatabaseID FROM dbo.Databases WHERE LastUpdated <= @DeleteToDate)

	DELETE
	  FROM dbo.DatabaseSize
	 WHERE DatabaseID IN (SELECT DatabaseID FROM dbo.Databases WHERE LastUpdated <= @DeleteToDate)

	DELETE
	  FROM dbo.AGDatabases
	 WHERE DatabaseID IN (SELECT DatabaseID FROM dbo.Databases WHERE LastUpdated <= @DeleteToDate)
	    OR LastUpdated <= @DeleteToDate

	DELETE
	  FROM dbo.Databases
	 WHERE LastUpdated <= @DeleteToDate

	-- Disk Volume Clean Up --
	DELETE
	  FROM History.DiskVolumeSpace
	 WHERE DiskVolumeID IN (SELECT DiskVolumeID FROM dbo.DiskVolumes WHERE LastUpdated <= @DeleteToDate)

	DELETE
	  FROM dbo.DiskVolumeSpace
	 WHERE DiskVolumeID IN (SELECT DiskVolumeID FROM dbo.DiskVolumes WHERE LastUpdated <= @DeleteToDate)

	DELETE
	  FROM dbo.DiskVolumes
	 WHERE LastUpdated <= @DeleteToDate

	-- Availaibility Group Clean Up --
	DELETE
	  FROM dbo.AGInstances
	 WHERE LastUpdated <= @DeleteToDate

	DELETE
	  FROM dbo.AGs
	 WHERE LastUpdated <= @DeleteToDate

	-- Clean Up SQL Error Logs --
	DELETE
	  FROM dbo.SQLErrorLog
	 WHERE SQLInstanceID IN (SELECT SQLInstanceID FROM dbo.SQLInstances WHERE LastUpdated <= @DeleteToDate)

	-- Clean Up SQL Agent Logs --
	DELETE
	  FROM dbo.SQLJobHistory
	 WHERE SQLJobID IN (SELECT SQLJobID FROM dbo.SQLJobs WHERE SQLInstanceID IN (SELECT SQLInstanceID FROM dbo.SQLInstances WHERE LastUpdated <= @DeleteToDate))

	DELETE
	  FROM dbo.SQLJobs
	 WHERE SQLInstanceID IN (SELECT SQLInstanceID FROM dbo.SQLInstances WHERE LastUpdated <= @DeleteToDate)

	DELETE
	  FROM dbo.SQLJobCategory
	 WHERE NOT EXISTS (SELECT * FROM dbo.SQLJobs J WHERE J.SQLJobCategoryID = SQLJobCategoryID)

	-- Clean Up Instances --
	DELETE
	  FROM dbo.SQLInstances
	 WHERE LastUpdated <= @DeleteToDate

	-- Clean Up Clusters --
	DELETE
	  FROM dbo.SQLClusterNodes
	 WHERE LastUpdated <= @DeleteToDate

	DELETE
	  FROM dbo.SQLClusters
	 WHERE LastUpdated <= @DeleteToDate

	-- Clean Up Servers --
	DELETE
	  FROM dbo.SQLService
	 WHERE ServerID IN (SELECT ServerID FROM dbo.Servers WHERE LastUpdated <= @DeleteToDate)
	    OR LastUpdated <= @DeleteToDate

	DELETE
	  FROM dbo.Servers
	 WHERE LastUpdated <= @DeleteToDate
END