--     Purpose: Meta data about the version of the database.
--              The PowerShell script for data collection will validate these
--              values before starting data collection.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Oct. 3, 2020

USE [SQLOpsDB]
GO

DECLARE @LastUpdated NVARCHAR(255) = '2010.10.04'
DECLARE @Version     NVARCHAR(255) = '3.00.00.0000'

IF (NOT (EXISTS (SELECT * FROM sys.extended_properties WHERE name = 'SQLOpsDBLastUpdated')))
	EXEC sys.sp_addextendedproperty @name=N'SQLOpsDBLastUpdated', @value=@LastUpdated 
ELSE
	EXEC sys.sp_updateextendedproperty @name=N'SQLOpsDBLastUpdated', @value=@LastUpdated

IF (NOT (EXISTS (SELECT * FROM sys.extended_properties WHERE name = 'SQLOpsDBVersion')))
	EXEC sys.sp_addextendedproperty @name=N'SQLOpsDBVersion', @value=@Version 
ELSE
	EXEC sys.sp_updateextendedproperty @name=N'SQLOpsDBVersion', @value=@Version
GO
