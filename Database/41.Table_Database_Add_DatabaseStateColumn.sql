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

ALTER TABLE dbo.Databases
	DROP CONSTRAINT FK_Databases_SQLInstances
GO

ALTER TABLE dbo.SQLInstances SET (LOCK_ESCALATION = TABLE)
GO

COMMIT

BEGIN TRANSACTION
GO
ALTER TABLE dbo.Databases
	DROP CONSTRAINT DF_Databases_IsMonitored
GO

ALTER TABLE dbo.Databases
	DROP CONSTRAINT DF_Databases_DiscoveryOn
GO

ALTER TABLE dbo.Databases
	DROP CONSTRAINT DF_Databases_LastUpdated
GO

CREATE TABLE dbo.Tmp_Databases
	(
	DatabaseID int NOT NULL IDENTITY (1, 1),
	SQLInstanceID int NOT NULL,
	DatabaseName varchar(255) NOT NULL,
	DatabaseState varchar(60) NOT NULL,
	IsMonitored bit NOT NULL,
	DiscoveryOn date NOT NULL,
	LastUpdated date NOT NULL
	)  ON [PRIMARY]
GO
ALTER TABLE dbo.Tmp_Databases SET (LOCK_ESCALATION = TABLE)
GO
ALTER TABLE dbo.Tmp_Databases ADD CONSTRAINT
	DF_Databases_DatabaseState DEFAULT 'Online' FOR DatabaseState
GO
ALTER TABLE dbo.Tmp_Databases ADD CONSTRAINT
	DF_Databases_IsMonitored DEFAULT ((1)) FOR IsMonitored
GO
ALTER TABLE dbo.Tmp_Databases ADD CONSTRAINT
	DF_Databases_DiscoveryOn DEFAULT (getdate()) FOR DiscoveryOn
GO
ALTER TABLE dbo.Tmp_Databases ADD CONSTRAINT
	DF_Databases_LastUpdated DEFAULT (getdate()) FOR LastUpdated
GO
SET IDENTITY_INSERT dbo.Tmp_Databases ON
GO
IF EXISTS(SELECT * FROM dbo.Databases)
	 EXEC('INSERT INTO dbo.Tmp_Databases (DatabaseID, SQLInstanceID, DatabaseName, IsMonitored, DiscoveryOn, LastUpdated)
		SELECT DatabaseID, SQLInstanceID, DatabaseName, IsMonitored, DiscoveryOn, LastUpdated FROM dbo.Databases WITH (HOLDLOCK TABLOCKX)')
GO
SET IDENTITY_INSERT dbo.Tmp_Databases OFF
GO
ALTER TABLE dbo.AGDatabases
	DROP CONSTRAINT FK_AGDatabases_DatabaseID
GO
ALTER TABLE dbo.DatabaseSize
	DROP CONSTRAINT FK_DatabaseSize_Databases
GO
ALTER TABLE History.DatabaseSize
	DROP CONSTRAINT FK_DatabaseSize_Databases
GO
DROP TABLE dbo.Databases
GO
EXECUTE sp_rename N'dbo.Tmp_Databases', N'Databases', 'OBJECT' 
GO
ALTER TABLE dbo.Databases ADD CONSTRAINT
	PK_Databases PRIMARY KEY CLUSTERED 
	(
	DatabaseID
	) WITH( STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

GO
CREATE NONCLUSTERED INDEX idx_Databases_LastUpdated ON dbo.Databases
	(
	LastUpdated
	) WITH( PAD_INDEX = OFF, FILLFACTOR = 90, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE dbo.Databases ADD CONSTRAINT
	FK_Databases_SQLInstances FOREIGN KEY
	(
	SQLInstanceID
	) REFERENCES dbo.SQLInstances
	(
	SQLInstanceID
	) ON UPDATE  NO ACTION 
	 ON DELETE  NO ACTION 
	
GO
COMMIT
BEGIN TRANSACTION
GO
ALTER TABLE History.DatabaseSize ADD CONSTRAINT
	FK_DatabaseSize_Databases FOREIGN KEY
	(
	DatabaseID
	) REFERENCES dbo.Databases
	(
	DatabaseID
	) ON UPDATE  NO ACTION 
	 ON DELETE  NO ACTION 
	
GO
ALTER TABLE History.DatabaseSize SET (LOCK_ESCALATION = TABLE)
GO
COMMIT
BEGIN TRANSACTION
GO
ALTER TABLE dbo.DatabaseSize ADD CONSTRAINT
	FK_DatabaseSize_Databases FOREIGN KEY
	(
	DatabaseID
	) REFERENCES dbo.Databases
	(
	DatabaseID
	) ON UPDATE  NO ACTION 
	 ON DELETE  NO ACTION 
	
GO
ALTER TABLE dbo.DatabaseSize SET (LOCK_ESCALATION = TABLE)
GO
COMMIT
BEGIN TRANSACTION
GO
ALTER TABLE dbo.AGDatabases ADD CONSTRAINT
	FK_AGDatabases_DatabaseID FOREIGN KEY
	(
	DatabaseID
	) REFERENCES dbo.Databases
	(
	DatabaseID
	) ON UPDATE  NO ACTION 
	 ON DELETE  NO ACTION 
	
GO
ALTER TABLE dbo.AGDatabases SET (LOCK_ESCALATION = TABLE)
GO
COMMIT
