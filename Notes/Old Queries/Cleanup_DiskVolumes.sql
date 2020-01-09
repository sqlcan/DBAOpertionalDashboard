DECLARE @DBToDelete AS TABLE (DiskVolumeID INT)

INSERT INTO @DBToDelete
SELECT DiskVolumeID
  FROM dbo.DiskVolumes
 WHERE LastUpdated <= DATEADD(Day,-90,GetDate())
   AND IsMonitored = 1

DELETE
  FROM History.DiskVolumeSpace
 WHERE DiskVolumeID IN (SELECT DiskVolumeID FROM @DBToDelete)

DELETE
  FROM dbo.DiskVolumeSpace
 WHERE DiskVolumeID IN (SELECT DiskVolumeID FROM @DBToDelete)

DELETE
  FROM dbo.DiskVolumes
 WHERE DiskVolumeID IN (SELECT DiskVolumeID FROM @DBToDelete)
 