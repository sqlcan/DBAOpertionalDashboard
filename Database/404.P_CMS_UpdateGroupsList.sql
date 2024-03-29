USE [SQLOpsDB]
GO
/****** Object:  StoredProcedure [CMS].[UpdateGroupMonitorStatus]    Script Date: 11/27/2021 12:56:43 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER   PROCEDURE [CMS].[UpdateGroupsList] 	
AS
BEGIN
	SET NOCOUNT ON;

    WITH Groups (GroupID, GroupName)
    AS
    (   SELECT server_group_id, CAST(name AS VARCHAR(75))
	        FROM msdb.dbo.sysmanagement_shared_server_groups
	        WHERE parent_id IS NULL
			  AND server_group_id = 1

	    UNION ALL

	    SELECT server_group_id, CAST(GroupName + '\' + CAST(name AS VARCHAR(100)) AS VARCHAR(75))
	        FROM msdb.dbo.sysmanagement_shared_server_groups SSG
	        JOIN Groups G
	        ON SSG.parent_id = G.GroupID),
	UserGroupList (GroupID)
	AS
	( SELECT GroupID
	    FROM Groups
	   WHERE GroupID <> 1)
	MERGE CMS.GroupsToMonitor AS Target
	USING (SELECT GroupID FROM UserGroupList) AS Source (GroupID)
	   ON (Target.GroupID = Source.GroupID)
	 WHEN NOT MATCHED BY TARGET THEN
		INSERT (GroupID, IsMonitored)
		VALUES (Source.GroupID, 0)
	 WHEN NOT MATCHED BY SOURCE THEN
		DELETE;
END
