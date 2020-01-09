<#
.SYNOPSIS
Updates the last time AG was referenced.

.DESCRIPTION 
Update-AG connects to the Central Management Database (CMDB) to retrive
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
Update-AG -ServerVNOName SQLTest -SQLInstanceName MSSQLServer -AGName AGTest

Get Availability Group details for a default instance.

.EXAMPLE
Update-AG -ServerVNOName SCOMServer -SQLInstanceName SCOMInstance -AGName "SCOM Testing"

Get Availability Group details for a named instance.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2016.07.14 0.01    Initial Draft
2016.12.13 0.02    Removed -Level attribute from Write-StatusUpdate
#>
function Update-AG
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerVNOName,
    [Parameter(Position=1, Mandatory=$true)] [string]$SQLInstanceName,
    [Parameter(Position=2, Mandatory=$true)] [string]$AGName,
    [Parameter(Position=3, Mandatory=$true)] [string]$AGGuid
    )

    $ModuleName = 'Update-AG'
    $ModuleVersion = '0.02'
    $ModuleLastUpdated = 'December 13, 2016'

    try
    {
        
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        #Get list of all AGs and their Replicas details.
        $TSQL = "UPDATE AG
                    SET LastUpdated = GetDate()
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
                    AND AG.AGGuid LIKE '$AGGuid'"

        
        Write-StatusUpdate -Message $TSQL -IsTSQL

        Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                            -Database $Global:SQLCMDB_DatabaseName `
                            -Query $TSQL

        $TSQL = "UPDATE AG
                    SET LastUpdated = GetDate()
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

        Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                            -Database $Global:SQLCMDB_DatabaseName `
                            -Query $TSQL
    }
    catch
    {
        
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expection" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}