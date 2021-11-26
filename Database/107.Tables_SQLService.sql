--     Purpose: This table stores names of each operation system as full discription and their short names.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: No changes since release.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

USE [SQLOpsDB]
GO

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'SQLService')
BEGIN

	CREATE TABLE dbo.SQLService (SQLServiceID INT PRIMARY KEY IDENTITY (1,1) NOT NULL,
								 ServerID INT,
								 ServiceName VARCHAR(255),
								 InstanceName VARCHAR(255),
								 DisplayName VARCHAR(255),
								 FilePath VARCHAR(512),
								 ServiceType VARCHAR(25),
								 StartMode VARCHAR(25),
								 ServiceAccount VARCHAR(50),
								 ServiceVersion INT,
								 ServiceBuild VARCHAR(25),
								 Status VARCHAR(25),
								 DiscoveryOn DATE DEFAULT(GetDate()),
								 LastUpdated DATE DEFAULT(GetDate()))

	ALTER TABLE [dbo].[SQLService]  WITH CHECK ADD  CONSTRAINT [FK_SQLService_Servers] FOREIGN KEY([ServerID])
	REFERENCES [dbo].[Servers] ([ServerID])

	ALTER TABLE [dbo].[SQLService] CHECK CONSTRAINT [FK_SQLService_Servers]

	CREATE INDEX idx_SQLService_ServerID ON dbo.SQLService(ServerID)

END