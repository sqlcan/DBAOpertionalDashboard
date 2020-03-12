<#
.SYNOPSIS
Add-SQLOpOperatingSystem

.DESCRIPTION 
Add-SQLOpOperatingSystem register a new operating system in SQLOpsDB.

.PARAMETER OperatingSystem
Get details about an operating system.

.INPUTS
None

.OUTPUTS
Server Details

.EXAMPLE
Add-SQLOpOperatingSystem -OperatingSystem "Windows Server 2008"

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2020.03.12 0.00.01 Initial Version
#>

function Add-SQLOpOperatingSystem
{ 
    [CmdletBinding()] 
    param( 
        [Alias('OS','OSName','Name')]
        [Parameter(Mandatory=$true)] [string] $OperatingSystem
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Add-SQLOpOperatingSystem'
    $ModuleVersion = '0.00.01'
    $ModuleLastUpdated = 'March 12, 2020'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"


        $OSObj = Get-SQLOpOperatingSystem -OperatingSystem $OperatingSystem

        if ($OSObj -eq $Global:Error_FailedToComplete)
        {
            Write-Output $Global:Error_FailedToComplete
            return
        }
        elseif (!($OSObj -eq $Global:Error_ObjectsNotFound))
        {
            Write-Output $Global:Error_Duplicate
            return
        }

        $TSQL = "INSERT INTO dbo.OperatingSystems (OperatingSystemName)
                      VALUES ('$OperatingSystem')"           
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