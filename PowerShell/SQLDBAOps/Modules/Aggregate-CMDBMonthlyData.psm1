<#
.SYNOPSIS
Aggregate-CMDBMonthlyData

.DESCRIPTION 
Aggregate-CMDBMonthlyData

.PARAMETER Type
What do they want to aggregate data for?

.INPUTS
None

.OUTPUTS
Aggregate-CMDBMonthlyData

.EXAMPLE
Aggregate-CMDBMonthlyData -Type DiskVolumes

Aggregate data for last month for all disk volumes.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2016.12.14 0.01    Inital Version
2017.01.10 0.02    Misspelled stored procedure name for aggregating disk volume
                   information
#>
function Aggregate-CMDBMonthlyData
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [ValidateSet(“DiskVolumes”,”Databases”)] [string]$Type
    )

    $ModuleName = 'Aggregate-CMDBMonthlyData'
    $ModuleVersion = '0.02'
    $ModuleLastUpdated = 'January 10, 2017'

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