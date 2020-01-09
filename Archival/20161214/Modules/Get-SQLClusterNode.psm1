function Get-SQLClusterNode
{

    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$SQLClusterName,
    [Parameter(Position=1, Mandatory=$true)] [string]$SQLNodeName
    )

    try
    {
        Write-StatusUpdate -Message "Get-SQLClusterNode" -Level $Global:OutputLevel_Six

        $TSQL = "SELECT SC.SQLClusterName, S.ServerName AS SQLClusterNodeName, CN.IsActiveNode, CN.DiscoveryOn, CN.LastUpdated
                   FROM dbo.SQLClusters SC
                   JOIN dbo.SQLClusterNodes CN
                     ON SC.SQLClusterID = CN.SQLClusterID
                   JOIN dbo.Servers S
                     ON S.ServerID = CN.SQLNodeID
                  WHERE S.ServerName = '$SQLNodeName'
                    AND SC.SQLClusterName = '$SQLClusterName'"
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
        Write-StatusUpdate -Message "Failed to Update-SQLInstance (unhandled expection)." -Level $Global:OutputLevel_Seven -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $Global:OutputLevel_Seven -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}