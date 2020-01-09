<#
.SYNOPSIS
Create-CMDBMonthlyTrend

.DESCRIPTION 
Create-CMDBMonthlyTrend will create monthly thread for last month.

.PARAMETER Type
For what object do you want to create trends for?

.INPUTS
None

.OUTPUTS
Create-CMDBMonthlyTrend

.EXAMPLE
Create-CMDBMonthlyTrend -Type SQLInstances

Description

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2016.12.14 0.01    Initial Version
2017.03.06 0.02    Missing the quotations in the date parameter.
#>
function Create-CMDBMonthlyTrend
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [ValidateSet(“Servers”,”SQLInstances”,"Databases")] [string]$Type
    )

    $ModuleName = 'Create-CMDBMonthlyTrend'
    $ModuleVersion = '0.02'
    $ModuleLastUpdated = 'Mar. 6, 2017'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        $CurrentDate = Get-Date
        $FirstOfCurrentMonth = Get-Date -Year $CurrentDate.Year -Month $CurrentDate.Month -Day 1
        $LowerBoundDate = $FirstOfCurrentMonth.AddDays(-1).ToString("yyyyMMdd")

        switch ($Type)
        {
            'Servers'
            {$TSQL = "EXEC Trending.Servers_Monthly @LowerBoundDate = '$LowerBoundDate'"}
            'SQLInstances'
            {$TSQL = "EXEC Trending.SQLInstances_Monthly @LowerBoundDate = '$LowerBoundDate'"}
            'Databases'
            {$TSQL = "EXEC Trending.Databases_Monthly @LowerBoundDate = '$LowerBoundDate'"}
        }
        Write-StatusUpdate -Message $TSQL

        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
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
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expection" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}