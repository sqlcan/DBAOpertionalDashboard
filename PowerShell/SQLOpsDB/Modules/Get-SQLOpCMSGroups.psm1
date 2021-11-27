<#
.SYNOPSIS
Get-SQLOpCMSGroups

.DESCRIPTION 
Get-SQLOpCMSGroups

.PARAMETER GroupName
Not required.  Can supply a group name to do a substring match.

.INPUTS
None

.OUTPUTS
CMS Group List

.EXAMPLE
Get list of all groups currently in CMDB Dashboard Database and their current status.

GET-SQLOpCMSGroups

.EXAMPLE
Get list of set of groups and their current status.

GET-SQLOpCMSGroups -GroupName 2005

Description

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2016.12.12 0.01    Inital Verison
2021.11.25 1.00.00 Refactored to new coding standards and improved ability to return
                   group list.
#>
function Get-SQLOpCMSGroups
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$false)] [string]$GroupName
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    $ModuleName = 'Get-SQLOpCMSGroups'
    $ModuleVersion = '1.00.00'
    $ModuleLastUpdated = 'Nov. 26, 2021'

    # Define the class to collect all the information to export to user.
    Class cCMSGroup {
		[int] $GroupID;
        [string] $GroupName;
		[bool] $IsMonitored;
    }

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        if ([String]::IsNullOrEmpty($GroupName))
        {
            $TSQL = "EXEC CMS.GetGroupList"
            Write-StatusUpdate -Message "Returning all groups with their monitor status." -WriteToDB
        }
        else
        {
            $TSQL = "EXEC CMS.GetGroupList @GroupName='$GroupName'"
            Write-StatusUpdate -Message "Find all groups with substring match for [$GroupName]." -WriteToDB
        }

        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                                    -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                                    -Query $TSQL
        
        # If no result sets are returned return an error; unless return the appropriate resultset.
        if (!($Results))
        {
            Write-Output $Global:Error_FailedToComplete
        }
        else
        {
            $CMSGroups = @()

            ForEach ($Row in $Results)
            {
                $CMSGroupObj = New-Object cCMSGroup

                $CMSGroupObj.GroupID = $Row.GroupID
				$CMSGroupObj.GroupName = $Row.GroupName

				if ($Row.IsMonitored -eq 1)
				{
					$CMSGroupObj.IsMonitored = $True
				}
				else {
					$CMSGroupObj.IsMonitored = $False
				}

                $CMSGroups += $CMSGroupObj

            }

            Write-Output $CMSGroups
        }
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Exception" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}