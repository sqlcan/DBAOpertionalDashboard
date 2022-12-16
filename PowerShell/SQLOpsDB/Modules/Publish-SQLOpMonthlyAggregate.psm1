<#
.SYNOPSIS
Publish-SQLOpMonthlyAggregate

.DESCRIPTION 
Publish-SQLOpMonthlyAggregate moves the data from raw data and disk space
to monthly aggregate summary data.

.PARAMETER Type
What do they want to aggregate data for?

.INPUTS
None

.OUTPUTS
Results from execution.

.EXAMPLE
Publish-SQLOpMonthlyAggregate -Type DiskVolumes

Aggregate data for last month for all disk volumes.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2016.12.14 0.01    Inital Version
2017.01.10 0.02    Misspelled stored procedure name for aggregating disk volume
                   information
2022.10.29 0.00.04 Updated command let name.
				   Added standard code for working with JSON parameters.
2022.10.30 0.00.05 Updated command let name with standard "SQLOp".
2022.11.04 0.00.06 Simplified the command let to create both disk and database
                    aggregate at same time.
2022.12.16 0.00.07 Fixing logic bug on date range calculation.
#>
function Publish-SQLOpMonthlyAggregate
{
    [CmdletBinding()] 
    param()

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    $ModuleName = 'Publish-SQLOpMonthlyAggregate'
    $ModuleVersion = '0.00.07'
    $ModuleLastUpdated = 'December 16, 2022'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        $CurrentDate = Get-Date
        $Month = $CurrentDate.Month
        $Year = $CurrentDate.Year

		# This procesure ideally should be called on the first of the month.  It might be called in middle
		# manually.  Each time the Create Aggregate should create aggreagte for previous month only.
		#
		# If current = -1, then previous month = 12.
		#
		# Start date of aggreagte will be 1st of previous month to last day of previous month.
		# Calculated in the stored procedure.

		$Month -= 1

        if ($Month -eq 0)
        {
			$Month = 12
            $Year--
        }

        $TSQL = "EXEC History.CreateAggregate @Month=$Month, @Year=$Year"
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