function Update-Server
{
    # This is minor Command Let that just updates the LastUpdated date for Severs
    #
    # However in future this can be expanded to allow update to other attributes.
 
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerName,
    [Parameter(Position=1, Mandatory=$true)] [string]$OperatingSystem,
    [Parameter(Position=2, Mandatory=$true)] [string]$ProcessorName,
    [Parameter(Position=3, Mandatory=$true)] [int]$NumberOfCores,
    [Parameter(Position=4, Mandatory=$true)] [int]$NumberOfLogicalCores,
    [Parameter(Position=5, Mandatory=$true)] [int]$IsPhysical
    )

    try
    {
        Write-StatusUpdate -Message "Update-Server" -Level $Global:OutputLevel_Six

        $TSQL = "SELECT OperatingSystemID FROM dbo.OperatingSystems WHERE OperatingSystemName = '$OperatingSystem'"
        Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

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


        $TSQL = "UPDATE dbo.Servers
                    SET LastUpdated = CAST(GETDATE() AS DATE),
                  OperatingSystemID = $OperatingSystemID,
                      ProcessorName = '$ProcessorName',
               NumberOfLogicalCores = $NumberOfLogicalCores,
                      NumberOfCores = $NumberOfCores,
                         IsPhysical = $IsPhysical WHERE ServerName = '$ServerName'"
        Write-StatusUpdate -Message $TSQL  -Level $Global:OutputLevel_Seven -IsTSQL

        Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                        -Database $Global:SQLCMDB_DatabaseName `
                        -Query $TSQL -ErrorAction Stop

        Write-Output $Global:Error_Successful
    }
    catch
    {
        Write-StatusUpdate -Message "Failed to Update-Server (unhandled expection)." -Level $Global:OutputLevel_Seven -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $Global:OutputLevel_Seven -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}