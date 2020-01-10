function Add-Database
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerVNOName,
    [Parameter(Position=1, Mandatory=$true)] [string]$SQLInstanceName
    )

    Write-StatusUpdate -Message "Add-Database" -Level $Global:OutputLevel_Six

    $TSQL = "SELECT COUNT(*) AS SvrCnt
               FROM dbo.SQLInstances SI
               JOIN dbo.Servers S
                 ON SI.ServerID = S.ServerID
                AND SI.SQLClusterID IS NULL
              WHERE S.ServerName = '$ServerVNOName'
                AND SI.SQLInstanceName = '$SQLInstanceName'"
    Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

    $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                -Database $Global:SQLCMDB_DatabaseName `
                                -Query $TSQL

    $StandAloneInstanceCount = $Results.SvrCnt

    $TSQl = "SELECT COUNT(*) AS SvrCnt
               FROM dbo.SQLInstances SI
               JOIN dbo.SQLClusters SC
                 ON SI.SQLClusterID = SC.SQLClusterID
                AND SI.ServerID IS NULL
              WHERE SC.SQLClusterName = '$ServerVNOName'
                AND SI.SQLInstanceName = '$SQLInstanceName'"
    Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

    $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                -Database $Global:SQLCMDB_DatabaseName `
                                -Query $TSQL

    $ClusteredInstanceCount = $Results.SvrCnt

    if (($ClusteredInstanceCount -eq 0) -and (Get-SQLCluster $ServerVNOName))
    { # This is a cluster and the instance defination does not exist.

        $TSQL = "SELECT SQLClusterID
                   FROM dbo.SQLClusters SC
                  WHERE SC.SQLClusterName = '$ServerVNOName'"
        Write-StatusUpdate $TSQL $OUTPUT_LEVEL_THREE

        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL
                 
        $TSQL = "INSERT INTO dbo.SQLInstances (SQLInstanceName, ServerID, SQLClusterID) VALUES ('$SQLInstanceName', null, $($Results.SQLClusterID))"
        Write-StatusUpdate $TSQL $OUTPUT_LEVEL_THREE

        Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                        -Database $Global:SQLCMDB_DatabaseName `
                        -Query $TSQL

        Write-Output 0 # Successful
    }
    elseif (($StandAloneInstanceCount -eq 0) -and ($ClusteredInstanceCount -eq 0))
    {
        $TSQL = "SELECT S.ServerID
                   FROM dbo.Servers S
                  WHERE S.ServerName = '$ServerVNOName'"
        Write-StatusUpdate $TSQL $OUTPUT_LEVEL_THREE

        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL
                 
        $TSQL = "INSERT INTO dbo.SQLInstances (SQLInstanceName, ServerID, SQLClusterID) VALUES ('$SQLInstanceName', $($Results.ServerID), null)"
        Write-StatusUpdate $TSQL $OUTPUT_LEVEL_THREE

        Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                        -Database $Global:SQLCMDB_DatabaseName `
                        -Query $TSQL

        Write-Output 0 # Successful
    }
    else
    {
        Write-Output -1 # Sever already exists
    }
    
}