USE [SQLOpsDB]
GO

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
GO

ALTER TABLE [dbo].[SQLService]  WITH CHECK ADD  CONSTRAINT [FK_SQLService_Servers] FOREIGN KEY([ServerID])
REFERENCES [dbo].[Servers] ([ServerID])
GO

ALTER TABLE [dbo].[SQLService] CHECK CONSTRAINT [FK_SQLService_Servers]
GO

CREATE INDEX idx_SQLService_ServerID ON dbo.SQLService(ServerID)
GO