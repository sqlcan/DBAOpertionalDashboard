<#
.SYNOPSIS
Clear-SQLOpData

.DESCRIPTION 
Cleans various datasets in the SQLOps database as per the configuration parameters.
Such as raw disk/database size data, monthly aggregate data, trending data,
sql error logs, sql agent logs, SQLOps logs and archival (expired) data.

All clean up is controlled by settings defined in SQLOp database.

.PARAMETER DataSet
SQLOps_Logs		Clean up dbo.Logs
Expired			Clean user objects that have not been updated in last 90 days (default)
Trending		Clean up Trending.* Tables
Aggregate		Clean up History.* Tables
RawData			Clean Up dbo.DatabaseSize and dbo.DiskVolumeSize
SQL_ErrorLog	Clean Up dbo.SQLErrorLogs
SQL_JobHistory	Clean Up dbo.SQLAgentLogs

.INPUTS
None

.OUTPUTS
Success {0} or Failure {-1}

.EXAMPLE
Clear-SQLOpData -DataSet SQLOps_Logs

Clean up old logs for the SQLOps DB.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2016.12.14 0.01    Initial version
2017.01.24 0.02    Added upper and lower range validation for all cleanup variables.
2017.02.21 0.03    Fixed logic mistake in checking for valid range for Cleanup.
2022.10.30 1.00.00 Full Re-write.  This procedure has become the master clean up 
				   command-let.  No other command needed.  As such multiple old
				   command-lets are removed from solution.
				   - Delete-CMDData
				   - Truncate-CMDData
				   - Truncate-CMDLog

				   In addition, the related database stored procedures have been
				   simplified by Dataset clean up instead of object type.
#>
function Clear-SQLOpData
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)]
	[ValidateSet('SQLOps_Logs',						# Clean up dbo.Logs
				 'Expired',							# Clean user objects that have not been updated in last 90 days (default)
				 'Trending',						# Clean up Trending.* Tables
				 'Aggregate',						# Clean up History.* Tables
				 'RawData',							# Clean Up dbo.DatabaseSize and dbo.DiskVolumeSize
				 'SQL_ErrorLog',					# Clean Up dbo.SQLErrorLogs
				 'SQL_JobHistory')					# Clean Up dbo.SQLJobHistory
	] [string]$DataSet	
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    $ModuleName = 'Clear-SQLOpData'
    $ModuleVersion = '1.00.00'
    $ModuleLastUpdated = 'October 30, 2022'


    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        switch ($DataSet)
        {
			'SQLOps_Logs'
			{
				if ($Global:SQLOpsDB_Log_CleanUp_Enabled)
				{
					$TSQL = "EXEC dbo.CleanData_SQLOpLogs @NumberOfDaysToKeep = $Global:SQLOpsDB_Logs_CleanUp_Retention_Days"
				}
			}
			'Expired'
			{
				if ($Global:Expired_Objects_Enabled)
				{
					$TSQL = "EXEC dbo.CleanData_Expired @NumberOfDaysToKeep = $Global:Expired_Objects_CleanUp_Retention_Days"
				}
			}
			'Trending'
			{
				if ($Global:Trend_Creation_CleanUp_Enabled)
				{
					$TSQL = "EXEC Trending.CleanData_TrendData @NumberOfMonthsToKeep = $Global:Trend_Creation_CleanUp_Retention_Months"
				}
			}
			'Aggregate'
			{
				if ($Global:Aggregate_CleanUp_Enabled)
				{
					$TSQL = "EXEC History.CleanData_Aggregates @NumberOfMonthsToKeep = $Global:Aggregate_CleanUp_Retention_Months"
				}
			}
            'RawData'
            {
				if ($Global:RawData_CleanUp_Enabled)
				{
					$TSQL = "EXEC dbo.CleanData_RawData @NumberOfDaysToKeep = $Global:RawData_CleanUp_Retention_Days"
				}
			}
            'SQL_ErrorLog'
			{
				if ($Global:ErrorLog_CleanUp_Enabled)
				{
					$TSQL = "EXEC dbo.CleanData_SQLErrorLogs @NumberOfDaysToKeep = $Global:ErrorLog_CleanUp_Retention_Days"
				}
			}
			'SQL_JobHistory'
			{
				if ($Global:SQLAgent_Jobs_CleanUp_Enabled)
				{
					$TSQL = "EXEC dbo.CleanData_SQLJobHistory @NumberOfDaysToKeep = $Global:SQLAgent_Jobs_CleanUp_Retention_Days"	
				}
			}
        }

        Write-StatusUpdate -Message $TSQL -IsTSQL
		Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
						-Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
						-Query $TSQL

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