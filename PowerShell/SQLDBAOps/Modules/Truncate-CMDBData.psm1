<#
.SYNOPSIS
Truncate-CMDBData

.DESCRIPTION 
Truncate-CMDBData

.PARAMETER Type
Which dataset you wish to truncate?

.INPUTS
None

.OUTPUTS
Truncate-CMDBData

.EXAMPLE
Truncate-CMDBData -Type Raw_DiskVolumes

Clean up the raw data for disk volumes based on the global configuration parameters defined.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2016.12.14 0.01    Initial version
2017.01.24 0.02    Added upper and lower range validation for all cleanup variables.
2017.02.21 0.03    Fixed logic mistake in checking for valid range for Cleanup.
#>
function Truncate-CMDBData
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [ValidateSet(“Raw_DiskVolumes”,”Raw_Database”,"Monthly_DiskVolumes","Monthly_Database","Trending_AllObjects")] [string]$Type
    )

    $ModuleName = 'Truncate-CMDBData'
    $ModuleVersion = '0.03'
    $ModuleLastUpdated = 'February 21, 2017'
    $RawData_Cleanup_LowerRange = 31
    $RawData_Cleanup_UpperRange = 62
    $Aggregate_Cleanup_LowerRange = 12
    $Aggregate_Cleanup_UpperRange = 60
    $Trending_Cleanup_LowerRange = 12
    $Trending_Cleanup_UpperRange = 60

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        if (($Global:RawData_Cleanup -lt $RawData_Cleanup_LowerRange) -or ($Global:RawData_Cleanup -gt $RawData_Cleanup_UpperRange))
        {
            Write-StatusUpdate -Message "ERROR: `$Global:RawData_Cleanup value is outside the accepted range." -WriteToDB
            Write-StatusUpdate -Message "ERROR: Current value for `$Global:RawData_Cleanup: $Global:RawData_Cleanup Accepted Range: [$RawData_Cleanup_LowerRange - $RawData_Cleanup_UpperRange]." -WriteToDB
            Write-StatusUpdate -Message "ERROR: Defaulting `$Global:RawData_Cleanup to $RawData_Cleanup_UpperRange." -WriteToDB
            $Global:RawData_Cleanup = $RawData_Cleanup_UpperRange
        }

        if (($Global:Aggregate_Cleanup -lt $Aggregate_Cleanup_LowerRange) -or ($Global:Aggregate_Cleanup -gt $Aggregate_Cleanup_UpperRange))
        {
            Write-StatusUpdate -Message "ERROR: `$Global:Aggregate_Cleanup value is outside the accepted range." -WriteToDB
            Write-StatusUpdate -Message "ERROR: Current value for `$Global:Aggregate_Cleanup: $Global:Aggregate_Cleanup Accepted Range: [$Aggregate_Cleanup_LowerRange - $Aggregate_Cleanup_UpperRange]." -WriteToDB
            Write-StatusUpdate -Message "ERROR: Defaulting `$Global:Aggregate_Cleanup to $Aggregate_Cleanup_UpperRange." -WriteToDB
            $Global:Aggregate_Cleanup = $Aggregate_Cleanup_UpperRange
        }

        if (($Global:Trending_Cleanup -lt $Trending_Cleanup_LowerRange) -or ($Global:Trending_Cleanup -gt $Trending_Cleanup_UpperRange))
        {
            Write-StatusUpdate -Message "ERROR: `$Global:Trending_Cleanup value is outside the accepted range." -WriteToDB
            Write-StatusUpdate -Message "ERROR: Current value for `$Global:Trending_Cleanup: $Global:Trending_Cleanup Accepted Range: [$Trending_Cleanup_LowerRange - $Trending_Cleanup_UpperRange]." -WriteToDB
            Write-StatusUpdate -Message "ERROR: Defaulting `$Global:Trending_Cleanup to $Trending_Cleanup_UpperRange." -WriteToDB
            $Global:Trending_Cleanup = $Trending_Cleanup_UpperRange
        }

        switch ($Type)
        {
            'Raw_DiskVolumes'
            {$TSQL = "EXEC History.TruncateRawDataForDiskVolumes @NumberOfDaysToKeep = $Global:RawData_Cleanup"}
            'Raw_Database'
            {$TSQL = "EXEC History.TruncateRawDataForDatabases @NumberOfDaysToKeep = $Global:RawData_Cleanup"}
            'Monthly_DiskVolumes'
            {$TSQL = "EXEC History.TruncateAggregatesForDiskVolumes @NumberOfMonthsToKeep = $Global:Aggregate_Cleanup"}
            'Monthly_Database'
            {$TSQL = "EXEC History.TruncateAggregatesForDatabases @NumberOfMonthsToKeep = $Global:Aggregate_Cleanup"}
            'Trending_AllObjects'
            {$TSQL = "EXEC Trending.TruncateMonthlyData @NumberOfMonthsToKeep = $Global:Trending_Cleanup"}
        }
        Write-StatusUpdate -Message $TSQL

        if ((!($Global:Aggregate_CleanUp_Enabled)) -and (($Type -eq 'Monthly_DiskVolumes') -or ($Type -eq 'Monthly_Database')))
        {
            Write-StatusUpdate -Message "Aggregate data for Disk Volumes or Databases cannot be deleted; it is disabled in Global Settings!"
            Write-Output $Global:Error_Successful
        }
        elseif ((!($Global:Trending_CleanUp_Enabled)) -and ($Type -eq 'Trending_AllObjects'))
        {
            Write-StatusUpdate -Message "Trending data for all objects cannot be deleted; it is disabled in Global Settings!"
            Write-Output $Global:Error_Successful
        }
        else
        {
            $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                                        -Database $Global:SQLCMDB_DatabaseName `
                                        -Query $TSQL
        
            # If no result sets are returned return an error; unless return the appropriate resultset.
            if (!($Results))
            {
                Write-Output $Global:Error_ObjectsNotFound
            }
            else
            {
                Write-Output $Results
            }
        }
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expection" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}