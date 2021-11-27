<#
.SYNOPSIS
Get-SQLOpSettings

.DESCRIPTION 
Get-SQLOpSettings

.INPUTS
None

.OUTPUTS
List of pre-configured SQL Operational Dashboard settings.

.EXAMPLE
Get list of all settings and their current configured value.

Get-SQLOpSettings

Description

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2021.11.27 1.00.00 Initial version.
#>
function Get-SQLOpSettings
{
    [CmdletBinding()] 
    param()

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    $ModuleName = 'Get-SQLOpSettings'
    $ModuleVersion = '1.00.00'
    $ModuleLastUpdated = 'Nov. 27, 2021'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"
        
		$TSQL = "SELECT SettingName, SettingValue FROM dbo.Setting"
		
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
            Return $Results
        }
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Exception" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}