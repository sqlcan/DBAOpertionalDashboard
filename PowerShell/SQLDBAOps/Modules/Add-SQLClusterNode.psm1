function Add-SQLClusterNode
{

    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$SQLClusterName,
    [Parameter(Position=1, Mandatory=$true)] [string]$SQLNodeName,
    [Parameter(Position=2, Mandatory=$true)] [string]$IsActiveNode
    )

    Write-StatusUpdate -Message "Add-SQLClusterNode" -Level $Global:OutputLevel_Six

    try
    {

        $ServerID = 0
        $SQLClusterID = 0

        $TSQL = "SELECT ServerID FROM dbo.Servers WHERE ServerName = '$SQLNodeName'"
        Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL -ErrorAction Stop

        if ($Results)
        {
            $ServerID = $Results.ServerID
        }

        $TSQL = "SELECT SQLClusterID FROM dbo.SQLClusters WHERE SQLClusterName = '$SQLClusterName'"
        Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL -ErrorAction Stop

        if ($Results)
        {
            $SQLClusterID = $Results.SQLClusterID
        }

        if (($ServerID -ne 0) -and ($SQLClusterID -ne 0))
        {

            $TSQL = "SELECT COUNT(*) AS SvrClusCnt FROM dbo.SQLClusterNodes WHERE SQLClusterID = $SQLClusterID AND SQLNodeID = $ServerID"
            Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

            $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                        -Database $Global:SQLCMDB_DatabaseName `
                                        -Query $TSQL -ErrorAction Stop

            if ($Results.SvrClusCnt -eq 0)
            {

                $TSQL = "INSERT INTO dbo.SQLClusterNodes (SQLClusterID, SQLNodeID, IsActiveNode) VALUES ($SQLClusterID, $ServerID, $IsActiveNode)"
                Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

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
        else
        {
            Write-Output $Global:Error_ObjectsNotFound
        }

    }
    catch
    {
        Write-StatusUpdate -Message "Failed to Add-SQLclusterNode (unhandled expection)." -Level $Global:OutputLevel_Seven -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $Global:OutputLevel_Seven -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }

}