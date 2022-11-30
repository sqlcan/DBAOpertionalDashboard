USE [SQLOpsDB]
GO
-- This script contains ALL Non-Clustered indexes required for SQLOpsDB.

-- CMS.GroupsToMonitor
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_GroupsToMonitor_GroupID')
	CREATE UNIQUE NONCLUSTERED INDEX [idx_GroupsToMonitor_GroupID] ON [CMS].[GroupsToMonitor] ([GroupID] ASC)

-- dbo.AGDatabases
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_GroupsToMonitor_GroupID')
	CREATE NONCLUSTERED INDEX [idx_AGDatabases_AGInstanceID] ON [dbo].[AGDatabases] ([AGInstanceID] ASC)

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_AGDatabases_DatabaseID')
	CREATE NONCLUSTERED INDEX [idx_AGDatabases_DatabaseID] ON [dbo].[AGDatabases] ([DatabaseID] ASC)

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_AGDatabases_LastUpdated')
	CREATE NONCLUSTERED INDEX [idx_AGDatabases_LastUpdated] ON [dbo].[AGDatabases] ([LastUpdated] ASC)

-- dbo.AGInstances
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_AGInstances_AGID')
	CREATE NONCLUSTERED INDEX [idx_AGInstances_AGID] ON [dbo].[AGInstances] ([AGID] ASC)

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_AGInstances_SQLInstanceID')
	CREATE NONCLUSTERED INDEX [idx_AGInstances_SQLInstanceID] ON [dbo].[AGInstances] ([SQLInstanceID] ASC)

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_AGInstances_LastUpdated')
	CREATE NONCLUSTERED INDEX [idx_AGInstances_LastUpdated] ON [dbo].[AGInstances] ([LastUpdated] ASC)

-- dbo.AGs

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_AGs_LastUpdated')
	CREATE NONCLUSTERED INDEX [idx_AGs_LastUpdated] ON [dbo].[AGs] ([LastUpdated] ASC)

-- dbo.Applications -- No Indexes Needed

-- dbo.Databases
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_Databases_SQLInstanceID')
	CREATE NONCLUSTERED INDEX [idx_Databases_SQLInstanceID] ON [dbo].[Databases] ([SQLInstanceID] ASC) WHERE IsMonitored = 1

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_Databases_ApplicationID')
	CREATE NONCLUSTERED INDEX [idx_Databases_ApplicationID] ON [dbo].[Databases] ([ApplicationID] ASC) WHERE IsMonitored = 1

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_Databases_LastUpdated')
	CREATE NONCLUSTERED INDEX [idx_Databases_LastUpdated] ON [dbo].[Databases] ([LastUpdated] ASC) WHERE IsMonitored = 1

-- dbo.Databases_Exclusions -- No Indexes Needed

-- dbo.DatabaseSize

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_DatabaseSize_DatabaseID')
	CREATE NONCLUSTERED INDEX [idx_DatabaseSize_DatabaseID] ON [dbo].[DatabaseSize] ([DatabaseID] ASC) INCLUDE (FileType)

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_DatabaseSize_DateCaptured')
	CREATE NONCLUSTERED INDEX [idx_DatabaseSize_DateCaptured] ON [dbo].[DatabaseSize] ([DateCaptured] ASC)

-- dbo.DiskVolumes

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_DiskVolumes_LastUpdated')
	CREATE NONCLUSTERED INDEX [idx_DiskVolumes_LastUpdated] ON [dbo].[DiskVolumes] ([LastUpdated] ASC) WHERE IsMonitored = 1

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_DiskVolumes_ServerID')
	CREATE NONCLUSTERED INDEX [idx_DiskVolumes_ServerID] ON [dbo].[DiskVolumes] ([ServerID] ASC) WHERE IsMonitored = 1

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_DiskVolumes_SQLClusterID')
	CREATE NONCLUSTERED INDEX [idx_DiskVolumes_SQLClusterID] ON [dbo].[DiskVolumes] ([SQLClusterID] ASC) WHERE IsMonitored = 1

-- dbo.DiskVolumeSpace

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_DiskVolumeSpace_DiskVolumeID')
	CREATE NONCLUSTERED INDEX [idx_DiskVolumeSpace_DiskVolumeID] ON [dbo].[DiskVolumeSpace] ([DiskVolumeID] ASC)

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_DiskVolumeSpace_DateCaptured')
	CREATE NONCLUSTERED INDEX [idx_DiskVolumeSpace_DateCaptured] ON [dbo].[DiskVolumeSpace] ([DateCaptured] ASC)

-- dbo.ExtendedProperty
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_ExtendedProperty_ExtendedPropertyName')
	CREATE UNIQUE NONCLUSTERED INDEX [idx_ExtendedProperty_ExtendedPropertyName] ON [dbo].[ExtendedProperty] ([ExtendedPropertyName] ASC)

-- dbo.ExtendedPropertyValues
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_ExtendedPropertyValues_LastUpdated')
	CREATE NONCLUSTERED INDEX [idx_ExtendedPropertyValues_LastUpdated] ON [dbo].[ExtendedPropertyValues] ([LastUpdated] ASC)

-- dbo.Logs
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_Logs_DateTimeCaptured')
	CREATE NONCLUSTERED INDEX [idx_Logs_DateTimeCaptured] ON [dbo].[Logs] ([DateTimeCaptured] ASC) INCLUDE (Description)

-- dbo.OperatingSystems
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_OperatingSystems_OSName_OSShortName')
	CREATE UNIQUE NONCLUSTERED INDEX [idx_OperatingSystems_OSName_OSShortName] ON [dbo].[OperatingSystems] ([OperatingSystemName] ASC, [OperatingSystemShortName] ASC)

-- dbo.Servers
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_Servers_OperatingSystemID')
	CREATE NONCLUSTERED INDEX [idx_Servers_OperatingSystemID] ON [dbo].[Servers] ([OperatingSystemID] ASC) WHERE IsMonitored = 1

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_Servers_ServerName')
	CREATE UNIQUE NONCLUSTERED INDEX [idx_Servers_ServerName] ON [dbo].[Servers] ([ServerName] ASC) WHERE IsMonitored = 1

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_Servers_LastUpdated')
	CREATE NONCLUSTERED INDEX [idx_Servers_LastUpdated] ON [dbo].[Servers] ([LastUpdated] ASC) WHERE IsMonitored = 1

-- dbo.Setting
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_Setting_SettingName')
	CREATE UNIQUE INDEX [idx_Setting_SettingName] ON dbo.Setting(SettingName ASC)

-- dbo.SQLClusterNodes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_SQLClusterNodes_LastUpdated')
	CREATE NONCLUSTERED INDEX [idx_SQLClusterNodes_LastUpdated] ON [dbo].[SQLClusterNodes] ([LastUpdated] ASC)

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_SQLClusterNodes_SQLNodeID')
	CREATE NONCLUSTERED INDEX [idx_SQLClusterNodes_SQLNodeID] ON [dbo].[SQLClusterNodes] ([SQLNodeID] ASC)

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_SQLClusterNodes_SQLClusterID')
	CREATE NONCLUSTERED INDEX [idx_SQLClusterNodes_SQLClusterID] ON [dbo].[SQLClusterNodes] ([SQLClusterID] ASC)

-- dbo.SQLClusters
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_SQLClusters_SQLClusterName')
	CREATE UNIQUE INDEX [idx_SQLClusters_SQLClusterName] ON dbo.SQLClusters([SQLClusterName]) WHERE IsMonitored = 1

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_SQLClusters_LastUpdated')
	CREATE NONCLUSTERED INDEX [idx_SQLClusters_LastUpdated] ON dbo.SQLClusters([LastUpdated]) WHERE IsMonitored = 1

-- dbo.SQLErrorLog
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_SQLErrorLog_SQLInstanceID')
	CREATE INDEX [idx_SQLErrorLog_SQLInstanceID] ON [dbo].[SQLErrorLog]([SQLInstanceID] ASC)

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_SQLErrorLog_DateTime')
	CREATE INDEX [idx_SQLErrorLog_DateTime] ON [dbo].[SQLErrorLog]([DateTime] ASC)

-- dbo.SQLInstances
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_SQLInstances_LastUpdated')
	CREATE NONCLUSTERED INDEX [idx_SQLInstances_LastUpdated] ON [dbo].[SQLInstances] ([LastUpdated] ASC) WHERE IsMonitored=1

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_SQLInstances_ServerID')
	CREATE NONCLUSTERED INDEX [idx_SQLInstances_ServerID] ON [dbo].[SQLInstances] ([ServerID] ASC) WHERE IsMonitored=1

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_SQLInstances_SQLClusterID')
	CREATE NONCLUSTERED INDEX [idx_SQLInstances_SQLClusterID] ON [dbo].[SQLInstances] ([SQLClusterID] ASC) WHERE IsMonitored=1

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_SQLInstances_SQLInstanceVersionID')
	CREATE NONCLUSTERED INDEX [idx_SQLInstances_SQLInstanceVersionID] ON [dbo].[SQLInstances] ([SQLInstanceVersionID] ASC) WHERE IsMonitored=1

-- dbo.SQLJobCategory
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_SQLJobCategory_SQLJobCategoryName')
	CREATE UNIQUE INDEX [idx_SQLJobCategory_SQLJobCategoryName] ON [dbo].[SQLJobCategory]([SQLJobCategoryName] ASC)

-- dbo.SQLJobHistory
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_SQLJobHistory_SQLJobID')
	CREATE NONCLUSTERED INDEX [idx_SQLJobHistory_SQLJobID] ON [dbo].[SQLJobHistory]([SQLJobID] ASC)

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_SQLJobHistory_JobStatus')
	CREATE NONCLUSTERED INDEX [idx_SQLJobHistory_JobStatus] ON [dbo].[SQLJobHistory]([JobStatus] ASC)

-- dbo.SQLJobs
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_SQLJobs_SQLInstanceID')
	CREATE NONCLUSTERED INDEX [idx_SQLJobs_SQLInstanceID] ON [dbo].[SQLJobs]([SQLInstanceID] ASC)

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_SQLJobs_SQLJobCategoryID')
	CREATE NONCLUSTERED INDEX [idx_SQLJobs_SQLJobCategoryID] ON [dbo].[SQLJobs]([SQLJobCategoryID] ASC)

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_SQLJobs_LastUpdated')
	CREATE NONCLUSTERED INDEX [idx_SQLJobs_LastUpdated] ON [dbo].[SQLJobs]([LastUpdated] ASC)

-- dbo.SQLService
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_SQLService_ServerID')
	CREATE NONCLUSTERED INDEX [idx_SQLService_ServerID] ON dbo.SQLService([ServerID] ASC)

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_SQLService_LastUpdated')
	CREATE NONCLUSTERED INDEX [idx_SQLService_LastUpdated] ON dbo.SQLService([LastUpdated] ASC)

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_SQLService_Status')
	CREATE NONCLUSTERED INDEX [idx_SQLService_Status] ON dbo.SQLService([Status] ASC)

-- dbo.SQLVersions
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_SQLVersions_SQLVer_SQLShortVer')
	CREATE UNIQUE NONCLUSTERED INDEX [idx_SQLVersions_SQLVer_SQLShortVer] ON [dbo].[SQLVersions] ([SQLVersion] ASC, [SQLVersionShortName] ASC)

-- History.DatabaseSize
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_History_DatabaseSize_DatabaseID')
	CREATE NONCLUSTERED INDEX [idx_History_DatabaseSize_DatabaseID] ON History.DatabaseSize([DatabaseID] ASC) INCLUDE (FileType)

-- History.DiskVolumeSpace
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_History_DiskVolumeSpace_DiskVolumeID')
	CREATE NONCLUSTERED INDEX [idx_History_DiskVolumeSpace_DiskVolumeID] ON History.DiskVolumeSpace([DiskVolumeID] ASC)

-- Security.DatabasePermissions
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_DatabasePermission_GranteeID')
	CREATE NONCLUSTERED INDEX [idx_DatabasePermission_GranteeID] ON [Security].[DatabasePermission] ([GranteeID] ASC)

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_DatabasePermission_GrantorID')
	CREATE NONCLUSTERED INDEX [idx_DatabasePermission_GrantorID] ON [Security].[DatabasePermission] ([GrantorID] ASC)

-- Security.DatabasePrincipalMembership
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_DatabasePrincipalMembership_DatabaseUserID')
	CREATE NONCLUSTERED INDEX [idx_DatabasePrincipalMembership_DatabaseUserID] ON [Security].[DatabasePrincipalMembership] ([DatabaseUserID] ASC)

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_DatabasePrincipalMembership_DatabaseRoleID')
	CREATE NONCLUSTERED INDEX [idx_DatabasePrincipalMembership_DatabaseRoleID] ON [Security].[DatabasePrincipalMembership] ([DatabaseRoleID] ASC)

-- Security.ServerPermissions
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_ServerPermission_GranteeID')
	CREATE NONCLUSTERED INDEX [idx_ServerPermission_GranteeID] ON [Security].[ServerPermission] ([GranteeID] ASC)

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_DatabasePermission_GrantorID')
	CREATE NONCLUSTERED INDEX [idx_ServerPermission_GrantorID] ON [Security].[ServerPermission] ([GrantorID] ASC)

-- Security.ServerPrincipalMembership
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_ServerPrincipalMembership_DatabaseUserID')
	CREATE NONCLUSTERED INDEX [idx_ServerPrincipalMembership_ServerLoginID] ON [Security].[ServerPrincipalMembership] ([ServerLoginID] ASC)

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'idx_ServerPrincipalMembership_DatabaseRoleID')
	CREATE NONCLUSTERED INDEX [idx_ServerPrincipalMembership_ServerRoleID] ON [Security].[ServerPrincipalMembership] ([ServerRoleID] ASC)
