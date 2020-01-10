function Add-SQLCluster
{

    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$SQLClusterName
    )

    try
    {
        Write-StatusUpdate -Message "Add-SQLCluster" -Level $Global:OutputLevel_Six

        $TSQL = "SELECT COUNT(*) AS ClusCnt FROM dbo.SQLClusters WHERE SQLClusterName = '$SQLClusterName'"
        Write-StatusUpdate -Message $TSQL  -Level $Global:OutputLevel_Six -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL -ErrorAction Stop

        if ($Results.ClusCnt -eq 0)
        {

            $TSQL = "INSERT INTO dbo.SQLClusters (SQLClusterName) VALUES ('$SQLClusterName')"
            Write-StatusUpdate -Message $TSQL  -Level $Global:OutputLevel_Six -IsTSQL

            Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                            -Database $Global:SQLCMDB_DatabaseName `
                            -Query $TSQL -ErrorAction Stop

            Write-Output $Global:Error_Successful

        }
        else
        {
            Write-Output $Global:Error_Duplicate
        }
    }
    catch
    {
        Write-StatusUpdate -Message "Failed to Add-SQLCluster (unhandled expection)." -Level $Global:OutputLevel_Seven -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $Global:OutputLevel_Seven -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }

}