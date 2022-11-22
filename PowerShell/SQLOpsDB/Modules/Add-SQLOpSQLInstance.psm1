<#
.SYNOPSIS
Add-SQLOpSQLInstance

.DESCRIPTION 
Allows a new instance to be added, mapping to a SQL Cluster Name or Server Name.

.PARAMETER ServerInstance
Connection string to SQL Server e.g. (contososql.lab.local\sql1,2100)

.PARAMETER SQLVersion
English full name of version; e.g. "Microsoft SQL Server 2012".

.PARAMETER SQLEdition
English full name of the edition; not required full form. But recommended.
E.g. "Enterprise Edition"

.PARAMETER ServerType
Virtual? or Physical?

.PARAMETER ServerEnviornment
Prod? or Test?

.INPUTS
None

.OUTPUTS
None

.EXAMPLE
Add-SQLOpSQLInstance -ServerInstance contososql.lab.local\sql1,2100
-SQLVersion "Microsoft SQL Server 2008 R2" -SQLServer_Build 4567
-SQLEdition "Enterprise Edition" -ServerType Physical -ServerEnvironment Test

Add a new instance with name Inst01 mapping to ServerA with all the key properties.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
????.??.?? 0.01    Inital Version
2017.02.21 0.02    Added additional checks when adding an instance; if script cannot
                   find server or cluster name, instance addition fails with
                   appropriate recorded in error log.
           0.03    Updated code/documentation to fit new command let template.
2020.03.15 0.00.04 Updated reference to Get-SQLOpSQLCluster.
2021.11.28 1.00.00 Updated command-let name with new standard.
				   Updated connection string information for SQLOp
				   Supports FQDN.
				   Updated error handling.
				   Refactored the code.
#>

function Add-SQLOpSQLInstance
{
    [CmdletBinding()] 
    param( 
	[Parameter(Position=0, Mandatory=$true)] [string]$ServerInstance,
    [Parameter(Position=1, Mandatory=$true)] [string]$SQLVersion,
    [Parameter(Position=2, Mandatory=$true)] [int]$SQLServer_Build,
    [Parameter(Position=3, Mandatory=$true)] [string]$SQLEdition,
    [Parameter(Position=4, Mandatory=$true)] [string]$ServerType,
    [Parameter(Position=5, Mandatory=$true)] [string]$ServerEnviornment
    )

	if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    $ModuleName = 'Add-SQLOpSQLInstance'
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

        if ($SQLClusterID -ne 0)
        { # This is a cluster and the instance defination does not exist.
			$TSQL = "INSERT INTO dbo.SQLInstances (SQLInstanceName, ServerID, SQLClusterID, SQLInstanceVersionID, SQLInstanceBuild, SQLInstanceEdition, SQLInstanceType, SQLInstanceEnviornment) VALUES ('$SQLInstanceName', null, $SQLClusterID, $SQLVersionID, $SQLServer_Build, '$SQLEdition', '$ServerType', '$ServerEnviornment')"
        }
        elseif ($ServerID -ne 0)
        {
			$TSQL = "INSERT INTO dbo.SQLInstances (SQLInstanceName, ServerID, SQLClusterID, SQLInstanceVersionID, SQLInstanceBuild, SQLInstanceEdition, SQLInstanceType, SQLInstanceEnviornment) VALUES ('$SQLInstanceName', $ServerID, null, $SQLVersionID, $SQLServer_Build, '$SQLEdition', '$ServerType', '$ServerEnviornment')"			
        }

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