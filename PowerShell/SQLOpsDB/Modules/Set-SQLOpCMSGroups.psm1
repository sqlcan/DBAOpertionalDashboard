<#
.SYNOPSIS
Set-SQLOpCMSGroups

.DESCRIPTION 
Set-SQLOpCMSGroups toggles the monitor switch.  Must supply GroupName or GroupID parameter.

.PARAMETER GroupName
Must supply exact group name as it shows up in Get-CMSGroups to toggle the monitor switch.

.PARAMETER GroupID
Internal group ID in CMS; for which you wish to toggle the monitor switch.

.INPUTS
None

.OUTPUTS
Set-SQLOpCMSGroups

.EXAMPLE
Set-SQLOpCMSGroups -GroupID 10

Update Group ID 10 to enable monitoring.

.Example
Set-SQLOpCMSGroups -GroupName 'DatabaseEngineServerGroup\Contoso\Prod\2005'

Update Group, 'DatabaseEngineServerGroup\Contoso\Prod\2005' to enable monitoring.

.Example
Set-SQLOpCMSGroups -GroupName 'Dev'

Disable monitoring on all groups with "Dev" in its Path.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2016.12.13 0.00.01 Initial Version
2019.01.09 0.00.02 Updated the command let name to Set-SQLOpCMSGroups as per PowerShell BP.
           0.00.03 Introduced parameter sets to make sure both GroupName and GroupID
                   are required parameters vs optional.
2021.11.27 2.00.00 Updated commandlet name, refactored the code per new standard.
#>
function Set-SQLOpCMSGroups
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$false, ParameterSetName='By Name')] [string]$GroupName,
    [Parameter(Position=0, Mandatory=$false, ParameterSetName='By ID')] [int]$GroupID
    )

	if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    $ModuleName = 'Set-SQLOpCMSGroups'
    $ModuleVersion = '0.00.02'
    $ModuleLastUpdated = 'January 9, 2019'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        #Enable or disable the group from CMS.
        if ($GroupID -ne 0)
        {
            $TSQL = "EXEC CMS.UpdateGroupMonitorStatus @GroupID=$GroupID"
        }
        else
        {
            $TSQL = "EXEC CMS.UpdateGroupMonitorStatus @GroupName='$GroupName'"
        }

        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                                    -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
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
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Exception" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}