<#
.SYNOPSIS
Set-CMSGroups

.DESCRIPTION 
Set-CMSGroups toggles the monitor switch.  Must supply GroupName or GroupID parameter.

.PARAMETER GroupName
Must supply exact group name as it shows up in Get-CMSGroups to toggle the monitor switch.

.PARAMETER GroupID
Internal group ID in CMS; for which you wish to toggle the monitor switch.

.INPUTS
None

.OUTPUTS
Set-CMSGroups

.EXAMPLE
Set-CMSGroups -GroupID 10

Update Group ID 10 to enable monitoring.

.Example
Set-CMSGroups -GroupName 'DatabaseEngineServerGroup\Contoso\Prod\2005'

Update Group, 'DatabaseEngineServerGroup\Contoso\Prod\2005' to enable monitoring.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2016.12.13 0.00.01 Initial Version
2019.01.09 0.00.02 Updated the command let name to Set-CMSGroups as per PowerShell BP.
           0.00.03 Introduced parameter sets to make sure both GroupName and GroupID
                   are required parameters vs optional.
#>
function Set-CMSGroups
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true, ParameterSetName='By Name')] [string]$GroupName = '',
    [Parameter(Position=0, Mandatory=$true, ParameterSetName='By ID')] [int]$GroupID = 0
    )

    $ModuleName = 'Set-CMSGroups'
    $ModuleVersion = '0.00.02'
    $ModuleLastUpdated = 'January 9, 2019'
    $OutputLevel = $Global:OutputLevel_Zero

    try
    {
        $OutputLevel++
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)" -Level $OutputLevel

        #Enable or disable the group from CMS.
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
        
        # If no result sets are returned return an error; unless return the appropriate result set.
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