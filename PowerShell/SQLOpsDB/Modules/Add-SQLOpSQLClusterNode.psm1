﻿<#
.SYNOPSIS
Add-SQLOpSQLClusterNode

.DESCRIPTION 
Add-SQLOpSQLClusterNode add a new record about sql cluster from SQLOpDB.

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
Add-SQLOpSQLClusterNode -ComputerName ContosSQL


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

function Add-SQLOpSQLClusterNode
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
    
    $ModuleName = 'Add-SQLOpSQLClusterNode'
    $ModuleVersion = '2.00.00'
    $ModuleLastUpdated = 'March 15, 2020'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"
        
        $ClusterObj = Get-SQLOpCluster -ClusterName $Name -Internal
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

        $ClusNodeObj = Get-SQLOpClusterNode -Name $Name -NodeName $NodeName
        if ($ClusNodeObj -eq $Global:Error_FailedToComplete)
        {
            Write-Output $Global:Error_FailedToComplete
            return
        }
        elseif (!($ClusNodeObj -eq $Global:Error_ObjectsNotFound))
        {
            Write-Output $Global:Error_Duplicate
            return
        }

        $TSQL = "INSERT INTO dbo.SQLClusterNodes (SQLClusterID, SQLNodeID, IsActiveNode) VALUES ($($ClusterObj.SQLClusterID), $($ServerObj.ServerID), $IsActiveNode)"

        Write-StatusUpdate -Message $TSQL

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