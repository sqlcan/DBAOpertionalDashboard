<#
.SYNOPSIS
Get-CMSServers

.DESCRIPTION 
Get-CMSServers allows you to get list of servers registered in CMS server.  This 
command let will only return servers where the CMS group is set to monitor.

By default it will only return server name and their FQDN pairs.  However by supplying
IncludeGroupNames switch; you may also see where is the server being pulled from.

.PARAMETER IncludeGroupNames
Return group names inconjunction with server name details.


.INPUTS
None

.OUTPUTS
Get-CMSServers

.EXAMPLE
Get-CMSServers

Return list of servers and their FQDN.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2016.12.13 0.01    Inital Version.
#>
function Get-CMSServers
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$false)] [switch]$IncludeGroupNames,
    [Parameter(Position=1, Mandatory=$false)] [string]$ServerName = $null
    )

    $ModuleName = 'Get-CMSServers'
    $ModuleVersion = '0.01'
    $ModuleLastUpdated = 'December 13, 2016'
    $OutputLevel = $Global:OutputLevel_Zero

    try
    {
        $OutputLevel++
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)" -Level $OutputLevel

        if (($ServerName -eq $null) -or ($ServerName -eq ''))
        {
            if ($IncludeGroupNames)
            {
                $TSQL = "EXEC CMS.GetCMSServerList @IncludeGroupName = 1"
            }
            else
            {
                $TSQL = "EXEC CMS.GetCMSServerList"
            }
        }
        else
        {
            # This branch is added when needed to update a single server only; the server name does not have
            # to be fully qualified or complete.  It will do substring match starting with server name.
            #
            # i.e. WHERE ServerName LIKE '$ServerName%'
            $TSQL = "EXEC CMS.GetCMSServerList @ServerName='$ServerName'"
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