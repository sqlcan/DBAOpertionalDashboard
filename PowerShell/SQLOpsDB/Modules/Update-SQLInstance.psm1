# Updated 2020.03.15 to use Get-SQLOpSQLCluster
function Update-SQLInstance
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
        Write-StatusUpdate -Message "Update-SQLInstance" -Level $Global:OutputLevel_Six

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

        $ClusterDetails = (Get-SQLOpSQLCluster $ServerVNOName)

        if (($ClusterDetails -ne $Global:Error_ObjectsNotFound) -and ($ClusterDetails -ne $Global:Error_FailedToComplete))
        { # This is a cluster
                
            $TSQL = "UPDATE SI
                        SET LastUpdated = CAST(GETDATE() AS DATE),
                            SQLInstanceVersionID = $SQLVersionID,
                            SQLInstanceBuild = $SQLServer_Build,
                            SQLInstanceEdition = '$SQLEdition',
                            SQLInstanceType = '$ServerType',
                            SQLInstanceEnviornment = '$ServerEnviornment'
                       FROM dbo.SQLInstances SI
                       JOIN dbo.SQLClusters SC
                         ON SI.SQLClusterID = SC.SQLClusterID
                        AND SI.ServerID IS NULL
                      WHERE SI.SQLInstanceName = '$SQLInstanceName'
                        AND SC.SQLClusterName = '$ServerVNOName'"
            Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

            Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                            -Database $Global:SQLCMDB_DatabaseName `
                            -Query $TSQL -ErrorAction Stop

            Write-Output $Global:Error_Successful
        }
        else
        {
            $TSQL = "UPDATE SI
                        SET LastUpdated = CAST(GETDATE() AS DATE),
                            SQLInstanceVersionID = $SQLVersionID,
                            SQLInstanceBuild = $SQLServer_Build,
                            SQLInstanceEdition = '$SQLEdition',
                            SQLInstanceType = '$ServerType',
                            SQLInstanceEnviornment = '$ServerEnviornment'
                       FROM dbo.SQLInstances SI
                       JOIN dbo.Servers S
                         ON SI.ServerID = S.ServerID
                        AND SI.SQLClusterID IS NULL
                      WHERE SI.SQLInstanceName = '$SQLInstanceName'
                        AND S.ServerName = '$ServerVNOName'"
            Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

            Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                            -Database $Global:SQLCMDB_DatabaseName `
                            -Query $TSQL -ErrorAction Stop

            Write-Output $Global:Error_Successful
        }
        
    }
    catch
    {
        Write-StatusUpdate -Message "Failed to Update-SQLInstance (unhandled expection)." -Level $Global:OutputLevel_Seven -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $Global:OutputLevel_Seven -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }

}