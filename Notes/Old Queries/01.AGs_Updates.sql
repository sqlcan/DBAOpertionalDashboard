/*
   Tuesday, December 13, 201612:48:09 PM
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
ALTER TABLE dbo.AGs
	DROP CONSTRAINT DF_AGs_DiscoveryOn
GO
ALTER TABLE dbo.AGs
	DROP CONSTRAINT DF_AGs_LastUpdated
GO
CREATE TABLE dbo.Tmp_AGs
	(
	AGID int NOT NULL IDENTITY (1, 1),
	AGName varchar(255) NOT NULL,
	AGGuid uniqueidentifier NOT NULL,
	DiscoveryOn date NOT NULL,
	LastUpdated date NOT NULL
	)  ON [PRIMARY]
GO
ALTER TABLE dbo.Tmp_AGs SET (LOCK_ESCALATION = TABLE)
GO
ALTER TABLE dbo.Tmp_AGs ADD CONSTRAINT
	DF_AGs_AGGuid DEFAULT '00000000-0000-0000-0000-000000000000' FOR AGGuid
GO
ALTER TABLE dbo.Tmp_AGs ADD CONSTRAINT
	DF_AGs_DiscoveryOn DEFAULT (getdate()) FOR DiscoveryOn
GO
ALTER TABLE dbo.Tmp_AGs ADD CONSTRAINT
	DF_AGs_LastUpdated DEFAULT (getdate()) FOR LastUpdated
GO
SET IDENTITY_INSERT dbo.Tmp_AGs ON
GO
IF EXISTS(SELECT * FROM dbo.AGs)
	 EXEC('INSERT INTO dbo.Tmp_AGs (AGID, AGName, DiscoveryOn, LastUpdated)
		SELECT AGID, AGName, DiscoveryOn, LastUpdated FROM dbo.AGs WITH (HOLDLOCK TABLOCKX)')
GO
SET IDENTITY_INSERT dbo.Tmp_AGs OFF
GO
ALTER TABLE dbo.AGInstances
	DROP CONSTRAINT FK_AGInstance_AGID
GO
DROP TABLE dbo.AGs
GO
EXECUTE sp_rename N'dbo.Tmp_AGs', N'AGs', 'OBJECT' 
GO
ALTER TABLE dbo.AGs ADD CONSTRAINT
	PK_AG PRIMARY KEY CLUSTERED 
	(
	AGID
	) WITH( STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

GO
COMMIT
BEGIN TRANSACTION
GO
ALTER TABLE dbo.AGInstances ADD CONSTRAINT
	FK_AGInstance_AGID FOREIGN KEY
	(
	AGID
	) REFERENCES dbo.AGs
	(
	AGID
	) ON UPDATE  NO ACTION 
	 ON DELETE  NO ACTION 
	
GO
ALTER TABLE dbo.AGInstances SET (LOCK_ESCALATION = TABLE)
GO
COMMIT
