-- Name: SQLCMS Configuration
--
-- Purpose: Create folder structure to host multiple version of SQL Server.
--          Provide an organization schem to allow for operations of DBA Operational Dashboard.
--          The script should be run on CMS Server.
--
-- This script will create following structure:
--
-- Environment
-- -- Version
-- -- -- Standalone
-- -- -- AG Replicas
-- -- -- AG Listener
-- -- -- FCI

SET NOCOUNT ON

-- List each version name with semi-colon in between, finish the list with semi-colon.
-- DECLARE @MasterVersionsList VARCHAR(MAX) = 'SQL 2005;SQL 2008;SQL 2008 R2;SQL 2012;SQL 2014;SQL 2016;SQL 2017;SQL 2019;SQL 2022;'
DECLARE @MasterVersionsList VARCHAR(MAX) = 'SQL 2005;SQL 2019;'
-- List each environment name with semi-colon in between, finish the list with semi-colon.
DECLARE @Environments VARCHAR(MAX) = 'Prod;Test;Dev;'

IF (CHARINDEX(';',@MasterVersionsList) = 0)
BEGIN
	RAISERROR ('SQL Version list must be divided by semi-colon.  List must end in semi-colon.',1,1)
	Return
END

IF (CHARINDEX(';',@MasterVersionsList) = 0)
BEGIN
	RAISERROR ('Environment list must be divided by semi-colon.  List must end in semi-colon.',1,1)
	Return
END

DECLARE @Done BIT = 0

WHILE (@Done = 0)
BEGIN

	DECLARE @EnvName VARCHAR(255) = SUBSTRING(@Environments,1,CHARINDEX(';',@Environments)-1)
	DECLARE @SQLVersions VARCHAR(MAX) = @MasterVersionsList
	
	DECLARE @GroupIdentity int = null

	SELECT @GroupIdentity = server_group_id
	  FROM msdb.dbo.sysmanagement_shared_server_groups_internal
     WHERE name = @EnvName

	IF (@GroupIdentity IS NULL)
		EXEC msdb.dbo.sp_sysmanagement_add_shared_server_group
		@parent_id = 1, @name = @EnvName, @description = N'',
		@server_type = 0,  @server_group_id = @GroupIdentity OUTPUT

	--PRINT 'Group Name ' + @EnvName + ' ID: ' + CAST(@GroupIdentity AS VARCHAR)

	DECLARE @DoneInner BIT = 0

	WHILE (@DoneInner = 0)
	BEGIN

		DECLARE @VerName VARCHAR(255) = SUBSTRING(@SQLVersions,1,CHARINDEX(';',@SQLVersions)-1)

		DECLARE @InnerGroupIdentity int = null
		DECLARE @Dummy int

		SELECT @InnerGroupIdentity = server_group_id
		  FROM msdb.dbo.sysmanagement_shared_server_groups_internal
		 WHERE name = @VerName
		   AND parent_id = @GroupIdentity

		IF (@InnerGroupIdentity IS NULL)
			EXEC msdb.dbo.sp_sysmanagement_add_shared_server_group
			@parent_id = @GroupIdentity, @name = @VerName, @description = N'',
			@server_type = 0,  @server_group_id = @InnerGroupIdentity OUTPUT		

		--PRINT 'Version ' + @VerName + ' ID: ' + CAST(@InnerGroupIdentity AS VARCHAR)

		SET @Dummy = NULL
		SELECT @Dummy = server_group_id
		  FROM msdb.dbo.sysmanagement_shared_server_groups_internal
		 WHERE name = 'Stand Alone'
		   AND parent_id = @InnerGroupIdentity

		IF (@Dummy IS NULL)
			EXEC msdb.dbo.sp_sysmanagement_add_shared_server_group
			@parent_id = @InnerGroupIdentity, @name = 'Stand Alone', @description = N'',
			@server_type = 0,  @server_group_id = @Dummy;	

		IF (not ((@VerName LIKE '%2008%') OR (@VerName LIKE '%2005%')))
		BEGIN
			SET @Dummy = NULL
			SELECT @Dummy = server_group_id
			  FROM msdb.dbo.sysmanagement_shared_server_groups_internal
			 WHERE name = 'AG Replica'
			   AND parent_id = @InnerGroupIdentity

			IF (@Dummy IS NULL)
				EXEC msdb.dbo.sp_sysmanagement_add_shared_server_group
				@parent_id = @InnerGroupIdentity, @name = 'AG Replica', @description = N'',
				@server_type = 0,  @server_group_id = @Dummy;	

			SET @Dummy = NULL
			SELECT @Dummy = server_group_id
			  FROM msdb.dbo.sysmanagement_shared_server_groups_internal
			 WHERE name = 'AG Listener'
			   AND parent_id = @InnerGroupIdentity

			IF (@Dummy IS NULL)
				EXEC msdb.dbo.sp_sysmanagement_add_shared_server_group
				@parent_id = @InnerGroupIdentity, @name = 'AG Listener', @description = N'',
				@server_type = 0,  @server_group_id = @Dummy;	
		END

		SET @Dummy = NULL
		SELECT @Dummy = server_group_id
			FROM msdb.dbo.sysmanagement_shared_server_groups_internal
			WHERE name = 'FCI'
			AND parent_id = @InnerGroupIdentity

		IF (@Dummy IS NULL)
			EXEC msdb.dbo.sp_sysmanagement_add_shared_server_group
			@parent_id = @InnerGroupIdentity, @name = 'FCI', @description = N'',
			@server_type = 0,  @server_group_id = @Dummy;	

		SET @SQLVersions = SUBSTRING(@SQLVersions,CHARINDEX(';',@SQLVersions)+1,LEN(@SQLVersions))
	
		IF (LEN(@SQLVersions) = 0)
			SET @DoneInner = 1

	END

	SET @Environments = SUBSTRING(@Environments,CHARINDEX(';',@Environments)+1,LEN(@Environments))
	
	IF (LEN(@Environments) = 0)
		SET @Done = 1

END