<#
.SYNOPSIS
Get-CMSGroups

.DESCRIPTION 
Get-CMSGroups

.PARAMETER GroupName
Not required.  Can supply a group name to do a substring match.


.INPUTS
None

.OUTPUTS
Get-CMSGroups

.EXAMPLE
Get list of all groups currently in CMDB Dashboard Database and their current status.

GET-CMSGroups

.EXAMPLE
Get list of set of groups and their current status.

GET-CMSGroups -GroupName 2005

Description

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2016.12.12 0.01    Inital Verison
#>
function Get-CMSGroups
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$false)] [string]$GroupName
    )

    $ModuleName = 'Get-CMSGroups'
    $ModuleVersion = '0.01'
    $ModuleLastUpdated = 'December 12, 2016'
    $OutputLevel = $Global:OutputLevel_Zero

    try
    {
        $OutputLevel++
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)" -Level $OutputLevel

        #What is T-SQL Doing?
        $TSQL = "
            WITH Groups (GroupID, GroupName)
            AS
            (   SELECT server_group_id, CAST(name AS VARCHAR(75))
	                FROM msdb.dbo.sysmanagement_shared_server_groups
	                WHERE parent_id IS NULL

	            UNION ALL

	            SELECT server_group_id, CAST(GroupName + '\' + CAST(name AS VARCHAR(100)) AS VARCHAR(75))
	                FROM msdb.dbo.sysmanagement_shared_server_groups SSG
	                JOIN Groups G
	                ON SSG.parent_id = G.GroupID)

                SELECT STR(G.GroupID) AS GroupID, GroupName, GTM.IsMonitored
                FROM Groups G
                JOIN CMS.GroupsToMonitor GTM
                    ON G.GroupID = GTM.GroupID
                WHERE GroupName LIKE 'DatabaseEngineServerGroup\%$GroupName%'
            ORDER BY GroupName
        "

        $OutputLevel++
        Write-StatusUpdate -Message $TSQL -Level $OutputLevel -IsTSQL

        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL
        
        # If no result sets are returned return an error; unless return the appropriate resultset.
        if (!($Results))
        {
            Write-Output $Global:Error_FailedToComplete
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