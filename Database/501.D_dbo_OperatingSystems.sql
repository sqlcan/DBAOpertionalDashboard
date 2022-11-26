Use [SQLOpsDB]
GO

-- This script populates the Operating System values.  
--
-- Identity insert is only used to insert Unknown as it is default value in dbo.Servers.
--
-- To make it more flexible to load older installs, OperatingSystemID is not forced.

SET NOCOUNT ON

DECLARE @OperatingSystems AS TABLE (OperatingSystemName VARCHAR(255), OperatingSystemShortName VARCHAR(128))

INSERT INTO @OperatingSystems (OperatingSystemName, OperatingSystemShortName) 
     VALUES ('Windows Server 2000', 'Windows 2000'),
            ('Windows Server 2003', 'Windows 2003'),
            ('Windows Server 2008', 'Windows 2008'),
            ('Windows Server 2008 R2', 'Windows 2008 R2'),
            ('Windows Server 2012', 'Windows 2012'),
            ('Windows Server 2012 R2', 'Windows 2012 R2'),
            ('Windows Server 2016', 'Windows 2016'),
			('Windows Server 2019', 'Windows 2019')

IF NOT EXISTS (SELECT * FROM dbo.OperatingSystems WHERE OperatingSystemName <> 'Unknown')
BEGIN

	SET IDENTITY_INSERT dbo.OperatingSystems ON

	INSERT INTO dbo.OperatingSystems (OperatingSystemID,OperatingSystemName,OperatingSystemShortName) VALUES (1,'Unknown','Unknown')

	SET IDENTITY_INSERT dbo.OperatingSystems OFF
END

MERGE dbo.OperatingSystems AS Target
USING (SELECT OperatingSystemName, OperatingSystemShortName FROM @OperatingSystems) AS Source (OperatingSystemName, OperatingSystemShortName)
ON (Target.OperatingSystemName = Source.OperatingSystemName)
WHEN NOT MATCHED THEN
	INSERT (OperatingSystemName,OperatingSystemShortName)
	VALUES (Source.OperatingSystemName, Source.OperatingSystemShortName)
WHEN MATCHED THEN
	UPDATE SET OperatingSystemShortName = Source.OperatingSystemShortName;

GO
