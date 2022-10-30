#Import Required Modules for Data Collection
Import-Module SQLServer -DisableNameChecking
Import-Module '..\SQLOpsDB\SQLOpsDB.psd1' -DisableNameChecking

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
    $SQLServers = Get-SQLOpCMSServerInstance #-ServerInstance ContosoSQL
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

    #region Step #1: Extended Properties
    $ExtendedProperties = Get-SIExtendedProperties -ServerInstance $SQLServerRC.ServerInstanceConnectionString
    $SQLInstanceAccessible = $true

    if ($ExtendedProperties -eq $Global:Error_FailedToComplete)
    {
        $SQLInstanceAccessible = $false
        continue;
    }
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
	$SQLServer_Build = $SQLProperties['SQLBuild_Build']
	$SQLServer_Major = $SQLProperties['SQLBuild_Major']
    $SQLVersion = $SQLProperties['SQLVersion']
    Write-StatusUpdate -Message "SQL Server Version: [$SQLVersion]."

    $OperatingSystem = Get-SIOperatingSystem -ComputerName $SQLServerRC.ComputerName
    Write-StatusUpdate -Message "   Windows Version: [$OperatingSystem]."
    #endregion

    if (($OperatingSystem -eq 'Windows Server 2000') -or ($SQLVersion -eq 'Microsoft SQL Server 2000'))
    {
        Write-StatusUpdate -Message "Both Windows Server 2000 and SQL Server 2000 are no longer supported." -WriteToDB
        continue;
    }

    # Build a server list to check and the file paths to determine the volumes to check for space.
    # Only volumes we care to monitor are those which have SQL Server related files (i.e. backups, data, and t-logs)    

    if (($IsClustered -eq 1) -or ($ServerType -eq 'Microsoft Clustering') -or ($ServerType -eq 'Veritas Clustering'))
    {   
        Write-StatusUpdate -Message "Building server list for the FCI instance."

        # If this SQL Server is a clustered instance we need to do additional investigative queries.  TO collect information for
        # for data and file locations.  This will help calculate which volumes belong to instance where instance stacking is being used.

        $SQLInstanceFolderList = Get-SISQLVolumeDetails -ServerInstance $SQLServerRC.ServerInstanceConnectionString

        # Unlike Standalone Instances where the Physical Name is calculated, for FCI the node names must be supplied by DBA team.
        # If this information is blank, the servers list will be blank therefore no action will be taken.

		# This limitation is due to support for Vertias Cluster.

        # Grab active node value from extended properties, if the domain information is missing, append the default domain name.
        $ActiveNode = $ExtendedProperties["ActiveNode"].ToLower()
        Write-StatusUpdate -Message "Found Server: $ActiveNode"        

        # Follow code will be added once the other command lets support FQDN.
		#
		# Extended properties for ActiveNode, PassiveNode do not have strict standard for FQDN.
		#
		# SQLOp* command-let must be enabled to support domain name.  Domain specific information is not saved
		# or collected in SQLOps DB.  Therefore domain name information needs to be stripped before saving.
		#
		# However domain information is needed to connect to multiple domain environments.

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
        $IsServerAccessible = $true
        $IsWMIAccessible = $true

        Write-StatusUpdate -Message "Processing Server [$ServerName]."
        $ProcessorObj = Get-SIProcessor -ComputerName $ServerName

        # If WMI called for processor failed; chances are the volume call failed also.  To minimize the error reporting in
        # execution log; only attempt server related updates if initial WMI was successful.
        if ($IsServerAccessible)
        {
            Write-StatusUpdate -Message "Check if server exists."
            # Find the server, if it exists update it; if not add it.
            $Results = Get-SQLOpServer -ComputerName $ServerName

            switch ($Results)
            {
                $Global:Error_ObjectsNotFound
                {

                    Write-StatusUpdate -Message "... New server, adding to database."
                    $InnerResults = Add-SQLOpServer -ComputerName $ServerName -OperatingSystem $OperatingSystem -ProcessorName $ProcessorObj.Name `
                                                    -NumberOfCores $ProcessorObj.NumberOfCores -NumberOfLogicalCores $ProcessorObj.NumberOfLogicalProcessors `
                                                    -IsPhysical $IsPhysical
                    Switch ($InnerResults)
                    {
                        $Global:Error_FailedToComplete
                        {
                            $ServerIsMonitored = $false
                            Write-StatusUpdate -Message "... ... Failed to add server, review logs."
                            continue;
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
                    Write-StatusUpdate -Message "... Failed to get server, review logs."
                    continue;
                }
                default
                {
                    Write-StatusUpdate -Message "... Server found."
                    $ServerIsMonitored = $Results.IsMonitored
                    if ($ServerIsMonitored)
                    {
                        $InnerResults = Update-SQLOpServer -ComputerName $ServerName -OperatingSystem $OperatingSystem -ProcessorName $ProcessorObj.Name `
                                                           -NumberOfCores $ProcessorObj.NumberOfCores -NumberOfLogicalCores $ProcessorObj.NumberOfLogicalProcessors `
                                                           -IsPhysical $IsPhysical

                        if ($InnerResults -eq $Global:Error_FailedToComplete)
                        {
                            $ServerIsMonitored = $false
                            Write-StatusUpdate -Message "Failed to Update Server [$ServerName]."
                            continue;
                        }
                    }
                    break;
                }
            }


            if ((($IsClustered -eq 1) -or ($ServerType -eq 'Microsoft Clustering') -or ($ServerType -eq 'Veritas Clustering')) -and ($ServerIsMonitored))
            {
                Write-StatusUpdate -Message "Current instance is a Clustered Instance."
                # We have to use server name from CMS to build proper mapping between FCI Network name
                # and nodes.
                $Results = Get-SQLOpSQLCluster -Name $SQLServerRC.ComputerName

                Switch ($Results)
                {
                    $Global:Error_ObjectsNotFound
                    {
                        Write-StatusUpdate -Message "New Cluster"
                        $InnerResults = Add-SQLOpSQLCluster -Name $SQLServerRC.ComputerName
                        Switch ($InnerResults)
                        {
                            $Global:Error_FailedToComplete
                            {
                                $ClusterIsMonitored = $false
                                Write-StatusUpdate -Message "Failed to add new FCI network name [$($SQLServerRC.ComputerName)]."
                            }
                            default
                            {
                                Write-StatusUpdate -Message "Existing FCI network name."
                                $ClusterIsMonitored = $true
                            }
                        }
                        break;
                    }
                    $Global:Error_FailedToComplete
                    {
                        $ClusterIsMonitored = $false
                        Write-StatusUpdate -Message "Failed to get cluster details for [$ComputerName_NoDomain]."
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
                    $Results = Get-SQLOpQLClusterNode -Name $SQLServerRC.ComputerName -NodeName $ServerName

                    Switch ($Results)
                    {
                        $Global:Error_ObjectsNotFound
                        {
                            Write-StatusUpdate -Message "New Cluster Node"
                            $InnerResults = Add-SQLOpSQLClusterNode -Name $SQLServerRC.ComputerName -NodeName $ServerName -IsActive $ServerIsActiveNode

                            Switch ($InnerResults)
                            {
                                $Global:Error_ObjectsNotFound
                                {
                                    $ProcessTheNode = $false
                                    Write-StatusUpdate -Message "Failed to add missing the server or cluster object [$($SQLServerRC.ComputerName)\$ServerName]." -WriteToDB
                                }
                                $Global:Error_FailedToComplete
                                {
                                    $ProcessTheNode = $false
                                    Write-StatusUpdate -Message "Failed to add node to cluster [$($SQLServerRC.ComputerName)\$ServerName]."
                                }
                            }
                            break;
                        }
                        $Global:Error_FailedToComplete
                        {
                            $ProcessTheNode = $false
                            Write-StatusUpdate -Message "Failed to get cluster node details for [$($SQLServerRC.ComputerName)\$ServerName]."
                            break;
                        }
                    }

                    if ($ProcessTheNode)
                    {
                        $Results = Update-SQLOpSQLCluster -Name $SQLServerRC.ComputerName

                        if ($Results -eq $Global:Error_FailedToComplete)
                        {
                                Write-StatusUpdate -Message "Failed to update cluster's info for [$($SQLServerRC.ComputerName)]."
                        }

                        $Results = Update-SQLOpSQLClusterNode -Name $SQLServerRC.ComputerName -NodeName $ServerName -IsActive $ServerIsActiveNode

                        if ($Results -eq $Global:Error_FailedToComplete)
                        {
                                Write-StatusUpdate -Message "Failed to update cluster node's info for [$($SQLServerRC.ComputerName)\$ServerName]."
                        }

                        Write-StatusUpdate -Message "Windows 2003+ Updating Disk Volume Information"

                        if ($IsWMIAccessible)
                        {
                            $Results = Update-DiskVolumes -ComputerName $ServerName -ClusterName $SQLServerRC.ComputerName -FolderList $SQLInstanceFolderList

                            if ($Results -eq $Global:Error_FailedToComplete)
                            {
                                Write-StatusUpdate -Message "Failed to update the volume space details for [$($SQLServerRC.ComputerName)]."
                            }
                        }
                    }
                    
                }

            }
            else
            {
                if (($ServerIsMonitored))
                {
                    Write-StatusUpdate -Message "Stand alone instance; Windows 2003+ Updating Disk Volume Information"

                    if ($IsWMIAccessible)
                    {
                        $Results = Update-DiskVolumes -ComputerName $ServerName

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
            $SQLServices = Get-SISQLService -ComputerName $ServerName -Internal

            if ($SQLServices)
            {
                $Results = Update-SQLOpSQLService -ComputerName $ServerName -Data $SQLServices

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

    #region Phase 2: SQL Instances, Availability Groups, and Databases Process
    $Results = Get-SqlOpSQLInstance -ServerInstance $SQLServerRC.ServerInstanceConnectionString -Internal

    switch ($Results)
    {
        $Global:Error_ObjectsNotFound
        {
            Write-StatusUpdate -Message "New Instance."
            $InnerResults = Add-SQLOpSQLInstance -ServerInstance $SQLServerRC.ServerInstanceConnectionString `
			                                     -SQLVersion $SQLVersion -SQLServer_Build $SQLServer_Build `
												 -SQLEdition $SQLEdition -ServerType $ServerType `
												 -EnvironmentType $EnvironmentType

            switch ($InnerResults)
            {
                $Global:Error_Duplicate
                {
                    Write-StatusUpdate -Message "Failed to Add-SQLOpSQLInstance, duplicate object for [$($SQLServerRC.ServerInstance)]." -WriteToDB
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
		
			Update-SQLOpSQLInstance -ServerInstance $SQLServerRC.ServerInstanceConnectionString `
									-SQLVersion $SQLVersion -SQLServer_Build $SQLServer_Build `
									-SQLEdition $SQLEdition -ServerType $ServerType `
									-ServerEnviornment $EnvironmentType

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
		if ($SQLServer_Major -ge 11)
		{
			#Request all the AG and their replica details for current instance.                   
			$Results = Get-SIAvailabilityGroups -ServerInstance $SQLServerRC.ServerInstanceConnectionString -Internal

			# If result set is empty this instance has no AG on it right now.
			If ($Results -ne $Global:Error_ObjectsNotFound)
			{
				Update-SQLOpAvailabilityGroup -ServerInstance $SQLServerRC.ServerInstanceConnectionString -Data $Results | Out-Null
			}
		}


		Write-StatusUpdate -Message "Getting list of databases"

		$Results = Get-SIDatabases -ServerInstance $SQLServerRC.ServerInstanceConnectionString -Internal			

		if ($Results)
		{
			Update-SQLOpDatabase -ServerInstance $SQLServerRC.ServerInstanceConnectionString -Data $Results | Out-Null
		}
		else
		{
			Write-StatusUpdate -Message "No user databases found on [$($SQLServerRC.ServerInstance)]." -WriteToDB
			$SQLInstanceAccessible = $false
		}

        if ($DCS_ErrorLogs)
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

        if ($DCS_SQLJobs)
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
            
    }
    elseif (!($ServerInstanceIsMonitored))
    {
        Write-StatusUpdate -Message "Instance is not monitored."
    }

	#endregion Phase 2

}
#endregion


#Phase 3: Aggregation for Disk Space & Database Space
Write-StatusUpdate -Message "Phase 3: Aggregation for Disk Space & Database Space"

    $CurrentDate = Get-Date
    $FirstDayOfMonth = Get-Date -Year $CurrentDate.Year -Month $CurrentDate.Month -Day 1
    $Today = $CurrentDate.ToString('yyyyMMdd')
    $FirstDayOfMonth = $FirstDayOfMonth.ToString('yyyyMMdd')

    #Phase 3.1: Clean Up Expired Data
    Write-StatusUpdate -Message "Phase 3.1: Clean Up Expired Data"
	Clear-SQLOpData -DataSet Expired | Out-Null

    #Phase 3.2: Aggregate Data for Disk Space and Database Space
    Write-StatusUpdate -Message "Phase 3.2: Aggregate Data for Disk Space and Database Space"
    if ($Today -eq $FirstDayOfMonth)
    {
        Publish-SQLOpMonthlyAggregate -Type DiskVolumes
        Publish-SQLOpMonthlyAggregate -Type Databases
		Clear-SQLOpData -DataSet Aggregate | Out-Null
    }

    #Phase 3.3: Truncate Raw Data for Disk Space and Database Space
    Write-StatusUpdate -Message "Phase 3.3: Truncate Raw Data for Disk Space and Database Space"
	Clear-SQLOpData -DataSet RawData | Out-Null


    #Phase 3.4: Build Trending Data, Truncate Aggregate Data
    Write-StatusUpdate -Message "Phase 3.4: Build Trending Data, Truncate Aggregate Data"
    if ($Today -eq $FirstDayOfMonth)
    {
        <#Create-CMDBMonthlyTrend -Type Servers
        Create-CMDBMonthlyTrend -Type SQLInstances
        Create-CMDBMonthlyTrend -Type Databases#>
        Clear-SQLOpData -DataSet Trending | Out-Null
    }

    #Phase 3.5: Clean Up Expired Data
    Write-StatusUpdate -Message "Phase 3.5: Clean Up SQL Logs"
	Clear-SQLOpData -DataSet SQL_ErrorLog | Out-Null

    #Phase 3.6: Clean Up Expired Data
    Write-StatusUpdate -Message "Phase 3.6: Clean Up SQL Agent Logs"
	Clear-SQLOpData -DataSet SQL_JobHistory | Out-Null

    #Phase 3.7: Clean Up CMDB Log Data
    Write-StatusUpdate -Message "Phase 3.7: Clean Up CMDB Log Data"

    if ($Today -eq $FirstDayOfMonth)
    {
        Clear-SQLOpData -DataSet SQLOps_Logs | Out-Null
    }

	Write-StatusUpdate "SQLOpsDB - Collection End" -WriteToDB

## Code End