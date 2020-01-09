<#
.SYNOPSIS
Update-CMSGroups

.DESCRIPTION 
Update-CMSGroups toggles the monitor switch.  Must supply GroupName or GroupID parameter.
GroupID parameter will take presidence.

.PARAMETER GroupName
Must supply exact group name as it shows up in Get-CMSGroups to toggle the monitor switch.

.PARAMETER GroupID
Internal group ID in CMS; for which you wish to toggle the monitor switch.


.INPUTS
None

.OUTPUTS
Update-CMSGroups

.EXAMPLE
Update-CMSGroups -GroupID 10

Update Group ID 10 to enable monitoring.

.Example
Update-CMSGroups -GroupName 'DatabaseEngineServerGroup\AGFA\Prod\2005'

Update Group, 'DatabaseEngineServerGroup\AGFA\Prod\2005' to enable monitoring.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2016.12.13 0.01    Initial Version
#>
function Update-CMSGroups
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$false)] [string]$GroupName = '',
    [Parameter(Position=1, Mandatory=$false)] [int]$GroupID = 0
    )

    $ModuleName = 'Update-CMSGroups'
    $ModuleVersion = '0.01'
    $ModuleLastUpdated = 'December 13, 2016'
    $OutputLevel = $Global:OutputLevel_Zero

    # Validate that either or parameter is supplied; if not we cannot run the command.
    if (($GroupName -ne '') -and ($GroupID -ne 0))
    {
        $GroupName = $null
    }
    elseif (($GroupName -eq '') -and ($GroupID -eq 0))
    {
        $OutputLevel++
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) " -Level $OutputLevel
        Write-StatusUpdate -Message "Must supply at least GroupID or GroupName."
        Write-Output $Global:Error_FailedToComplete
        return
    }

    try
    {
        $OutputLevel++
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)" -Level $OutputLevel

        #What is T-SQL Doing?
        if ($GroupID -ne 0)
        {
            $TSQL = "EXEC CMS.UpdateGroupMonitorStatus @GroupID=$GroupID"
        }
        else
        {
            $TSQL = "EXEC CMS.UpdateGroupMonitorStatus @GroupName='$GroupName'"
        }

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