USE [SQLOpsDB]
GO

/****** Object:  View [dbo].[vSQLInstances]    Script Date: 11/17/2022 5:57:19 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE OR ALTER VIEW [dbo].[vSQLInstances]
AS
   SELECT SI.SQLInstanceID,
		  CASE WHEN SI.SQLClusterID IS NULL THEN
             S.ServerName
		  ELSE
		     SC.SQLClusterName
		  END + 
		  CASE WHEN SI.SQLInstanceName = 'MSSQLServer' THEN
			 ''
		  ELSE 
		     '\' + SI.SQLInstanceName
		  END AS ServerInstance,
          CASE WHEN SI.SQLClusterID IS NULL THEN
             S.ServerName
		  ELSE
		     SC.SQLClusterName
		  END AS ComputerName,		  
		  SI.SQLInstanceName,
		  SI.SQLInstanceVersionID, 
		  SV.SQLVersion,
          SV.SQLMajorVersion, SV.SQLMinorVersion,
          SI.SQLInstanceBuild,
          SI.SQLInstanceEdition,
          SI.SQLInstanceType,
          SI.SQLInstanceEnviornment,
          SI.IsMonitored,
          SI.DiscoveryOn,
          SI.LastUpdated
     FROM dbo.SQLInstances SI
	 JOIN dbo.SQLVersions SV
	   ON SI.SQLInstanceVersionID = SV.SQLVersionID
LEFT JOIN dbo.Servers S
       ON SI.ServerID = S.ServerID
	  AND SI.SQLClusterID IS NULL
LEFT JOIN dbo.SQLClusters SC
       ON SI.SQLClusterID = SC.SQLClusterID
	  AND SI.ServerID IS NULL
GO


