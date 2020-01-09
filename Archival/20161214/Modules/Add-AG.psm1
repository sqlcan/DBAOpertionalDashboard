<#
.SYNOPSIS
Adds a new AG in the CMDB.

.DESCRIPTION 
Add-AG connects to the Central Management Database (CMDB) to add a new 
Availability Groups with pair of
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
Returns success or failure.

.EXAMPLE
Add-AG -ServerVNOName SQLTest -SQLInstanceName MSSQLServer -AGName AGTest

Add Availability Group details for a default instance.

.EXAMPLE
Add-AG -ServerVNOName SCOMServer -SQLInstanceName SCOMInstance -AGName "SCOM Testing"

Add Availability Group details for a named instance.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2016.07.12 0.01    Initial Draft
#>
function Add-AG
{

    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerVNOName,
    [Parameter(Position=1, Mandatory=$true)] [string]$SQLInstanceName,
    [Parameter(Position=2, Mandatory=$true)] [string]$AGName
    )

    $ModuleName = 'Add-AG'
    $ModuleVersion = '0.01'
    $ModuleLastUpdated = 'July 12, 2016'
    $OutputLevel = $Global:OutputLevel_Zero

    try
    {
        $OutputLevel++
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)" -Level $OutputLevel

        #Get list of all AGs and their Replicas details.
        $TSQL1 = "SELECT COUNT(*) AS AgRwCnt
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
                    AND AG.AGName LIKE '$AGName'"

        $TSQL2 = "SELECT COUNT(*) AS AgRwCnt
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
        Write-StatusUpdate -Message $TSQL1 -Level $OutputLevel -IsTSQL
        Write-StatusUpdate -Message $TSQL2 -Level $OutputLevel -IsTSQL

        $Results1 = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL1 -ErrorAction Stop
        $Results2 = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL2 -ErrorAction Stop


        #If count value is greater then zero, then object already exists.  If less then zero, object is new.
        #First result set is checking for ag rows that exist for stand alone instances.
        #Second result set is checking for ag rows that exist for clustered instances.
        if (($Results1.AgRwCnt -eq 0) -and ($Results2.AgRwCnt -eq 0))
        {

            $TSQL = "INSERT INTO dbo.AGs (AGName) VALUES ('$AGName')"
            $OutputLevel++
            Write-StatusUpdate -Message $TSQL  -Level $OutputLevel -IsTSQL

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
        $OutputLevel++
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expection" -Level $OutputLevel -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $OutputLevel -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }

}