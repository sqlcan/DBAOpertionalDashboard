<#
.SYNOPSIS
Get-SIOperatingSystem

.DESCRIPTION 
Get-SIOperatingSystem wrapper for Win32_OperatingSystem.  If unable to retrieve the
name, it will default to Unknown.  Appropriate errors will be logs in the Logs table.

.PARAMETER ComputerName
Server name for data collection.

.INPUTS
None

.OUTPUTS
[String] Operating System Name

.EXAMPLE
Get-SIOperatingSystem -ComputerName ContosSQL

Return the current operating system name.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2020.03.12 0.00.01 Initial Version
#>
function Get-SIOperatingSystem
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ComputerName
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Get-SIOperatingSystem'
    $ModuleVersion = '0.00.01'
    $ModuleLastUpdated = 'March 12, 2020'
    
    # Review: https://devblogs.microsoft.com/scripting/hey-scripting-guy-how-can-i-use-erroractionpreference-to-control-cmdlet-handling-of-errors/
    $ErrorActionPreference = 'Stop'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"
        [string] $OperatingSystem = "Unknown"

        $OSDetails = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ComputerName | Select-Object Caption

        if ($OSDetails)
        {
            $OperatingSystem = $OSDetails.Caption
        }
    }
    catch [System.Runtime.InteropServices.COMException]
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - WMI Call Failed. $ComputerName not found." -WriteToDB
    }
    catch [System.UnauthorizedAccessException]
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - WMI Call Failed. Access denied on $ComputerName." -WriteToDB
    }
    catch [System.Management.ManagementException]
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - WMI Call Failed for $ComputerName." -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expectation" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
    }
    finally
    {
        Write-Output $OperatingSystem
    }
}