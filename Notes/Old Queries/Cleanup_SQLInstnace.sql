DECLARE @ToDelete AS TABLE (SQLInstanceID INT)

INSERT INTO @ToDelete
SELECT SQLInstanceID
  FROM dbo.SQLInstances
 WHERE LastUpdated <= DATEADD(Day,-90,GetDate())
   AND IsMonitored = 1

DELETE
  FROM A
  FROM dbo.AGs AS A
  JOIN dbo.AGInstances  AS AI
    ON A.AGID = AI.AGID
 WHERE AI.SQLInstanceID IN (SELECT SQLInstanceID FROM @ToDelete)

DELETE
  FROM dbo.AGDatabases
 WHERE AGInstanceID IN (SELECT AGInstanceID
                          FROM dbo.AGInstances
                         WHERE SQLInstanceID IN (SELECT SQLInstanceID FROM @ToDelete))

DELETE
  FROM dbo.SQLInstances
 WHERE SQLInstanceID IN (SELECT SQLInstanceID FROM @ToDelete)