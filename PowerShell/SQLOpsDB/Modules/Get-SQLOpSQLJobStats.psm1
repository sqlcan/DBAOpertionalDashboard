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
2022.10.28	0.00.03 Get data from dbo.SQLInstnaces instead of current table dbo.SQLJobs_Stats.
					Updated behavior on returning full resultset.
#>
function Get-SQLOpSQLJobStats
{
    [CmdletBinding(DefaultParameterSetName = 'List')] 
    param( 
    [Parameter(ParameterSetName='ServerInstance',Position=0, Mandatory=$true)] [string]$ServerInstance,
	[Alias('List','All')]
	[Parameter(ParameterSetName='List',Position=0, Mandatory=$true)] [switch]$ListAvailable
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Get-SQLOpSQLJobStats'
    $ModuleVersion = '0.00.03'
    $ModuleLastUpdated = 'October 28, 2022'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        #What is T-SQL Doing?
        $TSQL = "SELECT vSI.ComputerName, vSI.SQLInstanceName, SI.JobStats_LastDateTimeCaptured AS LastDateTimeCaptured
                FROM dbo.SQLInstances SI
                JOIN dbo.vSQLInstances vSI
                ON SI.SQLInstanceID = vSI.SQLInstanceID "

        if (!($ListAvailable))
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
            Write-Output $Global:Error_ObjectsNotFound
        }
        else
        {
            Write-Output $Results
        }
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