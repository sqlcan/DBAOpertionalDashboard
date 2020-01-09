function Add-SQLInstance
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerVNOName,
    [Parameter(Position=1, Mandatory=$true)] [string]$SQLInstanceName,
    [Parameter(Position=2, Mandatory=$true)] [string]$SQLVersion,
    [Parameter(Position=3, Mandatory=$true)] [int]$SQLServer_Build,
    [Parameter(Position=4, Mandatory=$true)] [string]$SQLEdition,
    [Parameter(Position=5, Mandatory=$true)] [string]$ServerType,
    [Parameter(Position=6, Mandatory=$true)] [string]$ServerEnviornment
    )

    try
    {
        Write-StatusUpdate -Message "Add-SQLInstance" -Level $Global:OutputLevel_Six

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
                                    -Query $TSQL -ErrorAction Stop

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
                                    -Query $TSQL -ErrorAction Stop

        $ClusteredInstanceCount = $Results.SvrCnt


        $TSQL = "SELECT TOP 1 SQLVersionID
                   FROM dbo.SQLVersions
                  WHERE SQLVersion LIKE '$SQLVersion%'
                    AND SQLBuild <= $SQLServer_Build
               ORDER BY SQLBuild DESC"

        Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL -ErrorAction Stop

        if ($Results)
        {
            $SQLVersionID = $Results.SQLVersionID
        }
        else
        {
            $SQLVersionID = 1
        }

        $Results = Get-SQLCluster $ServerVNOName

        if (($ClusteredInstanceCount -eq 0) -and ($Results -ne $Global:Error_ObjectsNotFound))
        { # This is a cluster and the instance defination does not exist.

            $TSQL = "SELECT SQLClusterID
                       FROM dbo.SQLClusters SC
                      WHERE SC.SQLClusterName = '$ServerVNOName'"
            Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Eight -IsTSQL

            $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                        -Database $Global:SQLCMDB_DatabaseName `
                                        -Query $TSQL -ErrorAction Stop
                 
            $TSQL = "INSERT INTO dbo.SQLInstances (SQLInstanceName, ServerID, SQLClusterID, SQLInstanceVersionID, SQLInstanceBuild, SQLInstanceEdition, SQLInstanceType, SQLInstanceEnviornment) VALUES ('$SQLInstanceName', null, $($Results.SQLClusterID), $SQLVersionID, $SQLServer_Build, '$SQLEdition', '$ServerType', '$ServerEnviornment')"
            Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Eight -IsTSQL

            Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                            -Database $Global:SQLCMDB_DatabaseName `
                            -Query $TSQL -ErrorAction Stop

            Write-Output $Global:Error_Successful
        }
        elseif (($StandAloneInstanceCount -eq 0) -and ($ClusteredInstanceCount -eq 0))
        {
            $TSQL = "SELECT S.ServerID
                       FROM dbo.Servers S
                      WHERE S.ServerName = '$ServerVNOName'"
            Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Eight -IsTSQL

            $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                        -Database $Global:SQLCMDB_DatabaseName `
                                        -Query $TSQL -ErrorAction Stop
                 
            $TSQL = "INSERT INTO dbo.SQLInstances (SQLInstanceName, ServerID, SQLClusterID, SQLInstanceVersionID, SQLInstanceBuild, SQLInstanceEdition, SQLInstanceType, SQLInstanceEnviornment) VALUES ('$SQLInstanceName', $($Results.ServerID), null, $SQLVersionID, $SQLServer_Build, '$SQLEdition', '$ServerType', '$ServerEnviornment')"
            Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Eight -IsTSQL

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
        Write-StatusUpdate -Message "Failed to Add-SQLInstance (unhandled expection)." -Level $Global:OutputLevel_Seven -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $Global:OutputLevel_Seven -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}