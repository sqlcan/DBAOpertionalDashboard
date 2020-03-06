USE [SQLOpsDB]
GO

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
ALTER TABLE dbo.SQLService
	DROP CONSTRAINT FK_SQLService_Servers
GO
ALTER TABLE dbo.Servers SET (LOCK_ESCALATION = TABLE)
GO
COMMIT
BEGIN TRANSACTION
GO
ALTER TABLE dbo.SQLService
	DROP CONSTRAINT DF__SQLServic__Disco__2C1E8537
GO
ALTER TABLE dbo.SQLService
	DROP CONSTRAINT DF__SQLServic__LastU__2D12A970
GO
CREATE TABLE dbo.Tmp_SQLService
	(
	SQLServiceID int NOT NULL IDENTITY (1, 1),
	ServerID int NULL,
	ServiceName varchar(255) NULL,
	InstanceName varchar(255) NULL,
	DisplayName varchar(255) NULL,
	FilePath varchar(512) NULL,
	ServiceType varchar(25) NULL,
	StartMode varchar(25) NULL,
	ServiceAccount varchar(50) NULL,
	ServiceVersion int NULL,
	ServiceBuild varchar(25) NULL,
	Status varchar(25) NULL,
	DiscoveryOn date NULL,
	LastUpdated date NULL
	)  ON [PRIMARY]
GO
ALTER TABLE dbo.Tmp_SQLService SET (LOCK_ESCALATION = TABLE)
GO
ALTER TABLE dbo.Tmp_SQLService ADD CONSTRAINT
	DF__SQLServic__Disco__2C1E8537 DEFAULT (getdate()) FOR DiscoveryOn
GO
ALTER TABLE dbo.Tmp_SQLService ADD CONSTRAINT
	DF__SQLServic__LastU__2D12A970 DEFAULT (getdate()) FOR LastUpdated
GO
SET IDENTITY_INSERT dbo.Tmp_SQLService ON
GO
IF EXISTS(SELECT * FROM dbo.SQLService)
	 EXEC('INSERT INTO dbo.Tmp_SQLService (SQLServiceID, ServerID, ServiceName, InstanceName, DisplayName, FilePath, ServiceType, StartMode, ServiceAccount, ServiceVersion, ServiceBuild, DiscoveryOn, LastUpdated)
		SELECT SQLServiceID, ServerID, ServiceName, InstanceName, DisplayName, FilePath, ServiceType, StartMode, ServiceAccount, ServiceVersion, ServiceBuild, DiscoveryOn, LastUpdated FROM dbo.SQLService WITH (HOLDLOCK TABLOCKX)')
GO
SET IDENTITY_INSERT dbo.Tmp_SQLService OFF
GO
DROP TABLE dbo.SQLService
GO
EXECUTE sp_rename N'dbo.Tmp_SQLService', N'SQLService', 'OBJECT' 
GO
ALTER TABLE dbo.SQLService ADD CONSTRAINT
	PK__SQLServi__1093A1B6F28BDEFA PRIMARY KEY CLUSTERED 
	(
	SQLServiceID
	) WITH( PAD_INDEX = OFF, FILLFACTOR = 90, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

GO
CREATE NONCLUSTERED INDEX idx_SQLService_ServerID ON dbo.SQLService
	(
	ServerID
	) WITH( PAD_INDEX = OFF, FILLFACTOR = 90, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE dbo.SQLService ADD CONSTRAINT
	FK_SQLService_Servers FOREIGN KEY
	(
	ServerID
	) REFERENCES dbo.Servers
	(
	ServerID
	) ON UPDATE  NO ACTION 
	 ON DELETE  NO ACTION 
	
GO
COMMIT
