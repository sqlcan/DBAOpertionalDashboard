USE [SQLOpsDB]
GO

/****** Object:  StoredProcedure [CMS].[GetGroupList]    Script Date: 11/27/2021 12:48:31 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER   PROCEDURE [CMS].[GetGroupList] 
@GroupName varchar(512) = null
AS
BEGIN
	SET NOCOUNT ON;

	-- Before returning group and server list. 
	-- Update existing group membership.  In case CMS been updated since last execution.

	EXEC CMS.UpdateGroupsList;

	-- Return Server List based on Search Criteria supplied.
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
	SELECT G.GroupID, G.GroupName, GTM.IsMonitored
        FROM Groups G
        JOIN CMS.GroupsToMonitor GTM
        ON G.GroupID = GTM.GroupID
        WHERE ((@GroupName IS NULL) OR (G.GroupName like '%' + @GroupName + '%'))
    ORDER BY GTM.IsMonitored DESC, GroupName

END
GO