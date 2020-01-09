<# CMS Group IDs - Last Exported on Dec 13, 2016
 
Execute CMS.GenerateGroupList in DBA_Resource Database to Get Updated List
 
GroupID    GroupName                                                                   IsMonitored
---------- --------------------------------------------------------------------------- -----------
      2023 DatabaseEngineServerGroup\3DPP                                              0
      1018 DatabaseEngineServerGroup\3DPP\Express                                      0
      2022 DatabaseEngineServerGroup\3DPP\Standard                                     0
      2031 DatabaseEngineServerGroup\AGFA                                              0
      2045 DatabaseEngineServerGroup\AGFA\No Access                                    0
      2032 DatabaseEngineServerGroup\AGFA\Prod                                         0
      2034 DatabaseEngineServerGroup\AGFA\Prod\2000                                    0
      2035 DatabaseEngineServerGroup\AGFA\Prod\2005                                    0
      2036 DatabaseEngineServerGroup\AGFA\Prod\2008                                    0
      2033 DatabaseEngineServerGroup\AGFA\UAT                                          0
      2038 DatabaseEngineServerGroup\AGFA\UAT\2000                                     0
      2040 DatabaseEngineServerGroup\AGFA\UAT\2005                                     0
      2041 DatabaseEngineServerGroup\AGFA\UAT\2008                                     0
         6 DatabaseEngineServerGroup\Prod                                              0
         8 DatabaseEngineServerGroup\Prod\2000                                         0
         9 DatabaseEngineServerGroup\Prod\2005                                         0
        10 DatabaseEngineServerGroup\Prod\2008                                         0
        11 DatabaseEngineServerGroup\Prod\2012                                         0
      2056 DatabaseEngineServerGroup\Prod\2014                                         0
      2057 DatabaseEngineServerGroup\Prod\2016                                         0
         7 DatabaseEngineServerGroup\UAT                                               0
      1012 DatabaseEngineServerGroup\UAT\2000                                          0
      1013 DatabaseEngineServerGroup\UAT\2005                                          0
      1014 DatabaseEngineServerGroup\UAT\2008                                          0
      1015 DatabaseEngineServerGroup\UAT\2012                                          0
      2055 DatabaseEngineServerGroup\UAT\2014                                          0
      2058 DatabaseEngineServerGroup\UAT\2016                                          0
      2030 DatabaseEngineServerGroup\Various                                           0
      2054 DatabaseEngineServerGroup\Various\AG Listeners                              0
      2026 DatabaseEngineServerGroup\Various\Aliases                                   0
      2044 DatabaseEngineServerGroup\Various\Automed - Vendor License                  0
      2043 DatabaseEngineServerGroup\Various\Deleted Servers                           0
      2046 DatabaseEngineServerGroup\Various\Express                                   0
      2047 DatabaseEngineServerGroup\Various\Express\2000                              0
      2048 DatabaseEngineServerGroup\Various\Express\2005                              0
      2049 DatabaseEngineServerGroup\Various\Express\2008                              0
      2050 DatabaseEngineServerGroup\Various\Express\2012                              0
      2051 DatabaseEngineServerGroup\Various\IBM                                       0
      2052 DatabaseEngineServerGroup\Various\IBM\2000                                  0
      2053 DatabaseEngineServerGroup\Various\IBM\2005+                                 0
      1019 DatabaseEngineServerGroup\Various\Legacy                                    0
      1010 DatabaseEngineServerGroup\Various\Legacy\Dont Touch 6.5                     0
      1020 DatabaseEngineServerGroup\Various\Legacy\Prod                               0
        12 DatabaseEngineServerGroup\Various\Legacy\Prod\7                             0
      1021 DatabaseEngineServerGroup\Various\Legacy\UAT                                0
      1011 DatabaseEngineServerGroup\Various\Legacy\UAT\7                              0
      2025 DatabaseEngineServerGroup\Various\Missing Servers                           0
      2024 DatabaseEngineServerGroup\Various\New Discovery                             0
      2019 DatabaseEngineServerGroup\Various\Others                                    0
      1016 DatabaseEngineServerGroup\Various\Others\DBA_Team_No_Access_Prod            0
      1017 DatabaseEngineServerGroup\Various\Others\DBA_Team_No_Access_UAT             0
      2027 DatabaseEngineServerGroup\Various\Veritas Cluster Nodes                     0

#>

#Import Required Modules for Data Collection
Import-Module SQLPS -DisableNameChecking
Import-Module 'D:\Scripts\PowerShell\SQLCMDB\SQLCMDB.psd1' -DisableNameChecking


## Code Start

Write-StatusUpdate -Message "SQLCMDB - Collection Start" -WriteToDB

try
{

    Write-StatusUpdate -Message "Getting list of SQL Instances from CMS Server [$Global:CMS_SQLServerName]."

    # Get list of SQL Server Instances from Central Management Server (CMS)
    $SQLServers = Get-CMSServers
    #$SQLServers = Get-CMSServers -ServerName 'wssqlb04\testsql2008c'
}
catch
{
    Write-StatusUpdate -Message "Failed to get list of servers from CMS Server (unhandled exception)." -WriteToDB
    Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
    return
}

# Loop through all the SQL Instnaces collected from Central Management Servers (CMS).
ForEach ($SQLServerRC in $SQLServers)
{

    $OutputLevel++
    $SQLServer = $SQLServerRC.name
    $SQLServerFQDN = $SQLServerRC.server_name
    Write-StatusUpdate -Message "Processing SQL Instance [$SQLServerFQDN] ..." -WriteToDB
        

    # Intialize all the variables for current Instance
    [Array] $ServerList = $null
    $IsClustered = 0
    $IsPhysical = 1
    $InstanceName = 'MSSSQLServer'
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
    $FQDN = 'healthy.bewell.ca'

    # Before we start processing the SQL Instance, we need to parse out the VCO/Server Name and Instance Name.
    # The connection will still happen with SERVER.FQDN\INSTANCE,PORT or VCO.FQDN\INSTANCE,PORT.
    $SQLServer = $SQLServer.ToLower()
    $SQLServerFQDN = $SQLServerFQDN.ToLower()
    $TokenizedSQLInstanceName = $($SQLServer.Split(',')).Split('\')
    $TokenizedSQLInstanceNameFQDN = $($SQLServerFQDN.Split(',')).Split('\')
    $ServerVNOName = $TokenizedSQLInstanceName[0]
    $ServerVNONameFQDN = $TokenizedSQLInstanceNameFQDN[0]

    # Find the FQDN for the VNO/Server as it will be required when talking to instances and servers that are not
    # in the default domain.
    $FQDN = $SQLServerFQDN.Replace($ServerVNOName,'').SubString(1)
    $FQDN = $($FQDN.Split('\')).Split(',')[0]
    $SQLInstanceName = 'mssqlserver'

    switch ($TokenizedSQLInstanceName.Count)
    {
        3
        { # Server\Instance,Port
            $SQLInstanceName = $TokenizedSQLInstanceName[1]
            break;
        }
        2
        { # Server\Instance
            $SQLInstanceName = $TokenizedSQLInstanceName[1]
            break;
        }
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

            # Find if the SQL Server a clustered instance (only appicable to FCI running under WFCS)
            $Results = Invoke-SQLCMD -ServerInstance $SQLServerFQDN  `
                                        -Database 'master' `
                                        -Query $TSQL -ErrorAction Stop

            if ($Results.RwCnt -ne 3)
            {
                Write-StatusUpdate -Message "Missing one or more of the key extended propertie(s) (EnvironmentType,MachineType,ServerType) in [$SQLServerFQDN]." -WriteToDB
                $SQLInstanceAccessible = $false
            }
            else
            {
                Write-StatusUpdate -Message "Getting instance details IsClustered, @@VERSION, Edition, ProductionVersion."
                $TSQL = "SELECT SERVERPROPERTY('IsClustered') AS IsClustered, @@VERSION AS SQLServerVersion, SERVERPROPERTY('Edition') AS SQLEdition, SERVERPROPERTY('ProductVersion') AS SQLBuild"
                Write-StatusUpdate -Message $TSQL -IsTSQL

                $SQLInstanceAccessible = $true -and $SQLInstanceAccessible  # must consider the value for previous resultset; therefore both must be true for us to access the instance.

                # Find if the SQL Server a clustered instance (only appicable to FCI running under WFCS)
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
        Write-StatusUpdate -Message "Failed to talk to SQL Instance (unhandled exception)." -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        $SQLInstanceAccessible = $false
    }

    if ($SQLInstanceAccessible)
    {

        $IsClustered = $Results.IsClustered
        $SQLServerVersion = $Results.SQLServerVersion
        $SQLBuildString = $Results.SQLBuild
        $SQLEdition = $Results.SQLEdition

        #Build the SQL Server Version and Windows Verion Details
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

        Write-StatusUpdate -Message "SQL Server Vesion: [$SQLVersion]."
        Write-StatusUpdate -Message "  Windows Version: [$OperatingSystem]."

        # Collected Extended Properties Details

        # AHS Standard -- Since VERITAS clusterds do not register with SQL Sever DMV, there is no way to identify if the current instance is clustered or not.
        #                 Therefore to identify instnaces as clustered vs stand alone instances; each instance's master database will have extended property
        #                 that gives this information.  These extended properties will be populated at configuration time.  For older servers DBA team
        #                 must retroactively update this value.  If not the a VERITAS Clustered instance will be registered as stand alone instance
        #                 and will show up as duplicate instance running on two nodes.  Generating errors due to non-accessiblity on passive node.


        # SQL Server 2000 does not have extended properties; however to mimic the functionality Extended Properties table has been created in
        # master database on SQL Server 2000 instances with in [dbo] schema vs SQL Server 2005+'s [sys] schema.
        if ($SQLServerVersion -eq 'Microsoft SQL Server 2000')
        {
            $SchemaPrefix = 'dbo'
        }

        Write-StatusUpdate -Message "Getting extended properties:"

        $TSQL = "SELECT value FROM $SchemaPrefix.extended_properties WHERE name = 'ServerType'"
        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $SQLServerFQDN `
                                    -Database 'master' `
                                    -Query $TSQL -ErrorAction Stop

        if ($Results)
        { # Extended properties are configured.
            $ServerType = $Results.value
        }
        else
        { # Extended properties are not configured.
            $ServerType = 'Stand Alone'
        }

        Write-StatusUpdate -Message "Server Type: $ServerType"

        $TSQL = "SELECT value FROM $SchemaPrefix.extended_properties WHERE name = 'EnvironmentType'"
        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $SQLServerFQDN `
                                    -Database 'master' `
                                    -Query $TSQL -ErrorAction Stop

        if ($Results)
        { # Extended properties are configured.
            $EnvironmentType = $Results.value
        }
        else
        { # Extended properties are not configured.
            $EnvironmentType = 'Prod'
        }

        Write-StatusUpdate -Message "Enviornment: $EnvironmentType"

        $TSQL = "SELECT value FROM $SchemaPrefix.extended_properties WHERE name = 'MachineType'"
        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $SQLServerFQDN `
                                    -Database 'master' `
                                    -Query $TSQL -ErrorAction Stop

        if ($Results)
        { # Extended properties are configured.
            if ($Results.value -eq 'Physical')
            {
                $IsPhysical = 1
            }
            else
            {
                $IsPhysical = 0
            }
        }
        else
        { # Extended properties are not configured.
            $IsPhysical = 1
        }

        Write-StatusUpdate -Message "Is Physical: $IsPhysical"

        # Build a server list to check and the file paths to determine the volumes to check for space.
        # Only volumes we care to monitor are those which have SQL Server related files (i.e. backups, data, and t-logs)

        Write-StatusUpdate -Message "Building server list for the instance:"

        if (($IsClustered -eq 1) -or ($ServerType -eq 'Microsoft Clustering') -or ($ServerType -eq 'Veritas Clustering'))
        {

            # If this SQL Server is a clustered instance we need to do additional investigative queries.  TO collect information for
            # for data and file locations.  This will help calculate which volumns belong to instance where instance stacking is being used.

            if ($SQLServerVersion -like '*SQL*Server*2000*')
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

            # Server name is not being assumed from $SQLServer name collected from CMS because heavy use of Aliases with in AHS domain.
            #
            # $PhysicalServerName = Invoke-SQLCMD -ServerInstance $SQLInstance  -Database 'master' -Query "SELECT SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS ComputerNamePhysicalNetBIOS"
            #
            # Removed, now the Server name will be calculated from $SQLSever.  DBA team is working on cleaning up CMS Server list to make sure no Alisas show up under monitored groups.

            $ServerList += ,($ServerVNOName,1)
            Write-StatusUpdate -Message "Found Server: $ServerVNOName"
        }

        # Phase 1: Server, Cluster, and Volume Process
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
                    $Processors = Get-WmiObject -Class Win32_Processor -ComputerName "$ServerName.$FQDN"

                    ForEach ($Processor IN $Processors)
                    {
                        $ProcessorName = $Processor.Name
                        $NumberOfCores += $Processor.NumberOfCores
                        $NumberOfLogicalCores += $Processor.NumberOfLogicalProcessors
                    }
                }
                catch [System.Runtime.InteropServices.COMException]
                {
                    Write-StatusUpdate -Message "WMI Call Failed [Process Information] for [$SQLServerFQDN]; server not found." -WriteToDB
                    $IsServerAccessible = $false
                }
                catch [System.UnauthorizedAccessException]
                {
                    Write-StatusUpdate -Message "WMI Call Failed [Process Information] for [$SQLServerFQDN]; access denied." -WriteToDB
                    $IsWMIAccessible = $false
                }
                catch [System.Management.ManagementException]
                {
                    Write-StatusUpdate -Message "WMI Call Failed [Process Information] for [$SQLServerFQDN]; unknown cause." -WriteToDB
                    $IsWMIAccessible = $false
                }
                catch
                {
                    Write-StatusUpdate -Message "WMI Call Failed [Process Information] for [$SQLServerFQDN] (unhandled expection)." -WriteToDB
                    Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
                    $IsServerAccessible = $false
                }
            }

            # If WMI called for processor failed; chances are the volume call failed also.  To minimize the error reporting in
            # execution log; only attempt server related updates if inital WMI was successful.
            if ($IsServerAccessible)
            {
                # Find the server, if it exists update it; if not add it.
                $Results = Get-Server $ServerName

                switch ($Results)
                {
                    $Global:Error_ObjectsNotFound
                    {
                        Write-StatusUpdate -Message "New server, adding to CMDB."
                        $InnerResults = Add-Server $ServerName $OperatingSystem $ProcessorName $NumberOfCores $NumberOfLogicalCores $IsPhysical
                        Switch ($InnerResults)
                        {
                            $Global:Error_Duplicate
                            {   # This should not happen in code line.  However, it is being handled if a manual entry is made between inital
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

                            # AHS does not have requirement to get disk space for Windows 2000 servers.
                            # - Also WMI calls will need to be updated for Windows 2000 servers.
                            if ($OperatingSystem -ne "Windows Server 2000")
                            {
                                Write-StatusUpdate -Message "Windows 2003+ Updating Disk Volume Information"

                                if ($IsWMIAccessible)
                                {
                                    $Results = Update-DiskVolumes $ServerName $FQDN $ServerVNOName $DBFolderList $BackupFolderList

                                    if ($Results -eq $Global:Error_FailedToComplete)
                                    {
                                        Write-StatusUpdate -Message "Failed to update the volume space details for [$ServerName.$FQDN]."
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
                                Write-StatusUpdate -Message "Failed to update the volume space details for [$ServerName.$FQDN]."
                            }
                        }
                    }
                    elseif (!($ServerIsMonitored))
                    {
                        Write-StatusUpdate -Message "Stand alone instance; server not monitored."
                    }

                }
            }

        }

        # Phase 2: SQL Instnaces, Availability Groups, and Databases Process
        $Results = Get-SQLInstance $ServerVNOName $SQLInstanceName

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
                        $InnerResults = Get-SQLInstance $ServerVNOName $SQLInstanceName
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
            #existing AG configuraiton.  AG is only possible on SQL Server version 2012+.
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

                    # If resultset is empty this instance has no AG on it right now.
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
                Write-StatusUpdate -Message "Failed to talk to SQL Instance (unhandled expection)." -WriteToDB
                Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
                $SQLInstanceAccessible = $false
            }

            # Update the Database Space Information
            $Results = Update-SQLInstance $ServerVNOName $SQLInstanceName $SQLVersion $SQLServer_Build $SQLEdition $ServerType $EnvironmentType
            if ($Results -eq $Global:Error_FailedToComplete)
            {
                Write-StatusUpdate -Message "Failed to Update-SQLInstance for [$ServerVNOName\$SQLInstanceName]."
            }
                
        }
        elseif (!($ServerInstanceIsMonitored))
        {
            Write-StatusUpdate -Message "Instance is not monitored."
        }
    }

}

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

Write-StatusUpdate "SQLCMDB - Collection End" -WriteToDB

## Code End