<#
.SYNOPSIS
Returns AG details from the CMDB.

.DESCRIPTION 
Get-AG connects to the Central Management Database (CMDB) to retrive
the current Availability Groups registered with pair of
ServerVNOName\InstanceName and Availability Group Name pair.

.PARAMETER ServerVNOName
Left side part of ServerName\InstanceName pair.

.PARAMETER SQLInstanceName
Right side part of ServerName\InstanceName pair.

.PARAMETER AGName
Availability group name as it shows up in SQL Server 2012+.

.INPUTS
None

.OUTPUTS
Returns a result set with AG Name, AG Discovery Date, AG Last Update Date,
and SQL Instance Name (ServerName\InstanceName).

.EXAMPLE
GET-AG -ServerVNOName SQLTest -SQLInstanceName MSSQLServer -AGName AGTest

Get Availability Group details for a default instance.

.EXAMPLE
GET-AG -ServerVNOName SCOMServer -SQLInstanceName SCOMInstance -AGName "SCOM Testing"

Get Availability Group details for a named instance.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2016.06.09 0.01    Initial Draft
#>
function Get-AG
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerVNOName,
    [Parameter(Position=1, Mandatory=$true)] [string]$SQLInstanceName,
    [Parameter(Position=2, Mandatory=$true)] [string]$AGName
    )

    $ModuleName = 'Get-AG'
    $ModuleVersion = '0.01'
    $ModuleLastUpdated = 'June 9, 2016'
    $OutputLevel = $Global:OutputLevel_Zero

    try
    {
        $OutputLevel++
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)" -Level $OutputLevel

        #Get list of all AGs and their Replicas details.
        $TSQL = "SELECT AG.AGID, S.ServerName AS ServerVNOName, SI.SQLInstanceName, AG.AGName, AG.DiscoveryOn, AG.LastUpdated
                   FROM dbo.SQLInstances SI
                   JOIN dbo.Servers S
                     ON SI.ServerID = S.ServerID
                    AND SI.SQLClusterID IS NULL
                   JOIN dbo.AGInstances AGI
                     ON AGI.SQLInstanceID = SI.SQLInstanceID
                   JOIN dbo.AGs AG
                     ON AG.AGID = AGI.AGID
                  WHERE S.ServerName LIKE '$ServerVNOName'
                    AND SI.SQLInstanceName LIKE '$SQLInstanceName'
                    AND AG.AGName LIKE '$AGName'

                UNION ALL

                 SELECT AG.AGID, SC.SQLClusterName AS ServerVNOName, SI.SQLInstanceName, AG.AGName, AG.DiscoveryOn, AG.LastUpdated
                   FROM dbo.SQLInstances SI
                   JOIN dbo.SQLClusters SC
                     ON SI.SQLClusterID = SC.SQLClusterID
                    AND SI.ServerID IS NULL
                   JOIN dbo.AGInstances AGI
                     ON AGI.SQLInstanceID = SI.SQLInstanceID
                   JOIN dbo.AGs AG
                     ON AG.AGID = AGI.AGID
                  WHERE SC.SQLClusterName LIKE '$ServerVNOName'
                    AND SI.SQLInstanceName LIKE '$SQLInstanceName'
                    AND AG.AGName LIKE '$AGName'"

        $OutputLevel++
        Write-StatusUpdate -Message $TSQL -Level $OutputLevel -IsTSQL

        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL
        
        # If no result sets are returned return an error; unless return the appropriate resultset.
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
        $OutputLevel++
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expection" -Level $OutputLevel -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $OutputLevel -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}