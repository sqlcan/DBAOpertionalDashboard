<#
.SYNOPSIS
Get-SIServerRole

.DESCRIPTION 
Get-SIServerRole get list of all server roles.

.PARAMETER ServerInstance
Server instance from which to capture server role information.

.INPUTS
None

.OUTPUTS
All server role information

.EXAMPLE
Get-SIServerRole -ServerInstance ContosSQL

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2022.11.02 0.00.01 Initial Version
#>
function Get-SIServerRole
{
    param( 
    [Parameter(Mandatory=$true)][string]$ServerInstance,
    [Parameter(Mandatory=$false, DontShow)] [Switch]$Internal
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Get-SIServerRole'
    $ModuleVersion = '0.00.01'
    $ModuleLastUpdated = 'October 31, 2022'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

		$SQLInstanceObj = Get-SQLOpSQLInstance -ServerInstance $ServerInstance -Internal
		$ProcessID = $pid

		$TSQL = "   SELECT $(IF ($Internal) { "$ProcessID AS ProcessID, " })
					       $(IF ($Internal) { "$($SQLInstanceObj.SQLInstanceID) AS InstanceID, " })
					       '$ServerInstance' AS ServerInstance,
					       name AS RoleName, type_desc AS RoleType
  					  FROM sys.server_principals 
 					 WHERE type = 'R'"		
		

		Write-StatusUpdate -Message $TSQL -IsTSQL                    
		$Results = Invoke-SQLCMD -ServerInstance $ServerInstance `
									-Database 'master' `
									-Query $TSQL -ErrorAction Stop
        Write-Output $Results
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