# Updated -- 2020-03-15 Reference to Get-SQLOpSQLCluster

function Update-Database
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerVNOName,
    [Parameter(Position=1, Mandatory=$true)] [string]$SQLInstanceName
    )

    Write-StatusUpdate "Update-Database" $OUTPUT_LEVEL_ONE

    if (Get-SQLOpSQLCluster $ServerVNOName)
    { # This is a cluster
                
        $TSQL = "UPDATE SI
                    SET LastUpdated = CAST(GETDATE() AS DATE)
                   FROM dbo.SQLInstances SI
                   JOIN dbo.SQLClusters SC
                     ON SI.SQLClusterID = SC.SQLClusterID
                    AND SI.ServerID IS NULL
                  WHERE SI.SQLInstanceName = $SQLInstanceName
                    AND SC.SQLClusterName = $ServerVNOName"
        Write-StatusUpdate $TSQL $OUTPUT_LEVEL_TWO

        Invoke-SQLCMD -ServerInstance $MasterServerName `
                        -Database $MasterDBName `
                        -Query $TSQL

        Write-Output 0 # Successful
    }
    else
    {
        $TSQL = "UPDATE SI
                    SET LastUpdated = CAST(GETDATE() AS DATE)
                   FROM dbo.SQLInstances SI
                   JOIN dbo.Servers S
                     ON SI.ServerID = S.ServerID
                    AND SI.SQLClusterID IS NULL
                  WHERE SI.SQLInstanceName = $SQLInstanceName
                    AND S.ServerName = $ServerVNOName"
        Write-StatusUpdate $TSQL $OUTPUT_LEVEL_TWO

        Invoke-SQLCMD -ServerInstance $MasterServerName `
                        -Database $MasterDBName `
                        -Query $TSQL

        Write-Output 0 # Successful
    }
}