<#
.SYNOPSIS
Get-SIMemory

.DESCRIPTION 
Get-SIMemory wrapper for Win32_PageFileUsage and Win32_ComputerSystem.
If unable to the information it will default to 0 for both memory size
and page file size.

.PARAMETER ComputerName
Server name for data collection.

.INPUTS
None

.OUTPUTS
[System.Object] Memory and Page File size.

.EXAMPLE
Get-SIMemory -ComputerName ContosSQL

Return the current processor details.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2022.10.31 0.00.01 Initial Version
2022.11.25 0.00.02 Handling multiple page files.
2022.11.30 0.00.03 Reverting Get-CIMInstance to Get-WMIObject
#>
function Get-SIMemory
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
    
    $ModuleName = 'Get-SIMemory'
    $ModuleVersion = '0.00.03'
    $ModuleLastUpdated = 'November 30, 2022'
    
    # Review: https://devblogs.microsoft.com/scripting/hey-scripting-guy-how-can-i-use-erroractionpreference-to-control-cmdlet-handling-of-errors/
    $ErrorActionPreference = 'Stop'

    class cMemory {
        [Int] $Memory_MB
        [Int] $PageFile_MB
    }

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"
        $MemoryObj = New-Object cMemory

        $MemoryObj.Memory_MB = 0
        $MemoryObj.PageFile_MB = 0

        $MemoryObj.Memory_MB = ((Get-WMIObject -ClassName Win32_ComputerSystem -ComputerName $ComputerName).TotalPhysicalMemory)/1MB

		$PageFiles = Get-WMIObject -ClassName Win32_PageFileUsage -ComputerName $ComputerName
		ForEach ($PageFile in $PageFiles)
		{
			$MemoryObj.PageFile_MB += $PageFile.AllocatedBaseSize
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
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Exception" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
    }
    finally
    {
        Write-Output $MemoryObj
    }
}