<#
.SYNOPSIS
Get-SISQLVolumeDetails

.DESCRIPTION 
Get-SISQLVolumeDetails return information for location of data, log, and
backup directories.

.PARAMETER ServerInstance
Server instance from which to capture the information.

.INPUTS
None

.OUTPUTS
[System.Data.DataRow] .NET Object

.EXAMPLE
Get-SISQLVolumeDetails -ServerInstance ContosSQL

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2020.03.14 0.00.01 Initial Version
#>
function Get-SISQLVolumeDetails
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string] $ServerInstance
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Get-SISQLVolumeDetails'
    $ModuleVersion = '0.00.01'
    $ModuleLastUpdated = 'March 14, 2020'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        $TSQL = "SELECT DISTINCT LOWER(SUBSTRING(physical_name,1,LEN(physical_name)-CHARINDEX('\',REVERSE(physical_name)))) AS FolderName FROM sys.master_files

        UNION ALL
        
        SELECT DISTINCT LOWER(SUBSTRING(physical_device_name,1,LEN(physical_device_name)-CHARINDEX('\',REVERSE(physical_device_name)))) AS FolderName
          FROM msdb.dbo.backupmediafamily
         WHERE physical_device_name <> 'nul:'"

        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-Sqlcmd -ServerInstance $ServerInstance `
                                 -Database 'msdb' `
                                 -Query $TSQL

        Write-Output $Results
    }
    catch [System.Data.SqlClient.SqlException]
    {
        if ($($_.Exception.Message) -like '*Could not open a connection to SQL Server*')
        {
            Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Cannot connect to SQL Instance." -WriteToDB
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