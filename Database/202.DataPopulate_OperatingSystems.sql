Use [SQLOpsDB]
GO

-- This script populates the Operating System values.  
--
-- Identity insert is used to make sure ID values do not change 
-- as future upgrades are applied.

SET IDENTITY_INSERT dbo.OperatingSystems ON

SET NOCOUNT ON

DECLARE @OperatingSystems AS TABLE (OperatingSystemID INT, OperatingSystemName VARCHAR(255), OperatingSystemShortName VARCHAR(128))

INSERT INTO @OperatingSystems (OperatingSystemID,OperatingSystemName, OperatingSystemShortName) 
     VALUES (1,'Unknown', 'Unknown'),
            (2,'Windows Server 2000', 'Windows 2000'),
            (3,'Windows Server 2003', 'Windows 2003'),
            (4,'Windows Server 2008', 'Windows 2008'),
            (5,'Windows Server 2008 R2', 'Windows 2008 R2'),
            (6,'Windows Server 2012', 'Windows 2012'),
            (7,'Windows Server 2012 R2', 'Windows 2012 R2'),
            (8,'Windows Server 2016', 'Windows 2016'),
			(9,'Windows Server 2019', 'Windows 2019')


MERGE dbo.OperatingSystems AS Target
USING (SELECT OperatingSystemID, OperatingSystemName, OperatingSystemShortName FROM @OperatingSystems) AS Source (OperatingSystemID, OperatingSystemName, OperatingSystemShortName)
ON (Target.OperatingSystemName = Source.OperatingSystemName)
WHEN NOT MATCHED THEN
	INSERT (OperatingSystemID,OperatingSystemName,OperatingSystemShortName)
	VALUES (Source.OperatingSystemID, Source.OperatingSystemName, Source.OperatingSystemShortName);

SET IDENTITY_INSERT dbo.OperatingSystems OFF
GO
