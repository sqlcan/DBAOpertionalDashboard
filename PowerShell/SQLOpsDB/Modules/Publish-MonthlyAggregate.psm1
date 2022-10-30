<#
.SYNOPSIS
Publish-MonthlyAggregate

.DESCRIPTION 
Publish-MonthlyAggregate moves the data from raw data and disk space
to monthly aggregate summary data.

.PARAMETER Type
What do they want to aggregate data for?

.INPUTS
None

.OUTPUTS
Publish-MonthlyAggregate

.EXAMPLE
Publish-MonthlyAggregate -Type DiskVolumes

Aggregate data for last month for all disk volumes.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2016.12.14 0.01    Inital Version
2017.01.10 0.02    Misspelled stored procedure name for aggregating disk volume
                   information
2022.10.29 0.00.04 Updated command let name.
				   Added standard code for working with JSON parameters.
#>
function Publish-MonthlyAggregate
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [ValidateSet(“DiskVolumes”,”Databases”)] [string]$Type
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    $ModuleName = 'Publish-MonthlyAggregate'
    $ModuleVersion = '0.00.04'
    $ModuleLastUpdated = 'October 30, 2022'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        $CurrentDate = Get-Date
        $Month = $CurrentDate.Month
        $Year = $CurrentDate.Year

        if ($Month -eq 1)
        {
            $Month = 12
            $Year--
        }

        #What is T-SQL Doing?
        if ($Type -eq 'Databases')
        {
            $TSQL = "EXEC History.AggregateDatabases @Month=$Month, @Year=$Year"
        }
        elseif ($Type -eq 'DiskVolumes')
        {
        
            $TSQL = "EXEC History.AggregateDiskVolumes @Month=$Month, @Year=$Year"
        }
        Write-StatusUpdate -Message $TSQL

        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
							     -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
						 		 -Query $TSQL
        
        # If no result sets are returned return an error; unless return the appropriate resultset.
        if (!($Results))
        {
            Write-Output $Global:Error_FailedToComplete
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