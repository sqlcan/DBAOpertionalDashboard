<#
.SYNOPSIS
Get-SQLOpSQLCluster

.DESCRIPTION 
Get-SQLOpSQLCluster returns details about sql cluster from SQLOpDB.

.PARAMETER Name
SQL Cluster name for which information is required.  This is is the network name
for FCI.

.PARAMETER NodeName
Node name that is part of the FCI cluster.

.PARAMETER ListAvailable
Provide full SQLOpDB output.

.PARAMETER Internal
Return internal ID value if needed.

.INPUTS
None

.OUTPUTS
Full list or failure (-1) or no objects found (-3).

.EXAMPLE
Get-SQLOpSQLClusterNode -Name ContosSQLClus -NodeName -ContosoSQL

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
function Get-SQLOpSQLClusterNode
{

    [CmdletBinding(DefaultParameterSetName='List')] 
    param(
    [Alias('List','All')]
    [Parameter(ParameterSetName='List', Mandatory=$false)] [switch] $ListAvailable, 
    [Alias('ClusterName')]
    [Parameter(ParameterSetName='NodeName', Position=0, Mandatory=$true)]
    [Parameter(ParameterSetName='Name', Position=0, Mandatory=$true)] [string]$Name,
    [Alias('ServerName','Computer','Server',"ComputerName")]
    [Parameter(ParameterSetName='NodeName', Position=1, Mandatory=$true)] [string] $NodeName,
    [Parameter(ParameterSetName='NodeName', Position=2, Mandatory=$false, DontShow)] [Switch]$Internal
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Get-SQLOpSQLClusterNode'
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
            $TSQL = "SELECT CN.SQLClusterNodeID, SC.SQLClusterName, S.ServerName AS SQLClusterNodeName, CN.IsActiveNode, CN.DiscoveryOn, CN.LastUpdated
                   FROM dbo.SQLClusters SC
                   JOIN dbo.SQLClusterNodes CN
                     ON SC.SQLClusterID = CN.SQLClusterID
                   JOIN dbo.Servers S
                     ON S.ServerID = CN.SQLNodeID "
        }
        else {
            $TSQL = "SELECT SC.SQLClusterName, S.ServerName AS SQLClusterNodeName, CN.IsActiveNode, CN.DiscoveryOn, CN.LastUpdated
                   FROM dbo.SQLClusters SC
                   JOIN dbo.SQLClusterNodes CN
                     ON SC.SQLClusterID = CN.SQLClusterID
                   JOIN dbo.Servers S
                     ON S.ServerID = CN.SQLNodeID "
        }

        if (!($ListAvailable))
        {
            $ClusObj = Split-Parts -ComputerName $Name
            $TSQL += "WHERE SC.SQLClusterName = '$($ClusObj.ComputerName)' "

            if (!([String]::IsNullOrEmpty($NodeName)))
            {
                $ClusNodeObj = Split-Parts -ComputerName $NodeName
                $TSQL += "AND S.ServerName = '$($ClusNodeObj.ComputerName)'"
            }
        }

        Write-StatusUpdate -Message $TSQL -IsTSQL

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