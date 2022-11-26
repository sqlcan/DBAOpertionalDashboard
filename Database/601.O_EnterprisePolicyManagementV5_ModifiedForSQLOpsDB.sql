/*
SQLCMD script to generate the required objects to support a centralized Policy-Based Management solution.
This is the first script to run.
Set the variables to define the server and database which stores the Policy results.

This solution is copied as is from https://github.com/microsoft/sql-server-samples/tree/master/samples/features/epm-framework/5.0

Minor updated have been made:
* policy > Policy (Case)
* Database Name has to default to SQLOpsDB, as the SQL Opertional Dashboard is expecting all components to be 
  in the central database.
* Not run in SQLCMD Mode.
* Updated [pfn_ServerGroupInstances] to integrate with SQLOpsDB.
*/

--Create a schema to support the EPM framework objects.
USE [SQLOpsDB]
GO

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'Policy')
EXEC sys.sp_executesql N'CREATE SCHEMA [Policy] AUTHORIZATION [dbo]'

--Start create tables and indexes

--Create the table to store the results from the PowerShell evaluation.
IF NOT EXISTS(SELECT * FROM sys.objects WHERE type = N'U' AND name = N'PolicyHistory')
BEGIN 
	CREATE TABLE [Policy].[PolicyHistory](
		[PolicyHistoryID] [int] IDENTITY NOT NULL ,
		[EvaluatedServer] [nvarchar](50) NULL,
		[EvaluationDateTime] [datetime] NULL,
		[EvaluatedPolicy] [nvarchar](128) NULL,
		[EvaluationResults] [xml] NOT NULL,
		CONSTRAINT PK_PolicyHistory PRIMARY KEY CLUSTERED (PolicyHistoryID)
	)
	
	ALTER TABLE [Policy].[PolicyHistory] ADD CONSTRAINT [DF_PolicyHistory_EvaluationDateTime]  DEFAULT (GETDATE()) FOR [EvaluationDateTime]
END
GO
IF EXISTS(SELECT * FROM sys.columns WHERE object_id = object_id('Policy.Policyhistory')	AND name = 'PolicyResult')
	BEGIN 
		ALTER TABLE Policy.PolicyHistory
		DROP COLUMN PolicyResult
	END
GO
IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistory]') AND name = N'IX_EvaluationResults')
DROP INDEX IX_EvaluationResults ON Policy.PolicyHistory
GO
CREATE PRIMARY XML INDEX IX_EvaluationResults ON Policy.PolicyHistory (EvaluationResults)
GO

CREATE XML INDEX IX_EvaluationResults_PROPERTY ON Policy.PolicyHistory (EvaluationResults)
USING XML INDEX IX_EvaluationResults
FOR PROPERTY  
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistory]') AND name = N'IX_EvaluatedPolicy')
DROP INDEX IX_EvaluatedPolicy ON Policy.PolicyHistory
GO
CREATE INDEX IX_EvaluatedPolicy ON Policy.PolicyHistory(EvaluatedPolicy)
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistory]') AND name = N'IX_EvaluatedServer')
DROP INDEX IX_EvaluatedServer ON Policy.PolicyHistory
GO
CREATE INDEX IX_EvaluatedServer ON [Policy].[PolicyHistory] ([EvaluatedServer])
INCLUDE ([PolicyHistoryID],[EvaluationDateTime],[EvaluatedPolicy])
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistory]') AND name = N'IX_EvaluationDateTime')
DROP INDEX IX_EvaluationDateTime ON Policy.PolicyHistory
GO
CREATE INDEX IX_EvaluationDateTime ON Policy.PolicyHistory (EvaluationDateTime)
GO

--Create the table to store the error information from the failed PowerShell executions.
IF NOT EXISTS (SELECT * FROM sys.objects WHERE type = N'U' AND name = N'EvaluationErrorHistory')
BEGIN 
	CREATE TABLE [Policy].[EvaluationErrorHistory](
		[ErrorHistoryID] [int] IDENTITY(1,1) NOT NULL,
		[EvaluatedServer] [nvarchar](50) NULL,
		[EvaluationDateTime] [datetime] NULL,
		[EvaluatedPolicy] [nvarchar](128) NULL,
		[EvaluationResults] [nvarchar](max) NOT NULL,
		CONSTRAINT PK_EvaluationErrorHistory PRIMARY KEY CLUSTERED ([ErrorHistoryID] ASC)
	)

	ALTER TABLE [Policy].[EvaluationErrorHistory] ADD  CONSTRAINT [DF_EvaluationErrorHistory_EvaluationDateTime]  DEFAULT (getdate()) FOR [EvaluationDateTime]
END

IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[Policy].[EvaluationErrorHistory]') AND name = N'IX_EvaluationErrorHistoryView')
DROP INDEX IX_EvaluationErrorHistoryView ON Policy.EvaluationErrorHistory
GO
CREATE INDEX [IX_EvaluationErrorHistoryView] ON Policy.EvaluationErrorHistory ([EvaluatedPolicy] ASC, [EvaluatedServer] ASC, [EvaluationDateTime] DESC)
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[Policy].[EvaluationErrorHistory]') AND name = N'IX_EvaluationErrorHistoryPurge')
DROP INDEX IX_EvaluationErrorHistoryPurge ON Policy.EvaluationErrorHistory
GO
CREATE INDEX [IX_EvaluationErrorHistoryPurge] ON Policy.EvaluationErrorHistory ([EvaluationDateTime])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[EvaluationErrorHistory]') AND name = 'Stat_EvaluatedPolicy_ErrorHistoryID_EvaluatedServer' )
DROP STATISTICS Policy.[EvaluationErrorHistory].[Stat_EvaluatedPolicy_ErrorHistoryID_EvaluatedServer]
GO
CREATE STATISTICS [Stat_EvaluatedPolicy_ErrorHistoryID_EvaluatedServer] ON [Policy].[EvaluationErrorHistory]([EvaluatedPolicy], [ErrorHistoryID], [EvaluatedServer])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[EvaluationErrorHistory]') AND name = 'Stat_CategoryName_EvaluatedPolicy_EvaluationDateTime' )
DROP STATISTICS Policy.[EvaluationErrorHistory].[Stat_CategoryName_EvaluatedPolicy_EvaluationDateTime]
GO
CREATE STATISTICS [Stat_ErrorHistoryID_EvaluatedServer_EvaluationDateTime_EvaluatedPolicy] ON [Policy].[EvaluationErrorHistory]([ErrorHistoryID], [EvaluatedServer], [EvaluationDateTime], [EvaluatedPolicy])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[EvaluationErrorHistory]') AND name = 'Stat_CategoryName_EvaluatedPolicy_EvaluationDateTime' )
DROP STATISTICS Policy.[EvaluationErrorHistory].[Stat_CategoryName_EvaluatedPolicy_EvaluationDateTime]
GO
CREATE STATISTICS [Stat_ErrorHistoryID_EvaluatedServer_EvaluationDateTime] ON [Policy].[EvaluationErrorHistory]([ErrorHistoryID], [EvaluatedServer], [EvaluationDateTime])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[EvaluationErrorHistory]') AND name = 'Stat_CategoryName_EvaluatedPolicy_EvaluationDateTime' )
DROP STATISTICS Policy.[EvaluationErrorHistory].[Stat_CategoryName_EvaluatedPolicy_EvaluationDateTime]
GO
CREATE STATISTICS [Stat_ErrorHistoryID_EvaluatedPolicy_EvaluatedServer_EvaluationDateTime] ON [Policy].[EvaluationErrorHistory]([ErrorHistoryID], [EvaluatedPolicy], [EvaluatedServer], [EvaluationDateTime])
GO

--Create the table to store the Policy result details.
--This table is loaded with the procedure Policy.epm_LoadPolicyHistoryDetail or through the SQL Server SSIS Policy package.
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND type in (N'U'))
BEGIN
	CREATE TABLE [Policy].[PolicyHistoryDetail](
		[PolicyHistoryDetailID] [int] IDENTITY NOT NULL,
		[PolicyHistoryID] [int] NULL,
		[EvaluatedServer] [nvarchar](128) NULL,
		[EvaluationDateTime] [datetime] NULL,
		[MonthYear] [nvarchar](14) NULL,
		[EvaluatedPolicy] [nvarchar](128) NULL,
		[Policy_id] [int] NULL,
		[CategoryName] [nvarchar](128) NULL,
		[EvaluatedObject] [nvarchar](256) NULL,
		[PolicyResult] [nvarchar](5) NOT NULL,
		[ExceptionMessage] [nvarchar](max) NULL,
		[ResultDetail] [xml] NULL,
		[PolicyHistorySource] [nvarchar](50) NOT NULL,
		CONSTRAINT PK_PolicyHistoryDetail PRIMARY KEY CLUSTERED	([PolicyHistoryDetailID])
	)
END
GO

ALTER TABLE Policy.PolicyHistoryDetail ADD CONSTRAINT
	FK_PolicyHistoryDetail_PolicyHistory FOREIGN KEY
	(PolicyHistoryID) REFERENCES Policy.PolicyHistory
	(PolicyHistoryID) 
		ON UPDATE CASCADE 
		ON DELETE CASCADE
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = N'FK_PolicyHistoryID')
DROP INDEX FK_PolicyHistoryID ON Policy.PolicyHistoryDetail
GO
CREATE INDEX FK_PolicyHistoryID ON [Policy].[PolicyHistoryDetail] (PolicyHistoryID)
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = N'IX_EvaluatedPolicy')
DROP INDEX IX_EvaluatedPolicy ON Policy.PolicyHistoryDetail
GO
CREATE INDEX IX_EvaluatedPolicy ON [Policy].[PolicyHistoryDetail] ([EvaluatedPolicy]) 
INCLUDE ([PolicyHistoryID], [EvaluatedServer], [EvaluationDateTime], [MonthYear], [Policy_id], [CategoryName], [EvaluatedObject], [PolicyResult])
GO
IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = N'IX_PolicyHistoryView')
DROP INDEX IX_PolicyHistoryView ON Policy.PolicyHistoryDetail
GO
CREATE INDEX [IX_PolicyHistoryView] ON [Policy].[PolicyHistoryDetail] ([EvaluatedPolicy] ASC, [EvaluatedServer] ASC, [EvaluatedObject] ASC, [EvaluationDateTime] DESC, [PolicyResult] ASC, [Policy_id] ASC, CategoryName, MonthYear)
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = N'IX_PolicyHistoryView_2')
DROP INDEX IX_PolicyHistoryView_2 ON Policy.PolicyHistoryDetail
GO
CREATE INDEX [IX_PolicyHistoryView_2] ON [Policy].[PolicyHistoryDetail] ([EvaluatedPolicy] ASC ,[EvaluatedServer] ASC ,[EvaluationDateTime] ASC)
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = N'IX_EvaluatedServer_EvaluatedPolicy_EvaluatedObject_EvaluationDateTime')
DROP INDEX IX_EvaluatedServer_EvaluatedPolicy_EvaluatedObject_EvaluationDateTime ON Policy.PolicyHistoryDetail
GO
CREATE INDEX [IX_EvaluatedServer_EvaluatedPolicy_EvaluatedObject_EvaluationDateTime] ON [Policy].[PolicyHistoryDetail] ([EvaluatedServer] ASC, [EvaluatedPolicy] ASC, [EvaluatedObject] ASC, [EvaluationDateTime] ASC)
INCLUDE ([PolicyResult])
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = N'IX_EvaluatedPolicy_MonthYear')
DROP INDEX IX_EvaluatedPolicy_MonthYear ON Policy.PolicyHistoryDetail
GO
CREATE INDEX IX_EvaluatedPolicy_MonthYear ON [Policy].[PolicyHistoryDetail] ([EvaluatedPolicy],[MonthYear])
INCLUDE (EvaluationDateTime)
GO

--CREATE INDEX IX_CategoryName_EvaluatedPolicy ON [Policy].[PolicyHistoryDetail] ([CategoryName],[EvaluatedPolicy])
--GO

--CREATE INDEX IX_EvaluatedPolicy_CategoryName ON [Policy].[PolicyHistoryDetail] ([EvaluatedPolicy],[CategoryName])
--GO

IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = N'IX_EvaluatedPolicy_EvalDateTime_CategoryName')
DROP INDEX IX_EvaluatedPolicy_EvalDateTime_CategoryName ON Policy.PolicyHistoryDetail
GO
CREATE INDEX IX_EvaluatedPolicy_EvalDateTime_CategoryName ON [Policy].[PolicyHistoryDetail] ([EvaluatedPolicy],[EvaluationDateTime],[CategoryName])
INCLUDE ([PolicyHistoryDetailID],[MonthYear],[PolicyResult])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_EvaluatedServer_EvaluationDateTime' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_EvaluatedServer_EvaluationDateTime]
GO
CREATE STATISTICS [Stat_EvaluatedServer_EvaluationDateTime] ON [Policy].[PolicyHistoryDetail] ([EvaluatedServer], [EvaluationDateTime])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_EvaluatedPolicy_CategoryName' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_EvaluatedPolicy_CategoryName]
GO
CREATE STATISTICS [Stat_EvaluatedPolicy_CategoryName] ON [Policy].[PolicyHistoryDetail] ([EvaluatedPolicy], [CategoryName])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_EvaluatedPolicy_EvaluationDateTime' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_EvaluatedPolicy_EvaluationDateTime]
GO
CREATE STATISTICS [Stat_EvaluatedPolicy_EvaluationDateTime] ON [Policy].[PolicyHistoryDetail]([EvaluatedPolicy], [EvaluationDateTime])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_EvaluationDateTime_EvaluatedPolicy' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_EvaluationDateTime_EvaluatedPolicy]
GO
CREATE STATISTICS [Stat_EvaluationDateTime_EvaluatedPolicy] ON [Policy].[PolicyHistoryDetail]([EvaluationDateTime], [EvaluatedPolicy])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_CategoryName_EvaluatedServer') 
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_CategoryName_EvaluatedServer]
GO
CREATE STATISTICS [Stat_CategoryName_EvaluatedServer] ON [Policy].[PolicyHistoryDetail] ([CategoryName], [EvaluatedServer])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_PolicyResult_EvaluatedServer' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_PolicyResult_EvaluatedServer]
GO
CREATE STATISTICS [Stat_PolicyResult_EvaluatedServer] ON [Policy].[PolicyHistoryDetail] ([PolicyResult], [EvaluatedServer])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_EvaluatedPolicy_EvaluatedServer_CategoryName' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_EvaluatedPolicy_EvaluatedServer_CategoryName]
GO
CREATE STATISTICS [Stat_EvaluatedPolicy_EvaluatedServer_CategoryName] ON [Policy].[PolicyHistoryDetail] ([EvaluatedPolicy], [EvaluatedServer], [CategoryName])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_EvaluatedPolicy_PolicyResult_CategoryName')
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_EvaluatedPolicy_PolicyResult_CategoryName]
GO
CREATE STATISTICS [Stat_EvaluatedPolicy_PolicyResult_CategoryName] ON [Policy].[PolicyHistoryDetail] ([EvaluatedPolicy], [PolicyResult], [EvaluatedServer])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_EvaluatedPolicy_EvaluatedServer_EvaluationDateTime_PolicyResult_PolicyHistoryID_CategoryName' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_EvaluatedPolicy_EvaluatedServer_EvaluationDateTime_PolicyResult_PolicyHistoryID_CategoryName]
GO
CREATE STATISTICS [Stat_EvaluatedPolicy_EvaluatedServer_EvaluationDateTime_PolicyResult_PolicyHistoryID_CategoryName] ON [Policy].[PolicyHistoryDetail] ([EvaluatedPolicy], [EvaluatedServer], [EvaluationDateTime], [PolicyResult], [PolicyHistoryID], [CategoryName])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_CategoryName_PolicyResult' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_CategoryName_PolicyResult]
GO
CREATE STATISTICS Stat_CategoryName_PolicyResult ON [Policy].[PolicyHistoryDetail]([CategoryName], [PolicyResult])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_EvaluatedServer_PolicyHistoryDetailID_EvaluatedPolicy' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_EvaluatedServer_PolicyHistoryDetailID_EvaluatedPolicy]
GO
CREATE STATISTICS Stat_EvaluatedServer_PolicyHistoryDetailID_EvaluatedPolicy ON [Policy].[PolicyHistoryDetail]([EvaluatedServer], [PolicyHistoryDetailID], [EvaluatedPolicy])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_EvaluatedPolicy_CategoryName_PolicyResult_EvaluationDateTime' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_EvaluatedPolicy_CategoryName_PolicyResult_EvaluationDateTime]
GO
CREATE STATISTICS Stat_EvaluatedPolicy_CategoryName_PolicyResult_EvaluationDateTime ON [Policy].[PolicyHistoryDetail]([EvaluatedPolicy], [CategoryName], [PolicyResult], [EvaluationDateTime])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_EvaluatedPolicy_EvaluatedServer_PolicyHistoryDetailID_CategoryName_PolicyResult' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_EvaluatedPolicy_EvaluatedServer_PolicyHistoryDetailID_CategoryName_PolicyResult]
GO
CREATE STATISTICS Stat_EvaluatedPolicy_EvaluatedServer_PolicyHistoryDetailID_CategoryName_PolicyResult ON [Policy].[PolicyHistoryDetail]([EvaluatedPolicy], [EvaluatedServer], [PolicyHistoryDetailID], [CategoryName], [PolicyResult])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_EvaluatedServer_CategoryName_PolicyResult_EvaluatedPolicy_EvaluationDateTime_PolicyHistoryDetailID' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_EvaluatedServer_CategoryName_PolicyResult_EvaluatedPolicy_EvaluationDateTime_PolicyHistoryDetailID]
GO
CREATE STATISTICS Stat_EvaluatedServer_CategoryName_PolicyResult_EvaluatedPolicy_EvaluationDateTime_PolicyHistoryDetailID ON [Policy].[PolicyHistoryDetail]([EvaluatedServer], [CategoryName], [PolicyResult], [EvaluatedPolicy], [EvaluationDateTime], [PolicyHistoryDetailID])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_CategoryName_EvaluatedPolicy_EvaluationDateTime' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_CategoryName_EvaluatedPolicy_EvaluationDateTime]
GO
CREATE STATISTICS [Stat_CategoryName_EvaluatedPolicy_EvaluationDateTime] ON [Policy].[PolicyHistoryDetail]([CategoryName], [EvaluatedPolicy], [EvaluationDateTime])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_PolicyHistoryID_EvaluatedServer_EvaluationDateTime_CategoryName' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_PolicyHistoryID_EvaluatedServer_EvaluationDateTime_CategoryName]
GO
CREATE STATISTICS [Stat_PolicyHistoryID_EvaluatedServer_EvaluationDateTime_CategoryName] ON [Policy].[PolicyHistoryDetail]([PolicyHistoryID], [EvaluatedServer], [EvaluationDateTime], [CategoryName])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_EvaluatedServer_EvaluatedServer_EvaluationDateTime_PolicyResult' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_EvaluatedServer_EvaluatedServer_EvaluationDateTime_PolicyResult]
GO
CREATE STATISTICS [Stat_EvaluatedServer_EvaluatedServer_EvaluationDateTime_PolicyResult] ON [Policy].[PolicyHistoryDetail]([EvaluatedServer], [EvaluatedObject], [EvaluationDateTime], [PolicyResult])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_EvaluatedPolicy_1_EvaluatedServer_EvaluationDateTime' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_EvaluatedPolicy_1_EvaluatedServer_EvaluationDateTime]
GO
CREATE STATISTICS [Stat_EvaluatedPolicy_1_EvaluatedServer_EvaluationDateTime] ON [Policy].[PolicyHistoryDetail]([EvaluatedPolicy], [PolicyHistoryDetailID], [EvaluatedServer], [EvaluationDateTime])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_EvaluationDateTime_EvaluatedPolicy_PolicyHistoryDetailID_PolicyResult' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_EvaluationDateTime_EvaluatedPolicy_PolicyHistoryDetailID_PolicyResult]
GO
CREATE STATISTICS [Stat_EvaluationDateTime_EvaluatedPolicy_PolicyHistoryDetailID_PolicyResult] ON [Policy].[PolicyHistoryDetail]([EvaluationDateTime], [EvaluatedPolicy], [PolicyHistoryDetailID], [PolicyResult])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_PolicyResult_EvaluatedPolicy_PolicyHistoryDetailID_EvaluatedServer' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_PolicyResult_EvaluatedPolicy_PolicyHistoryDetailID_EvaluatedServer]
GO
CREATE STATISTICS [Stat_PolicyResult_EvaluatedPolicy_PolicyHistoryDetailID_EvaluatedServer] ON [Policy].[PolicyHistoryDetail]([PolicyResult], [EvaluatedPolicy], [PolicyHistoryDetailID], [EvaluatedServer])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_PolicyHistoryDetailID_PolicyHistoryID_EvaluatedPolicy_EvaluatedServer_EvaluationDateTime' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_PolicyHistoryDetailID_PolicyHistoryID_EvaluatedPolicy_EvaluatedServer_EvaluationDateTime]
GO
CREATE STATISTICS [Stat_PolicyHistoryDetailID_PolicyHistoryID_EvaluatedPolicy_EvaluatedServer_EvaluationDateTime] ON [Policy].[PolicyHistoryDetail]([PolicyHistoryDetailID], [PolicyHistoryID], [EvaluatedPolicy], [EvaluatedServer], [EvaluationDateTime])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_PolicyHistoryID_EvaluatedServer_EvaluationDateTime_EvaluatedPolicy_Policy_id' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_PolicyHistoryID_EvaluatedServer_EvaluationDateTime_EvaluatedPolicy_Policy_id]
GO
CREATE STATISTICS [Stat_PolicyHistoryID_EvaluatedServer_EvaluationDateTime_EvaluatedPolicy_Policy_id] ON [Policy].[PolicyHistoryDetail]([PolicyHistoryID], [EvaluatedServer], [EvaluationDateTime], [EvaluatedPolicy], [Policy_id])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_EvaluatedServer_EvaluationDateTime_EvaluatedPolicy_Policy_id_CategoryName_PolicyHistoryID' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_EvaluatedServer_EvaluationDateTime_EvaluatedPolicy_Policy_id_CategoryName_PolicyHistoryID]
GO
CREATE STATISTICS [Stat_EvaluatedServer_EvaluationDateTime_EvaluatedPolicy_Policy_id_CategoryName_PolicyHistoryID] ON [Policy].[PolicyHistoryDetail]([EvaluatedServer], [EvaluationDateTime], [EvaluatedPolicy], [Policy_id], [CategoryName], [PolicyHistoryID])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_EvaluatedPolicy_EvaluatedPolicy_EvaluatedServer_EvaluationDateTime_PolicyHistoryDetailID_Policy_id_CategoryName' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_EvaluatedPolicy_EvaluatedPolicy_EvaluatedServer_EvaluationDateTime_PolicyHistoryDetailID_Policy_id_CategoryName]
GO
CREATE STATISTICS [Stat_EvaluatedPolicy_EvaluatedPolicy_EvaluatedServer_EvaluationDateTime_PolicyHistoryDetailID_Policy_id_CategoryName] ON [Policy].[PolicyHistoryDetail]([EvaluatedPolicy], [PolicyResult], [EvaluatedServer], [EvaluationDateTime], [PolicyHistoryDetailID], [Policy_id], [CategoryName])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_EvaluatedPolicy_EvaluatedServer_EvaluatedPolicy_EvaluationDateTime_PolicyHistoryDetailID_PolicyHistoryID' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_EvaluatedPolicy_EvaluatedServer_EvaluatedPolicy_EvaluationDateTime_PolicyHistoryDetailID_PolicyHistoryID]
GO
CREATE STATISTICS [Stat_EvaluatedPolicy_EvaluatedServer_EvaluatedPolicy_EvaluationDateTime_PolicyHistoryDetailID_PolicyHistoryID] ON [Policy].[PolicyHistoryDetail]([EvaluatedPolicy], [EvaluatedServer], [PolicyResult], [EvaluationDateTime], [PolicyHistoryDetailID], [PolicyHistoryID], [Policy_id], [CategoryName])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_EvaluationDateTime_EvaluatedPolicy_PolicyResult' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_EvaluationDateTime_EvaluatedPolicy_PolicyResult]
GO
CREATE STATISTICS [Stat_EvaluationDateTime_EvaluatedPolicy_PolicyResult] ON [Policy].[PolicyHistoryDetail]([EvaluationDateTime], [EvaluatedPolicy], [PolicyResult])
GO

IF EXISTS(SELECT * FROM sys.stats WHERE object_id = OBJECT_ID(N'[Policy].[PolicyHistoryDetail]') AND name = 'Stat_PolicyHistoryID_EvaluatedServer_EvaluationDateTime_EvaluatedPolicy_CategoryName' )
DROP STATISTICS Policy.[PolicyHistoryDetail].[Stat_PolicyHistoryID_EvaluatedServer_EvaluationDateTime_EvaluatedPolicy_CategoryName]
GO
CREATE STATISTICS [Stat_PolicyHistoryID_EvaluatedServer_EvaluationDateTime_EvaluatedPolicy_CategoryName] ON [Policy].[PolicyHistoryDetail]([PolicyHistoryID], [EvaluatedServer], [EvaluationDateTime], [EvaluatedPolicy], [CategoryName])
GO

--Create the function to support server selection.
--The following function will support nested CMS folders for the EPM Framework.
--The function must be created in a database ON the CMS server. 
--This database will also store the Policy history. 

USE SQLOpsDB
GO
CREATE OR ALTER FUNCTION [Policy].[pfn_ServerGroupInstances] (@GroupName NVARCHAR(256))
RETURNS TABLE
AS
RETURN(WITH Groups(GroupID, GroupName) AS
             (
                    SELECT server_group_id, CAST(name AS VARCHAR(75))
               FROM msdb.dbo.sysmanagement_shared_server_groups
               WHERE parent_id IS NULL
 
           UNION ALL
 
           SELECT server_group_id, CAST(GroupName + '\' + CAST(name AS VARCHAR(100)) AS VARCHAR(75))
               FROM msdb.dbo.sysmanagement_shared_server_groups SSG
               JOIN Groups G
               ON SSG.parent_id = G.GroupID
             )
             SELECT s.server_name, GroupName
             FROM [msdb].[dbo].[sysmanagement_shared_registered_servers_internal] s
             INNER JOIN Groups SG ON s.server_group_id = sg.GroupID
             WHERE ((GroupName = @GroupName) OR (@GroupName = ''))
)
GO

--Create the views which are used in the Policy reports

--Drop the view if it exists.  
IF  EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[Policy].[v_ServerGroups]'))
DROP VIEW [Policy].[v_ServerGroups]
GO
CREATE VIEW Policy.v_ServerGroups AS 
WITH ServerGroups(parent_id, server_group_id, GroupName, GroupLevel, Sort, GroupValue) 
AS 
(SELECT parent_id
		, server_group_id
		, CAST('ALL' AS varchar(500))
		, 1 AS GroupLevel 
		, CAST('ALL' AS varchar(500)) AS Sort
		, CAST('' AS varchar(255)) AS GroupValue
FROM msdb.dbo.sysmanagement_shared_server_groups tg
WHERE server_type = 0 AND parent_id IS NULL
UNION ALL
SELECT cg.parent_id
	, cg.server_group_id
	, CAST(REPLICATE('  ', GroupLevel) + cg.name AS varchar(500))
	, GroupLevel + 1
	, CAST(Sort + ' | ' + cg.name AS varchar(500)) AS Sort
	, CAST(name AS varchar(255)) AS GroupValue
FROM msdb.dbo.sysmanagement_shared_server_groups cg
INNER JOIN ServerGroups pg ON cg.parent_id = pg.server_group_id)
		
SELECT parent_id, server_group_id, GroupName, GroupLevel, Sort, GroupValue
FROM ServerGroups 
GO			

--Create the procedure epm_LoadPolicyHistoryDetail will load the details from the XML documents in PolicyHistory to the PolicyHistoryDetails table.
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[Policy].[epm_LoadPolicyHistoryDetail]') AND type in (N'P', N'PC'))
DROP PROCEDURE [Policy].[epm_LoadPolicyHistoryDetail]
GO
CREATE PROCEDURE Policy.epm_LoadPolicyHistoryDetail @PolicyCategoryFilter VARCHAR(255)
AS
SET NOCOUNT ON;

IF @PolicyCategoryFilter = ''
SET @PolicyCategoryFilter = NULL

DECLARE @sqlcmd VARCHAR(8000), @Text NVARCHAR(255), @Remain int
SELECT @Text = CONVERT(varchar, GETDATE(), 9) + ' - Starting data integration for ' + CASE WHEN @PolicyCategoryFilter IS NULL THEN 'ALL categories' ELSE 'Category ' + @PolicyCategoryFilter END
RAISERROR (@Text, 10, 1) WITH NOWAIT;

--Insert the evaluation results.
SELECT @sqlcmd = ';WITH XMLNAMESPACES (''http://schemas.microsoft.com/sqlserver/DMF/2007/08'' AS DMF)
,cteEval AS (SELECT PH.PolicyHistoryID
	, PH.EvaluatedServer
	, PH.EvaluationDateTime
	, PH.EvaluatedPolicy
	, Res.Expr.value(''(../DMF:TargetQueryExpression)[1]'', ''nvarchar(150)'') AS EvaluatedObject
	, (CASE WHEN Res.Expr.value(''(../DMF:Result)[1]'', ''nvarchar(150)'') = ''FALSE'' AND Expr.value(''(../DMF:Exception)[1]'', ''nvarchar(max)'') = ''''
	THEN ''FAIL''
	WHEN Res.Expr.value(''(../DMF:Result)[1]'', ''nvarchar(150)'')= ''FALSE'' AND Expr.value(''(../DMF:Exception)[1]'', ''nvarchar(max)'') <> ''''
						   THEN ''ERROR''
						   ELSE ''PASS''
						END) AS PolicyResult
					, Expr.value(''(../DMF:Exception)[1]'', ''nvarchar(max)'') AS ExceptionMessage
					, CAST(Expr.value(''(../DMF:ResultDetail)[1]'', ''nvarchar(max)'')AS XML) AS ResultDetail
					, p.Policy_id
					, c.name AS CategoryName
					, datename(month, EvaluationDateTime) + '' '' + datename(year, EvaluationDateTime) AS MonthYear
					, ''PowerShell EPM Framework'' AS PolicyHistorySource
					, DENSE_RANK() OVER (PARTITION BY Res.Expr.value(''(../DMF:TargetQueryExpression)[1]'', ''nvarchar(150)'') ORDER BY Expr) AS [TopRank]
				FROM Policy.PolicyHistory AS PH
				INNER JOIN msdb.dbo.sysPolicy_policies AS p ON p.name = PH.EvaluatedPolicy
				INNER JOIN msdb.dbo.sysPolicy_Policy_categories AS c ON p.Policy_category_id = c.Policy_category_id
				CROSS APPLY EvaluationResults.nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/DMF/2007/08";
					//TargetQueryExpression''
					) AS Res(Expr)
				WHERE NOT EXISTS (SELECT DISTINCT PHD.PolicyHistoryID FROM Policy.PolicyHistoryDetail PHD WITH(NOLOCK) WHERE PHD.PolicyHistoryID = PH.PolicyHistoryID AND PHD.ResultDetail IS NOT NULL)
					' + CASE WHEN @PolicyCategoryFilter IS NULL THEN '' ELSE 'AND c.name = ''' + @PolicyCategoryFilter + '''' END + '
					AND EvaluationResults.exist(''declare namespace DMF="http://schemas.microsoft.com/sqlserver/DMF/2007/08";
						 //DMF:EvaluationDetail'') = 1)
INSERT INTO Policy.PolicyHistoryDetail (
	PolicyHistoryID
	, EvaluatedServer
	, EvaluationDateTime
	, EvaluatedPolicy
	, EvaluatedObject
	, PolicyResult
	, ExceptionMessage
	, ResultDetail
	, Policy_id
	, CategoryName
	, MonthYear
	, PolicyHistorySource
)
SELECT PolicyHistoryID
	, EvaluatedServer
	, EvaluationDateTime
	, EvaluatedPolicy
	, EvaluatedObject
	, PolicyResult
	, ExceptionMessage
	, ResultDetail
	, Policy_id
	, CategoryName
	, MonthYear
	, PolicyHistorySource 
FROM cteEval
WHERE cteEval.[TopRank] = 1'; -- Remove duplicates

EXEC (@sqlcmd);

SELECT @Text = CONVERT(NVARCHAR, GETDATE(), 9) + '   |- ' + CONVERT(NVARCHAR, @@ROWCOUNT) + ' rows inserted...'
RAISERROR (@Text, 10, 1) WITH NOWAIT;

SELECT @Text = CONVERT(varchar, GETDATE(), 9) + ' - Starting no target data integration'
RAISERROR (@Text, 10, 1) WITH NOWAIT;

--Insert the policies that evaluated with no target	
SELECT @sqlcmd = ';WITH XMLNAMESPACES (''http://schemas.microsoft.com/sqlserver/DMF/2007/08'' AS DMF)
INSERT INTO Policy.PolicyHistoryDetail	(		
	PolicyHistoryID
	, EvaluatedServer
	, EvaluationDateTime
	, EvaluatedPolicy
	, EvaluatedObject
	, PolicyResult
	, ExceptionMessage
	, ResultDetail
	, Policy_id
	, CategoryName
	, MonthYear
	, PolicyHistorySource
	)
SELECT PH.PolicyHistoryID
	, PH.EvaluatedServer
	, PH.EvaluationDateTime
	, PH.EvaluatedPolicy
	, ''No Targets Found'' AS EvaluatedObject
	, (CASE WHEN Res.Expr.value(''(../DMF:Result)[1]'', ''nvarchar(150)'')= ''FALSE'' AND Expr.value(''(../DMF:Exception)[1]'', ''nvarchar(max)'') = ''''
		   THEN ''FAIL'' 
		   WHEN Res.Expr.value(''(../DMF:Result)[1]'', ''nvarchar(150)'')= ''FALSE'' AND Expr.value(''(../DMF:Exception)[1]'', ''nvarchar(max)'')<> ''''
		   THEN ''ERROR''
		   ELSE ''PASS'' 
		END) AS PolicyResult
	, Expr.value(''(../DMF:Exception)[1]'', ''nvarchar(max)'') AS ExceptionMessage
	, NULL AS ResultDetail
	, p.Policy_id
	, c.name AS CategoryName
	, datename(month, EvaluationDateTime) + '' '' + datename(year, EvaluationDateTime)  AS MonthYear
	, ''PowerShell EPM Framework''
FROM Policy.PolicyHistory AS PH
INNER JOIN msdb.dbo.sysPolicy_policies AS p ON p.name = PH.EvaluatedPolicy
INNER JOIN msdb.dbo.sysPolicy_Policy_categories AS c ON p.Policy_category_id = c.Policy_category_id
CROSS APPLY EvaluationResults.nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/DMF/2007/08";
	//DMF:ServerInstance''
	) AS Res(Expr)
WHERE NOT EXISTS (SELECT DISTINCT PHD.PolicyHistoryID FROM Policy.PolicyHistoryDetail PHD WITH(NOLOCK) WHERE PHD.PolicyHistoryID = PH.PolicyHistoryID AND PHD.ResultDetail IS NULL)
	' + CASE WHEN @PolicyCategoryFilter IS NULL THEN '' ELSE 'AND c.name = ''' + @PolicyCategoryFilter + '''' END + '
	AND EvaluationResults.exist(''declare namespace DMF="http://schemas.microsoft.com/sqlserver/DMF/2007/08";
	 //DMF:EvaluationDetail'') = 0
ORDER BY DENSE_RANK() OVER (ORDER BY Expr);' -- Remove duplicates

EXEC (@sqlcmd);

SELECT @Text = CONVERT(NVARCHAR, GETDATE(), 9) + '   |- ' + CONVERT(NVARCHAR, @@ROWCOUNT) + ' rows inserted...'
RAISERROR (@Text, 10, 1) WITH NOWAIT;

SELECT @Text = CONVERT(varchar, GETDATE(), 9) + ' - Starting errors data integration'
RAISERROR (@Text, 10, 1) WITH NOWAIT;

--Insert the error records
SELECT @sqlcmd = ';WITH XMLNAMESPACES (''http://schemas.microsoft.com/sqlserver/DMF/2007/08'' AS DMF)
INSERT INTO Policy.EvaluationErrorHistory(		
	EvaluatedServer
	, EvaluationDateTime
	, EvaluatedPolicy
	, EvaluationResults
	)
SELECT PH.EvaluatedServer
	, PH.EvaluationDateTime
	, PH.EvaluatedPolicy
	, Expr.value(''(../DMF:Exception)[1]'', ''nvarchar(max)'') AS ExceptionMessage
FROM Policy.PolicyHistory AS PH
INNER JOIN msdb.dbo.sysPolicy_policies AS p ON p.name = PH.EvaluatedPolicy
INNER JOIN msdb.dbo.sysPolicy_Policy_categories AS c ON p.Policy_category_id = c.Policy_category_id
CROSS APPLY EvaluationResults.nodes(''declare default element namespace "http://schemas.microsoft.com/sqlserver/DMF/2007/08";
	//DMF:ServerInstance''
	) AS Res(Expr)
WHERE PH.PolicyHistoryID NOT IN (SELECT DISTINCT PH.PolicyHistoryID FROM Policy.EvaluationErrorHistory AS PHD WITH(NOLOCK) INNER JOIN Policy.PolicyHistory AS PH WITH(NOLOCK) ON PH.EvaluatedServer = PHD.EvaluatedServer AND PH.EvaluationDateTime = PHD.EvaluationDateTime AND PH.EvaluatedPolicy = PHD.EvaluatedPolicy)
	' + CASE WHEN @PolicyCategoryFilter IS NULL THEN '' ELSE 'AND c.name = ''' + @PolicyCategoryFilter + '''' END + '
	AND Expr.value(''(../DMF:Exception)[1]'', ''nvarchar(max)'') <> ''''
	--AND Res.Expr.value(''(../DMF:Result)[1]'', ''nvarchar(150)'') = ''FALSE''
ORDER BY DENSE_RANK() OVER (ORDER BY Expr);' -- Remove duplicates

EXEC (@sqlcmd);

SELECT @Text = CONVERT(NVARCHAR, GETDATE(), 9) + '   |- ' + CONVERT(NVARCHAR, @@ROWCOUNT) + ' rows inserted...'
RAISERROR (@Text, 10, 1) WITH NOWAIT;

SELECT @Text = CONVERT(varchar, GETDATE(), 9) + ' - Finished data integration for ' + CASE WHEN @PolicyCategoryFilter IS NULL THEN 'ALL categories' ELSE 'Category ' + @PolicyCategoryFilter END
RAISERROR (@Text, 10, 1) WITH NOWAIT;
GO

USE SQLOpsDB
GO
EXEC Policy.epm_LoadPolicyHistoryDetail NULL
GO

USE SQLOpsDB
GO
IF (SELECT SERVERPROPERTY('EditionID')) IN (1804890536, 1872460670, 610778273, -2117995310)	-- Supports Enterprise only features
BEGIN
	ALTER INDEX [PK_EvaluationErrorHistory] ON [Policy].[EvaluationErrorHistory] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
	ALTER INDEX [PK_PolicyHistoryDetail] ON [Policy].[PolicyHistoryDetail] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
	ALTER INDEX [PK_PolicyHistory] ON [Policy].[PolicyHistory] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = PAGE)
END;
GO
