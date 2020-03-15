<#
.SYNOPSIS
Get-SQLOpSQLCluster

.DESCRIPTION 
Get-SQLOpSQLCluster returns details about sql cluster from SQLOpDB.

.PARAMETER Name
SQL Cluster name for which information is required.  This is is the network name
for FCI.

.INPUTS
None

.OUTPUTS
Status of success (0) or failure (-1) or duplicate object (-2).

.EXAMPLE
Get-SQLOpSQLCluster -ComputerName ContosSQL


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
#>
function Get-SQLOpSQLCluster
{

    [CmdletBinding(DefaultParameterSetName='List')] 
    param(
    [Alias('List','All')]
    [Parameter(ParameterSetName='List', Mandatory=$false)] [switch] $ListAvailable, 
    [Alias('ComputerName','ClusterName')]
    [Parameter(ParameterSetName='Name', Position=0, Mandatory=$true)] [string]$Name,
    [Parameter(ParameterSetName='Name', Position=1, Mandatory=$false, DontShow)] [Switch]$Internal
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Get-SQLOpSQLCluster'
    $ModuleVersion = '2.00.00'
    $ModuleLastUpdated = 'March 15, 2020'

    if (($PSCmdlet.ParameterSetName -eq 'List') -and (!($PSBoundParameters.ListAvailable)))
    {
        $ListAvailable = $true
    }

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"        

        if ($Internal)
        {
            $TSQL = "SELECT SQLClusterID, SQLClusterName, IsMonitored, DiscoveryOn, LastUpdated
                    FROM dbo.SQLClusters "
        }
        else
        {
            $TSQL = "SELECT SQLClusterName, IsMonitored, DiscoveryOn, LastUpdated
                    FROM dbo.SQLClusters "
        }

        if (!($ListAvailable))
        {
            $CompObj = Split-Parts -ComputerName $Name
            $TSQL += "WHERE SQLClusterName = '$($CompObj.ComputerName)'"
        }

        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                                 -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                                 -Query $TSQL `
                                 -ErrorAction Stop

        if ($Results)
        {
            Write-Output $Results
        }
        else
        {
            Write-Output $Global:Error_ObjectsNotFound # No results.
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