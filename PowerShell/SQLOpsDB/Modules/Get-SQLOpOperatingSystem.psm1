<#
.SYNOPSIS
Get-SQLOpOperatingSystem

.DESCRIPTION 
Get-SQLOpOperatingSystem returns details about operating systems registered in SQLOpsDB.

.PARAMETER ListAvailable
Provide list of all operating systems registered in SQLOpsDB.

.PARAMETER OperatingSystem
Get details about an operating system.

.PARAMETER Internal
If the internal ID parameter is required for additional work.

.INPUTS
None

.OUTPUTS
Server Details

.EXAMPLE
Get-SQLOpOperatingSystem -OperatingSystem "Windows Server 2008"

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2020.03.12 0.00.01 Initial Version
#>

function Get-SQLOpOperatingSystem
{ 
    [CmdletBinding(DefaultParameterSetName='List')] 
    param( 
        [Alias('List','All')]
        [Parameter(ParameterSetName='List', Mandatory=$false)] [switch] $ListAvailable,
        [Alias('OS','OSName','Name')]
        [Parameter(ParameterSetName='OperatingSystem', Mandatory=$true)] [string]        
        [Parameter(ParameterSetName='Internal', Mandatory=$true)] $OperatingSystem,
        [Parameter(ParameterSetName='Internal', Mandatory=$true, DontShow)] [Switch]$Internal
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    if (($PSCmdlet.ParameterSetName -eq 'List') -and (!($PSBoundParameters.ListAvailable)))
    {
        $ListAvailable = $true
    }

    $ModuleName = 'Get-SQLOpOperatingSystem'
    $ModuleVersion = '0.00.01'
    $ModuleLastUpdated = 'March 12, 2020'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        if ($Internal)
        {
            $TSQL = "SELECT OperatingSystemID, OperatingSystemName
                       FROM dbo.OperatingSystems "
        }
        else {
            $TSQL = "SELECT OperatingSystemName
                       FROM dbo.OperatingSystems "
        }

        if (!($ListAvailable))
        {
            $TSQL += "WHERE OperatingSystemName = '$OperatingSystem'"
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