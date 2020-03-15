<#
.SYNOPSIS
Update-SQLOpSQLCluster

.DESCRIPTION 
Update-SQLOpSQLCluster update details about sql cluster from SQLOpDB.

.PARAMETER Name
SQL Cluster name for which information is required.  This is is the network name
for FCI.

.INPUTS
None

.OUTPUTS
Status of success (0) or failure (-1) or object not found (-3).

.EXAMPLE
Update-SQLOpSQLCluster -ClusterName ContosSQL


.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2015.08.10 1.00.00 Initial Version
2020.03.14 2.00.00 Rewrite to match new standards.
                   Updated parameter name, added additional parameters.
                   Updated to handle FQDN.
                   Updated for JSON parameters.
                   Updated function name.
                   Added alias for parameter ComputerName.
                   Added ability to return full server list.
#>

function Update-SQLOpSQLCluster
{

    [CmdletBinding()] 
    param( 
    [Alias('ComputerName','ClusterName')]
    [Parameter(Position=0, Mandatory=$true)] [string]$Name   
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Update-SQLOpSQLCluster'
    $ModuleVersion = '2.00.00'
    $ModuleLastUpdated = 'March 14, 2020'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        $ClusObj = Get-SQLOpSQLCluster -Name $Name -Internal

        if ($ClusObj -eq $Global:Error_FailedToComplete)
        {
            Write-Output $Global:Error_FailedToComplete
            return
        }
        elseif ($ClusObj -eq $Global:Error_ObjectsNotFound)
        {
            Write-Output $Global:Error_ObjectsNotFound
            return
        }

        $TSQL = "UPDATE dbo.SQLClusters SET LastUpdated = CAST(GETDATE() AS DATE) WHERE SQLClusterID = $($ClusObj.SQLClusterID)"
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