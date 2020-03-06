<#
.SYNOPSIS
Get-SQLOpSQLJobStats

.DESCRIPTION 
Gets the last date/time sql jobs were collected.  If this is a new instance
for which no jobs are collected, then it will call Update-SQLOpSQLJobStats 
to set it to today -7 days.

.PARAMETER ServerInstance
Get the last collection date/time for SQL instance. 

.INPUTS
None

.OUTPUTS
Date/time of the last sql job collection collection.

.EXAMPLE
Get-SQLOpSQLJobStats -ServerInstance ContosoSQL

Get details for this instance.

.EXAMPLE
Get-SQLOpSQLJobStats

Get details for all instances and their last collection date/time.

.NOTES
Date        Version Comments
----------  ------- ------------------------------------------------------------------
2020.03.06  0.00.01 Initial Version.
#>
function Get-SQLOpSQLJobStats
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$false)] [string]$ServerInstance
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Get-SQLOpSQLJobStats'
    $ModuleVersion = '0.01'
    $ModuleLastUpdated = 'March 6, 2020'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        #What is T-SQL Doing?
        $TSQL = "SELECT SI.ComputerName, SI.SQLInstanceName, JS.LastDateTimeCaptured
                FROM dbo.SQLJobs_Stats JS
                JOIN dbo.vSQLInstances SI
                ON JS.SQLInstanceID = SI.SQLInstanceID "

        if (!([String]::IsNullOrEmpty($ServerInstance)))
        {
            # Validate sql instance exists.
            $ServerInstanceObj = Get-SqlOpSQLInstance -ServerInstance $ServerInstance -Internal

            IF ($ServerInstanceObj -eq $Global:Error_ObjectsNotFound)
            {
                Write-StatusUpdate "Failed to find SQL Instance [$ServerInstance] in SQLOpsDB." -WriteToDB
                Write-Output $Global:Error_FailedToComplete
                return
            }

            $TSQL += "WHERE SI.SQLInstanceID = $($ServerInstanceObj.SQLInstanceID)"
        }

        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                                    -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                                    -Query $TSQL
        
        # If no result sets are returned return an error; unless return the appropriate result set.
        if (!($Results))
        {
            # If this is for a SQL instance, then it means there has been no collection for this instance to-date.
            # Create a new default entry in the database and return current date -7 days as date.

            if (!([String]::IsNullOrEmpty($ServerInstance)))
            {
                $Results = Update-SQLOpSQLJobStats -ServerInstance $ServerInstance -DateTime ((get-date).AddDays(-7).toString("yyyy-MM-dd HH:mm:ss"))
                Write-Output $Results
            }
            else {
                Write-Output $Global:Error_ObjectsNotFound
            }
        }
        else
        {
            Write-Output $Results
        }
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expectation" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}