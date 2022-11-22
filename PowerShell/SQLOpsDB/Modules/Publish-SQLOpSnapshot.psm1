<#
.SYNOPSIS
Publish-SQLOpSnapshot

.DESCRIPTION 
Publish-SQLOpSnapshot will create the daily snapshot.  Last command executed after
the collection.

.INPUTS
None

.OUTPUTS
Publish-SQLOpSnapshot

.EXAMPLE
Publish-SQLOpSnapshot

Description

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2022.11.15 0.00.01 Initial Version
#>
function Publish-SQLOpSnapshot
{
    [CmdletBinding()] 
    param()

	if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    $ModuleName = 'Publish-SQLOpSnapshot'
    $ModuleVersion = '0.00.01'
    $ModuleLastUpdated = 'November 15, 2022'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

		$TSQL = "EXEC Snapshot.CreateDashboardSnapshot"
        
		Write-StatusUpdate -Message $TSQL
		Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
				      -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
					  -Query $TSQL
        
		Write-Output $Global:Error_Successful
    }
    catch [System.Data.SqlClient.SqlException]
    {
        if ($($_.Exception.Message) -like '*Could not open a connection to SQL Server*')
        {
            Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Cannot connect to $ServerInstance." -WriteToDB
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