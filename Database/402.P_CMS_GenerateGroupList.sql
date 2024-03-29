--     Purpose: Meta Data Script, used to export list of Groups  being monitored.
--           
--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER proc [CMS].[GenerateGroupList]
AS
BEGIN

    SET NOCOUNT ON

    PRINT '<# CMS Group IDs - Last Exported on ' + CONVERT(VARCHAR(25),GetDate(),107);
    PRINT ''
    PRINT 'Execute CMS.GenerateGroupList in DBA_Resource Database to Get Updated List'
    PRINT '';
     
    WITH Groups (GroupID, GroupName)
    AS
    (   SELECT server_group_id, CAST(name AS VARCHAR(75))
	        FROM msdb.dbo.sysmanagement_shared_server_groups
	        WHERE parent_id IS NULL

	    UNION ALL

	    SELECT server_group_id, CAST(GroupName + '\' + CAST(name AS VARCHAR(100)) AS VARCHAR(75))
	        FROM msdb.dbo.sysmanagement_shared_server_groups SSG
	        JOIN Groups G
	        ON SSG.parent_id = G.GroupID)

        SELECT STR(G.GroupID) AS GroupID, GroupName, GTM.IsMonitored
        FROM Groups G
        JOIN CMS.GroupsToMonitor GTM
          ON G.GroupID = GTM.GroupID
        WHERE GroupName LIKE 'DatabaseEngineServerGroup\%'
    ORDER BY GroupName;

    PRINT '#>';

END
