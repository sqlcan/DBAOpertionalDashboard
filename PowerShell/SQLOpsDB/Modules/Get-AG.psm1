<#
.SYNOPSIS
Returns AG details from the CMDB.

.DESCRIPTION 
Get-AG connects to the Central Management Database (CMDB) to retrive
the current Availability Groups registered based on paramters passed.

.PARAMETER ServerVNOName
Left side part of ServerName\InstanceName pair.

.PARAMETER SQLInstanceName
Right side part of ServerName\InstanceName pair.

.PARAMETER AGName
Availability group name as it shows up in SQL Server 2012+.

.PARAMETER AGGuid
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
2016.07.14 0.02    Added AG Guid field as internal parameter to check if AG exists.
2016.12.13 0.03    Removed the -Level attribute from Write-StatusUpdate
#>
function Get-AG
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$false)] [string]$ServerVNOName = '%',
    [Parameter(Position=1, Mandatory=$false)] [string]$SQLInstanceName = '%',
    [Parameter(Position=2, Mandatory=$false)] [string]$AGName = '%',
    [Parameter(Position=3, Mandatory=$false, DontShow=$true)] [string]$AGGuid = '%'
    )

    $ModuleName = 'Get-AG'
    $ModuleVersion = '0.03'
    $ModuleLastUpdated = 'December 13, 2016'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

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
                    AND AG.AGGuid LIKE '$AGGuid'

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
                    AND AG.AGName LIKE '$AGName'
                    AND AG.AGGuid LIKE '$AGGuid'"

        Write-StatusUpdate -Message $TSQL -IsTSQL

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
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expection" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}