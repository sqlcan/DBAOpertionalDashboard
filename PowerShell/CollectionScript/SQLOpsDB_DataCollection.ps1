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

$DCS_ErrorLogs = $true            # Collect SQL Server Error Logs
$DSC_DiscoverSQLServices = $true  # Review SQL Services Installed on a Server.

## Code Start

Write-StatusUpdate -Message "SQLOpsDB - Collection Start" -WriteToDB

#region Get Server List
try
{
    Write-StatusUpdate -Message "Getting list of SQL Instances from CMS Server [$Global:CMS_SQLServerName]."

    # Get list of SQL Server Instances from Central Management Server (CMS).
    # Enable or disable which CMS groups are monitored via Set-CMSGroup commandlet.
    $SQLServers = Get-CMSServers #-ServerName contoso.com
}
catch
{
    Write-StatusUpdate -Message "Failed to get list of servers from CMS Server (unhandled exception)." -WriteToDB
    Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
    return
}
#endregion

#region Loop through all the SQL Instances collected from Central Management Servers (CMS).
ForEach ($SQLServerRC in $SQLServers)
{

    $SQLServer = $SQLServerRC.name
    $SQLServerFQDN = $SQLServerRC.server_name
    Write-StatusUpdate -Message "Processing SQL Instance [$SQLServerFQDN] ..." -WriteToDB

    # Initialize all the variables for current Instance
    [Array] $ServerList = $null
    $IsClustered = 0
    $IsPhysical = 1
    $SQLInstanceName = 'MSSQLServer'
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

    # Before we start processing the SQL Instance, we need to parse out the VCO/Server Name and Instance Name.
    # The connection will still happen with SERVER.FQDN\INSTANCE,PORT or VCO.FQDN\INSTANCE,PORT.
    $SQLServer = $SQLServer.ToLower()
    $SQLServerFQDN = $SQLServerFQDN.ToLower()

    if ($SQLServer.IndexOf(',') -gt -1)
    {
        # User has included the port number in display name.  Strip out the port number.
        #
        # Raise a warning in logs to correct CMS configuration.

        Write-StatusUpdate -Message "Display Name in CMS misconfigured for [$($TokenizedSQLInstanceName[0])], port number should not be included." -WriteToDB
        $SQLServer = $SQLServer.Substring(0,$SQLServer.IndexOf(','))
    }

    $TokenizedSQLInstanceName = $($SQLServer.Split(',')).Split('\')
    $TokenizedSQLInstanceNameFQDN = $($SQLServerFQDN.Split(',')).Split('\')

    # Check to make sure server name and server name FQDN follow standards set in CMS.
    if ($TokenizedSQLInstanceName[0].IndexOf('.') -gt -1)
    {
        # User has fully qualified the server name also.  Strip away the domain information.
        #
        # Raise a warning in logs to correct CMS configuration.

        Write-StatusUpdate -Message "Display Name in CMS misconfigured for [$($TokenizedSQLInstanceName[0])], domain name should not be included." -WriteToDB
        $TokenizedSQLInstanceName[0] = $TokenizedSQLInstanceName[0].Substring(0,$TokenizedSQLInstanceName[0].IndexOf('.'))
        
    }

    if ($TokenizedSQLInstanceNameFQDN[0].IndexOf('.') -eq -1)
    {
        # User is missing fully qualified domain name for server name.  
        #
        # Raise a warning in logs to correct CMS configuration.

        Write-StatusUpdate -Message "Server Name in CMS misconfigured for [$($TokenizedSQLInstanceNameFQDN[0])], domain name should be included." -WriteToDB
        $TokenizedSQLInstanceNameFQDN[0] = [String]::Concat($TokenizedSQLInstanceNameFQDN[0],'.',$FQDN)
    }

    $ServerVNOName = $TokenizedSQLInstanceName[0]
    $ServerVNONameFQDN = $TokenizedSQLInstanceNameFQDN[0]

    # If the tokenized array count is two, it means non-default instance name is supplied.
    if ($TokenizedSQLInstanceName.Count -eq 2)
    {
        $SQLInstanceName = $TokenizedSQLInstanceName[1]
    }

    # Check to confirm Extended Properties table exists; as script heavily relies on this table.
    # Also check if Extended Properties are defined for key settings; as it leads to confusion if they are missing.
    try
    {

        Write-StatusUpdate -Message "Checking if extended properties table exists."

        $SQLInstanceAccessible = $true

        $TSQL = "SELECT id AS TblId FROM sysobjects WHERE name = 'extended_properties'"
        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $SQLServerFQDN  `
                                    -Database 'master' `
                                    -Query $TSQL -ErrorAction Stop

        if (($Results) -and ($Results.TblId -lt 0))
        {
            $SchemaPrefix = 'sys'
        }
        elseif (($Results) -and ($Results.TblId -gt 0))
        {
            $SchemaPrefix = 'dbo'
        }
        else
        {
            Write-StatusUpdate -Message "Missing extended properties table in [$SQLServerFQDN]." -WriteToDB
            $SQLInstanceAccessible = $false
        }

        if ($SQLInstanceAccessible)
        {
            Write-StatusUpdate -Message "Checking if key extended properties exists."
            $TSQL = "SELECT COUNT(*) AS RwCnt FROM $SchemaPrefix.extended_properties WHERE name in ('EnvironmentType','MachineType','ServerType')"
            Write-StatusUpdate -Message $TSQL -IsTSQL

            # Find if the SQL Server a clustered instance (only applicable to FCI running under WFCS)
            $Results = Invoke-SQLCMD -ServerInstance $SQLServerFQDN  `
                                        -Database 'master' `
                                        -Query $TSQL -ErrorAction Stop

            if ($Results.RwCnt -ne 3)
            {
                Write-StatusUpdate -Message "Missing one or more of the key extended properties (EnvironmentType,MachineType,ServerType) in [$SQLServerFQDN]." -WriteToDB
                $SQLInstanceAccessible = $false
            }
            else
            {
                Write-StatusUpdate -Message "Getting instance details IsClustered, @@VERSION, Edition, ProductionVersion."
                $TSQL = "SELECT SERVERPROPERTY('IsClustered') AS IsClustered, @@VERSION AS SQLServerVersion, SERVERPROPERTY('Edition') AS SQLEdition, SERVERPROPERTY('ProductVersion') AS SQLBuild"
                Write-StatusUpdate -Message $TSQL -IsTSQL

                # must consider the value for previous result set; therefore both must be true for us to access the instance.
                $SQLInstanceAccessible = $true -and $SQLInstanceAccessible

                # Find if the SQL Server a clustered instance (only applicable to FCI running under WFCS)
                $Results = Invoke-SQLCMD -ServerInstance $SQLServerFQDN  `
                                            -Database 'master' `
                                            -Query $TSQL -ErrorAction Stop
            }
        }
    }
    catch [System.Data.SqlClient.SqlException]
    {
        Write-StatusUpdate -Message "Cannot reach SQL Server instance [$SQLServerFQDN]." -WriteToDB
        $SQLInstanceAccessible = $false
    }
    catch
    {
        Write-StatusUpdate -Message "Failed to connect to SQL Instance (unhandled exception)." -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        $SQLInstanceAccessible = $false
    }

    if ($SQLInstanceAccessible)
    {

        $IsClustered = $Results.IsClustered
        $SQLServerVersion = $Results.SQLServerVersion
        $SQLBuildString = $Results.SQLBuild
        $SQLEdition = $Results.SQLEdition

        #Build the SQL Server Version and Windows Version Details
        $TokenizedSQLBuild = $SQLBuildString.Split('.')

        [int]$SQLServer_Major = $TokenizedSQLBuild[0]
        [int]$SQLServer_Minor = $TokenizedSQLBuild[1]
        [int]$SQLServer_Build = $TokenizedSQLBuild[2]

        $SQLVersion = 'Microsoft SQL Server'

        switch ($SQLServer_Major)
        {
            8
            {
                $SQLVersion += ' 2000'
                break;
            }
            9
            {
                $SQLVersion += ' 2005'
                break;
            }
            10
            {
                $SQLVersion += ' 2008'
                switch ($SQLServer_Minor)
                {
                    {$_ -ge 50}
                    {
                        $SQLVersion += ' R2'
                    }
                }
                break;
            }
            11
            {
                $SQLVersion += ' 2012'
                break;
            }
            12
            {
                $SQLVersion += ' 2014'
            }
            13
            {
                $SQLVersion += ' 2016'
            }
            14
            {
                $SQLVersion += ' 2017'
            }
            15
            {
                $SQLVersion += ' 2019'
            }
        }

        if ($SQLServerVersion -like '*Windows NT 5.0*')
        {
            $OperatingSystem = "Windows Server 2000"
        }
        elseif ($SQLServerVersion -like '*Windows NT 5.2*')
        {
            $OperatingSystem = "Windows Server 2003"
        }
        elseif ($SQLServerVersion -like '*Windows NT 6.0*')
        {
            $OperatingSystem = "Windows Server 2008"
        }
        elseif ($SQLServerVersion -like '*Windows NT 6.1*')
        {
            $OperatingSystem = "Windows Server 2008 R2"
        }
        elseif ($SQLServerVersion -like '*Windows NT 6.2*')
        {
            $OperatingSystem = "Windows Server 2012"
        }
        elseif ($SQLServerVersion -like '*Windows NT 6.3*')
        {
            $OperatingSystem = "Windows Server 2012 R2"
        }
        elseif ($SQLServerVersion -like '*Windows Server 2016*')
        {
            $OperatingSystem = "Windows Server 2016"
        }
        elseif ($SQLServerVersion -like '*Windows Server 2019*')
        {
            $OperatingSystem = "Windows Server 2019"
        }

        Write-StatusUpdate -Message "SQL Server Version: [$SQLVersion]."
        Write-StatusUpdate -Message "   Windows Version: [$OperatingSystem]."

        # Collected Extended Properties Details

        # SQL Server 2000 does not have extended properties; however to mimic the functionality Extended Properties table has been created in
        # master database on SQL Server 2000 instances with in [dbo] schema vs SQL Server 2005+'s [sys] schema.
        if ($SQLVersion -eq 'Microsoft SQL Server 2000')
        {
            $SchemaPrefix = 'dbo'
        }

        Write-StatusUpdate -Message "Getting extended properties:"

        $TSQL = "SELECT value FROM $SchemaPrefix.extended_properties WHERE name = 'ServerType'"
        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $SQLServerFQDN `
                                    -Database 'master' `
                                    -Query $TSQL -ErrorAction Stop

        $ServerType = $Results.value

        Write-StatusUpdate -Message "Server Type: $ServerType"

        $TSQL = "SELECT value FROM $SchemaPrefix.extended_properties WHERE name = 'EnvironmentType'"
        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $SQLServerFQDN `
                                    -Database 'master' `
                                    -Query $TSQL -ErrorAction Stop

        $EnvironmentType = $Results.value


        Write-StatusUpdate -Message "Environment: $EnvironmentType"

        $TSQL = "SELECT value FROM $SchemaPrefix.extended_properties WHERE name = 'MachineType'"
        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $SQLServerFQDN `
                                    -Database 'master' `
                                    -Query $TSQL -ErrorAction Stop

        if ($Results.value -eq 'Physical')
        {
            $IsPhysical = 1
        }
        else
        {
            $IsPhysical = 0
        }

        Write-StatusUpdate -Message "Is Physical: $IsPhysical"

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

                $DBFolderList = Invoke-SQLCMD -ServerInstance $SQLServerFQDN `
                                                -Database 'master' `
                                                -Query $TSQL -ErrorAction Stop

                $TSQL = "SELECT DISTINCT LOWER(SUBSTRING(physical_device_name,1,LEN(physical_device_name)-CHARINDEX('\',REVERSE(physical_device_name)))) AS FolderName FROM msdb.dbo.backupmediafamily"
                Write-StatusUpdate -Message $TSQL -IsTSQL

                $BackupFolderList = Invoke-SQLCMD -ServerInstance $SQLServerFQDN  `
                                                    -Database 'master' `
                                                    -Query $TSQL -ErrorAction Stop
            }

            # Unlike Standalone Instances where the Physical Name is calculated, for FCI the node names must be supplied by DBA team.
            # If this information is blank, the servers list will be blank therefore no action against the $SQLServer will be taken.

            $TSQL = "SELECT value FROM $SchemaPrefix.extended_properties WHERE name = 'ActiveNode'"
            Write-StatusUpdate -Message $TSQL -IsTSQL

            $Results = Invoke-SQLCMD -ServerInstance $SQLServerFQDN  -Database 'master' -Query $TSQL -ErrorAction Stop

            if ($Results)
            {
                $ActiveNode = $($Results.value).ToLower()
                $ServerList += ,($ActiveNode,1)
                Write-StatusUpdate -Message "Found Server: $ActiveNode"

                $TSQL = "SELECT value FROM $SchemaPrefix.extended_properties WHERE name LIKE 'PassiveNode%'"
                Write-StatusUpdate -Message $TSQL -IsTSQL

                $PassiveNodes = Invoke-SQLCMD -ServerInstance $SQLServerFQDN  -Database 'master' -Query $TSQL -ErrorAction Stop

                if ($Results)
                {
                    ForEach ($PassiveNode in $PassiveNodes)
                    {
                        $ServerList += ,($($PassiveNode.value).ToLower(),0)
                        Write-StatusUpdate -Message "Found Server: $($PassiveNode.value.ToLower())"
                    }
                }
                else
                {
                    Write-StatusUpdate -Message "Extended properties PassiveNode* missing for [$SQLServerFQDN]." -WriteToDB
                }
            }
            else
            {
                Write-StatusUpdate -Message "Extended properties ActiveNode missing for [$SQLServerFQDN]." -WriteToDB
            }

        }
        else
        {
            $ServerList += ,($ServerVNOName,1)
            Write-StatusUpdate -Message "Found Server: $ServerVNOName"
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
                    $Processors = Get-WmiObject -Class Win32_Processor -ComputerName $ServerVNONameFQDN

                    ForEach ($Processor IN $Processors)
                    {
                        $ProcessorName = $Processor.Name
                        $NumberOfCores += $Processor.NumberOfCores
                        $NumberOfLogicalCores += $Processor.NumberOfLogicalProcessors
                    }
                }
                catch [System.Runtime.InteropServices.COMException]
                {
                    Write-StatusUpdate -Message "WMI Call Failed [Process Information] for [$ServerVNONameFQDN]; server not found." -WriteToDB
                    $IsServerAccessible = $false
                }
                catch [System.UnauthorizedAccessException]
                {
                    Write-StatusUpdate -Message "WMI Call Failed [Process Information] for [$ServerVNONameFQDN]; access denied." -WriteToDB
                    $IsWMIAccessible = $false
                }
                catch [System.Management.ManagementException]
                {
                    Write-StatusUpdate -Message "WMI Call Failed [Process Information] for [$ServerVNONameFQDN]; unknown exception." -WriteToDB
                    $IsWMIAccessible = $false
                }
                catch
                {
                    Write-StatusUpdate -Message "WMI Call Failed [Process Information] for [$SQLServerFQDN] (unhandled exception)." -WriteToDB
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
                    $Results = Get-SQLCluster $ServerVNOName

                    Switch ($Results)
                    {
                        $Global:Error_ObjectsNotFound
                        {
                            Write-StatusUpdate -Message "New Cluster"
                            $InnerResults = Add-SQLCluster $ServerVNOName
                            Switch ($InnerResults)
                            {
                                $Global:Error_Duplicate
                                {
                                    $ClusterIsMonitored = $false
                                    Write-StatusUpdate -Message "Failed to Add-SQLCluster, duplicate value found [$ServerVNOName]." -WriteToDB
                                }
                                $Global:Error_FailedToComplete
                                {
                                    $ClusterIsMonitored = $false
                                    Write-StatusUpdate -Message "Failed to Add-SQLCluster [$ServerVNOName]."
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
                            Write-StatusUpdate -Message "Failed to Get-SQLCluster [$ServerVNOName]."
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
                        $Results = Get-SQLClusterNode $ServerVNOName $ServerName

                        Switch ($Results)
                        {
                            $Global:Error_ObjectsNotFound
                            {
                                Write-StatusUpdate -Message "New Cluster Node"
                                $InnerResults = Add-SQLClusterNode $ServerVNOName $ServerName $ServerIsActiveNode

                                Switch ($InnerResults)
                                {
                                    $Global:Error_Duplicate
                                    {
                                        $ProcessTheNode = $false
                                        Write-StatusUpdate -Message "Failed to Add-SQLClusterNode, duplicate object. [$ServerVNOName\$ServerName]." -WriteToDB
                                    }
                                    $Global:Error_ObjectsNotFound
                                    {
                                        $ProcessTheNode = $false
                                        Write-StatusUpdate -Message "Failed to Add-SQLClusterNode, missing the server or cluster object [$ServerVNOName\$ServerName]." -WriteToDB
                                    }
                                    $Global:Error_FailedToComplete
                                    {
                                        $ProcessTheNode = $false
                                        Write-StatusUpdate -Message "Failed to Add-SQLClusterNode [$ServerVNOName\$ServerName]."
                                    }
                                }
                                break;
                            }
                            $Global:Error_FailedToComplete
                            {
                                $ProcessTheNode = $false
                                Write-StatusUpdate -Message "Failed to Get-SQLClusterNode [$ServerVNOName\$ServerName]."
                                break;
                            }
                        }

                        if ($ProcessTheNode)
                        {
                            $Results = Update-SQLCluster $ServerVNOName

                            if ($Results -eq $Global:Error_FailedToComplete)
                            {
                                    Write-StatusUpdate -Message "Failed to update SQL CMDB Cluster's info for [$ServerVNOName]."
                            }

                            $Results = Update-SQLClusterNode $ServerVNOName $ServerName

                            if ($Results -eq $Global:Error_FailedToComplete)
                            {
                                    Write-StatusUpdate -Message "Failed to update SQL CMDB Cluster Node's info for [$ServerVNOName\$ServerName]."
                            }

                            # Current solution does not support Windows 2000 disk space report.
                            if ($OperatingSystem -ne "Windows Server 2000")
                            {
                                Write-StatusUpdate -Message "Windows 2003+ Updating Disk Volume Information"

                                if ($IsWMIAccessible)
                                {
                                    $Results = Update-DiskVolumes $ServerName $FQDN $ServerVNOName $DBFolderList $BackupFolderList

                                    if ($Results -eq $Global:Error_FailedToComplete)
                                    {
                                        Write-StatusUpdate -Message "Failed to update the volume space details for [$ServerVNONameFQDN]."
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
                                Write-StatusUpdate -Message "Failed to update the volume space details for [$ServerName.$FQDN]." -WriteToDB
                            }
                        }
                    }
                    elseif (!($ServerIsMonitored))
                    {
                        Write-StatusUpdate -Message "Stand alone instance; server not monitored."
                    }

                }
            }

            if ($DSC_DiscoverSQLServices)
            {
                $SQLServices = Get-SISQLService -ComputerName $ServerVNONameFQDN

                if ($SQLServices)
                {
                    $Results = Update-SQLService -ComputerName $ServerName -Data $SQLServices

                    if ($Results -eq $Global:Error_FailedToComplete)
                    {
                        Write-StatusUpdate -Message "Failed to update SQL Services Detail for [$ServerVNONameFQDN]" -WriteToDB
                    }
                }
                else {
                    Write-StatusUpdate -Message "Failed to collect SQL Services Detail for [$ServerVNONameFQDN]" -WriteToDB
                }
            }

        }
        #endregion

        # Phase 2: SQL Instances, Availability Groups, and Databases Process
        $Results = Get-SqlOpSQLInstance -ServerInstance $SQLServerFQDN -Internal

        switch ($Results)
        {
            $Global:Error_ObjectsNotFound
            {
                Write-StatusUpdate -Message "New Instance."
                $InnerResults = Add-SQLInstance $ServerVNOName $SQLInstanceName $SQLVersion $SQLServer_Build $SQLEdition $ServerType $EnvironmentType

                switch ($InnerResults)
                {
                    $Global:Error_Duplicate
                    {
                        Write-StatusUpdate -Message "Failed to Add-SQLInstance, duplicate object for [$ServerVNOName\$SQLInstanceName]." -WriteToDB
                        break;
                    }
                    $Global:Error_FailedToComplete
                    {
                        $SQLInstanceAccessible = $false
                        break;
                    }
                    default
                    {
                        $InnerResults = Get-SqlOpSQLInstance -ServerInstance $SQLServerFQDN -Internal
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
                    $Results = Invoke-SQLCMD -ServerInstance $SQLServerFQDN  `
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
                Write-StatusUpdate -Message "Cannot reach SQL Server instance [$SQLServerFQDN]." -WriteToDB
                $SQLInstanceAccessible = $false
            }
            catch
            {
                Write-StatusUpdate -Message "Failed to talk to SQL Instance (unhandled expection)." -WriteToDB
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
                                     , '----' AS FileType
		                             , 0 AS FileSize_mb                                        
                                FROM sysdatabases
                                WHERE dbid NOT IN (1,3,4)"
                }
                elseif (($SQLServer_Major -ge 9) -and ($SQLServer_Major -le 10))
                {
                    $TSQL = "   WITH DBDetails
                                    AS (SELECT   DB_NAME(database_id) AS DatabaseName
	                                            , CASE WHEN type = 0 THEN 'Data' ELSE 'Log' END AS FileType
				                                , size/128 AS FileSize_mb
                                        FROM sys.master_files
                                        WHERE database_id NOT IN (1,3,4))
                                SELECT   $SQLInstanceID AS InstanceID
                                        , CAST('00000000-0000-0000-0000-000000000000' AS uniqueidentifier) AS AGGuid
                                        , DatabaseName
                                        , FileType
		                                , SUM(FileSize_mb) AS FileSize_mb
                                FROM DBDetails
                            GROUP BY DatabaseName, FileType"
                }
                else
                {
                    $TSQL = "  WITH DBDetails
                                    AS (SELECT   ISNULL(AG.group_id,CAST('00000000-0000-0000-0000-000000000000' AS uniqueidentifier)) AS AGGuid
                                            , DB_NAME(MF.database_id) AS DatabaseName
                                            , CASE WHEN type = 0 THEN 'Data' ELSE 'Log' END AS FileType
                                            , size/128 AS FileSize_mb
                                        FROM sys.master_files MF
                                    LEFT JOIN sys.databases D
                                            ON MF.database_id = D.Database_id
                                    LEFT JOIN sys.availability_replicas AR
                                            ON D.replica_id = AR.replica_id
                                    LEFT JOIN sys.availability_groups AG
                                            ON AR.group_id = AG.group_id
                                        WHERE MF.database_id NOT IN (1,3,4))
                            SELECT   $SQLInstanceID AS InstanceID
                                    , AGGuid
                                    , DatabaseName
                                    , FileType
		                            , SUM(FileSize_mb) AS FileSize_mb
                                FROM DBDetails
                            GROUP BY AGGuid, DatabaseName, FileType"
                }
                Write-StatusUpdate -Message $TSQL -IsTSQL                    
                $Results = Invoke-SQLCMD -ServerInstance $SQLServerFQDN  `
                                            -Database 'master' `
                                            -Query $TSQL -ErrorAction Stop

                if ($Results)
                {

                    $TSQL = "Truncate Table Staging.DatabaseSizeDetails"
                    Write-StatusUpdate -Message $TSQL -IsTSQL                    
                    Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL -ErrorAction Stop

                    Write-StatusUpdate -Message "Writing database details to staging table" -IsTSQL                    
                    Write-DataTable -ServerInstance $Global:SQLCMDB_SQLServerName -Database $Global:SQLCMDB_DatabaseName -Data $Results -Table "Staging.DatabaseSizeDetails"

                    # Update database catalog
                    $TSQL = "WITH CTE AS
                            ( SELECT DISTINCT SQLInstanceID, DatabaseName
                                FROM Staging.DatabaseSizeDetails)
                            MERGE dbo.Databases AS Target
                            USING (SELECT SQLInstanceID, DatabaseName FROM CTE) AS Source (SQLInstanceID, DatabaseName)
                            ON (Target.SQLInstanceID = Source.SQLInstanceID AND Target.DatabaseName = Source.DatabaseName)
                            WHEN MATCHED THEN
	                            UPDATE SET Target.LastUpdated = GETDATE()
                            WHEN NOT MATCHED THEN
                                INSERT (SQLInstanceID, DatabaseName, IsMonitored, DiscoveryOn, LastUpdated) VALUES (Source.SQLInstanceID, Source.DatabaseName, 1, GetDate(), GetDate());"

                    Write-StatusUpdate -Message $TSQL -IsTSQL                    
                    $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                                -Database $Global:SQLCMDB_DatabaseName `
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
                        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                                    -Database $Global:SQLCMDB_DatabaseName `
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
                        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                                    -Database $Global:SQLCMDB_DatabaseName `
                                                    -Query $TSQL -ErrorAction Stop
                    }

                }
                else
                {
                    Write-StatusUpdate -Message "No user databases found on [$SQLServerFQDN]." -WriteToDB
                    $SQLInstanceAccessible = $false
                }

            }
            catch [System.Data.SqlClient.SqlException]
            {
                Write-StatusUpdate -Message "Cannot reach SQL Server instance [$SQLServerFQDN]." -WriteToDB
                $SQLInstanceAccessible = $false
            }
            catch
            {
                Write-StatusUpdate -Message "Failed to talk to SQL Instance (unhandled exception)." -WriteToDB
                Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
                $SQLInstanceAccessible = $false
            }

            # Update the Database Space Information
            $Results = Update-SQLInstance $ServerVNOName $SQLInstanceName $SQLVersion $SQLServer_Build $SQLEdition $ServerType $EnvironmentType
            if ($Results -eq $Global:Error_FailedToComplete)
            {
                Write-StatusUpdate -Message "Failed to Update-SQLInstance for [$ServerVNOName\$SQLInstanceName]."
            }

            if ($DCS_ErrorLogs)
            {
                # Get SQL Instance Error Logs.  Get the last collect date, then get only errors since last collection.
                # record the errors in SQLOpsDB.  Then update all collection date time.

                $LastDataCollection = Get-SQLOpSQLErrorLogStats -ServerInstance $SQLServerFQDN
                $ErrorLogs = Get-SISQLErrorLogs -ServerInstance $SQLServerFQDN -After $LastDataCollection.LastDateTimeCaptured -Internal
                if ($ErrorLogs)
                {
                    Update-SQLOpSQLErrorLog -ServerInstance $SQLServerFQDN -Data $ErrorLogs | Out-Null
                }
                Update-SQLOpSQLErrorLogStats -ServerInstance $SQLServerFQDN | Out-Null
            }
                
        }
        elseif (!($ServerInstanceIsMonitored))
        {
            Write-StatusUpdate -Message "Instance is not monitored."
        }
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

    Delete-CMDBData -Type Databases
    Delete-CMDBData -Type DiskVolumes
    Delete-CMDBData -Type SQLInstances
    Delete-CMDBData -Type SQLClusters
    Delete-CMDBData -Type Servers

    #Phase 3.5: Clean Up CMDB Log Data
    Write-StatusUpdate -Message "Phase 3.5: Clean Up CMDB Log Data"

    if ($Today -eq $FirstDayOfMonth)
    {
        Truncate-CMDBLog
    }

Write-StatusUpdate "SQLOpsDB - Collection End" -WriteToDB

## Code End