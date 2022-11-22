<#
.SYNOPSIS
Update-SQLOpSQLErrorLogStats

.DESCRIPTION 
Update the last collection date for SQL Server instance.  This information
is used to make sure we are only selecting errors since last collection.

.PARAMETER ServerInstance
SQL Server instance for which the date needs to be updated.

.PARAMETER DateTime
Specify a specific date that needs to be updated.  If not supplied, it will 
use current date.

.INPUTS
None

.OUTPUTS
Results for current instance.

.EXAMPLE
Update-SQLOpSQLErrorLogStats -ServerInstance ContosoSQL

Update the collection date/time to now.

.EXAMPLE
Update-SQLOpSQLErrorLogStats -ServerInstance ContosoSQL -DateTime '2020-01-01 00:00:00'

Set the date time for collect date to Jan 1, 2020 Midnight.  

.NOTES
Date        Version Comments
----------  ------- ------------------------------------------------------------------
2020.02.07  0.00.01 Initial Version.
2020.02.13  0.00.03 Updated reference to Get-SQLInstance to use new variable name.
                    Refactored how results are returned.
2020.02.19  0.00.05 Updated reference to Get-SQLOpSQLInstance.
                    Updated module name to Get-SQLOpSQLErrorLogStats.
2020.02.27  0.00.06 Fixed Bug #33.
2022.10.28	0.00.07 Moved the stats column to dbo.SQLInstances.
#>
function Update-SQLOpSQLErrorLogStats
{
    [CmdletBinding()] 
    param( 
    [Parameter(ParameterSetName='ServerInstance',Position=0, Mandatory=$true)]
    [Parameter(ParameterSetName='DateTime',Position=0, Mandatory=$true)] [string]$ServerInstance,
    [Parameter(ParameterSetName='DateTime',Position=1, Mandatory=$true)] [DateTime]$DateTime
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Update-SQLOpSQLErrorLogStats'
    $ModuleVersion = '0.07'
    $ModuleLastUpdated = 'October 28, 2022'
   
    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        # Validate sql instance exists. 
        $ServerInstanceObj = Get-SqlOpSQLInstance -ServerInstance $ServerInstance -Internal
    
        IF ($ServerInstanceObj -eq $Global:Error_ObjectsNotFound)
        {
            Write-StatusUpdate "Failed to find SQL Instance [$ServerInstance] in SQLOpsDB." -WriteToDB
            Write-Output $Global:Error_FailedToComplete
            return
        }

        if ([String]::IsNullOrEmpty($DateTime))
        {
            $DateTime = (Get-Date -format "yyyy-MM-dd HH:mm:ss")
        }

        $TSQL = "UPDATE dbo.SQLInstances SET ErrorLog_LastDateTimeCaptured = '$DateTime' WHERE SQLInstanceID = $($ServerInstanceObj.SQLInstanceID)"             
        Write-StatusUpdate -Message $TSQL -IsTSQL
        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                      -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                      -Query $TSQL
        
        $Results = Get-SQLOpSQLErrorLogStats -ServerInstance $ServerInstance                                                                        
        Write-Output $Results
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