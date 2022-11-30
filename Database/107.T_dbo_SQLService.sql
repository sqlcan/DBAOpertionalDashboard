--     Purpose: This table stores names of each operation system as full discription and their short names.
--
--              If table already exists the table is ignored.
-- 
-- NOTE: No changes since release.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.01
-- Last Tested: Nov. 26, 2022

USE [SQLOpsDB]
GO

CREATE TABLE dbo.SQLService (SQLServiceID INT IDENTITY (1,1) NOT NULL,
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
							 LastUpdated DATE DEFAULT(GetDate()),
							CONSTRAINT [PK_SQLService] PRIMARY KEY CLUSTERED 
							( [SQLServiceID] ASC)
							WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY])

ALTER TABLE [dbo].[SQLService]  WITH CHECK ADD  CONSTRAINT [FK_SQLService_Servers] FOREIGN KEY([ServerID])
REFERENCES [dbo].[Servers] ([ServerID])

ALTER TABLE [dbo].[SQLService] CHECK CONSTRAINT [FK_SQLService_Servers]

