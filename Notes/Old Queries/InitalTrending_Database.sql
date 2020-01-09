WITH AGInstancesByRowNumber AS (
 SELECT AGI.AGID,
        AGI.SQLInstanceID,
        ROW_NUMBER () OVER (PARTITION BY AGI.AGID ORDER BY AGI.SQLInstanceID) AS InstanceNumber
   FROM dbo.AGInstances AGI)
, DatabaseCounts AS (
   SELECT D.SQLInstanceID,
          COUNT(*) DBCount
     FROM dbo.Databases D
    WHERE D.DatabaseID NOT IN (SELECT DatabaseID FROM dbo.AGDatabases)
       OR D.SQLInstanceID IN (SELECT SQLInstanceID FROM AGInstancesByRowNumber WHERE InstanceNumber = 1)
 GROUP BY D.SQLInstanceID)
   SELECT SI.SQLInstanceEnviornment, SV.SQLVersionID, SUM(DC.DBCount) AS DBCount
     FROM dbo.SQLInstances SI
LEFT JOIN DatabaseCounts DC
       ON DC.SQLInstanceID = SI.SQLInstanceID
LEFT JOIN dbo.SQLVersions SV
       ON SI.SQLInstanceVersionID = SV.SQLVersionID
    WHERE DBCount IS NOT NULL
      AND SI.DiscoveryOn <= '2015-01-31'
      AND SI.LastUpdated >= DATEADD(Day,-30,'2015-01-31')
 GROUP BY SI.SQLInstanceEnviornment, SV.SQLVersionID
 ORDER BY SQLVersionID, SQLInstanceEnviornment