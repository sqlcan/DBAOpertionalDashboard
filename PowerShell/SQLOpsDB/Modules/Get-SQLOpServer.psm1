<#
.SYNOPSIS
Get-SQLOpServer

.DESCRIPTION 
Get-SQLOpServer returns details about server from SQLOpDB.

.PARAMETER ComputerName
Computer for which information is required.

.PARAMETER Internal
If the internal ID parameter is required for additional work.

.INPUTS
None

.OUTPUTS
Server Details

.EXAMPLE
Get-SQLOpServer -ComputerName ContosSQL


.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2015.08.10 1.00.00 Initial Version
2020.03.12 2.00.00 Rewrite to match new standards.
                   Updated parameter name, added additional parameters.
                   Updated to handle FQDN.
                   Updated for JSON parameters.
                   Updated function name.
                   Added alias for parameter ComputerName.
           2.00.01 Exposed Operating system details.
           2.00.02 Added ability to return full server list.
2022.10.31 2.00.04 Added support to return current memory and page file size info.
#>

function Get-SQLOpServer
{ 
    [CmdletBinding(DefaultParameterSetName='List')] 
    param(
    [Alias('List','All')]
    [Parameter(ParameterSetName='List', Mandatory=$false)] [switch] $ListAvailable, 
    [Alias('ServerName','Computer','Server')]
    [Parameter(ParameterSetName='ComputerName', Position=0, Mandatory=$true)]
    [Parameter(ParameterSetName='Internal', Position=0, Mandatory=$true)] [string]$ComputerName,
    [Parameter(ParameterSetName='Internal', Mandatory=$true, DontShow)] [Switch]$Internal
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Get-SQLOpServer'
    $ModuleVersion = '2.00.04'
    $ModuleLastUpdated = 'October 31, 2022'

    if (($PSCmdlet.ParameterSetName -eq 'List') -and (!($PSBoundParameters.ListAvailable)))
    {
        $ListAvailable = $true
    }

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"        

        if ($Internal)
        {
            $TSQL = "SELECT S.ServerID, ServerName AS ComputerName, OS.OperatingSystemName, ProcessorName,
                            NumberOfCores, NumberOfLogicalCores, Memory_mb, PageFile_mb, IsMonitored, DiscoveryOn, LastUpdated
                       FROM dbo.Servers S
                       JOIN dbo.OperatingSystems OS ON S.OperatingSystemID = OS.OperatingSystemID "
        }
        else {
            $TSQL = "SELECT ServerName AS ComputerName, OS.OperatingSystemName, ProcessorName,
                            NumberOfCores, NumberOfLogicalCores, Memory_mb, PageFile_mb, IsMonitored, DiscoveryOn, LastUpdated
                       FROM dbo.Servers S
                       JOIN dbo.OperatingSystems OS ON S.OperatingSystemID = OS.OperatingSystemID "
        }
        
        if (!($ListAvailable))
        {
            $CompObj = Split-Parts -ComputerName $ComputerName
            $TSQL += "WHERE ServerName = '$($CompObj.ComputerName)'"
        }
        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                                 -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                                 -Query $TSQL `
                                 -ErrorAction Stop

        if (!($Results))
        {
            Write-Output $Global:Error_ObjectsNotFound
        }
        else
        {
            Write-Output $Results
        }
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