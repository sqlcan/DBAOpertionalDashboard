<#
.SYNOPSIS
Truncate-CMDBLog

.DESCRIPTION 
Truncate-CMDBLog

.PARAMETER ServerVNOName
Left side part of ServerName\InstanceName pair.

.PARAMETER SQLInstanceName
Right side part of ServerName\InstanceName pair.


.INPUTS
None

.OUTPUTS
Truncate-CMDBLog

.EXAMPLE
PowerShell Command Let

Description

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2017.01.24 0.01    Inital Draft
2017.02.21 0.02    Fixed logic mistake in checking for valid range for Cleanup.
#>
function Truncate-CMDBLog
{

    $ModuleName = 'Truncate-CMDBLog'
    $ModuleVersion = '0.02'
    $ModuleLastUpdated = 'February 21, 2017'
    $Logs_Cleanup_LowerRange = 30
    $Logs_Cleanup_UpperRange = 180

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        if (!($Global:Logs_CleanUp_Enabled))
        {
            Write-StatusUpdate -Message "CMDB Log data cannot be deleted; it is disabled in Global Settings!"
            return
        }

        if (($Global:Logs_CleanUp -lt $Logs_Cleanup_LowerRange) -or ($Global:Logs_CleanUp -gt $Logs_Cleanup_UpperRange))
        {
            Write-StatusUpdate -Message "ERROR: `$Global:Logs_Cleanup value is outside the accepted range." -WriteToDB
            Write-StatusUpdate -Message "ERROR: Current value for `$Global:Logs_Cleanup: $Global:Logs_Cleanup Accepted Range: [$Logs_Cleanup_LowerRange - $Logs_Cleanup_UpperRange]." -WriteToDB
            Write-StatusUpdate -Message "ERROR: Defaulting `$Global:Logs_Cleanup to $Logs_Cleanup_UpperRange." -WriteToDB
            $Global:Logs_Cleanup = $Logs_Cleanup_UpperRange
        }

        $TSQL = "SELECT TOP 1 DateTimeCaptured
                   FROM dbo.Logs
                  WHERE Description = 'SQLCMDB - Collection End'
                    AND DateTimeCaptured <= DATEADD(Day,$Global:Logs_Cleanup,GETDATE())
               ORDER BY DateTimeCaptured DESC"

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

            $DateToDeleteTo = $Results.DateTimeCaptured

            $TSQL = "DELETE
                       FROM dbo.Logs
                      WHERE DateTimeCaptured <= '$DateToDeleteTo'"

            Write-StatusUpdate -Message $TSQL

            Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                          -Database $Global:SQLCMDB_DatabaseName `
                          -Query $TSQL

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