<#
.SYNOPSIS
Update-SQLOpServer

.DESCRIPTION 
Update-SQLOpServer server entry with its detail to SQLOpDB.

.PARAMETER ComputerName
Server Name

.PARAMETER OperatingSystem
Operating System Name

.PARAMETER ProcessorName
Processor Name Information

.PARAMETER NumberOfCores
Number of Physical Cores

.PARAMETER NumberOfLogicalCores
Number of Logical Cores

.PARAMETER IsPhysical
Bit Value for 1 = Physical, 0 = Virtual

.INPUTS
None

.OUTPUTS
Server Details

.EXAMPLE
Update-SQLOpServer -ComputerName ContosSQL

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2015.08.10 1.00.00 Initial Version
2020.03.12 2.00.00 Rewrite to match new standards.
                   Updated parameter name, added additional parameters.
                   Updated to handle FQDN.
                   Updated for JSON parameters.
                   Updated function name.
                   Added alias for computer name.
#>
function Update-SQLOpServer
{
 
    [CmdletBinding()] 
    param( 
    [Alias('ServerName','Computer','Server')]
    [Parameter(Position=0, Mandatory=$true)] [string]$ComputerName,
    [Parameter(Position=1, Mandatory=$true)] [string]$OperatingSystem,
    [Parameter(Position=2, Mandatory=$true)] [string]$ProcessorName,
    [Parameter(Position=3, Mandatory=$true)] [int]$NumberOfCores,
    [Parameter(Position=4, Mandatory=$true)] [int]$NumberOfLogicalCores,
    [Parameter(Position=5, Mandatory=$true)] [int]$IsPhysical,
    [Parameter(Position=6, Mandatory=$false, DontShow)] [switch]$Internal
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Update-SQLOpServer'
    $ModuleVersion = '2.00.00'
    $ModuleLastUpdated = 'March 12, 2020'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        # Check and validate the server does exist before we try an update.
        $ServerObj = Get-SQLOpServer -ComputerName $ComputerName
        if ($ServerObj -eq $Global:Error_FailedToComplete)
        {   # Something went wrong in Get-SQLOpServer call, we cannot proceed in the collection.
            Write-Output $Global:Error_FailedToComplete
            return
        }
        elseif ($ServerObj -eq $Global:Error_ObjectsNotFound)
        {
            Write-Output $Global:Error_ObjectsNotFound
            return
        }
        
        $OSObj = Get-SQLOpOperatingSystem -OperatingSystem $OperatingSystem -Internal
        if ($OSObj -eq $Global:Error_FailedToComplete)
        {   # We do not need to do additional reporting as Get-SQLOpOperatingSystem should have reported the error.
            Write-Output $Global:Error_FailedToComplete
            return
        }
        elseif ($OSObj -eq $Global:Error_ObjectsNotFound)
        {
            # New Operating System Discovered Add It
            $Results = Add-SQLOpOperatingSystem -OperatingSystem $OperatingSystem

            if ($Results -eq $Global:Error_Successful)
            {
                $OSObj = Get-SQLOpOperatingSystem -OperatingSystem $OperatingSystem -Internal
            }
            else
            {
                Write-Output $Global:Error_FailedToComplete
                return
            }
        }

        $OperatingSystemID = $OSObj.OperatingSystemID

        # Splits the Computer Name into parts Computer Name and Domain Name.
        $CompObj = Split-Parts -ComputerName $ComputerName
        $TSQL = "UPDATE dbo.Servers
                    SET LastUpdated = CAST(GETDATE() AS DATE),
                  OperatingSystemID = $OperatingSystemID,
                      ProcessorName = '$ProcessorName',
               NumberOfLogicalCores = $NumberOfLogicalCores,
                      NumberOfCores = $NumberOfCores,
                         IsPhysical = $IsPhysical WHERE ServerName = '$($CompObj.ComputerName)'"

        Write-StatusUpdate -Message $TSQL -IsTSQL

        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                      -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                      -Query $TSQL `
                      -ErrorAction Stop

        Write-Output $Global:Error_Successful
    }
    catch [System.Data.SqlClient.SqlException]
    {
        if ($($_.Exception.Message) -like '*Could not open a connection to SQL Server*')
        {
            Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Cannot connect to SQLOpsDB." -WriteToDB
        }
        else
        {
            Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - SQL Expectation" -WriteToDB
            Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        }
        Write-Output $Global:Error_FailedToComplete
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expectation" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}