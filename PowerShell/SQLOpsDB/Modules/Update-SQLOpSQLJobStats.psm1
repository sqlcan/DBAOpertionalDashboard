<#
.SYNOPSIS
Update-SQLOpSQLJobStats

.DESCRIPTION 
Update the last collection date for SQL Server instance.  This information
is used to make sure we are only selecting job history since last collection.

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
Update-SQLOpSQLJobStats -ServerInstance ContosoSQL

Update the collection date/time to now.

.EXAMPLE
Update-SQLOpSQLJobStats -ServerInstance ContosoSQL -DateTime '2020-01-01 00:00:00'

Set the date time for collect date to Jan 1, 2020 Midnight.  

.NOTES
Date        Version Comments
----------  ------- ------------------------------------------------------------------
2020.03.06  0.00.01 Initial Version.
            0.00.02 Fixed bug, was call Get-SQLOpSQLErrorLogStats vs Get-SQLOpSQLJobStats.
2022.10.28	0.00.03 Moved the job stats column to dbo.SQLInstances.

#>
function Update-SQLOpSQLJobStats
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
    
    $ModuleName = 'Update-SQLOpSQLJobStats'
    $ModuleVersion = '0.03'
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

        $TSQL = "UPDATE dbo.SQLInstances SET JobStats_LastDateTimeCaptured = '$DateTime' WHERE SQLInstanceID = $($ServerInstanceObj.SQLInstanceID)"             
        Write-StatusUpdate -Message $TSQL -IsTSQL
        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                      -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                      -Query $TSQL
        
        $Results = Get-SQLOpSQLJobStats -ServerInstance $ServerInstance                                                                        
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