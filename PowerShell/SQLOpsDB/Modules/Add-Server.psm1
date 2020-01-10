<# 
.SYNOPSIS 
Add the new server to CMDB.
.DESCRIPTION 
Command let writes error log/status details to screen and database; based on the parameters passed.
.PARAMETER Message
Information that needs to be recorded
.PARAMETER Level
Level defines the deapth of the information; it is strictly used for formatting.
.RETURNVALUE 
integer
.NOTES 
Version History 
2015.08.10 -  1.00 - Mohit K. Gupta - Inital Development of Script
#> 

function Add-Server
{ 

    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerName,
    [Parameter(Position=1, Mandatory=$true)] [string]$OperatingSystem,
    [Parameter(Position=2, Mandatory=$true)] [string]$ProcessorName,
    [Parameter(Position=3, Mandatory=$true)] [int]$NumberOfCores,
    [Parameter(Position=4, Mandatory=$true)] [int]$NumberOfLogicalCores,
    [Parameter(Position=5, Mandatory=$true)] [int]$IsPhysical
    )

    Write-StatusUpdate -Message "Add-Server" -Level $Global:OutputLevel_Six

    try
    {

        $TSQL = "SELECT COUNT(*) AS SvrCnt FROM dbo.Servers WHERE ServerName = '$ServerName'"
        Write-StatusUpdate -Message $TSQL  -Level $Global:OutputLevel_Seven -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL -ErrorAction Stop

        if ($Results.SvrCnt -eq 0)
        { # Server does not exist in database.

            $TSQL = "SELECT OperatingSystemID FROM dbo.OperatingSystems WHERE OperatingSystemName = '$OperatingSystem'"
            Write-StatusUpdate -Message $TSQL  -Level $Global:OutputLevel_Seven -IsTSQL

            $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                        -Database $Global:SQLCMDB_DatabaseName `
                                        -Query $TSQL -ErrorAction Stop

            if ($Results)
            {
                $OperatingSystemID = $Results.OperatingSystemID
            }
            else
            {
                $OperatingSystemID = 1 # Unknown
            }
        

            $TSQL = "INSERT INTO dbo.Servers (ServerName, OperatingSystemID, ProcessorName, NumberOfCores, NumberOfLogicalCores, IsPhysical) VALUES ('$ServerName', $OperatingSystemID, '$ProcessorName', $NumberOfCores, $NumberOfLogicalCores, $IsPhysical)"
            Write-StatusUpdate -Message $TSQL  -Level $Global:OutputLevel_Seven -IsTSQL

            Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                            -Database $Global:SQLCMDB_DatabaseName `
                            -Query $TSQL -ErrorAction Stop

            Write-Output $Global:Error_Successful # Successful
        }
        else
        {
            Write-Output $Global:Error_Duplicate # Sever already exists
        }
    }
    catch
    {
        Write-StatusUpdate -Message "Failed to Add-Server (unhandled expection)." -Level $Global:OutputLevel_Seven -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $Global:OutputLevel_Seven -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }

}