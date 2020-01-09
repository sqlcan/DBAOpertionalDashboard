# Current Version 1.03

#Import Required Modules for Data Collection
Import-Module SQLPS -DisableNameChecking
Import-Module 'D:\Scripts\PowerShell\SQLCMDB\SQLCMDB.psd1' -DisableNameChecking

<# CMS Group IDs - Last Exported on August 8, 2015

	GroupID Group Name
	1018	[DatabaseEngineServerGroup\3DPP\Express
	2022	[DatabaseEngineServerGroup\3DPP\Standard
	2034	[DatabaseEngineServerGroup\AGFA\Prod\2000
	2035	[DatabaseEngineServerGroup\AGFA\Prod\2005
	2036	[DatabaseEngineServerGroup\AGFA\Prod\2008
	2038	[DatabaseEngineServerGroup\AGFA\UAT\2000
	2040	[DatabaseEngineServerGroup\AGFA\UAT\2005
	2041	[DatabaseEngineServerGroup\AGFA\UAT\2008
	8		[DatabaseEngineServerGroup\Prod\2000
	9		[DatabaseEngineServerGroup\Prod\2005
	10		[DatabaseEngineServerGroup\Prod\2008
	11		[DatabaseEngineServerGroup\Prod\2012
	1012	[DatabaseEngineServerGroup\UAT\2000
	1013	[DatabaseEngineServerGroup\UAT\2005
	1014	[DatabaseEngineServerGroup\UAT\2008
	1015	[DatabaseEngineServerGroup\UAT\2012
	2026	[DatabaseEngineServerGroup\Various\Aliases
	1010	[DatabaseEngineServerGroup\Various\Legacy\Dont Touch 6.5
	12		[DatabaseEngineServerGroup\Various\Legacy\Prod\7
	1011	[DatabaseEngineServerGroup\Various\Legacy\UAT\7
	2025	[DatabaseEngineServerGroup\Various\Missing Servers
	2024	[DatabaseEngineServerGroup\Various\New Discovery
	2019	[DatabaseEngineServerGroup\Various\Others
	1016	[DatabaseEngineServerGroup\Various\Others\DBA_Team_No_Access_Prod
	1017	[DatabaseEngineServerGroup\Various\Others\DBA_Team_No_Access_UAT
	2027	[DatabaseEngineServerGroup\Various\Veritas Cluster Nodes

#>


## Code Start

Write-StatusUpdate -Message "SQLCMDB - Collection Start" -WriteToDB

try
{

    Write-StatusUpdate -Message "Getting list of SQL Instances from CMS Server [$Global:CMS_SQLServerName]." -Level $Global:OutputLevel_One

    # Get list of SQL Server Instances from Central Management Server (CMS)

    $TSQL_ServerList = "
    WITH Groups (GroupID, GroupName)
    AS
    (
	    SELECT server_group_id, '[' + CAST(name AS VARCHAR(1000))
	      FROM msdb.dbo.sysmanagement_shared_server_groups
	     WHERE parent_id IS NULL

	    UNION ALL

	    SELECT server_group_id, CAST(GroupName + '\' + CAST(name AS VARCHAR(100)) AS VARCHAR(1001))
	      FROM msdb.dbo.sysmanagement_shared_server_groups SSG
	      JOIN Groups G
	        ON SSG.parent_id = G.GroupID
    )

      SELECT name, server_name
        FROM Groups G
        JOIN msdb.dbo.sysmanagement_shared_registered_servers SRS
          ON SRS.server_group_id = G.GroupID
       WHERE G.GroupID IN (1012, 1013, 1014, 1015) -- DatabaseEngineServerGroup\UAT\*
          OR G.GroupID IN (8, 9, 10, 11)           -- DatabaseEngineServerGroup\Prod\*
          OR G.GroupID IN (2038, 2040, 2041)       -- DatabaseEngineServerGroup\AGFA\UAT\*
          OR G.GroupID IN (2034, 2035, 2036)       -- DatabaseEngineServerGroup\AGFA\Prod\*
          OR G.GroupID IN (2018, 2022)             -- DatabaseEngineServerGroup\3DPP\*
    ORDER BY name"

    $CMSServerAccessible = $true
    $SQLServers = Invoke-Sqlcmd -ServerInstance $Global:CMS_SQLServerName -Database $Global:CMS_DatabaseName -Query $TSQL_ServerList -ErrorAction Stop
}
catch [System.Management.Automation.RuntimeException]
{
    Write-StatusUpdate -Message "Cannot reach CMS Server [$Global:CMS_SQLServerName]." -Level $Global:OutputLevel_Two -WriteToDB
    $CMSServerAccessible = $false
}
catch
{
    Write-StatusUpdate -Message "Failed to get list of servers from CMS Server (unhandled exception)." -Level $Global:OutputLevel_Two -WriteToDB
    Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $Global:OutputLevel_Two -WriteToDB
    $CMSServerAccessible = $false
}

if ($CMSServerAccessible)
{
    # Loop through all the SQL Instnaces collected from Central Management Servers (CMS).
    ForEach ($SQLServerRC in $SQLServers)
    {

        $SQLServer = $SQLServerRC.name
        $SQLServerFQDN = $SQLServerRC.server_name
        Write-StatusUpdate -Message "Processing SQL Instance [$SQLServerFQDN] ..." -Level $Global:OutputLevel_One -WriteToDB
        

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

            Write-StatusUpdate -Message "Checking if extended properties table exists." -Level $Global:OutputLevel_Two
            $TSQL = "SELECT id AS TblId FROM sysobjects WHERE name = 'extended_properties'"
            Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Three -IsTSQL

            $SQLInstanceAccessible = $true
            

            # Find if the SQL Server a clustered instance (only appicable to FCI running under WFCS)
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
                Write-StatusUpdate -Message "Missing extended properties table in [$SQLServerFQDN]." -Level $Global:OutputLevel_Three -WriteToDB
                $SQLInstanceAccessible = $false
            }

            if ($SQLInstanceAccessible)
            {
                Write-StatusUpdate -Message "Checking if key extended properties exists." -Level $Global:OutputLevel_Two
                $TSQL = "SELECT COUNT(*) AS RwCnt FROM $SchemaPrefix.extended_properties WHERE name in ('EnvironmentType','MachineType','ServerType')"
                Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Three -IsTSQL

                # Find if the SQL Server a clustered instance (only appicable to FCI running under WFCS)
                $Results = Invoke-SQLCMD -ServerInstance $SQLServerFQDN  `
                                            -Database 'master' `
                                            -Query $TSQL -ErrorAction Stop

                if ($Results.RwCnt -ne 3)
                {
                    Write-StatusUpdate -Message "Missing one or more extended propertie(s) in [$SQLServerFQDN]." -Level $Global:OutputLevel_Three -WriteToDB
                    $SQLInstanceAccessible = $false
                }
            }
        }
        catch [System.Data.SqlClient.SqlException]
        {
            Write-StatusUpdate -Message "Cannot reach SQL Server instance [$SQLServerFQDN]." -Level $Global:OutputLevel_Two -WriteToDB
            $SQLInstanceAccessible = $false
        }
        catch
        {
            Write-StatusUpdate -Message "Failed to talk to SQL Instance (unhandled exception)." -Level $Global:OutputLevel_Two -WriteToDB
            Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $Global:OutputLevel_Two -WriteToDB
            $SQLInstanceAccessible = $false
        }

        try
        {

            Write-StatusUpdate -Message "Getting instance details IsClustered, @@VERSION, Edition, ProductionVersion." -Level $Global:OutputLevel_Two
            $TSQL = "SELECT SERVERPROPERTY('IsClustered') AS IsClustered, @@VERSION AS SQLServerVersion, SERVERPROPERTY('Edition') AS SQLEdition, SERVERPROPERTY('ProductVersion') AS SQLBuild"
            Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Three -IsTSQL

            $SQLInstanceAccessible = $true -and $SQLInstanceAccessible  # must consider the value for previous resultset; therefore both must be true for us to access the instance.

            # Find if the SQL Server a clustered instance (only appicable to FCI running under WFCS)
            $Results = Invoke-SQLCMD -ServerInstance $SQLServerFQDN  `
                                        -Database 'master' `
                                        -Query $TSQL -ErrorAction Stop

        }
        catch [System.Data.SqlClient.SqlException]
        {
            Write-StatusUpdate -Message "Cannot reach SQL Server instance [$SQLServerFQDN]." -Level $Global:OutputLevel_Two -WriteToDB
            $SQLInstanceAccessible = $false
        }
        catch
        {
            Write-StatusUpdate -Message "Failed to talk to SQL Instance (unhandled expection)." -Level $Global:OutputLevel_Two -WriteToDB
            Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $Global:OutputLevel_Two -WriteToDB
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

            Write-StatusUpdate -Message "SQL Server Vesion: [$SQLVersion]." -Level $Global:OutputLevel_Three
            Write-StatusUpdate -Message "  Windows Version: [$OperatingSystem]." -Level $Global:OutputLevel_Three

            # Collected Extended Properties Details

            # AHS Standard -- Since VERITAS clusterds do not register with SQL Sever DMV, there is no way to identify if the current instance is clustered or not.
            #                 Therefore to identify instnaces as clustered vs stand alone instances; each instance's master database will have extended property
            #                 that gives this information.  These extended properties will be populated at configuration time.  For older servers DBA team
            #                 must retroactively update this value.  If not the a VERITAS Clustered instance will be registered as stand alone instance
            #                 and will show up as duplicate instance running on two nodes.  Generating errors due to non-accessiblity on passive node.


            # SQL Server 2000 does not have extended properties; however to mimic the functionality Extended Properties table has been created in
            # master database on SQL Server 2000 instances with in [dbo] schema vs SQL Server 2005+'s [sys] schema.
            if ($SQLServerVersion -like '*SQL*Server*2000*')
            {
                $SchemaPrefix = 'dbo'
            }

            Write-StatusUpdate -Message "Getting extended properties:" -Level $Global:OutputLevel_Two

            $TSQL = "SELECT value FROM $SchemaPrefix.extended_properties WHERE name = 'ServerType'"
            Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Three -IsTSQL

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

            Write-StatusUpdate -Message "Server Type: $ServerType" -Level $Global:OutputLevel_Three

            $TSQL = "SELECT value FROM $SchemaPrefix.extended_properties WHERE name = 'EnvironmentType'"
            Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Three -IsTSQL

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

            Write-StatusUpdate -Message "Enviornment: $EnvironmentType" -Level $Global:OutputLevel_Three

            $TSQL = "SELECT value FROM $SchemaPrefix.extended_properties WHERE name = 'MachineType'"
            Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Three -IsTSQL

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

            Write-StatusUpdate -Message "Is Physical: $IsPhysical" -Level $Global:OutputLevel_Three

            # Build a server list to check and the file paths to determine the volumes to check for space.
            # Only volumes we care to monitor are those which have SQL Server related files (i.e. backups, data, and t-logs)

            Write-StatusUpdate -Message "Building server list for the instance:" -Level $Global:OutputLevel_Two

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
                    Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Three -IsTSQL

                    $DBFolderList = Invoke-SQLCMD -ServerInstance $SQLServerFQDN `
                                                    -Database 'master' `
                                                    -Query $TSQL -ErrorAction Stop

                    $TSQL = "SELECT DISTINCT LOWER(SUBSTRING(physical_device_name,1,LEN(physical_device_name)-CHARINDEX('\',REVERSE(physical_device_name)))) AS FolderName FROM msdb.dbo.backupmediafamily"
                    Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Three -IsTSQL

                    $BackupFolderList = Invoke-SQLCMD -ServerInstance $SQLServerFQDN  `
                                                        -Database 'master' `
                                                        -Query $TSQL -ErrorAction Stop
                }

                # Unlike Standalone Instances where the Physical Name is calculated, for FCI the node names must be supplied by DBA team.
                # If this information is blank, the servers list will be blank therefore no action against the $SQLServer will be taken.

                $TSQL = "SELECT value FROM $SchemaPrefix.extended_properties WHERE name = 'ActiveNode'"
                Write-StatusUpdate -Message $TSQL -Level $Global:Out000putLevel_Three -IsTSQL

                $Results = Invoke-SQLCMD -ServerInstance $SQLServerFQDN  -Database 'master' -Query $TSQL -ErrorAction Stop

                if ($Results)
                {
                    $ActiveNode = $($Results.value).ToLower()
                    $ServerList += ,($ActiveNode,1)
                    Write-StatusUpdate -Message "Found Server: $ActiveNode" -Level $Global:OutputLevel_Three

                    $TSQL = "SELECT value FROM $SchemaPrefix.extended_properties WHERE name LIKE 'PassiveNode%'"
                    Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Three -IsTSQL

                    $PassiveNodes = Invoke-SQLCMD -ServerInstance $SQLServerFQDN  -Database 'master' -Query $TSQL -ErrorAction Stop

                    if ($Results)
                    {
                        ForEach ($PassiveNode in $PassiveNodes)
                        {
                            $ServerList += ,($($PassiveNode.value).ToLower(),0)
                            Write-StatusUpdate -Message "Found Server: $($PassiveNode.value.ToLower())" -Level $Global:OutputLevel_Three
                        }
                    }
                    else
                    {
                        Write-StatusUpdate -Message "Extended properties PassiveNode* missing for [$SQLServerFQDN]." -Level $Global:OutputLevel_Three -WriteToDB
                    }
                }
                else
                {
                    Write-StatusUpdate -Message "Extended properties ActiveNode missing for [$SQLServerFQDN]." -Level $Global:OutputLevel_Three -WriteToDB
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
                Write-StatusUpdate -Message "Found Server: $ServerVNOName" -Level $Global:OutputLevel_Three
            }

            # Process storage information for each Server identfied for current instance.
            ForEach ($Server in $ServerList)
            {
                $ServerName = $Server[0]
                $ServerIsActiveNode = $Server[1]
                $ClusterIsMonitored = $true
                $ServerIsMonitored = $true
                $NumberOfLogicalCores = 0
                $NumberOfCores = 0
                $ProcessorName = 'Unknown'

                Write-StatusUpdate -Message "Processing Server [$ServerName]." -Level $Global:OutputLevel_Two

                # Find the server, if it exists update it; if not add it.
                $Results = Get-Server $ServerName

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
                        Write-StatusUpdate -Message "Could not complete WMI Call to server for Processor information [$SQLServerFQDN]; server not found." -Level $Global:OutputLevel_Four -WriteToDB
                        $IsServerAccessible = $false
                    }
                    catch [System.UnauthorizedAccessException]
                    {
                        Write-StatusUpdate -Message "Could not complete WMI Call to server for Processor information [$SQLServerFQDN]; access denied." -Level $Global:OutputLevel_Four -WriteToDB
                        $IsServerAccessible = $false
                    }
                    catch [System.Management.ManagementException]
                    {
                        Write-StatusUpdate -Message "Could not complete WMI Call to server for Processor information [$SQLServerFQDN]; WMI call failed." -Level $Global:OutputLevel_Four -WriteToDB
                        $IsServerAccessible = $false
                    }
                    catch
                    {
                        Write-StatusUpdate -Message "Could not complete WMI Call to server for Processor information [$SQLServerFQDN] (unhandled expection)." -Level $Global:OutputLevel_Four -WriteToDB
                        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $Global:OutputLevel_Five -WriteToDB
                        $IsServerAccessible = $false
                    }
                }

                switch ($Results)
                {
                    $Global:Error_ObjectsNotFound
                    {
                        Write-StatusUpdate -Message "New server, adding to CMDB." -Level $Global:OutputLevel_Three
                        $InnerResults = Add-Server $ServerName $OperatingSystem $ProcessorName $NumberOfCores $NumberOfLogicalCores $IsPhysical
                        Switch ($InnerResults)
                        {
                            $Global:Error_Duplicate
                            {
                                $ClusterIsMonitored = $false
                                Write-StatusUpdate -Message "Failed to Add-Server, duplicate value found [$ServerName]." -Level $Global:OutputLevel_Three -WriteToDB
                            }
                            $Global:Error_FailedToComplete
                            {
                                $ClusterIsMonitored = $false
                                Write-StatusUpdate -Message "Failed to Add-Server [$ServerName]." -Level $Global:OutputLevel_Three
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
                        Write-StatusUpdate -Message "Failed to Get-Server [$ServerName]." -Level $Global:OutputLevel_Three
                        break;
                    }
                    default
                    {
                        Write-StatusUpdate -Message "Existing server." -Level $Global:OutputLevel_Three
                        $ServerIsMonitored = $Results.IsMonitored
                        if ($ServerIsMonitored)
                        {
                            $InnerResults = Update-Server $ServerName $OperatingSystem $ProcessorName $NumberOfCores $NumberOfLogicalCores $IsPhysical

                            if ($InnerResults -eq $Global:Error_FailedToComplete)
                            {
                                $ServerIsMonitored = $false
                                Write-StatusUpdate -Message "Failed to Update-Server [$ServerName]." -Level $Global:OutputLevel_Three
                            }
                        }
                        break;
                    }
                }


                if ((($IsClustered -eq 1) -or ($ServerType -eq 'Microsoft Clustering') -or ($ServerType -eq 'Veritas Clustering')) -and ($ServerIsMonitored))
                {
                    Write-StatusUpdate -Message "Current instance is a Clustered Instance." -Level $Global:OutputLevel_Two
                    $Results = Get-SQLCluster $ServerVNOName

                    Switch ($Results)
                    {
                        $Global:Error_ObjectsNotFound
                        {
                            Write-StatusUpdate -Message "New Cluster" -Level $Global:OutputLevel_Three
                            $InnerResults = Add-SQLCluster $ServerVNOName
                            Switch ($InnerResults)
                            {
                                $Global:Error_Duplicate
                                {
                                    $ClusterIsMonitored = $false
                                    Write-StatusUpdate -Message "Failed to Add-SQLCluster, duplicate value found [$ServerVNOName]." -Level $Global:OutputLevel_Three -WriteToDB
                                }
                                $Global:Error_FailedToComplete
                                {
                                    $ClusterIsMonitored = $false
                                    Write-StatusUpdate -Message "Failed to Add-SQLCluster [$ServerVNOName]." -Level $Global:OutputLevel_Three
                                }
                                default
                                {
                                    Write-StatusUpdate -Message "Existing Cluster" -Level $Global:OutputLevel_Three
                                    $ClusterIsMonitored = $true
                                }
                            }
                            break;
                        }
                        $Global:Error_FailedToComplete
                        {
                            $ClusterIsMonitored = $false
                            Write-StatusUpdate -Message "Failed to Get-SQLCluster [$ServerVNOName]." -Level $Global:OutputLevel_Three
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
                        Write-StatusUpdate -Message "Cluster is monitored; updating node information." -Level $Global:OutputLevel_Three
                        $ProcessTheNode = $true
                        $Results = Get-SQLClusterNode $ServerVNOName $ServerName

                        Switch ($Results)
                        {
                            $Global:Error_ObjectsNotFound
                            {
                                Write-StatusUpdate -Message "New Cluster Node" -Level $Global:OutputLevel_Four
                                $InnerResults = Add-SQLClusterNode $ServerVNOName $ServerName $ServerIsActiveNode

                                Switch ($InnerResults)
                                {
                                    $Global:Error_Duplicate
                                    {
                                        $ProcessTheNode = $false
                                        Write-StatusUpdate -Message "Failed to Add-SQLClusterNode, duplicate object. [$ServerVNOName\$ServerName]." -Level $Global:OutputLevel_Three -WriteToDB
                                    }
                                    $Global:Error_ObjectsNotFound
                                    {
                                        $ProcessTheNode = $false
                                        Write-StatusUpdate -Message "Failed to Add-SQLClusterNode, missing the server or cluster object [$ServerVNOName\$ServerName]." -Level $Global:OutputLevel_Three -WriteToDB
                                    }
                                    $Global:Error_FailedToComplete
                                    {
                                        $ProcessTheNode = $false
                                        Write-StatusUpdate -Message "Failed to Add-SQLClusterNode [$ServerVNOName\$ServerName]." -Level $Global:OutputLevel_Three
                                    }
                                }
                                break;
                            }
                            $Global:Error_FailedToComplete
                            {
                                $ProcessTheNode = $false
                                Write-StatusUpdate -Message "Failed to Get-SQLClusterNode [$ServerVNOName\$ServerName]." -Level $Global:OutputLevel_Three
                                break;
                            }
                        }

                        if ($ProcessTheNode)
                        {
                            $Results = Update-SQLCluster $ServerVNOName

                            if ($Results -eq $Global:Error_FailedToComplete)
                            {
                                 Write-StatusUpdate -Message "Failed to update SQL CMDB Cluster's info for [$ServerVNOName]." -Level $Global:OutputLevel_Three
                            }

                            $Results = Update-SQLClusterNode $ServerVNOName $ServerName

                            if ($Results -eq $Global:Error_FailedToComplete)
                            {
                                 Write-StatusUpdate -Message "Failed to update SQL CMDB Cluster Node's info for [$ServerVNOName\$ServerName]." -Level $Global:OutputLevel_Three
                            }

                            # AHS does not have requirement to get disk space for Windows 2000 servers.
                            # - Also WMI calls will need to be updated for Windows 2000 servers.
                            if ($OperatingSystem -ne "Windows Server 2000")
                            {
                                Write-StatusUpdate -Message "Windows 2003+ Updating Disk Volume Information" -Level $Global:OutputLevel_Three
                                $Results = Update-DiskVolumes $ServerName $FQDN $ServerVNOName $DBFolderList $BackupFolderList

                                if ($Results -eq $Global:Error_FailedToComplete)
                                {
                                    Write-StatusUpdate -Message "Failed to update the volume space details for [$ServerName.$FQDN]." -Level $Global:OutputLevel_Four
                                }
                            }
                        }
                        
                        
                    }

                }
                else
                {
                    if (($ServerIsMonitored) -and ($OperatingSystem -ne "Windows Server 2000"))
                    {
                        Write-StatusUpdate -Message "Stand alone instance; Windows 2003+ Updating Disk Volume Information" -Level $Global:OutputLevel_Three

                        $Results = Update-DiskVolumes $ServerName $FQDN

                        if ($Results -eq $Global:Error_FailedToComplete)
                        {
                            Write-StatusUpdate -Message "Failed to update the volume space details for [$ServerName.$FQDN]." -Level $Global:OutputLevel_Four
                        }
                    }
                    elseif (!($ServerIsMonitored))
                    {
                        Write-StatusUpdate -Message "Stand alone instance; server not monitored." -Level $Global:OutputLevel_Three
                    }

                }

            }

            # The current instances nodes and/or server has been processed.
            # Must process events related to instance now.

            $Results = Get-SQLInstance $ServerVNOName $SQLInstanceName

            switch ($Results)
            {
                $Global:Error_ObjectsNotFound
                {
                    Write-StatusUpdate -Message "New Instance." -Level $Global:OutputLevel_Three
                    $InnerResults = Add-SQLInstance $ServerVNOName $SQLInstanceName $SQLVersion $SQLServer_Build $SQLEdition $ServerType $EnvironmentType

                    switch ($InnerResults)
                    {
                        $Global:Error_Duplicate
                        {
                            Write-StatusUpdate -Message "Failed to Add-SQLInstance, duplicate object for [$ServerVNOName\$SQLInstanceName]." -Level $Global:OutputLevel_Four -WriteToDB
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
                    Write-StatusUpdate -Message "Existing Instance." -Level $Global:OutputLevel_Three
                    $ServerInstanceIsMonitored = $Results.IsMonitored
                    $SQLInstanceID = $Results.SQLInstanceID
                    break;
                }
            }

            # Currently IsInstanceAccessible means that it exists with in CMDB.
            if (($ServerInstanceIsMonitored) -and ($SQLInstanceAccessible))
            {
                Write-StatusUpdate -Message "Instance is monitored." -Level $Global:OutputLevel_Four                
                try
                {
                    <#-- Incomplete 
                    Write-StatusUpdate -Message "Getting list of databases" -Level $Global:OutputLevel_Five
                    $TSQL = "   WITH DBDetails
                                  AS (SELECT   DB_NAME(database_id) AS DatabaseName
	                                         , CASE WHEN type = 0 THEN 'Data' ELSE 'Log' END AS FileType
				                             , (size * 8)/1024 AS FileSize_mb
                                        FROM sys.master_files
                                       WHERE database_id >= 5)
                              SELECT   $SQLInstanceID AS InstanceID
                                     , DatabaseName
                                     , FileType
		                             , SUM(FileSize_mb) AS FileSize_mb
                                FROM DBDetails
                            GROUP BY DatabaseName, FileType"
                    Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Six -IsTSQL                    
                    $Results = Invoke-SQLCMD -ServerInstance $SQLServerFQDN  `
                                                -Database 'master' `
                                                -Query $TSQL -ErrorAction Stop

                    #ForEach ($DatabaseDetail IN $Results)
                    #{
                    #}#>

                }
                catch [System.Data.SqlClient.SqlException]
                {
                    Write-StatusUpdate -Message "Cannot reach SQL Server instance [$SQLServerFQDN]." -Level $Global:OutputLevel_Two -WriteToDB
                    $SQLInstanceAccessible = $false
                }
                catch
                {
                    Write-StatusUpdate -Message "Failed to talk to SQL Instance (unhandled expection)." -Level $Global:OutputLevel_Two -WriteToDB
                    Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $Global:OutputLevel_Two -WriteToDB
                    $SQLInstanceAccessible = $false
                }

                # Update the Database Space Information
                $Results = Update-SQLInstance $ServerVNOName $SQLInstanceName $SQLVersion $SQLServer_Build $SQLEdition $ServerType $EnvironmentType
                if ($Results -eq $Global:Error_FailedToComplete)
                {
                    Write-StatusUpdate -Message "Failed to Update-SQLInstance for [$ServerVNOName\$SQLInstanceName]." -Level $Global:OutputLevel_Four
                }
                
            }
            elseif (!($ServerInstanceIsMonitored))
            {
                Write-StatusUpdate -Message "Instance is not monitored." -Level $Global:OutputLevel_Four
            }
        }

     }

    # After all servers have been processed we need to do some house keeping.
    #
    # 1) If its 1st of the month, summarize the results from last month and
    #    save it history table clearning up the main table.
    # 2) If any server has not been accessed in last 30, 60, or 90 days create
    #    proper alerts.
    # 3) If any database has not been accessed in last 30, 60, or 90 days create
    #    proper alerts.
    # 4) If server or db reach 90 days, clearn up related data.

    Write-StatusUpdate -Message "Running Archive Process" -Level $Global:OutputLevel_One

    # History Cleanup has 3 Phases
    #
    # -- Phase 1 --
    #
    # Clean up all records in the dbo.DiskVolumeSpace table that are older then 32 days.
    # By allowing for data to precist past 31 days we get rich history reference
    # for projecting database and volume growth trends.
    #
    # -- Phase 2 --
    #
    # Only triggered 1st of every month.  Archive data from dbo.DiskVolumeSpace to
    # HIstory.DiskVolumeSpace; store aggregated results for last month.
    #
    # -- Phase 3 --
    #
    # Cleanup the History.DiskVolumeSpace to remove any data that is more then 1 year
    # old.

    try
    {
        $TSQL_Phase1_CleanupOldData = 'DELETE FROM dbo.DiskVolumeSpace
                                             WHERE DateCaptured <= CAST(DATEADD(Day,-32,GETDATE()) AS DATE)'

        $TSQL_Phase2_ArchiveData = "INSERT INTO History.DiskVolumeSpace (DiskVolumeID, YearMonth, SpaceUsed_mb, TotalSpace_mb)
                                         SELECT DiskVolumeID, CONVERT(varchar(6),DateCaptured,112), AVG(SpaceUsed_mb), AVG(TotalSpace_mb)
                                           FROM dbo.DiskVolumeSpace
                                          WHERE DateCaptured >= CAST(DATEADD(mm,DATEDIFF(mm,0,DATEADD(mm,-1,GETDATE())),0) AS DATE)
                                            AND DateCaptured <= CAST(DATEADD(dd,-1,DATEADD(mm,DATEDIFF(mm,0,GETDATE()),-1)) AS DATE)
                                       GROUP BY DiskVolumeID, CONVERT(varchar(6),DateCaptured,112)"

        $TSQL_Phase3_CleanUpArchive = "DELETE FROM History.DiskVolumeSpace
                                        WHERE YearMonth < CONVERT(VARCHAR(6),DATEADD(MONTH,-13,GETDATE()),112)"

        Write-StatusUpdate -Message "Phase 1: Cleanup Data" -Level $Global:OutputLevel_Two
        Write-StatusUpdate -Message $TSQL_Phase1_CleanupOldData -Level $Global:OutputLevel_Three -IsTSQL

        Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                      -Database $Global:SQLCMDB_DatabaseName `
                      -Query $TSQL_Phase1_CleanupOldData -ErrorAction Stop

        Write-StatusUpdate "Phase 2: Archive Data" $OUTPUT_LEVEL_TWO
        $CurrentDate = Get-Date
        $FirstDayOfMonth = Get-Date -Year $CurrentDate.Year -Month $CurrentDate.Month -Day 1
        $CurrentDate = $CurrentDate.ToString('yyyyMMdd')
        $FirstDayOfMonth = $FirstDayOfMonth.ToString('yyyyMMdd')

        if ($CUrrentDate -eq $FirstDayOfMonth)
        {
            Write-StatusUpdate -Message "Executing; first of the month"  -Level $Global:OutputLevel_Two
            Write-StatusUpdate -Message $TSQL_Phase2_ArchiveData -Level $Global:OutputLevel_Three -IsTSQL

            Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                          -Database $Global:SQLCMDB_DatabaseName `
                          -Query $TSQL_Phase2_ArchiveData -ErrorAction Stop
        }
        else
        {
            Write-StatusUpdate -Message "Skipped; not first of the month." -Level $Global:OutputLevel_Two
        }

        Write-StatusUpdate -Message "Phase 3: Cleanup Archive Data" -Level $Global:OutputLevel_Two
        Write-StatusUpdate -Message $TSQL_Phase3_CleanUpArchive -Level $Global:OutputLevel_Three -IsTSQL

        Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                      -Database $Global:SQLCMDB_DatabaseName `
                      -Query $TSQL_Phase3_CleanUpArchive -ErrorAction Stop
    }
    catch
    {
        Write-StatusUpdate -Message "Archival phase failed. (Unhandled expection)" -Level $Global:OutputLevel_Two -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $Global:OutputLevel_Seven -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}

Write-StatusUpdate "SQLCMDB - Collection End" -WriteToDB

## Code End