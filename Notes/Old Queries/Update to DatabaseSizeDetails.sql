/*
   Thursday, July 14, 20162:22:24 PM
   User: 
   Server: WSSQLTOOLS01T\CMS
   Database: DBA_Resource_Test
   Application: 
*/

/* To prevent any potential data loss issues, you should review this script in detail before running it outside the context of the database designer.*/
BEGIN TRANSACTION
SET QUOTED_IDENTIFIER ON
SET ARITHABORT ON
SET NUMERIC_ROUNDABORT OFF
SET CONCAT_NULL_YIELDS_NULL ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
COMMIT
BEGIN TRANSACTION
GO
CREATE TABLE Staging.Tmp_DatabaseSizeDetails
	(
	SQLInstanceID int NULL,
	AGGuid uniqueidentifier NULL,
	DatabaseName varchar(255) NULL,
	FileType char(4) NULL,
	FileSize_mb bigint NULL
	)  ON [PRIMARY]
GO
ALTER TABLE Staging.Tmp_DatabaseSizeDetails SET (LOCK_ESCALATION = TABLE)
GO
IF EXISTS(SELECT * FROM Staging.DatabaseSizeDetails)
	 EXEC('INSERT INTO Staging.Tmp_DatabaseSizeDetails (SQLInstanceID, DatabaseName, FileType, FileSize_mb)
		SELECT SQLInstanceID, DatabaseName, FileType, FileSize_mb FROM Staging.DatabaseSizeDetails WITH (HOLDLOCK TABLOCKX)')
GO
DROP TABLE Staging.DatabaseSizeDetails
GO
EXECUTE sp_rename N'Staging.Tmp_DatabaseSizeDetails', N'DatabaseSizeDetails', 'OBJECT' 
GO
COMMIT
