<#
.SYNOPSIS
Get-SIServerPermission

.DESCRIPTION 
Get-SIServerPermission get list of all explicit permissions defined on the server.

.PARAMETER ServerInstance
Server instance from which to capture permission detail.

.INPUTS
None

.OUTPUTS
All logins and their respective permissions.

.EXAMPLE
Get-SIServerPermission -ServerInstance ContosSQL

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2022.11.02 0.00.01 Initial Version
#>
function Get-SIServerPermission
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
    
    $ModuleName = 'Get-SIServerPermission'
    $ModuleVersion = '0.00.01'
    $ModuleLastUpdated = 'November 2, 2022'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

		$SQLInstanceObj = Get-SQLOpSQLInstance -ServerInstance $ServerInstance -Internal
		$ProcessID = $pid

		$TSQL = "SELECT $(IF ($Internal) { "$ProcessID AS ProcessID, " })
						$(IF ($Internal) { "$($SQLInstanceObj.SQLInstanceID) AS InstanceID, " })
						'$ServerInstance' AS ServerInstance,SP.name AS GranteeName,       
						SGP.name AS GrantorName,
						SP.type_desc AS GranteeType,
						SGP.type_desc AS GrantorType,
						PE.class_desc AS ObjectType,
						PE.major_id AS ObjectID,
						PE.state_desc AS Access,
						PE.permission_name AS PermissionName
				FROM sys.server_principals SP
				JOIN sys.server_permissions PE 
					ON PE.grantee_principal_id = SP.principal_id
				JOIN sys.server_principals SGP
					ON PE.grantor_principal_id = SGP.principal_id
				WHERE SP.name NOT IN ('sa','public','##MS_SQLResourceSigningCertificate##','##MS_SQLReplicationSigningCertificate##',
										'##MS_SQLAuthenticatorCertificate##','##MS_PolicySigningCertificate##','##MS_SmoExtendedSigningCertificate##',
										'##MS_PolicyTsqlExecutionLogin##','NT AUTHORITY\SYSTEM','NT SERVICE\SQLSERVERAGENT','NT SERVICE\ReportServer',
										'NT Service\MSSQLSERVER','NT SERVICE\SQLWriter','NT SERVICE\Winmgmt','##MS_AgentSigningCertificate##',
										'##MS_PolicyEventProcessingLogin##','NT SERVICE\SQLTELEMETRY','NT Service\HealthService','##MS_SSISServerCleanupJobLogin##')
					AND SP.name NOT LIKE 'NT SERVICE\MSSQL$%'
					AND SP.name NOT LIKE 'NT SERVICE\SQLAGENT$%'
					AND PE.permission_name NOT IN ('AUTHENTICATE SERVER','CONNECT SQL','CONNECT')"		

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