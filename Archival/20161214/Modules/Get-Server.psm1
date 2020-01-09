<# 
.SYNOPSIS 
Checks to see if server exists in CMDB already.
.DESCRIPTION 
Search CMDB for server name supplied in the parameters.
.PARAMETER ServerName
Server name without the FQDN.
.RETURNVALUE 
resultset
.NOTES 
Version History 
2015.08.10 -  1.00 - Mohit K. Gupta - Inital Development of Script
#> 

function Get-Server
{ 
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerName
    )

    try
    {
        Write-StatusUpdate -Message "Get-Server" -Level $Global:OutputLevel_Six

        $TSQL = "SELECT ServerID, ServerName, ProcessorName, NumberOfCores, NumberOfLogicalCores, IsMonitored, DiscoveryOn, LastUpdated FROM dbo.Servers WHERE ServerName = '$ServerName'"
        Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL -ErrorAction Stop

        if (!($Results))
        {
            Write-Output $Global:Error_ObjectsNotFound
        }
        else
        {
            Write-Output $Results
        }
    }
    catch
    {
        Write-StatusUpdate -Message "Failed to Get-Server (unhandled expection)." -Level $Global:OutputLevel_Seven -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $Global:OutputLevel_Seven -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}