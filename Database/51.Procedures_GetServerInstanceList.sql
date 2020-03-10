USE [SQLOpsDB]
GO

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'GetCMSServerList')
	DROP PROC [CMS].[GetCMSServerList]
GO

IF EXISTS (SELECT * FROM sys.procedures WHERE name = 'GetServerInstanceList')
	DROP PROC [CMS].[GetServerInstanceList]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [CMS].[GetServerInstanceList] 
@ServerName varchar(255) = null,
@GroupName varchar(512) = null
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
	SELECT G.GroupName, LOWER(name) AS ServerInstance, LOWER(server_name) AS ServerInstanceConnectionString
        FROM Groups G
        JOIN CMS.GroupsToMonitor GTM
        ON G.GroupID = GTM.GroupID
        JOIN msdb.dbo.sysmanagement_shared_registered_servers S
        ON S.server_group_id = GTM.GroupID 
        WHERE GTM.IsMonitored = 1
        AND ((@ServerName IS NULL) OR (S.name = @ServerName))
		AND ((@GroupName IS NULL) OR (G.GroupName like '%' + @GroupName + '%'))
    ORDER BY name
END
