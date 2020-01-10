<#
.SYNOPSIS
Delete-CMDBData

.DESCRIPTION 
Delete-CMDBData

.PARAMETER Type
For which object you wish to clean up expired data?

.INPUTS
None

.OUTPUTS
Delete-CMDBData

.EXAMPLE
Delete-CMDBData -Type Servers

Clean up all data for servers which have been expired; expired default threshold is
90 days.  But can be changed in global settings.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2016.14.12 0.01    Inital Version
2017.01.24 0.02    Added upper and lower range validation for all cleanup variables.
2017.02.21 0.03    Fixed logic mistake in checking for valid range for Cleanup.
#>
function Delete-CMDBData
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [ValidateSet(“Servers”,”SQLInstances”,"Databases","DiskVolumes","SQLClusters")] [string]$Type
    )

    $ModuleName = 'Delete-CMDBData'
    $ModuleVersion = '0.03'
    $ModuleLastUpdated = 'February 21, 2017'
    $Expired_Cleanup_LowerRange = 90
    $Expired_Cleanup_UpperRange = 120

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        if (($Global:Expired_Cleanup -lt $Expired_Cleanup_LowerRange) -or ($Global:Expired_Cleanup -gt $Expired_Cleanup_UpperRange))
        {
            Write-StatusUpdate -Message "ERROR: `$Global:Expired_Cleanup value is outside the accepted range." -WriteToDB
            Write-StatusUpdate -Message "ERROR: Current value for `$Global:Expired_Cleanup: $Global:Expired_Cleanup Accepted Range: [$Expired_Cleanup_LowerRange - $Expired_Cleanup_UpperRange]." -WriteToDB
            Write-StatusUpdate -Message "ERROR: Defaulting `$Global:Expired_Cleanup to $Expired_Cleanup_UpperRange." -WriteToDB
            $Global:Expired_Cleanup = $Expired_Cleanup_UpperRange
        }

        switch ($Type)
        {
            'Servers'
            {$TSQL = "EXEC Expired.CleanUp_Servers @NumberOfDaysToKeep = $Global:Expired_Cleanup"}
            'SQLInstances'
            {$TSQL = "EXEC Expired.CleanUp_SQLInstance @NumberOfDaysToKeep = $Global:Expired_Cleanup"}
            'Databases'
            {$TSQL = "EXEC Expired.CleanUp_Databases @NumberOfDaysToKeep = $Global:Expired_Cleanup"}
            'DiskVolumes'
            {$TSQL = "EXEC Expired.CleanUp_DiskVolumes @NumberOfDaysToKeep = $Global:Expired_Cleanup"}
            'SQLClusters'
            {$TSQL = "EXEC Expired.CleanUp_SQLClusters @NumberOfDaysToKeep = $Global:Expired_Cleanup"}
        }
        Write-StatusUpdate -Message $TSQL

        if ($Global:Expired_CleanUp_Enabled)
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
        else
        {
            Write-StatusUpdate -Message "Expired data for all objects cannot be deleted; it is disabled in Global Settings!"
            Write-Output $Global:Error_Successful
        }
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expection" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}