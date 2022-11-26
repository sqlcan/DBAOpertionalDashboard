Use [SQLOpsDB]
GO

-- This script populates the SQL Version values.  
--
-- Identity insert is used to make sure ID values do not change 
-- as future upgrades are applied.
--
-- Last Updated Nov. 26, 2022

SET NOCOUNT ON

DECLARE @SQLVersions AS TABLE (SQLVersion VARCHAR(50), SQLVersionShortName VARCHAR(50), SQLMajorVersion int, SQLMinorVersion int, SQLBuild int, SQLVersionSupportEndDate date)

INSERT INTO @SQLVersions (SQLVersion, SQLVersionShortName, SQLMajorVersion, SQLMinorVersion, SQLBuild, SQLVersionSupportEndDate) 
     VALUES ('Microsoft SQL Server 2000 RTM', 'SQL 2000', 8, 0, 194, '2002-07-11'), 
			('Microsoft SQL Server 2000 Service Pack 1', 'SQL 2000', 8, 0, 384, '2002-02-28'), 
			('Microsoft SQL Server 2000 Service Pack 2', 'SQL 2000', 8, 0, 532, '2003-04-07'), 
			('Microsoft SQL Server 2000 Service Pack 3a', 'SQL 2000', 8, 0, 760, '2007-07-10'), 
			('Microsoft SQL Server 2000 Service Pack 4', 'SQL 2000', 8, 0, 2039, '2013-04-09'), 
			('Microsoft SQL Server 2005 RTM', 'SQL 2005', 9, 0, 1399, '2007-07-10'), 
			('Microsoft SQL Server 2005 Service Pack 1', 'SQL 2005', 9, 0, 2047, '2008-04-08'), 
			('Microsoft SQL Server 2005 Service Pack 2', 'SQL 2005',9, 0, 3042, '2010-01-12'), 
			('Microsoft SQL Server 2005 Service Pack 3', 'SQL 2005', 9, 0, 4035, '2012-01-10'), 
			('Microsoft SQL Server 2005 Service Pack 4', 'SQL 2005', 9, 0, 5000, '2016-04-12'), 
			('Microsoft SQL Server 2008 R2 RTM', 'SQL 2008 R2', 10, 50, 1600, '2012-07-10'), 
			('Microsoft SQL Server 2008 R2 Service Pack 1', 'SQL 2008 R2', 10, 50, 2500, '2013-10-08'), 
			('Microsoft SQL Server 2008 R2 Service Pack 2', 'SQL 2008 R2', 10, 50, 4000, '2015-10-13'), 
			('Microsoft SQL Server 2008 R2 Service Pack 3', 'SQL 2008 R2', 10, 50, 6000, '2019-07-09'), 
			('Microsoft SQL Server 2008 RTM', 'SQL 2008', 10, 0, 1600, '2010-04-13'), 
			('Microsoft SQL Server 2008 Service Pack 1', 'SQL 2008', 10, 0, 2531, '2011-10-11'), 
			('Microsoft SQL Server 2008 Service Pack 2', 'SQL 2008', 10, 0, 4000, '2012-10-09'), 
			('Microsoft SQL Server 2008 Service Pack 3', 'SQL 2008', 10, 0, 5500, '2015-10-13'), 
			('Microsoft SQL Server 2008 Service Pack 4', 'SQL 2008', 10, 0, 6000, '2019-07-09'), 
			('Microsoft SQL Server 2012 RTM', 'SQL 2012', 11, 0, 2100, '2014-01-14'), 
			('Microsoft SQL Server 2012 Service Pack 1', 'SQL 2012', 11, 0, 3000, '2015-07-14'), 
			('Microsoft SQL Server 2012 Service Pack 2', 'SQL 2012', 11, 0, 5058, '2017-01-10'), 
			('Microsoft SQL Server 2014 RTM', 'SQL 2014', 12, 0, 2000, '2016-07-12'), 
			('Microsoft SQL Server 2014 Service Pack 1', 'SQL 2014', 12, 0, 4100, '2017-10-10'), 
			('Microsoft SQL Server 6.5 RTM-SP5a', 'SQL 6.5', 6, 50, 0, '2004-03-31'), 
			('Microsoft SQL Server 7.0 RTM-SP4', 'SQL 7', 7, 0, 0, '2011-01-11'), 
			('Microsoft SQL Server 2012 Service Pack 3', 'SQL 2012', 11, 0, 6020, '2022-07-12'), 
			('Microsoft SQL Server 2014 Service Pack 2', 'SQL 2014', 12, 0, 5000, '2020-01-14'), 
			('Microsoft SQL Server 2016 RTM', 'SQL 2016', 13, 0, 1601, '2018-01-19'), 
			('Microsoft SQL Server 2016 Service Pack 1', 'SQL 2016', 13, 0, 4001, '2026-07-14'), 
			('Microsoft SQL Server 2017 RTM', 'SQL 2017', 14, 0, 1000, '2027-10-12'), 
			('Microsoft SQL Server 2012 Service Pack 4', 'SQL 2012', 11, 0, 7001, '2022-07-12'), 
			('Microsoft SQL Server 2016 Service Pack 2', 'SQL 2016', 13, 0, 5026, '2022-10-11'), 
			('Microsoft SQL Server 2019 RTM', 'SQL 2019', 15, 0, 1000, '2030-01-08'),
			('Microsoft SQL Server 2016 Service Pack 3', 'SQL 2016', 13, 0, 6300, '2026-07-14'),
			('Microsoft SQL Server 2022 RTM', 'SQL 2022', 15, 0, 1000, '2030-01-08'),
			('Microsoft SQL Server 2014 Service Pack 3', 'SQL 2014', 12, 0, 6024, '2024-07-09')
			
IF NOT EXISTS (SELECT * FROM dbo.SQLVersions WHERE SQLVersion = 'Unknown')
BEGIN

	SET IDENTITY_INSERT dbo.SQLVersions ON

	INSERT
	  INTO dbo.SQLVersions (SQLVersionID, SQLVersion, SQLVersionShortName, SQLMajorVersion, SQLMinorVersion, SQLBuild, SQLVersionSupportEndDate)
	VALUES (1, 'Unknown', 'Unknown', 0, 0, 0, '1900-01-01')

	SET IDENTITY_INSERT dbo.SQLVersions OFF
END

MERGE dbo.SQLVersions AS Target
USING (SELECT SQLVersion, SQLVersionShortName, SQLMajorVersion, SQLMinorVersion, SQLBuild, SQLVersionSupportEndDate FROM @SQLVersions) AS Source 
      (SQLVersion, SQLVersionShortName, SQLMajorVersion, SQLMinorVersion, SQLBuild, SQLVersionSupportEndDate)
ON (Target.SQLVersion = Source.SQLVersion)
WHEN NOT MATCHED THEN
	INSERT (SQLVersion, SQLVersionShortName, SQLMajorVersion, SQLMinorVersion, SQLBuild, SQLVersionSupportEndDate)
	VALUES (Source.SQLVersion, Source.SQLVersionShortName, Source.SQLMajorVersion, Source.SQLMinorVersion, Source.SQLBuild, Source.SQLVersionSupportEndDate)
WHEN MATCHED THEN
	UPDATE SET SQLVersionShortName = Source.SQLVersionShortName,
	           SQLVersionSupportEndDate = Source.SQLVersionSupportEndDate;
