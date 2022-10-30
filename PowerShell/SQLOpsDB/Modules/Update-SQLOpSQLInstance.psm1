<#
.SYNOPSIS
Update-SQLOpSQLInstance

.DESCRIPTION 
Allows you to update properties of an existing instance to be added.

.PARAMETER $ServerInstance
Full qualified connection string e.g. (contososql.lab.local\sqlinst1,2100).

.PARAMETER SQLVersion
English full name of version; e.g. "Microsoft SQL Server 2012".

.PARAMETER SQLEdition
English full name of the edition; not required full form. But recommended.
E.g. "Enterprise Edition"

.PARAMETER ServerType
Virtual? or Physical?

.PARAMETER ServerEnviornment
Prod? or Test?

.PARAMETER EnableMonitoring
Change the IsMonitor flag to true.  Allows to investigate inner elements of instance.

.PARAMETER DisableMonitoring
Change the IsMonitor flag to false.

.INPUTS
None

.OUTPUTS
None

.EXAMPLE
Update-SQLOpSQLInstance -ServerInstance "CotosoSQL1.Lab.Local\SQL1"
-SQLVersion "Microsoft SQL Server 2008 R2" -SQLServer_Build 4567
-SQLEdition "Enterprise Edition" -ServerType Physical -ServerEnvironment Test

Update server ifnormation.

.EXAMPLE
Update-SQLOpSQLInstance -ServerInstance "CotosoSQL1.Lab.Local\SQL1" -DisableMonitoring

Remove monitoring for the instance and all its components.

.EXAMPLE
Update-SQLOpSQLInstance -ServerInstance "CotosoSQL1.Lab.Local\SQL1" -EnableMonitoring

Enable monitoring for the instance and all its components.

.NOTES
Date       	Version Comments
---------- 	------- ------------------------------------------------------------------
2021.11.28	1.00.00	Initial Version.
#>

<# Future Notes

Consider difference between Update- and Set- command lets.  I feel this command-let
should be split into two different commands.  Update- updates the attributes of the
SQL instance.  Where as Set- updates the IsMonitored (a setting).

#>

function Update-SQLOpSQLInstance
{

    [CmdletBinding(DefaultParameterSetName='ServerInstance')] 
    param( 
	[Parameter(ParameterSetName='ServerInstance',Position=0, Mandatory=$true)]
	[Parameter(ParameterSetName='EnableMonitoring',Position=0, Mandatory=$true)]
	[Parameter(ParameterSetName='DisableMonitoring',Position=0, Mandatory=$true)] [string]$ServerInstance,
    [Parameter(ParameterSetName='ServerInstance',Position=1, Mandatory=$true)] [string]$SQLVersion,
    [Parameter(ParameterSetName='ServerInstance',Position=2, Mandatory=$true)] [int]$SQLServer_Build,
    [Parameter(ParameterSetName='ServerInstance',Position=3, Mandatory=$true)] [string]$SQLEdition,
    [Parameter(ParameterSetName='ServerInstance',Position=4, Mandatory=$true)] [string]$ServerType,
    [Parameter(ParameterSetName='ServerInstance',Position=5, Mandatory=$true)] [string]$ServerEnviornment,
	[Parameter(ParameterSetName='EnableMonitoring',Position=1, Mandatory=$true)] [switch]$EnableMonitoring,
	[Parameter(ParameterSetName='DisableMonitoring',Position=1, Mandatory=$true)] [switch]$DisableMonitoring
    )

	if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    $ModuleName = 'Update-SQLOpSQLInstance'
    $ModuleVersion = '1.00.00'
    $ModuleLastUpdated = 'Nov. 28, 2021'

	Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"
	$ServerInstanceParts = Split-Parts -ServerInstance $ServerInstance
	$SQLInstanceName = $ServerInstanceParts.SQLInstanceName
	$ServerID = 0
	$SQLClusterID = 0

	# Check if there is a server with computer name provided.
	$ServerObj = Get-SQLOpServer -ComputerName $ServerInstanceParts.ComputerName -Internal	

	if ($ServerObj -eq $Global:Error_ObjectsNotFound)
	{
		# No Server found with given connection name.  See if this is a cluster.
		$SQLClusterObj = Get-SQLOpSQLCluster -ClusterName $ServerInstanceParts.ComputerName -Internal

		if ($SQLClusterObj -eq $Global:Error_ObjectsNotFound)
		{
			Write-Output $Global:Error_ObjectsNotFound
			return
		}
		elseif ($ServerObj -eq $Global:Error_FailedToComplete)
		{
			Write-Output $Global:Error_FailedToComplete
			return
		}	
		else {
			$SQLClusterID = $SQLClusterObj.SQLClusterID
		}
	}
	elseif ($ServerObj -eq $Global:Error_FailedToComplete)
	{
		Write-Output $Global:Error_FailedToComplete
		return
	}
	else {
		$ServerID = $ServerObj.ServerID
	}


    try
    {    

		if ($PSBoundParameters.ContainsKey('DisableMonitoring'))
		{
			$TSQL = "UPDATE dbo.SQLInstances SET IsMonitored = 0 WHERE InstanceName = '$SQLInstanceName' AND "

			if ($ServerID -eq 0) {$TSQL += " SQLClusterID = $SQLClusterID"}
			else {$TSQL += " ServerID = $ServerID"}

			Write-StatusUpdate -Message $TSQL -IsTSQL

			Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
						-Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
						-Query $TSQL `
						-ErrorAction Stop
		}
		elseif ($PSBoundParameters.ContainsKey('EnableMonitoring'))
		{
			$TSQL = "UPDATE dbo.SQLInstances SET IsMonitored = 1 WHERE InstanceName = '$SQLInstanceName' AND "

			if ($ServerID -eq 0) {$TSQL += " SQLClusterID = $SQLClusterID"}
			else {$TSQL += " ServerID = $ServerID"}
			
			Write-StatusUpdate -Message $TSQL -IsTSQL

			Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
						-Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
						-Query $TSQL `
						-ErrorAction Stop
		}
		else {
			
			$TSQL = "SELECT TOP 1 SQLVersionID
					FROM dbo.SQLVersions
					WHERE SQLVersion LIKE '$SQLVersion%'
						AND SQLBuild <= $SQLServer_Build
				ORDER BY SQLBuild DESC"

			Write-StatusUpdate -Message $TSQL -IsTSQL

			$Results =  Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
									-Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
									-Query $TSQL `
									-ErrorAction Stop

			if ($Results)
			{
				$SQLVersionID = $Results.SQLVersionID
			}
			else
			{
				$SQLVersionID = 1 # Unknown
			}

			$TSQL = "UPDATE dbo.SQLInstances
			            SET SQLInstanceVersionID = $SQLVersionID,
						    SQLInstanceBuild = $SQLServer_Build, 
							SQLInstanceEdition = '$SQLEdition',
							SQLInstanceType = '$ServerType',
							SQLInstanceEnviornment = '$ServerEnviornment',
							LastUpdated = GETDATE()
					  WHERE SQLInstanceName = '$SQLInstanceName'
					    AND "

			if ($ServerID -eq 0) {$TSQL += " SQLClusterID = $SQLClusterID"}
			else {$TSQL += " ServerID = $ServerID"}
			
			Write-StatusUpdate -Message $TSQL -IsTSQL
			Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
						-Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
						-Query $TSQL `
						-ErrorAction Stop

			Write-Output $Global:Error_Successful 
		}
    }
    catch [System.Data.SqlClient.SqlException]
    {
        if ($($_.Exception.Message) -like '*Could not open a connection to SQL Server*')
        {
            Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Cannot connect to SQLOpsDB." -WriteToDB
        }
        else
        {
            Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - SQL Expectation" -WriteToDB
            Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        }
        Write-Output $Global:Error_FailedToComplete
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expectation" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}