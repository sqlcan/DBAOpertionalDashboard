<#
.SYNOPSIS
Get-SIDiskVolume

.DESCRIPTION 
Get-SIDiskVolume wrapper for Win32_Volume.  Return all the volumes on a computer.

.PARAMETER ComputerName
Server name for data collection.

.INPUTS
None

.OUTPUTS
[System.Object] Array of Disk Volumes

.EXAMPLE
Get-SIDiskVolume -ComputerName ContosSQL

Return the current operating system name.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2020.03.15 0.00.01 Initial Version
2020.03.16 0.00.02 Limited the data returned from command-let.
#>
function Get-SIDiskVolume
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
    
    $ModuleName = 'Get-SIDiskVolume'
    $ModuleVersion = '0.00.01'
    $ModuleLastUpdated = 'March 15, 2020'
    
    # Review: https://devblogs.microsoft.com/scripting/hey-scripting-guy-how-can-i-use-erroractionpreference-to-control-cmdlet-handling-of-errors/
    $ErrorActionPreference = 'Stop'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        $Volumes = Get-WmiObject -Class Win32_Volume -ComputerName $ComputerName -Filter "DriveType='3'" | Select-Object Name, Capacity, FreeSpace

        if ($Volumes)
        {
			Write-Output $Volumes	
		}
		else
		{
			Write-Output $Global:Error_ObjectsNotFound
		}
		
    }
    catch [System.Runtime.InteropServices.COMException]
    {
		Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - WMI Call Failed. $ComputerName not found." -WriteToDB
		Write-Output $Global:Error_FailedToComplete
    }
    catch [System.UnauthorizedAccessException]
    {
		Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - WMI Call Failed. Access denied on $ComputerName." -WriteToDB
		Write-Output $Global:Error_FailedToComplete
    }
    catch [System.Management.ManagementException]
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - WMI Call Failed for $ComputerName." -WriteToDB
		Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
		Write-Output $Global:Error_FailedToComplete
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Exception" -WriteToDB
		Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
		Write-Output $Global:Error_FailedToComplete
    }
}