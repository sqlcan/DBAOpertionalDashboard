<#
.SYNOPSIS
Get-SIDatabaseRole

.DESCRIPTION 
Get-SIDatabaseRole all distinct set of database role that exist on an
instance.

.PARAMETER ServerInstance
Server instance from which to capture the database role list.

.INPUTS
None

.OUTPUTS
List of all the database roles.

.EXAMPLE
Get-SIDatabaseRole -ServerInstance ContosSQL

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2022.11.02 0.00.01 Initial Version
2022.11.25 0.00.02 Fixing sp_MSforeachdb case to handle case senstive servers.
2022.11.25 0.00.03 sp_MSforeachdb was only executing against master db.
#>
function Get-SIDatabaseRole
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
    
    $ModuleName = 'Get-SIDatabaseRole'
    $ModuleVersion = '0.00.03'
    $ModuleLastUpdated = 'November 28, 2022'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

		$SQLInstanceObj = Get-SQLOpSQLInstance -ServerInstance $ServerInstance -Internal
		$ProcessID = $pid

		$TSQL = "CREATE TABLE #DatabaseRoles (RoleName VARCHAR(255), RoleType VARCHAR(255))

				INSERT INTO #DatabaseRoles (RoleName, RoleType)
				EXEC sp_MSforeachdb 'SELECT name AS RoleName, type_desc As RoleType FROM [?].sys.database_principals WHERE type = ''R'''
				
				SELECT DISTINCT $(IF ($Internal) { "$ProcessID AS ProcessID, " })
				$(IF ($Internal) { "$($SQLInstanceObj.SQLInstanceID) AS InstanceID, " })
				'$ServerInstance' AS ServerInstance,
				RoleName, RoleType
				FROM #DatabaseRoles"		
		
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
            Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - SQL Exception" -WriteToDB
            Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        }
        Write-Output $Global:Error_FailedToComplete
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Exception" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}