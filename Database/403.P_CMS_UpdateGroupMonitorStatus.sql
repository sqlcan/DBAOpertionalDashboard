--     Purpose: Update which groups the SQLOpsDB script should monitor.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Nov. 3, 2020

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [CMS].[UpdateGroupMonitorStatus] 
	@GroupID int = 0, 
	@GroupName varchar(75) = NULL
AS
BEGIN
	SET NOCOUNT ON;

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
	UPDATE GTM
       SET IsMonitored = CASE WHEN (IsNull(IsMonitored,0) = 0) THEN 1 ELSE 0 END
      FROM Groups G
 LEFT JOIN CMS.GroupsToMonitor GTM
        ON G.GroupID = GTM.GroupID
     WHERE G.GroupID = @GroupID
        OR (G.GroupName LIKE '%' + @GroupName + '%');

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
	SELECT G.GroupID, G.GroupName, IsNull(GTM.IsMonitored,0) AS IsMonitored
      FROM Groups G
 LEFT JOIN CMS.GroupsToMonitor GTM
        ON G.GroupID = GTM.GroupID
     WHERE G.GroupID = @GroupID
        OR (G.GroupName LIKE '%' + @GroupName + '%');

END
