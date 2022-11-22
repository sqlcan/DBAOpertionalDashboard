<#
.SYNOPSIS
Get-SIProcessor

.DESCRIPTION 
Get-SIProcessor wrapper for Win32_Processor.  If unable to the information
it will default to Unknown processor name and zero cores.

.PARAMETER ComputerName
Server name for data collection.

.INPUTS
None

.OUTPUTS
[System.Object] Processor Name and total cores on the server.

.EXAMPLE
Get-SIProcessor -ComputerName ContosSQL

Return the current processor details.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2020.03.15 0.00.01 Initial Version
#>
function Get-SIProcessor
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
    
    $ModuleName = 'Get-SIProcessor'
    $ModuleVersion = '0.00.01'
    $ModuleLastUpdated = 'March 15, 2020'
    
    # Review: https://devblogs.microsoft.com/scripting/hey-scripting-guy-how-can-i-use-erroractionpreference-to-control-cmdlet-handling-of-errors/
    $ErrorActionPreference = 'Stop'

    class cProcessor {
        [String] $Name
        [Int] $NumberOfCores
        [Int] $NumberOfLogicalCores
    }

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"
        $ProcessorObj = New-Object cProcessor

        $ProcessorObj.Name = 'Unknown'
        $ProcessorObj.NumberOfCores = 0
        $ProcessorObj.NumberOfLogicalCores = 0

        $Processors = Get-WmiObject -Class Win32_Processor -ComputerName $ComputerName

        if ($Processors)
        {
            ForEach ($Processor IN $Processors)
            {
                $ProcessorObj.Name = $Processor.Name
                $ProcessorObj.NumberOfCores += $Processor.NumberOfCores
                $ProcessorObj.NumberOfLogicalCores += $Processor.NumberOfLogicalProcessors
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
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Exception" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
    }
    finally
    {
        Write-Output $ProcessorObj
    }
}