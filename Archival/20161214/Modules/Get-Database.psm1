<# 
.SYNOPSIS 
Write Status Updates.
.DESCRIPTION 
Command let writes error log/status details to screen and database; based on the parameters passed.
.PARAMETER Message
Information that needs to be recorded
.PARAMETER Level
Level defines the deapth of the information; it is strictly used for formatting.
.RETURNVALUE 
integer
.NOTES 
Version History 
2015.08.10 -  1.00 - Mohit K. Gupta - INCOMPLETE

NEED TO UPDATE FOR GETTING DATABASE INFORMATION FROM DBA_RESOURCE DATABASE.
#> 
function Get-Database
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerVNOName,
    [Parameter(Position=1, Mandatory=$true)] [string]$SQLInstanceName
    )

    Write-StatusUpdate "Get-Database" $OUTPUT_LEVEL_ONE

    $TSQL = "SELECT S.ServerName AS ServerVNOName, SI.SQLInstanceName, SI.IsMonitored, SI.DiscoveryOn, SI.LastUpdated
               FROM dbo.SQLInstances SI
               JOIN dbo.Servers S
                 ON SI.ServerID = S.ServerID
                AND SI.SQLClusterID IS NULL
              WHERE S.ServerName = '$ServerVNOName'
                AND SI.SQLInstanceName = '$SQLInstanceName'

          UNION ALL

             SELECT SC.SQLClusterName AS ServerVNOName, SI.SQLInstanceName, SI.IsMonitored, SI.DiscoveryOn, SI.LastUpdated
               FROM dbo.SQLInstances SI
               JOIN dbo.SQLClusters SC
                 ON SI.SQLClusterID = SC.SQLClusterID
                AND SI.ServerID IS NULL
              WHERE SC.SQLClusterName = '$ServerVNOName'
                AND SI.SQLInstanceName = '$SQLInstanceName'"
    Write-StatusUpdate $TSQL $OUTPUT_LEVEL_TWO

    $Results = Invoke-Sqlcmd -ServerInstance $MasterServerName `
                                -Database $MasterDBName `
                                -Query $TSQL

    Write-Output $Results
}