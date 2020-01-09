function Update-SQLCluster
{

    # This is minor Command Let that just updates the LastUpdated date for Severs
    #
    # However in future this can be expanded to allow update to other attributes.

    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$SQLClusterName
    )

    try
    {
        Write-StatusUpdate -Message "Update-SQLCluster" -Level $Global:OutputLevel_Six

        $TSQL = "UPDATE dbo.SQLClusters SET LastUpdated = CAST(GETDATE() AS DATE) WHERE SQLClusterName = '$SQLClusterName'"
        Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

        Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                        -Database $Global:SQLCMDB_DatabaseName `
                        -Query $TSQL -ErrorAction Stop
    
        Write-Output $Global:Error_Successful
    }
    catch
    {
        Write-StatusUpdate -Message "Failed to Update-SQLCluster (unhandled expection)." -Level $Global:OutputLevel_Seven -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $Global:OutputLevel_Seven -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }

}