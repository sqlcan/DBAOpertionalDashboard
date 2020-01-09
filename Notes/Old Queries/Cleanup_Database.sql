DECLARE @DBToDelete AS TABLE (DatabaseID INT)

INSERT INTO @DBToDelete
SELECT DatabaseID
  FROM dbo.Databases
 WHERE LastUpdated <= DATEADD(Day,-90,GetDate())
   AND IsMonitored = 1

DELETE
  FROM dbo.AGDatabases
 WHERE DatabaseID IN (SELECT DatabaseID FROM @DBToDelete)

DELETE
  FROM History.DatabaseSize
 WHERE DatabaseID IN (SELECT DatabaseID FROM @DBToDelete)

DELETE
  FROM dbo.DatabaseSize
 WHERE DatabaseID IN (SELECT DatabaseID FROM @DBToDelete)

DELETE
  FROM dbo.Databases
 WHERE DatabaseID IN (SELECT DatabaseID FROM @DBToDelete)
 