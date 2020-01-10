function Get-SQLCluster
{

    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$SQLClusterName
    )

    try
    {
        Write-StatusUpdate -Message "Get-SQLCluster" -Level $Global:OutputLevel_Six

        $TSQL = "SELECT SQLClusterID, SQLClusterName, IsMonitored, DiscoveryOn, LastUpdated AS SvrCnt FROM dbo.SQLClusters WHERE SQLClusterName = '$SQLClusterName'"
        Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
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
        Write-StatusUpdate -Message "Failed to Get-SQLCluster (unhandled expection)." -Level $Global:OutputLevel_Seven -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $Global:OutputLevel_Seven -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}