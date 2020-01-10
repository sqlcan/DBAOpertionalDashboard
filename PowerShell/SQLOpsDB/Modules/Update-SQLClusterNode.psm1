function Update-SQLClusterNode
{

    # This is minor Command Let that just updates the LastUpdated date for Severs
    #
    # However in future this can be expanded to allow update to other attributes.

    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$SQLClusterName,
    [Parameter(Position=1, Mandatory=$true)] [string]$SQLNodeName
    )

    try
    {
        Write-StatusUpdate -Message "Update-SQLClusterNode" -Level $Global:OutputLevel_Six

        $TSQL = "UPDATE CN
                    SET LastUpdated = CAST(GETDATE() AS DATE)
                   FROM dbo.SQLClusters SC
                   JOIN dbo.SQLClusterNodes CN
                     ON SC.SQLClusterID = CN.SQLClusterID
                   JOIN dbo.Servers S
                     ON S.ServerID = CN.SQLNodeID
                  WHERE S.ServerName = '$SQLNodeName'
                    AND SC.SQLClusterName = '$SQLClusterName'"
        Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

        Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                        -Database $Global:SQLCMDB_DatabaseName `
                        -Query $TSQL -ErrorAction Stop

        Write-Output $Global:Error_Successful
    }
    catch
    {
        Write-StatusUpdate -Message "Failed to Update-SQLClusterNode (unhandled expection)." -Level $Global:OutputLevel_Seven -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $Global:OutputLevel_Seven -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }

}