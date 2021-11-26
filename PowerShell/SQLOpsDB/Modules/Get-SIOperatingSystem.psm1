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
           0.00.02 Updated to strip out verbose Windows caption detail from WMI call.
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
            if ($OSDetails.Caption -match '(?<OSversion>(\d{4}\sR2|\d{4}|\d{1,2}))')
            {
                if ($Matches['OSversion'] -eq '10')
                {
                    $OperatingSystem = "Windows $($Matches['OSversion'])"
                }
                else
                {
                    $OperatingSystem = "Windows Server $($Matches['OSversion'])"
                }
            }            
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