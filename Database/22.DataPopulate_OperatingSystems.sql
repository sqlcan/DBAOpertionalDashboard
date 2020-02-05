Use [SQLOpsDB]
GO

-- This script populates the Operating System values.  
--
-- Identity insert is used to make sure ID values do not change 
-- as future upgrades are applied.

SET IDENTITY_INSERT dbo.OperatingSystems ON

SET NOCOUNT ON

DECLARE @OperatingSystems AS TABLE (OperatingSystemID INT, OperatingSystemName VARCHAR(255))

INSERT INTO @OperatingSystems (OperatingSystemID,OperatingSystemName) 
     VALUES (1,'Unknown'),
            (2,'Windows Server 2000'),
            (3,'Windows Server 2003'),
            (4,'Windows Server 2008'),
            (5,'Windows Server 2008 R2'),
            (6,'Windows Server 2012'),
            (7,'Windows Server 2012 R2'),
            (8,'Windows Server 2016'),
			(9,'Windows Server 2019')


MERGE dbo.OperatingSystems AS Target
USING (SELECT OperatingSystemID, OperatingSystemName FROM @OperatingSystems) AS Source (OperatingSystemID, OperatingSystemName)
ON (Target.OperatingSystemName = Source.OperatingSystemName)
WHEN NOT MATCHED THEN
	INSERT (OperatingSystemID,OperatingSystemName)
	VALUES (Source.OperatingSystemID, Source.OperatingSystemName);

SET IDENTITY_INSERT dbo.OperatingSystems OFF
GO
