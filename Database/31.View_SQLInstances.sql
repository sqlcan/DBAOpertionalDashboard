USE [SQLOpsDB]
GO

CREATE VIEW vSQLInstances
AS
   SELECT CASE WHEN SI.SQLClusterID IS NULL THEN
             S.ServerName
		  ELSE
		     SC.SQLClusterName
		  END AS ComputerName,
		  SI.SQLInstanceID,
		  SI.SQLInstanceName,
          SI.SQLInstanceVersionID,
          SI.SQLInstanceBuild,
          SI.SQLInstanceEdition,
          SI.SQLInstanceType,
          SI.SQLInstanceEnviornment,
          SI.IsMonitored,
          SI.DiscoveryOn,
          SI.LastUpdated
     FROM dbo.SQLInstances SI
LEFT JOIN dbo.Servers S
       ON SI.ServerID = S.ServerID
	  AND SI.SQLClusterID IS NULL
LEFT JOIN dbo.SQLClusters SC
       ON SI.SQLClusterID = SC.SQLClusterID
	  AND SI.ServerID IS NULL
GO