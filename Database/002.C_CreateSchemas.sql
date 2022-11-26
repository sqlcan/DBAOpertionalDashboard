--     Purpose: Create required schemas for the database.  
--              These schemas are required for various functionality.
--
--              DBO       | Default schema stores all the data.
--              STAGING   | Stores all the data being pulled for a given execution.
--                         Used to minimize RBAR operations.
--              HISTORY   | Stores tables that store data in an aggregate fashion past
--                         the raw data retention policy.
--              TRENDING  | Stores data for various metrics for providing trending for
--                         month-over-month change.
--              CMS       | Stores data related to objects from Central Management Server.
--              Policy    | Stores data for Policy Based Management data.
--              Snapshot  | Snapshot of the daily stats.
--              Expired   | Objects past 90-days Old
--				Security  | Login & User information from all instances.
--				Reporting | Hold objects related to reporting needs only.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00.01
-- Last Tested: Oct. 17, 2020

USE [SQLOpsDB]
GO

-- Must wrap the Create Schema command in dynamic SQL.  As 
-- you are not allowed to execute any other code with Create Schema.
IF NOT (EXISTS (SELECT * FROM sys.schemas WHERE NAME = 'Staging'))
	EXEC ('CREATE SCHEMA [Staging]')
GO

IF NOT (EXISTS (SELECT * FROM sys.schemas WHERE NAME = 'History'))
	EXEC ('CREATE SCHEMA [History]')
GO

IF NOT (EXISTS (SELECT * FROM sys.schemas WHERE NAME = 'Trending'))
	EXEC ('CREATE SCHEMA [Trending]')
GO

IF NOT (EXISTS (SELECT * FROM sys.schemas WHERE NAME = 'Policy'))
	EXEC ('CREATE SCHEMA [Policy]')
GO

IF NOT (EXISTS (SELECT * FROM sys.schemas WHERE NAME = 'CMS'))
	EXEC ('CREATE SCHEMA [CMS]')
GO

IF NOT (EXISTS (SELECT * FROM sys.schemas WHERE NAME = 'Snapshot'))
	EXEC ('CREATE SCHEMA [Snapshot]')
GO

IF NOT (EXISTS (SELECT * FROM sys.schemas WHERE NAME = 'Expired'))
	EXEC ('CREATE SCHEMA [Expired]')
GO

IF NOT (EXISTS (SELECT * FROM sys.schemas WHERE NAME = 'Security'))
	EXEC ('CREATE SCHEMA [Security]')
GO

IF NOT (EXISTS (SELECT * FROM sys.schemas WHERE NAME = 'Reporting'))
	EXEC ('CREATE SCHEMA [Reporting]')
GO