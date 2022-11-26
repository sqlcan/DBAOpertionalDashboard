<#
.SYNOPSIS
Update-SQLOpSQLClusterNode

.DESCRIPTION 
Update-SQLOpSQLClusterNode allows you to make a node active or inactive. There is
no need to remove a mapping via PowerShell.  Once a node has not been checked for
a while, it will be removed by clean procedures.

.PARAMETER Name
SQL Cluster name for which information is required.  This is is the network name
for FCI.

.PARAMETER NodeName
Node to add to the cluster.

.PARAMETER IsActive
Is the current node being added active node. This is informational only.

.INPUTS
None

.OUTPUTS
Status of success (0) or failure (-1) or duplicate object (-2).

.EXAMPLE
Update-SQLOpSQLClusterNode -Name ContosSQLClus -NodeName ContosoSQL1


.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2015.08.10 1.00.00 Initial Version
2020.03.15 2.00.00 Rewrite to match new standards.
                   Updated parameter name, added additional parameters.
                   Updated to handle FQDN.
                   Updated for JSON parameters.
                   Updated function name.
                   Added alias for parameter ComputerName.
                   Added ability to return full server list.
2022.11.25 2.00.02 Fixed bugs with incorrect command-let names.
#>

function Update-SQLOpSQLClusterNode
{

	[CmdletBinding()] 
	param(
	[Alias('ClusterName')]
	[Parameter(Position=0, Mandatory=$true)] [string]$Name,
	[Alias('ServerName','Computer','Server',"ComputerName")]
	[Parameter(Position=1, Mandatory=$true)] [string] $NodeName,
	[Parameter(Position=2, Mandatory=$true)] [int] $IsActive 
	)

	if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
	{
		Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
		return
	}

	$ModuleName = 'Update-SQLOpSQLClusterNode'
	$ModuleVersion = '2.00.02'
	$ModuleLastUpdated = 'November 25, 2022'

	try
	{
		Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

		$ClusterObj = Get-SQLOpSQLCluster -ClusterName $Name -Internal
		if ($ClusterObj -eq $Global:Error_ObjectsNotFound)
		{
			Write-Output $Global:Error_ObjectsNotFound
			return
		}
		elseif ($ClusterObject -eq $Global:Error_ObjectsNotFound)
		{
			Write-Output $Global:Error_FailedToComplete
			return
		}

		$ServerObj = Get-SQLOpServer -ComputerName $NodeName -Internal
		if ($ServerObj -eq $Global:Error_ObjectsNotFound)
		{
			Write-Output $Global:Error_ObjectsNotFound
			return
		}
		elseif ($ServerObj -eq $Global:Error_FailedToComplete)
		{
			Write-Output $Global:Error_FailedToComplete
			return
		}

		$ClusNodeObj = Get-SQLOpSQLClusterNode -Name $Name -NodeName $NodeName
		if ($ClusNodeObj -eq $Global:Error_FailedToComplete)
		{
			Write-Output $Global:Error_FailedToComplete
			return
		}
		elseif ($ClusNodeObj -eq $Global:Error_ObjectsNotFound)
		{
			Write-Output $Global:Error_ObjectsNotFound
			return
		}

		$TSQL = "UPDATE dbo.SQLClusterNodes CN
				SET LastUpdated = CAST(GETDATE() AS DATE),
				    IsActiveNode = $IsActive 
				WHERE SQLClusterID = $($ClusterObj.SQLClusterID)
				  AND SQLNodeID = $($ServerObj.ServerID)"
		
		Write-StatusUpdate -Message $TSQL -IsTSQL

		Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
					-Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
					-Query $TSQL `
					-ErrorAction Stop

		Write-Output $Global:Error_Successful
	}
	catch [System.Data.SqlClient.SqlException]
	{
		if ($($_.Exception.Message) -like '*Could not open a connection to SQL Server*')
		{
			Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Cannot connect to SQLOpsDB." -WriteToDB
		}
		else
		{
			Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - SQL Exception" -WriteToDB
			Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
		}
		Write-Output $Global:Error_FailedToComplete
	}
	catch
	{
		Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Exception" -WriteToDB
		Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
		Write-Output $Global:Error_FailedToComplete
	}
}