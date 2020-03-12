#Import Required Modules for Data Collection
Import-Module SQLServer -DisableNameChecking
Import-Module '.\SQLOpsDB\SQLOpsDB.psd1' -DisableNameChecking

# Before we can utilize the command-lets in SQLOpsDB, it must be initialized.
if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
{
    Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
    return
}

# Data Collection Switches
#
# Goal of this switches is to turn on and off part of the data collection script.

$DCS_ErrorLogs = $true                  # Collect SQL Server Error Logs
$DCS_ThrottleErrorLogCollection = $true # If enabled, each server will be given at most $DCS_ThrottleLimit
                                        # in minutes to process the error logs.
$DCS_ThrottleLimit = 1                  # Time in minutes to process the error log files per instance.
$DCS_DiscoverSQLServices = $true        # Review SQL Services Installed on a Server.
$DCS_SQLJobs = $true                    # Collect SQL Jobs and their History

## Code Start

Write-StatusUpdate -Message "SQLOpsDB - Collection Start" -WriteToDB

#region Get Server List
try
{
    Write-StatusUpdate -Message "Getting list of SQL Instances from CMS Server [$Global:CMS_SQLServerName]."

    # Get list of SQL Server Instances from Central Management Server (CMS).
    # Enable or disable which CMS groups are monitored via Set-CMSGroup commandlet.
    $SQLServers = Get-CMSServerInstance #-ServerInstance ContosoSQL
    $TotalServers = ($SQLServers | Measure-Object).Count
    $ServersRunningCount = 0
}
catch
{
    Write-StatusUpdate -Message "Failed to get list of sql instances from CMS Server (unhandled exception)." -WriteToDB
    Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
    return
}

if (($SQLServers -eq $Global:Error_FailedToComplete) -or ($SQLServers -eq $Global:Error_ObjectsNotFound))
{
    Write-Error "No SQL Server instances found with criteria supplied. Collection failed."
    return
}
#endregion

#region Loop through all the SQL Instances collected from Central Management Servers (CMS).
ForEach ($SQLServerRC in $SQLServers)
{

    # For backwards compatibility.  Eventually will be removed as all modules should be able to handle FQDN.
    $ComputerName_NoDomain = $($SQLServerRC.ComputerName).Substring(0,$($SQLServerRC.ComputerName).IndexOf('.'))

    $ServersRunningCount++
    Write-StatusUpdate -Message "Processing SQL Instance [$($SQLServerRC.ServerInstance)] ($ServersRunningCount/$TotalServers) ..." -WriteToDB

    # Initialize all the variables for current Instance
    [Array] $ServerList = $null
    $IsClustered = 0
    $IsPhysical = 1
    $ServerType = 'Stand Alone'
    $EnvironmentType = 'Prod'
    $ServerInstanceIsMonitored = $true
    $DBFolderList = $null
    $BackupFolderList = $null
    $PassiveNodes = $null
    $ActiveNodeName = $null
    $InstanceDetails = $null
    $OperatingSystem = 'Unknown'
    $SQLEdition = 'Unknown'
    $SQLVersion = 'Unknown'
    $SQLBuild = 0
    $SQLInstanceAccessible = $true
    $SchemaPrefix = 'sys'
    $FQDN = $Global:Default_DomainName

    # Check to confirm Extended Properties table exists; as script heavily relies on this table.
    # Also check if Extended Properties are defined for key settings; as it leads to confusion if they are missing.

    $ExtendedProperties = Get-SIExtendedProperties -ServerInstance $SQLServerRC.ServerInstanceConnectionString
    $SQLInstanceAccessible = $true

    if ($ExtendedProperties -eq $Global:Error_FailedToComplete)
    {
        $SQLInstanceAccessible = $false
        continue;
    }

    #region Get SQL Properties
    Write-StatusUpdate -Message "Getting instance properties."
    $SQLProperties = Get-SISQLProperties -ServerInstance $SQLServerRC.ServerInstanceConnectionString

    if ($SQLProperties -eq $Global:Error_FailedToComplete)
    {
        $SQLInstanceAccessible = $false
        continue;
    }

    $IsClustered = $SQLProperties['IsClustered']
    $SQLEdition = $SQLProperties['SQLEdition']
    $SQLServer_Build = $SQLProperties['SQLEdition']
    $SQLVersion = $SQLProperties['SQLVersion']
    Write-StatusUpdate -Message "SQL Server Version: [$SQLVersion]."
    #endregion

    $OperatingSystem = Get-SIOperatingSystem -ComputerName $SQLServerRC.ComputerName
    Write-StatusUpdate -Message "   Windows Version: [$OperatingSystem]."

    #region Collected Extended Properties Details
    $ServerType = $ExtendedProperties["ServerType"]
    Write-StatusUpdate -Message "Server Type: $ServerType"

    $EnvironmentType = $ExtendedProperties["EnvironmentType"]
    Write-StatusUpdate -Message "Environment: $EnvironmentType"

    $MachineType = $ExtendedProperties["MachineType"]
    if ($MachineType -eq 'Physical')
    {
        $IsPhysical = 1
    }
    else
    {
        $IsPhysical = 0
    }

    Write-StatusUpdate -Message "Is Physical: $IsPhysical"
    #endregion

    # Build a server list to check and the file paths to determine the volumes to check for space.
    # Only volumes we care to monitor are those which have SQL Server related files (i.e. backups, data, and t-logs)

    Write-StatusUpdate -Message "Building server list for the instance:"

    if (($IsClustered -eq 1) -or ($ServerType -eq 'Microsoft Clustering') -or ($ServerType -eq 'Veritas Clustering'))
    {

        # If this SQL Server is a clustered instance we need to do additional investigative queries.  TO collect information for
        # for data and file locations.  This will help calculate which volumes belong to instance where instance stacking is being used.

        if ($SQLVersion -eq 'Microsoft SQL Server 2000')
        {
            $TSQL = "SELECT DISTINCT LOWER(SUBSTRING(filename,1,LEN(filename)-CHARINDEX('\',LTRIM(REVERSE(filename))))) AS FolderName FROM sysfiles"
        }
        else
        {
            $TSQL = "SELECT DISTINCT LOWER(SUBSTRING(physical_name,1,LEN(physical_name)-CHARINDEX('\',REVERSE(physical_name)))) AS FolderName FROM sys.master_files"
        }

        if ($OperatingSystem -ne "Windows Server 2000")
        {
            Write-StatusUpdate -Message $TSQL -IsTSQL

            $DBFolderList = Invoke-SQLCMD -ServerInstance $SQLServerRC.ServerInstanceConnectionString `
                                            -Database 'master' `
                                            -Query $TSQL -ErrorAction Stop

            $TSQL = "SELECT DISTINCT LOWER(SUBSTRING(physical_device_name,1,LEN(physical_device_name)-CHARINDEX('\',REVERSE(physical_device_name)))) AS FolderName FROM msdb.dbo.backupmediafamily"
            Write-StatusUpdate -Message $TSQL -IsTSQL

            $BackupFolderList = Invoke-SQLCMD -ServerInstance $SQLServerRC.ServerInstanceConnectionString  `
                                                -Database 'master' `
                                                -Query $TSQL -ErrorAction Stop
        }

        # Unlike Standalone Instances where the Physical Name is calculated, for FCI the node names must be supplied by DBA team.
        # If this information is blank, the servers list will be blank therefore no action will be taken.

        # Grab active node value from extended properties, if the domain information is missing, append the default domain name.
        $ActiveNode = $ExtendedProperties["ActiveNode"].ToLower()
        Write-StatusUpdate -Message "Found Server: $ActiveNode"        

        # Follow code will be added once the other command lets support FQDN.
        #$DomainDetails = $($SQLServerRC.ComputerName).Substring($($SQLServerRC.ComputerName).IndexOf('.')+1)
        #
        #if (($ActiveNode.IndexOf('.') -eq -1) -and ($DomainDetails -eq $FQDN))
        #{
        #    $ActiveNode += ".$FQDN"
        #}
        #else
        #{
        #    $ActiveNode += ".$DomainDetails"
        #}
        
        $ServerList += ($ActiveNode,1)

        # Check if there are passive nodes defined.
        if ($ExtendedProperties.Keys -contains 'PassiveNode')
        {
            $PassiveNode = $ExtendedProperties["PassiveNode"].ToLower()
            # Follow code will be added once the other command lets support FQDN.
            #if ($PassiveNode.IndexOf('.') -eq -1)
            #{
            #    $PassiveNode += ".$FQDN"
            #}
            #else
            #{
            #    $PassiveNode += ".$DomainDetails"
            #}

            Write-StatusUpdate -Message "Found Server: $PassiveNode)"
            $ServerList += $PassiveNode

            # I am assuming no clusters will be deployed with more then eight nodes in SQL world!
            For ($index = 2; $index -le 8; $index++)
            {
                $KeyName = "PassiveNode{0:00}" -f $index

                if ($ExtendedProperties.ContainsKey($KeyName))
                {
                    $PassiveNode = $ExtendedProperties[$KeyName].ToLower()
                    # Follow code will be added once the other command lets support FQDN.
                    #if ($PassiveNode.IndexOf('.') -eq -1)
                    #{
                    #    $PassiveNode += ".$FQDN"
                    #}
                    #else
                    #{
                    #    $PassiveNode += ".$DomainDetails"
                    #}

                    Write-StatusUpdate -Message "Found Server: $PassiveNode)"
                    $ServerList += ($PassiveNode,0)
                }
            }
        }
    }
    else
    {
        $ServerList += ,($ComputerName_NoDomain,1)
        Write-StatusUpdate -Message "Found Server: $ComputerName_NoDomain"
    }

    #region Phase 1: Server, Cluster, and Volume Process
    ForEach ($Server in $ServerList)
    {
        $ServerName = $Server[0]
        $ServerIsActiveNode = $Server[1]
        $ClusterIsMonitored = $true
        $ServerIsMonitored = $true
        $NumberOfLogicalCores = 0
        $NumberOfCores = 0
        $ProcessorName = 'Unknown'
        $IsServerAccessible = $true
        $IsWMIAccessible = $true

        Write-StatusUpdate -Message "Processing Server [$ServerName]."

        if ($OperatingSystem -ne 'Windows Server 2000')
        {
            try
            {
                $Processors = Get-WmiObject -Class Win32_Processor -ComputerName $ServerName

                ForEach ($Processor IN $Processors)
                {
                    $ProcessorName = $Processor.Name
                    $NumberOfCores += $Processor.NumberOfCores
                    $NumberOfLogicalCores += $Processor.NumberOfLogicalProcessors
                }
            }
            catch [System.Runtime.InteropServices.COMException]
            {
                Write-StatusUpdate -Message "WMI Call Failed [Process Information] for [$ServerName]; server not found." -WriteToDB
                $IsServerAccessible = $false
            }
            catch [System.UnauthorizedAccessException]
            {
                Write-StatusUpdate -Message "WMI Call Failed [Process Information] for [$ServerName]; access denied." -WriteToDB
                $IsWMIAccessible = $false
            }
            catch [System.Management.ManagementException]
            {
                Write-StatusUpdate -Message "WMI Call Failed [Process Information] for [$ServerName]; unknown exception." -WriteToDB
                $IsWMIAccessible = $false
            }
            catch
            {
                Write-StatusUpdate -Message "WMI Call Failed [Process Information] for [$ServerName] (unhandled exception)." -WriteToDB
                Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
                $IsServerAccessible = $false
            }
        }

        # If WMI called for processor failed; chances are the volume call failed also.  To minimize the error reporting in
        # execution log; only attempt server related updates if initial WMI was successful.
        if ($IsServerAccessible)
        {
            # Find the server, if it exists update it; if not add it.
            $Results = Get-Server $ServerName

            switch ($Results)
            {
                $Global:Error_ObjectsNotFound
                {
                    Write-StatusUpdate -Message "New server, adding to database."
                    $InnerResults = Add-Server $ServerName $OperatingSystem $ProcessorName $NumberOfCores $NumberOfLogicalCores $IsPhysical
                    Switch ($InnerResults)
                    {
                        $Global:Error_Duplicate
                        {   # This should not happen in code line.  However, it is being handled if a manual entry is made between initial
                            # detection of missing server to adding the new server.
                            $ServerIsMonitored = $false
                            Write-StatusUpdate -Message "Failed to Add-Server, duplicate value found [$ServerName]." -WriteToDB
                        }
                        $Global:Error_FailedToComplete
                        {
                            $ServerIsMonitored = $false
                            Write-StatusUpdate -Message "Failed to Add-Server [$ServerName]."
                        }
                        default
                        {
                            $ServerIsMonitored = $true
                        }
                    }
                    break;
                }
                $Global:Error_FailedToComplete
                {
                    $ServerIsMonitored = $false
                    Write-StatusUpdate -Message "Failed to Get-Server [$ServerName]."
                    break;
                }
                default
                {
                    Write-StatusUpdate -Message "Existing server."
                    $ServerIsMonitored = $Results.IsMonitored
                    if ($ServerIsMonitored)
                    {
                        $InnerResults = Update-Server $ServerName $OperatingSystem $ProcessorName $NumberOfCores $NumberOfLogicalCores $IsPhysical

                        if ($InnerResults -eq $Global:Error_FailedToComplete)
                        {
                            $ServerIsMonitored = $false
                            Write-StatusUpdate -Message "Failed to Update-Server [$ServerName]."
                        }
                    }
                    break;
                }
            }


            if ((($IsClustered -eq 1) -or ($ServerType -eq 'Microsoft Clustering') -or ($ServerType -eq 'Veritas Clustering')) -and ($ServerIsMonitored))
            {
                Write-StatusUpdate -Message "Current instance is a Clustered Instance."
                $Results = Get-SQLCluster $ComputerName_NoDomain

                Switch ($Results)
                {
                    $Global:Error_ObjectsNotFound
                    {
                        Write-StatusUpdate -Message "New Cluster"
                        $InnerResults = Add-SQLCluster $ComputerName_NoDomain
                        Switch ($InnerResults)
                        {
                            $Global:Error_Duplicate
                            {
                                $ClusterIsMonitored = $false
                                Write-StatusUpdate -Message "Failed to Add-SQLCluster, duplicate value found [$ComputerName_NoDomain]." -WriteToDB
                            }
                            $Global:Error_FailedToComplete
                            {
                                $ClusterIsMonitored = $false
                                Write-StatusUpdate -Message "Failed to Add-SQLCluster [$ComputerName_NoDomain]."
                            }
                            default
                            {
                                Write-StatusUpdate -Message "Existing Cluster"
                                $ClusterIsMonitored = $true
                            }
                        }
                        break;
                    }
                    $Global:Error_FailedToComplete
                    {
                        $ClusterIsMonitored = $false
                        Write-StatusUpdate -Message "Failed to Get-SQLCluster [$ComputerName_NoDomain]."
                        break;
                    }
                    default
                    {
                        $ClusterIsMonitored = $Results.IsMonitored
                        break;
                    }
                }


                if ($ClusterIsMonitored)
                {
                    Write-StatusUpdate -Message "Cluster is monitored; updating node information."
                    $ProcessTheNode = $true
                    $Results = Get-SQLClusterNode $ComputerName_NoDomain $ServerName

                    Switch ($Results)
                    {
                        $Global:Error_ObjectsNotFound
                        {
                            Write-StatusUpdate -Message "New Cluster Node"
                            $InnerResults = Add-SQLClusterNode $ComputerName_NoDomain $ServerName $ServerIsActiveNode

                            Switch ($InnerResults)
                            {
                                $Global:Error_Duplicate
                                {
                                    $ProcessTheNode = $false
                                    Write-StatusUpdate -Message "Failed to Add-SQLClusterNode, duplicate object. [$ComputerName_NoDomain\$ServerName]." -WriteToDB
                                }
                                $Global:Error_ObjectsNotFound
                                {
                                    $ProcessTheNode = $false
                                    Write-StatusUpdate -Message "Failed to Add-SQLClusterNode, missing the server or cluster object [$ComputerName_NoDomain\$ServerName]." -WriteToDB
                                }
                                $Global:Error_FailedToComplete
                                {
                                    $ProcessTheNode = $false
                                    Write-StatusUpdate -Message "Failed to Add-SQLClusterNode [$ComputerName_NoDomain\$ServerName]."
                                }
                            }
                            break;
                        }
                        $Global:Error_FailedToComplete
                        {
                            $ProcessTheNode = $false
                            Write-StatusUpdate -Message "Failed to Get-SQLClusterNode [$ComputerName_NoDomain\$ServerName]."
                            break;
                        }
                    }

                    if ($ProcessTheNode)
                    {
                        $Results = Update-SQLCluster $ComputerName_NoDomain

                        if ($Results -eq $Global:Error_FailedToComplete)
                        {
                                Write-StatusUpdate -Message "Failed to update SQL CMDB Cluster's info for [$ComputerName_NoDomain]."
                        }

                        $Results = Update-SQLClusterNode $ComputerName_NoDomain $ServerName

                        if ($Results -eq $Global:Error_FailedToComplete)
                        {
                                Write-StatusUpdate -Message "Failed to update SQL CMDB Cluster Node's info for [$ComputerName_NoDomain\$ServerName]."
                        }

                        # Current solution does not support Windows 2000 disk space report.
                        if ($OperatingSystem -ne "Windows Server 2000")
                        {
                            Write-StatusUpdate -Message "Windows 2003+ Updating Disk Volume Information"

                            if ($IsWMIAccessible)
                            {
                                $Results = Update-DiskVolumes $ServerName $FQDN $ComputerName_NoDomain $DBFolderList $BackupFolderList

                                if ($Results -eq $Global:Error_FailedToComplete)
                                {
                                    Write-StatusUpdate -Message "Failed to update the volume space details for [$($SQLServerRC.ComputerName)]."
                                }
                            }
                        }
                    }
                    
                }

            }
            else
            {
                if (($ServerIsMonitored) -and ($OperatingSystem -ne "Windows Server 2000"))
                {
                    Write-StatusUpdate -Message "Stand alone instance; Windows 2003+ Updating Disk Volume Information"

                    if ($IsWMIAccessible)
                    {
                        $Results = Update-DiskVolumes $ServerName $FQDN

                        if ($Results -eq $Global:Error_FailedToComplete)
                        {
                            Write-StatusUpdate -Message "Failed to update the volume space details for [$($SQLServerRC.ComputerName)]." -WriteToDB
                        }
                    }
                }
                elseif (!($ServerIsMonitored))
                {
                    Write-StatusUpdate -Message "Stand alone instance; server not monitored."
                }

            }
        }

        if ($DCS_DiscoverSQLServices)
        {
            $SQLServices = Get-SISQLService -ComputerName $ServerName

            if ($SQLServices)
            {
                $Results = Update-SQLService -ComputerName $ServerName -Data $SQLServices

                if ($Results -eq $Global:Error_FailedToComplete)
                {
                    Write-StatusUpdate -Message "Failed to update SQL Services Detail for [$ServerName]" -WriteToDB
                }
            }
            else {
                Write-StatusUpdate -Message "Failed to collect SQL Services Detail for [$ServerName]" -WriteToDB
            }
        }

    }
    #endregion

    # Phase 2: SQL Instances, Availability Groups, and Databases Process
    $Results = Get-SqlOpSQLInstance -ServerInstance $SQLServerRC.ServerInstanceConnectionString -Internal

    switch ($Results)
    {
        $Global:Error_ObjectsNotFound
        {
            Write-StatusUpdate -Message "New Instance."
            $InnerResults = Add-SQLInstance $ComputerName_NoDomain $SQLServerRC.SQLInstanceName $SQLVersion $SQLServer_Build $SQLEdition $ServerType $EnvironmentType

            switch ($InnerResults)
            {
                $Global:Error_Duplicate
                {
                    Write-StatusUpdate -Message "Failed to Add-SQLInstance, duplicate object for [$($SQLServerRC.ServerInstance)]." -WriteToDB
                    break;
                }
                $Global:Error_FailedToComplete
                {
                    $SQLInstanceAccessible = $false
                    break;
                }
                default
                {
                    $InnerResults = Get-SqlOpSQLInstance -ServerInstance $SQLServerRC.ServerInstanceConnectionString -Internal
                    $ServerInstanceIsMonitored = $InnerResults.IsMonitored
                    $SQLInstanceID = $InnerResults.SQLInstanceID
                    break;
                }
            }
            break;
        }
        $Global:Error_FailedToComplete
        {
            $SQLInstanceAccessible = $false
            break;
        }
        default
        {
            Write-StatusUpdate -Message "Existing Instance."
            $ServerInstanceIsMonitored = $Results.IsMonitored
            $SQLInstanceID = $Results.SQLInstanceID
            break;
        }
    }

    # Currently IsInstanceAccessible means that it exists with in CMDB.
    if (($ServerInstanceIsMonitored) -and ($SQLInstanceAccessible) -and ($IsServerAccessible))
    {
        Write-StatusUpdate -Message "Instance is monitored."

        #Instance is monitored; before we collect the database information; we need to check for any
        #existing AG configuration.  AG is only possible on SQL Server version 2012+.
        try
        {
            if ($SQLServer_Major -ge 11)
            {
                #Request all the AG and their replica details for current instance.
                $TSQL = "WITH CTE AS (
                            SELECT AG.Group_id AS AGGuid,
                                AG.name AS AGName,
                                lower(AR.replica_server_name) AS ReplicaName,
                                charindex('\',AR.replica_server_name) AS SlashLocation,
                                len(AR.replica_server_name) - charindex('\',AR.replica_server_name) AS LenInstanceName
                            FROM sys.availability_groups AG
                            JOIN sys.availability_replicas AR
                                ON AG.group_id = AR.group_id)
                            SELECT AGGuid,
                                AGName,
                                CASE WHEN SlashLocation > 0 THEN
                                    SUBSTRING(ReplicaName,1,SlashLocation-1)
                                ELSE
                                    ReplicaName
                                END AS ServerVCOName,
                                CASE WHEN SlashLocation > 0 THEN
                                    SUBSTRING(ReplicaName,SlashLocation+1,LenInstanceName)
                                ELSE
                                    'mssqlserver'
                                END AS InstanceName
                            FROM CTE"

                Write-StatusUpdate -Message $TSQL -IsTSQL                    
                $Results = Invoke-SQLCMD -ServerInstance $SQLServerRC.ServerInstanceConnectionString  `
                                            -Database 'master' `
                                            -Query $TSQL -ErrorAction Stop

                # If result set is empty this instance has no AG on it right now.
                If ($Results)
                {
                    ForEach ($Record in $Results)
                    {
                        $AGName = $Record.AGName
                        $AGGuid = $Record.AGGuid.Guid
                        $AGServerVCNOName = $Record.ServerVCOName
                        $AGInstanceName = $Record.InstanceName
                            
                        $Results = Get-AG $AGServerVCNOName $AGInstanceName $AGName $AGGuid

                        switch ($Results)
                        {
                            # Object not found means multiple things in this scenario:
                            # 1) AG does not exist.
                            # 2) Instance does not exist.
                            # 3) AG <-> Instance relationship does not exist.
                            $Global:Error_ObjectsNotFound
                            {
                                Write-StatusUpdate -Message "New AG."
                                $InnerResults = Add-AG $AGServerVCNOName $AGInstanceName $AGName $AGGuid

                                switch ($InnerResults)
                                {
                                    $Global:Error_Duplicate
                                    {
                                        Write-StatusUpdate -Message "Failed to Add-AG, duplicate object for [$AGServerVCNOName\$AGInstanceName\$AGName]." -WriteToDB
                                        break;
                                    }
                                    $Global:Error_FailedToComplete
                                    {
                                        Write-StatusUpdate -Message "Failed to Add-AG for [$AGServerVCNOName\$AGInstanceName\$AGName]."
                                        break;
                                    }
                                    default
                                    {
                                        $InnerResults = Get-AG $AGServerVCNOName $AGInstanceName $AGName $AGGuid
                                        $AGID = $InnerResults.AGID
                                        break;
                                    }
                                }
                                break;
                            }
                            $Global:Error_FailedToComplete
                            {
                                Write-StatusUpdate -Message "Failed to Get-AG for [$AGServerVCNOName\$AGInstanceName\$AGName]."
                                break;
                            }
                            default
                            {
                                Write-StatusUpdate -Message "Existing AG."
                                $AGID = $InnerResults.AGID
                                Update-AG $AGServerVCNOName $AGInstanceName $AGName $AGGuid
                                break;
                            }
                        }
                    }
                }
            }
        }
        catch [System.Data.SqlClient.SqlException]
        {
            Write-StatusUpdate -Message "Cannot reach SQL Server instance [$($SQLServerRC.ServerInstance)]." -WriteToDB
            $SQLInstanceAccessible = $false
        }
        catch
        {
            Write-StatusUpdate -Message "Failed to talk to SQL Instance (unhandled expectation)." -WriteToDB
            Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
            $SQLInstanceAccessible = $false
        }

        try
        {
            Write-StatusUpdate -Message "Getting list of databases"

            if ($SQLServer_Major -eq 8)
            {
                $TSQL = " SELECT   $SQLInstanceID AS InstanceID
                                    , CAST('00000000-0000-0000-0000-000000000000' AS uniqueidentifier) AS AGGuid
                                    , name AS DatabaseName
                                    , CASE
                                        WHEN ((status & 8 = 8) OR (status & 16 = 16) OR (status & 24 = 24)) and (status & 512 <> 512) THEN
                                            'Online'
                                        WHEN status & 512 = 512 THEN
                                            'Offline'
                                        WHEN status & 1024 = 1024 THEN
                                            'Read Only'
                                        ELSE
                                            'Unknown'
                                    END AS DatabaseState
                                    , '----' AS FileType
                                    , 0 AS FileSize_mb                                        
                            FROM sysdatabases
                            WHERE dbid NOT IN (1,3,4)"
            }
            elseif (($SQLServer_Major -ge 9) -and ($SQLServer_Major -le 10))
            {
                $TSQL = "   WITH DBDetails
                                AS (SELECT   DB_NAME(D.database_id) AS DatabaseName
                                            , D.state_desc AS DatabaseState
                                            , CASE WHEN type = 0 THEN 'Data' ELSE 'Log' END AS FileType
                                            , size/128 AS FileSize_mb
                                    FROM sys.master_files mf
                                    JOIN sys.databases D
                                        ON mf.database_id = D.database_id
                                    WHERE D.database_id NOT IN (1,3,4))
                            SELECT   $SQLInstanceID AS InstanceID
                                    , CAST('00000000-0000-0000-0000-000000000000' AS uniqueidentifier) AS AGGuid
                                    , DatabaseName
                                    , DatabaseState
                                    , FileType
                                    , SUM(FileSize_mb) AS FileSize_mb
                            FROM DBDetails
                        GROUP BY DatabaseName, DatabaseState, FileType"
            }
            else
            {
                $TSQL = "  WITH DBDetails
                                AS (SELECT   ISNULL(AG.group_id,CAST('00000000-0000-0000-0000-000000000000' AS uniqueidentifier)) AS AGGuid
                                        , DB_NAME(MF.database_id) AS DatabaseName
                                        , D.state_desc AS DatabaseState
                                        , CASE WHEN type = 0 THEN 'Data' ELSE 'Log' END AS FileType
                                        , size/128 AS FileSize_mb
                                    FROM sys.master_files MF
                                LEFT JOIN sys.databases D
                                        ON MF.database_id = D.database_id
                                LEFT JOIN sys.availability_replicas AR
                                        ON D.replica_id = AR.replica_id
                                LEFT JOIN sys.availability_groups AG
                                        ON AR.group_id = AG.group_id
                                    WHERE MF.database_id NOT IN (1,3,4))
                        SELECT   $SQLInstanceID AS InstanceID
                                , AGGuid
                                , DatabaseName
                                , DatabaseState 
                                , FileType
                                , SUM(FileSize_mb) AS FileSize_mb
                            FROM DBDetails
                        GROUP BY AGGuid, DatabaseName, DatabaseState, FileType"
            }
            Write-StatusUpdate -Message $TSQL -IsTSQL                    
            $Results = Invoke-SQLCMD -ServerInstance $SQLServerRC.ServerInstanceConnectionString  `
                                        -Database 'master' `
                                        -Query $TSQL -ErrorAction Stop

            if ($Results)
            {

                $TSQL = "Truncate Table Staging.DatabaseSizeDetails"
                Write-StatusUpdate -Message $TSQL -IsTSQL                    
                Invoke-SQLCMD -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                                -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                                -Query $TSQL -ErrorAction Stop

                Write-StatusUpdate -Message "Writing database details to staging table" -IsTSQL                    
                Write-DataTable -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                                -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database -Data $Results -Table "Staging.DatabaseSizeDetails"

                # Update database catalog
                $TSQL = "WITH CTE AS
                        ( SELECT DISTINCT SQLInstanceID, DatabaseName, DatabaseState
                            FROM Staging.DatabaseSizeDetails)
                        MERGE dbo.Databases AS Target
                        USING (SELECT SQLInstanceID, DatabaseName, DatabaseState FROM CTE) AS Source (SQLInstanceID, DatabaseName, DatabaseState)
                        ON (Target.SQLInstanceID = Source.SQLInstanceID AND Target.DatabaseName = Source.DatabaseName)
                        WHEN MATCHED THEN
                            UPDATE SET Target.LastUpdated = GETDATE(),
                                        Target.DatabaseState = Source.DatabaseState
                        WHEN NOT MATCHED THEN
                            INSERT (SQLInstanceID, DatabaseName, DatabaseState, IsMonitored, DiscoveryOn, LastUpdated) VALUES (Source.SQLInstanceID, Source.DatabaseName, Source.DatabaseState, 1, GetDate(), GetDate());"

                Write-StatusUpdate -Message $TSQL -IsTSQL                    
                $Results = Invoke-SQLCMD -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                                            -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                                            -Query $TSQL -ErrorAction Stop

                IF ($SQLServer_Major -ne 8)
                {
                    # Update database space's catalog, only collect database space information for SQL 2005+.
                    $TSQL = "WITH CTE AS (
                            SELECT D.DatabaseID, SD.FileSize_mb, SD.FileType
                                FROM Staging.DatabaseSizeDetails SD
                                JOIN dbo.Databases D
                                ON SD.DatabaseName = D.DatabaseName
                                AND SD.SQLInstanceID = D.SQLInstanceID
                                AND D.IsMonitored = 1)
                            MERGE dbo.DatabaseSize AS Target
                            USING (SELECT DatabaseID, FileSize_mb, FileType FROM CTE) AS Source (DatabaseID, FileSize_mb, FileType)
                            ON (Target.DatabaseID = Source.DatabaseID AND Target.DateCaptured = GetDate() AND Target.FileType = Source.FileType)
                            WHEN MATCHED THEN
                            UPDATE SET FileSize_mb = (Target.FileSize_mb + Source.FileSize_mb)/2
                            WHEN NOT MATCHED THEN
                            INSERT (DatabaseID, FileType, DateCaptured, FileSize_mb) VALUES (Source.DatabaseID, Source.FileType, GetDate(), Source.FileSize_mb);"

                    Write-StatusUpdate -Message $TSQL -IsTSQL                    
                    $Results = Invoke-SQLCMD -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                                                -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                                                -Query $TSQL -ErrorAction Stop
                }

                if ($SQLServer_Major -ge 11)
                {
                    #Update AG to Database Mapping Information
                    $TSQL = "  WITH CTE
                                    AS (SELECT AGInstanceID, DatabaseID
                                        FROM Staging.DatabaseSizeDetails SD
                                        JOIN dbo.Databases D
                                            ON SD.DatabaseName = D.DatabaseName
                                        AND SD.SQLInstanceID = D.SQLInstanceID
                                        AND D.IsMonitored = 1
                                        JOIN dbo.AGs A
                                        ON SD.AGGuid = A.AGGuid
                                        JOIN dbo.AGInstances AGI
                                            ON A.AGID = AGI.AGID
                                            AND AGI.SQLInstanceID = SD.SQLInstanceID
                                        WHERE FileType = 'Data')
                                MERGE dbo.AGDatabases AS Target
                                USING (SELECT AGInstanceID, DatabaseID FROM CTE) AS Source (AGInstanceID, DatabaseID)
                                    ON (Target.DatabaseID = Source.DatabaseID AND Target.AGInstanceID = Source.AGInstanceID)
                                WHEN NOT MATCHED THEN
                                INSERT (AGInstanceID,DatabaseID) VALUES (Source.AGInstanceID, Source.DatabaseID);"

                    Write-StatusUpdate -Message $TSQL -IsTSQL                    
                    $Results = Invoke-SQLCMD -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                                                -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                                                -Query $TSQL -ErrorAction Stop
                }

            }
            else
            {
                Write-StatusUpdate -Message "No user databases found on [$($SQLServerRC.ServerInstance)]." -WriteToDB
                $SQLInstanceAccessible = $false
            }

        }
        catch [System.Data.SqlClient.SqlException]
        {
            Write-StatusUpdate -Message "Cannot reach SQL Server instance [$($SQLServerRC.ServerInstance)]." -WriteToDB
            $SQLInstanceAccessible = $false
        }
        catch
        {
            Write-StatusUpdate -Message "Failed to talk to SQL Instance (unhandled exception)." -WriteToDB
            Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
            $SQLInstanceAccessible = $false
        }

        # Update the Database Space Information
        $Results = Update-SQLInstance $ComputerName_NoDomain $SQLServerRC.SQLInstanceName $SQLVersion $SQLServer_Build $SQLEdition $ServerType $EnvironmentType
        if ($Results -eq $Global:Error_FailedToComplete)
        {
            Write-StatusUpdate -Message "Failed to Update-SQLInstance for [$($SQLServerRC.ServerInstance)]."
        }

        if ($DCS_ErrorLogs)
        {
            # Cannot collect error logs from SQL 2000.  Get-SQLErrorLog is not backwards compatible.
            if ($SQLServer_Major -ne 8)
            {
                # Get SQL Instance Error Logs.  Get the last collect date, then get only errors since last collection.
                # record the errors in SQLOpsDB.  Then update all collection date time.

                if ($DCS_ThrottleErrorLogCollection)
                {

                    $LastDataCollection = Get-SQLOpSQLErrorLogStats -ServerInstance $SQLServerRC.ServerInstanceConnectionString
                    $Last30Hours = (Get-Date).AddHours(-30)
                    $StartDataCollectionTime = [DateTime]$LastDataCollection.LastDateTimeCaptured

                    $StartProcessTime = Get-Date

                    if ($Last30Hours -ge $StartDataCollectionTime)
                    {
                        Write-StatusUpdate -Message "Skipping Error Logs for [$($SQLServerRC.ServerInstance)].  Skipped from '$StartDataCollectionTime' to '$Last30Hours'." -WriteToDB
                        $StartDataCollectionTime = $Last30Hours
                    }

                    $ThrottleTriggered = $true

                    While (($EndProcessTime - $StartProcessTime).Seconds -le $DCS_ThrottleLimit * 60)
                    {
                        # Cycle through error log one hour at a time.

                        $OneHourPlus = $StartDataCollectionTime.AddHours(1)
                        $ErrorLogs = Get-SISQLErrorLogs -ServerInstance $SQLServerRC.ServerInstanceConnectionString -After $StartDataCollectionTime -Before $OneHourPlus -Internal
                        if ($ErrorLogs)
                        {
                            Update-SQLOpSQLErrorLog -ServerInstance $SQLServerRC.ServerInstanceConnectionString -Data $ErrorLogs | Out-Null
                        }
                        Update-SQLOpSQLErrorLogStats -ServerInstance $SQLServerRC.ServerInstanceConnectionString -DateTime $OneHourPlus | Out-Null 

                        $StartDataCollectionTime = $OneHourPlus
                        if ($StartDataCollectionTime.AddHours(1) -ge (Get-Date))
                        {
                            $ThrottleTriggered = $false
                            break
                        }
                        $EndProcessTime = Get-Date
                    }

                    if ($ThrottleTriggered)
                    {
                        Write-StatusUpdate -Message "Throttle Setting Triggered. Error logs for [$($SQLServerRC.ServerInstance)] did not finish.  Collection finished to [$StartDataCollectionTime]." -WriteToDB
                    }
                }
                else
                {
                    $LastDataCollection = Get-SQLOpSQLErrorLogStats -ServerInstance $SQLServerRC.ServerInstanceConnectionString
                    $ErrorLogs = Get-SISQLErrorLogs -ServerInstance $SQLServerRC.ServerInstanceConnectionString -After $LastDataCollection.LastDateTimeCaptured -Internal
                    if ($ErrorLogs)
                    {
                        Update-SQLOpSQLErrorLog -ServerInstance $SQLServerRC.ServerInstanceConnectionString -Data $ErrorLogs | Out-Null
                    }
                    Update-SQLOpSQLErrorLogStats -ServerInstance $SQLServerRC.ServerInstanceConnectionString | Out-Null   
                }
            }
            else
            {
                Write-StatusUpdate -Message "Skipping Error Logs for [$($SQLServerRC.ServerInstance)].  SQL Server 2000 not supported." -WriteToDB
            }
        }

        if ($DCS_SQLJobs)
        {
            # Cannot collect job stats from SQL 2000.  I don't have a SQL 2000 server.
            if ($SQLServer_Major -ne 8)
            {
                # Get SQL Instance Error Logs.  Get the last collect date, then get only errors since last collection.
                # record the errors in SQLOpsDB.  Then update all collection date time.

                $LastDataCollection = Get-SQLOpSQLJobStats -ServerInstance $SQLServerRC.ServerInstanceConnectionString
                $SQLJobs = Get-SISQLJobs -ServerInstance $SQLServerRC.ServerInstanceConnectionString -After $LastDataCollection.LastDateTimeCaptured -Internal
                if ($SQLJobs)
                {
                    Update-SQLOpSQLJobs -ServerInstance $SQLServerRC.ServerInstanceConnectionString -Data $SQLJobs | Out-Null
                }
                Update-SQLOpSQLJobStats -ServerInstance $SQLServerRC.ServerInstanceConnectionString | Out-Null   
            }
            else
            {
                Write-StatusUpdate -Message "Skipping SQL Job collection for [$($SQLServerRC.ServerInstance)].  SQL Server 2000 not supported." -WriteToDB
            }
        }
            
    }
    elseif (!($ServerInstanceIsMonitored))
    {
        Write-StatusUpdate -Message "Instance is not monitored."
    }

}
#endregion

#Phase 3: Aggregation for Disk Space & Database Space
Write-StatusUpdate -Message "Phase 3: Aggregation for Disk Space & Database Space"

    $CurrentDate = Get-Date
    $FirstDayOfMonth = Get-Date -Year $CurrentDate.Year -Month $CurrentDate.Month -Day 1
    $Today = $CurrentDate.ToString('yyyyMMdd')
    $FirstDayOfMonth = $FirstDayOfMonth.ToString('yyyyMMdd')

    #Phase 3.1: Aggregate Data for Disk Space and Database Space
    Write-StatusUpdate -Message "Phase 3.1: Aggregate Data for Disk Space and Database Space"

    if ($Today -eq $FirstDayOfMonth)
    {
        Aggregate-CMDBMonthlyData -Type DiskVolumes
        Aggregate-CMDBMonthlyData -Type Databases
    }

    #Phase 3.2: Truncate Raw Data for Disk Space and Database Space
    Write-StatusUpdate -Message "Phase 3.2: Truncate Raw Data for Disk Space and Database Space"

    Truncate-CMDBData -Type Raw_DiskVolumes
    Truncate-CMDBData -Type Raw_Database

    #Phase 3.3: Build Trending Data, Truncate Aggregate Data
    Write-StatusUpdate -Message "Phase 3.3: Build Trending Data, Truncate Aggregate Data"

    if ($Today -eq $FirstDayOfMonth)
    {
        Create-CMDBMonthlyTrend -Type Servers
        Create-CMDBMonthlyTrend -Type SQLInstances
        Create-CMDBMonthlyTrend -Type Databases
        Truncate-CMDBData -Type Monthly_DiskVolumes
        Truncate-CMDBData -Type Monthly_Database
        Truncate-CMDBData -Type Trending_AllObjects
    }

    #Phase 3.4: Clean Up Expired Data
    Write-StatusUpdate -Message "Phase 3.4: Clean Up Expired Data"

    # Disabled 20200310 -- Multiple bugs --
    #Delete-CMDBData -Type Databases
    #Delete-CMDBData -Type DiskVolumes
    #Delete-CMDBData -Type SQLInstances
    #Delete-CMDBData -Type SQLClusters
    #Delete-CMDBData -Type Servers

    #Phase 3.5: Clean Up CMDB Log Data
    Write-StatusUpdate -Message "Phase 3.5: Clean Up CMDB Log Data"

    if ($Today -eq $FirstDayOfMonth)
    {
        Truncate-CMDBLog
    }

Write-StatusUpdate "SQLOpsDB - Collection End" -WriteToDB

## Code End