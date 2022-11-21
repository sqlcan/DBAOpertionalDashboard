USE [SQLOpsDB]
GO

CREATE OR ALTER PROC SQLLicenseDetails
AS
BEGIN
	IF object_id('tempdb..#SQLLicenseOverview') IS NOT NULL
		DROP TABLE #SQLLicenseOverview

	IF object_id('tempdb..#ServerDetails') IS NOT NULL
		DROP TABLE #ServerDetails

	IF object_id('tempdb..#FCINodeInfo') IS NOT NULL
		DROP TABLE #FCINodeInfo

	IF object_id('tempdb..#AGReplicaInfo') IS NOT NULL
		DROP TABLE #AGReplicaInfo

	SELECT   ServerName
		   , CAST(Null AS VARCHAR(255)) AS SQLClusterName
		   , NumberOfCores
			  , IsPhysical
			  , 1 AS CoreFactor
			  , CAST('Active' AS VARCHAR(255)) AS ServerRole
			  , CAST('Enterprise Edition: Core-based Licensing (64-bit)' AS VARCHAR(255)) As Edition
			  , CAST('Prod' AS VARCHAR(255)) AS Enviornment
			  , CAST('Stand Alone' AS VARCHAR(255)) InstanceType
			  , 0 AS AssumedCPUInfo
	  INTO #SQLLicenseOverview
	  FROM dbo.Servers
	 WHERE LastUpdated >= DATEADD(Day,-30,GETDATE())
	   AND ServerID NOT IN (SELECT SQLNodeID FROM dbo.SQLClusterNodes);

	WITH CTE AS (
	SELECT SQLNodeID, SQLClusterID, ROW_NUMBER() OVER (PARTITION BY SQLNodeID ORDER BY SQLclusterID) AS RowNum
	FROM dbo.SQLClusterNodes)
	INSERT INTO #SQLLicenseOverview
	SELECT S.ServerName, c.SQLClusterName, S.NumberOfCores, S.IsPhysical, 1, 'Active', 'Enterprise Edition: Core-based Licensing (64-bit)','Prod','Veritas Cluster', 0
	  FROM dbo.SQLClusters c
	  JOIN dbo.SQLClusterNodes cn
		ON c.SQLClusterID = cn.SQLClusterID
	  JOIN dbo.Servers S
		ON cn.SQLNodeID = S.ServerID
	 WHERE C.SQLClusterID IN (SELECT SQLClusterID FROM CTE WHERE RowNum = 1)
	   AND S.ServerID IN (SELECT SQLNodeID FROM CTE WHERE RowNum = 1);


	-- For each server identity the most significant instance.
	-- Env > Instance Type > Edition.

	-- Select Single Instance per Server with Highest Edition
	DECLARE @SQLEditionRank AS TABLE (Edition VARCHAR(255), EdRank INT)
	DECLARE @EnvRank AS TABLE (Env VARCHAR(255), EnvRank INT)
	DECLARE @SvrRoleRank AS TABLE (SvrRole VARCHAR(255), SvrRoleRank INT)

	INSERT INTO @SQLEditionRank (Edition, EdRank)
		 VALUES ('Enterprise Edition: Core-based Licensing (64-bit)',1),('Enterprise Edition (64-bit)',2),('Standard Edition (64-bit)',3)

	INSERT INTO @EnvRank (Env, EnvRank)
		 VALUES ('Prod',1)

	INSERT INTO @SvrRoleRank (SvrRole, SvrRoleRank)
		 VALUES ('Stand Alone',1);

	WITH RoleRanks AS (
	   SELECT SI.ComputerName, SI.SQLInstanceEdition, SI.SQLInstanceEnviornment, SI.SQLInstanceType
					, ISNULL(EvR.EnvRank,2) AS EnvRank
					, ISNULL(SvRR.SvrRoleRank,2) AS SvrRoleRank
			  , ISNULL(ER.EDRank,4) AS EdRank         
		 FROM dbo.vSQLInstances SI
	LEFT JOIN @SQLEditionRank ER
		   ON SI.SQLInstanceEdition = ER.Edition
	LEFT JOIN @EnvRank EvR
		   ON SI.SQLInstanceEnviornment = EvR.Env
	LEFT JOIN @SvrRoleRank SvRR
		   ON SI.SQLInstanceType = SvRR.SvrRole),
	RowNumber AS (
	SELECT *,
		   ROW_NUMBER() OVER (Partition BY ComputerName ORDER BY EnvRank, SvrRoleRank, EdRank) AS RowNumber
	  FROM RoleRanks)
	SELECT *
	  INTO #ServerDetails
	  FROM RowNumber
	WHERE RowNumber = 1

	UPDATE #SQLLicenseOverview
		SET Edition = CASE WHEN SD.SQLInstanceEdition IS NULL THEN SD2.SQLInstanceEdition ELSE SD.SQLInstanceEdition END,
			   Enviornment = CASE WHEN SD.SQLInstanceEnviornment IS NULL THEN SD2.SQLInstanceEnviornment ELSE SD.SQLInstanceEnviornment END,
				  InstanceType = CASE WHEN SD.SQLInstanceType IS NULL THEN SD2.SQLInstanceType ELSE SD.SQLInstanceType END
	   FROM #SQLLicenseOverview SLO
	LEFT JOIN #ServerDetails SD
		 ON SLO.ServerName = SD.ComputerName
		AND SLO.SQLClusterName IS NULL
	LEFT JOIN #ServerDetails SD2
		 ON SLO.SQLClusterName = SD2.ComputerName


	-- Next identify Active vs Passive Roles for FCI and AG.
	-- If a server has stand alone instance it is consider active, event in AG/FCI configuration.

	-- First FCI
	SELECT SC.SQLClusterName, S.ServerName AS NodeName, ROW_NUMBER() OVER (Partition By SQLClusterName ORDER BY ServerName) AS RowNumber
	  INTO #FCINodeInfo
	  FROM dbo.SQLClusters SC
	  JOIN dbo.SQLClusterNodes CN
		ON SC.SQLClusterID = CN.SQLClusterID
	  JOIN dbo.Servers S
		ON CN.SQLNodeID = S.ServerID
  
	UPDATE #SQLLicenseOverview
	   SET ServerRole = CASE WHEN (NI.RowNumber = 1) THEN 'Active' ELSE 'Passive' END
	  FROM #SQLLicenseOverview SO
	  JOIN #FCINodeInfo  NI
		ON SO.ServerName = NI.NodeName

	-- SECOND AG
	SELECT SI.ComputerName, ROW_NUMBER() OVER (Partition By AGID ORDER BY ComputerName, SQLInstanceName) AS RowNum
	  INTO #AGReplicaInfo
	  FROM AGInstances AI
	  JOIN vSQLInstances SI
		ON AI.SQLInstanceID = SI.SQLInstanceID

	UPDATE #SQLLicenseOverview
	   SET ServerRole = CASE WHEN (AG.RowNum = 1) THEN 'Active' ELSE 'Passive' END
	  FROM #SQLLicenseOverview SO
	  JOIN #AGReplicaInfo  AG
		ON SO.ServerName = AG.ComputerName

	-- 3rd All Server with Stand Alone instances are consider active.
	UPDATE #SQLLicenseOverview
	   SET ServerRole = 'Active'
	WHERE InstanceType = 'Stand Alone'

	-- Update Flag Where CPU information Is Missing
	UPDATE #SQLLicenseOverview
	   SET NumberOfCores = 4,
		   IsPhysical = 1,
			  CoreFactor = 1,
			  AssumedCPUInfo = 1
	WHERE NumberOfCores = 0

	-- Core Factor Calulation Updates
	UPDATE #SQLLicenseOverview
	   SET CoreFactor = CASE WHEN NumberOfCores > 4 THEN 1 ELSE 4/NumberOfCores END

	-- Developer Edition / Express Edition are Free
	UPDATE #SQLLicenseOverview
	   SET CoreFactor = 0
	WHERE Edition LIKE '%Express%'
		OR Edition LIKE '%Developer%'

	-- Passive Do Not Need License
	UPDATE #SQLLicenseOverview
	   SET CoreFactor = 0
	WHERE ServerRole = 'Passive'

	SELECT *, NumberOfCores*CoreFactor AS LicenseCores
	  FROM #SQLLicenseOverview order by Enviornment,Edition,ServerName
END
GO