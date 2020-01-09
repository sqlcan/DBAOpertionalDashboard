function Get-SQLInstance
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerVNOName,
    [Parameter(Position=1, Mandatory=$true)] [string]$SQLInstanceName
    )

    Write-StatusUpdate -Message "Get-SQLInstance" -Level $Global:OutputLevel_Six

    $TSQL = "SELECT SI.SQLInstanceID, S.ServerName AS ServerVNOName, SI.SQLInstanceName, SI.IsMonitored, SI.DiscoveryOn, SI.LastUpdated
               FROM dbo.SQLInstances SI
               JOIN dbo.Servers S
                 ON SI.ServerID = S.ServerID
                AND SI.SQLClusterID IS NULL
              WHERE S.ServerName = '$ServerVNOName'
                AND SI.SQLInstanceName = '$SQLInstanceName'

          UNION ALL

             SELECT SI.SQLInstanceID, SC.SQLClusterName AS ServerVNOName, SI.SQLInstanceName, SI.IsMonitored, SI.DiscoveryOn, SI.LastUpdated
               FROM dbo.SQLInstances SI
               JOIN dbo.SQLClusters SC
                 ON SI.SQLClusterID = SC.SQLClusterID
                AND SI.ServerID IS NULL
              WHERE SC.SQLClusterName = '$ServerVNOName'
                AND SI.SQLInstanceName = '$SQLInstanceName'"
    Write-StatusUpdate -Message "Get-SQLInstance" -Level $Global:OutputLevel_Seven -IsTSQL

    try
    {
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
        Write-StatusUpdate -Message "Failed to Get-SQLInstance (unhandled expection)." -Level $Global:OutputLevel_Seven -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $Global:OutputLevel_Seven -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}