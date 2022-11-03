USE [SQLOpsDB]
GO

CREATE OR ALTER PROCEDURE Staging.TableUpdates
@TableName NVARCHAR(50),
@ModuleVersion NVARCHAR(25)
AS
BEGIN
	DECLARE @ObjectID BIGINT
	DECLARE @CurrentVersion NVARCHAR(25)
	DECLARE @Recreate INT = 0
	DECLARE @TSQLCmd NVARCHAR(MAX)

	SELECT @ObjectID = object_id FROM sys.tables WHERE name = @TableName AND schema_id = SCHEMA_ID('Staging')
	SELECT @CurrentVersion = CAST(ISNULL(value,'0') AS NVARCHAR) FROM sys.extended_properties WHERE major_id = @ObjectID and name = 'SQLOpsDBVersion'

	IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = @TableName and schema_id = SCHEMA_ID('Staging'))
		SET @Recreate = 1

	IF (((@CurrentVersion <> @ModuleVersion) OR (@CurrentVersion IS NULL)) AND (EXISTS (SELECT * FROM sys.tables WHERE name = @TableName and schema_id = SCHEMA_ID('Staging'))))
	BEGIN
		-- The table already exists however version does not match.
		SET @TSQLCmd = N'DROP TABLE Staging.' + @TableName
		EXEC (@TSQLCmd)
		SET @Recreate = 1
	END

	IF (@Recreate = 1)
	BEGIN
		IF (@TableName = 'SQLServiceDetails')
			CREATE TABLE Staging.SQLServiceDetails (
				ProcessID INT NULL,
				ServerName varchar(255) NULL,
				ServiceName varchar(255) NULL,
				InstanceName varchar(255) NULL,
				DisplayName varchar(255) NULL,
				FilePath varchar(512) NULL,
				ServiceType varchar(25) NULL,
				StartMode varchar(25) NULL,
				ServiceAccount varchar(50) NULL,
				ServiceVersion int NULL,
				ServiceBuild varchar(25) NULL,
				Status varchar(25) NULL
			)

		IF (@TableName = 'AG')
			CREATE TABLE Staging.AG (
                ProcessID INT NULL,
				SQLInstanceID int,
                ServerInstance VARCHAR(255),
                AGGuid uniqueidentifier,
                AGName VARCHAR(255),
                ComputerName VARCHAR(255),
				InstanceName VARCHAR(255),
                ReplicaRole VARCHAR(25))

		IF (@TableName = 'Databases')
			CREATE TABLE Staging.Databases(
			    ProcessID int NULL,
				SQLInstanceID int NULL,
				ServerInstance VARCHAR(255),
				AGGuid uniqueidentifier NULL,
				ApplicationName VARCHAR(255) NULL,
				DatabaseName varchar(255) NULL,
				DatabaseState varchar(60) NULL,
				FileType char(4) NULL,
				FileSize_mb bigint NULL)

		IF (@TableName = 'ExtendedProperties')
			CREATE TABLE Staging.ExtendedProperties(
			    ProcessID int NULL,
				SQLInstanceID int NULL,
				ExtendedPropertyName VARCHAR(255) NULL,
				ExtendedPropertyValue VARCHAR(250) NULL)

		IF (@TableName = 'SQLErrLog')
			CREATE TABLE Staging.SQLErrLog (
				ProcessID int,
                SQLInstanceID int,
                ServerInstance VARCHAR(255),
                DateTimeCaptured DATETIME,
                Message VARCHAR(MAX))
				
		IF (@TableName = 'SQLJobs')
			CREATE TABLE Staging.SQLJobs (
                ProcessID int,
				SQLInstanceID int,
                ServerInstance VARCHAR(255),
                JobName VARCHAR(255),
                CategoryName VARCHAR(255),
                ExecutionDateTime DATETIME,
                Duration INT,
                JobStatus VARCHAR(25))
				
		IF (@TableName = 'ServerRole')
			CREATE TABLE Staging.ServerRole (
                ProcessID int,
				SQLInstanceID int,
                ServerInstance VARCHAR(255),
                RoleName VARCHAR(255),
                RoleType VARCHAR(255))

		IF (@TableName = 'DatabaseRole')
			CREATE TABLE Staging.DatabaseRole (
                ProcessID int,
				SQLInstanceID int,
                ServerInstance VARCHAR(255),
                RoleName VARCHAR(255),
                RoleType VARCHAR(255))

		IF (@TableName = 'ServerPrincipalMembership')
			CREATE TABLE Staging.ServerPrincipalMembership (
                ProcessID int,
				SQLInstanceID int,
                ServerInstance VARCHAR(255),
                RoleName VARCHAR(255),
                LoginName VARCHAR(255),
				LoginType VARCHAR(255))
				
		IF (@TableName = 'DatabasePrincipalMembership')
			CREATE TABLE Staging.DatabasePrincipalMembership (
                ProcessID int,
				SQLInstanceID int,
				ServerInstance VARCHAR(255),
				DatabaseName VARCHAR(255),                
                RoleName VARCHAR(255),
                UserName VARCHAR(255),
				UserType VARCHAR(255),
				IsOrphaned BIT)

		IF (@TableName = 'ServerPermission')
			CREATE TABLE Staging.ServerPermission (
                ProcessID int,
				SQLInstanceID int,
				ServerInstance VARCHAR(255),
				GranteeName VARCHAR(255),                
                GrantorName VARCHAR(255),
                GranteeType VARCHAR(255),
				ObjectType VARCHAR(255),
				ObjectID BIGINT,
				Access VARCHAR(25),
				PermissionName VARCHAR(255))

		EXEC sys.sp_addextendedproperty @name=N'SQLOpsDBVersion', @value=@ModuleVersion , @level0type=N'SCHEMA',@level0name=N'Staging', @level1type=N'TABLE',@level1name=@TableName
	END
END
GO