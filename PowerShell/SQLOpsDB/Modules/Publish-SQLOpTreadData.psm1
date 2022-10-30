<#
.SYNOPSIS
Publish-SQLOpTreadData

.DESCRIPTION 
Publish-SQLOpTreadData will create monthly thread for last month.

.PARAMETER Type
For what object do you want to create trends for?

.INPUTS
None

.OUTPUTS
Publish-SQLOpTreadData

.EXAMPLE
Publish-SQLOpTreadData -Type SQLInstances

Description

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2016.12.14 0.01    Initial Version
2017.03.06 0.02    Missing the quotations in the date parameter.
2022.10.30 1.00.00 Re-write to new standards.  Simplified.

#>
function Publish-SQLOpTreadData
{
    [CmdletBinding()] 
    param()

	if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    $ModuleName = 'Publish-SQLOpTreadData'
    $ModuleVersion = '1.00.00'
    $ModuleLastUpdated = 'October 30, 2022'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        $CurrentDate = Get-Date
        $FirstOfCurrentMonth = Get-Date -Year $CurrentDate.Year -Month $CurrentDate.Month -Day 1
        $LowerBoundDate = $FirstOfCurrentMonth.AddDays(-1).ToString("yyyyMMdd")

		$TSQL = "EXEC Trending.CreateTrendData @LowerBoundDate = '$LowerBoundDate'"
        
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