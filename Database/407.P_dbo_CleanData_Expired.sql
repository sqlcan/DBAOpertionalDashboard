USE [SQLOpsDB]
GO
/****** Object:  StoredProcedure [dbo].[CleanData_Expired]    Script Date: 11/4/2022 6:48:23 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROC [dbo].[CleanData_Expired]
   @NumberOfDaysToKeep INT
AS
BEGIN

	DECLARE @DeleteToDate DATE
    SET @NumberOfDaysToKeep = @NumberOfDaysToKeep * -1
	SET @DeleteToDate = CAST(DATEADD(Day,@NumberOfDaysToKeep,GetDate()) AS DATE)


	-- Security Clean Up
	-- Security holds audit data for when permission was removed.
	-- Therefore, we cannot clean that up even if it is past Expiry Date.
	-- However clean up can take place if the instance or databases are decomissioned.
	DELETE
	  FROM Security.DatabasePermission
	 WHERE DatabaseID IN (SELECT DatabaseID FROM dbo.Databases WHERE LastUpdated <= @DeleteToDate)

    DELETE
	  FROM Security.DatabasePrincipalMembership
	 WHERE DatabaseID IN (SELECT DatabaseID FROM dbo.Databases WHERE LastUpdated <= @DeleteToDate)

	DELETE
	  FROM Security.ServerPermission
	 WHERE SQLInstanceID IN (SELECT SQLInstanceID FROM dbo.SQLInstances WHERE LastUpdated <= @DeleteToDate)

	DELETE
	  FROM Security.ServerPrincipalMembership
	 WHERE SQLInstanceID IN (SELECT SQLInstanceID FROM dbo.SQLInstances WHERE LastUpdated <= @DeleteToDate)

	DELETE
	  FROM Security.DatabasePrincipal
	 WHERE PrincipalID NOT IN (SELECT GranteeID FROM Security.DatabasePermission)
	   AND PrincipalID NOT IN (SELECT GrantorID FROM Security.DatabasePermission)
	   AND PrincipalID NOT IN (SELECT DatabaseUserID FROM Security.DatabasePrincipalMembership)
	   AND PrincipalID NOT IN (SELECT DatabaseRoleID FROM Security.DatabasePrincipalMembership)

	DELETE
	  FROM Security.ServerPrincipal
	 WHERE PrincipalID NOT IN (SELECT GranteeID FROM Security.ServerPermission)
	   AND PrincipalID NOT IN (SELECT GrantorID FROM Security.ServerPermission)
	   AND PrincipalID NOT IN (SELECT ServerLoginID FROM Security.ServerPrincipalMembership)
	   AND PrincipalID NOT IN (SELECT ServerRoleID FROM Security.ServerPrincipalMembership)

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

	-- Clean Up Applications --
	-- Application table does not have last updated / discovery dates.
	-- However if application is not refrenced by any database then it is not required.

	DELETE
	  FROM dbo.Application
	 WHERE ApplicationID NOT IN (SELECT ApplicationID FROM dbo.Databases)

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

	-- Clean Up Extended Properties --
	-- Extend property values can be cleaned up.
	-- However extended property look up table will be cleaned up if not referenced.
	DELETE
	  FROM dbo.ExtendedPropertyValues
	 WHERE LastUpdated <= @DeleteToDate

	DELETE
	  FROM dbo.ExtendedProperty
	 WHERE ExtendedPropertyID NOT IN (SELECT ExtendedPropertyID FROM dbo.ExtendedPropertyValues)

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