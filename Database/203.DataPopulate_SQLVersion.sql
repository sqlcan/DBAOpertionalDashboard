Use [SQLOpsDB]
GO

-- This script populates the SQL Version values.  
--
-- Identity insert is used to make sure ID values do not change 
-- as future upgrades are applied.

SET IDENTITY_INSERT dbo.SQLVersions ON

SET NOCOUNT ON

DECLARE @SQLVersions AS TABLE (SQLVersionID INT, SQLVersion VARCHAR(50), SQLVersionShortName VARCHAR(50), SQLMajorVersion int, SQLMinorVersion int, SQLBuild int, SQLVersionSupportEndDate date)

INSERT INTO @SQLVersions (SQLVersionID, SQLVersion, SQLVersionShortName, SQLMajorVersion, SQLMinorVersion, SQLBuild, SQLVersionSupportEndDate) 
     VALUES (1, 'Unknown', 'Unknown', 0, 0, 0, '1900-01-01'), 
			(2, 'Microsoft SQL Server 2000 RTM', 'SQL 2000', 8, 0, 194, '2002-07-11'), 
			(3, 'Microsoft SQL Server 2000 Service Pack 1', 'SQL 2000', 8, 0, 384, '2002-02-28'), 
			(4, 'Microsoft SQL Server 2000 Service Pack 2', 'SQL 2000', 8, 0, 532, '2003-04-07'), 
			(5, 'Microsoft SQL Server 2000 Service Pack 3a', 'SQL 2000', 8, 0, 760, '2007-07-10'), 
			(6, 'Microsoft SQL Server 2000 Service Pack 4', 'SQL 2000', 8, 0, 2039, '2013-04-09'), 
			(7, 'Microsoft SQL Server 2005 RTM', 'SQL 2005', 9, 0, 1399, '2007-07-10'), 
			(8, 'Microsoft SQL Server 2005 Service Pack 1', 'SQL 2005', 9, 0, 2047, '2008-04-08'), 
			(9, 'Microsoft SQL Server 2005 Service Pack 2', 'SQL 2005',9, 0, 3042, '2010-01-12'), 
			(10, 'Microsoft SQL Server 2005 Service Pack 3', 'SQL 2005', 9, 0, 4035, '2012-01-10'), 
			(11, 'Microsoft SQL Server 2005 Service Pack 4', 'SQL 2005', 9, 0, 5000, '2016-04-12'), 
			(12, 'Microsoft SQL Server 2008 R2 RTM', 'SQL 2008 R2', 10, 50, 1600, '2012-07-10'), 
			(13, 'Microsoft SQL Server 2008 R2 Service Pack 1', 'SQL 2008 R2', 10, 50, 2500, '2013-10-08'), 
			(14, 'Microsoft SQL Server 2008 R2 Service Pack 2', 'SQL 2008 R2', 10, 50, 4000, '2015-10-13'), 
			(15, 'Microsoft SQL Server 2008 R2 Service Pack 3', 'SQL 2008 R2', 10, 50, 6000, '2019-07-09'), 
			(16, 'Microsoft SQL Server 2008 RTM', 'SQL 2008', 10, 0, 1600, '2010-04-13'), 
			(17, 'Microsoft SQL Server 2008 Service Pack 1', 'SQL 2008', 10, 0, 2531, '2011-10-11'), 
			(18, 'Microsoft SQL Server 2008 Service Pack 2', 'SQL 2008', 10, 0, 4000, '2012-10-09'), 
			(19, 'Microsoft SQL Server 2008 Service Pack 3', 'SQL 2008', 10, 0, 5500, '2015-10-13'), 
			(20, 'Microsoft SQL Server 2008 Service Pack 4', 'SQL 2008', 10, 0, 6000, '2019-07-09'), 
			(21, 'Microsoft SQL Server 2012 RTM', 'SQL 2012', 11, 0, 2100, '2014-01-14'), 
			(22, 'Microsoft SQL Server 2012 Service Pack 1', 'SQL 2012', 11, 0, 3000, '2015-07-14'), 
			(23, 'Microsoft SQL Server 2012 Service Pack 2', 'SQL 2012', 11, 0, 5058, '2017-01-10'), 
			(24, 'Microsoft SQL Server 2014 RTM', 'SQL 2014', 12, 0, 2000, '2016-07-12'), 
			(25, 'Microsoft SQL Server 2014 Service Pack 1', 'SQL 2014', 12, 0, 4100, '2017-10-10'), 
			(26, 'Microsoft SQL Server 6.5 RTM-SP5a', 'SQL 6.5', 6, 50, 0, '2004-03-31'), 
			(27, 'Microsoft SQL Server 7.0 RTM-SP4', 'SQL 7', 7, 0, 0, '2011-01-11'), 
			(28, 'Microsoft SQL Server 2012 Service Pack 3', 'SQL 2012', 11, 0, 6020, '2022-07-12'), 
			(29, 'Microsoft SQL Server 2014 Service Pack 2', 'SQL 2014', 12, 0, 5000, '2024-07-09'), 
			(30, 'Microsoft SQL Server 2016 RTM', 'SQL 2016', 13, 0, 1601, '2018-01-19'), 
			(31, 'Microsoft SQL Server 2016 Service Pack 1', 'SQL 2016', 13, 0, 4001, '2026-07-14'), 
			(32, 'Microsoft SQL Server 2017 RTM', 'SQL 2017', 14, 0, 1000, '2027-10-12'), 
			(33, 'Microsoft SQL Server 2012 Service Pack 4', 'SQL 2012', 11, 0, 7001, '2022-07-12'), 
			(34, 'Microsoft SQL Server 2016 Service Pack 2', 'SQL 2016', 13, 0, 5026, '2026-07-14'), 
			(35, 'Microsoft SQL Server 2019 RTM', 'SQL 2019', 15, 0, 1000, '2030-01-08')


MERGE dbo.SQLVersions AS Target
USING (SELECT SQLVersionID, SQLVersion, SQLVersionShortName, SQLMajorVersion, SQLMinorVersion, SQLBuild, SQLVersionSupportEndDate FROM @SQLVersions) AS Source 
      (SQLVersionID, SQLVersion, SQLVersionShortName, SQLMajorVersion, SQLMinorVersion, SQLBuild, SQLVersionSupportEndDate)
ON (Target.SQLVersion = Source.SQLVersion)
WHEN NOT MATCHED THEN
	INSERT (SQLVersionID, SQLVersion, SQLVersionShortName, SQLMajorVersion, SQLMinorVersion, SQLBuild, SQLVersionSupportEndDate)
	VALUES (Source.SQLVersionID, Source.SQLVersion, Source.SQLVersionShortName, Source.SQLMajorVersion, Source.SQLMinorVersion, Source.SQLBuild, Source.SQLVersionSupportEndDate);

SET IDENTITY_INSERT dbo.SQLVersions OFF
GO
