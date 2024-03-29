<#
.SYNOPSIS
Get-SIDatabasePermission

.DESCRIPTION 
Get-SIDatabasePermission get list of all explicit permissions defined on all the databases.

.PARAMETER ServerInstance
Server instance from which to capture permission detail.

.INPUTS
None

.OUTPUTS
All users and their respective permissions.

.EXAMPLE
Get-SIDatabasePermission -ServerInstance ContosSQL

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2022.11.03 0.00.01 Initial Version
2022.11.17 0.00.02 Updated logic for passive AG replica that are not readable.
2022.11.25 0.00.05 Return error if SQL instance is not found.
                   Check for SQL version before checking for passive replica on AG.
				   Fixing the case sp_MSforeachdb procedure call to handle case
				    senstive.
#>
function Get-SIDatabasePermission
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
    
    $ModuleName = 'Get-SIDatabasePermission'
    $ModuleVersion = '0.00.05'
    $ModuleLastUpdated = 'November 25, 2022'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

		$SQLInstanceObj = Get-SQLOpSQLInstance -ServerInstance $ServerInstance -Internal
		IF ($SQLInstanceObj -eq $Global:Error_ObjectsNotFound)
		{
			Write-StatusUpdate "Failed to find SQL Instance [$ServerInstance] in SQLOpsDB." -WriteToDB
			Write-Output $Global:Error_ObjectsNotFound
			return
		}
		$ProcessID = $pid

		$SQLProperties = Get-SQLOpSQLProperties -ServerInstance $ServerInstance

		$TSQL = "CREATE TABLE #DatabasePermissions (DatabaseName VARCHAR(255), GranteeName VARCHAR(255),
                                   GrantorName VARCHAR(255), GranteeType VARCHAR(50), GrantorType VARCHAR(50),
								   ObjectType VARCHAR(50), ObjectName VARCHAR(255), Access VARCHAR(50),
								   PermissionName VARCHAR(255))

				INSERT INTO #DatabasePermissions
				EXEC sp_MSforeachdb '
				SELECT ''?'' AS DatabaseName,
						DP.name AS GranteeName,
						DGP.name AS GrantorName,
						DP.type_desc AS GranteeType,
						DGP.type_desc AS GrantorType,
						PE.class_desc AS ObjectType,
						ISNULL(AO.name,''UNKNOWN'') AS ObjectName,
						PE.state_desc AS Access,
						PE.permission_name AS PermissionName
					FROM [?].sys.database_principals DP
					JOIN [?].sys.database_permissions PE 
					ON PE.grantee_principal_id = DP.principal_id
					JOIN [?].sys.database_principals DGP
					ON PE.grantor_principal_id = DGP.principal_id
				LEFT JOIN [?].sys.all_objects AO
					ON PE.major_id = AO.object_id
				WHERE DP.name NOT IN (''sa'',''##MS_SQLResourceSigningCertificate##'',''##MS_SQLReplicationSigningCertificate##'',
									''##MS_SQLAuthenticatorCertificate##'',''##MS_PolicySigningCertificate##'',''##MS_SmoExtendedSigningCertificate##'',
									''##MS_PolicyTsqlExecutionLogin##'',''NT AUTHORITY\SYSTEM'',''NT SERVICE\SQLSERVERAGENT'',''NT SERVICE\ReportServer'',
									''NT Service\MSSQLSERVER'',''NT SERVICE\SQLWriter'',''NT SERVICE\Winmgmt'',''dbo'',''##MS_AgentSigningCertificate##'',
									''##MS_PolicyEventProcessingLogin##'')
				AND DP.name NOT LIKE ''NT SERVICE\MSSQL$%''
				AND DP.name NOT LIKE ''NT SERVICE\SQLAGENT$%''
				AND PE.permission_name NOT IN (''CONNECT'')
				AND PE.major_id > 0
				AND (DP.principal_id IN (SELECT grantee_principal_id FROM sys.database_permissions WHERE permission_name = ''CONNECT'')
					OR  DP.principal_id IN (SELECT principal_id FROM sys.database_principals WHERE type = ''R''))
				AND DP.name NOT IN (''PolicyAdministratorRole'',''SQLAgentOperatorRole'',''PolicyAdministratorRole'',''UtilityIMRWriter'',''UtilityCMRReader'',
									''UtilityIMRReader'',''TargetServersRole'',''SQLAgentUserRole'',''dc_operator'',''dc_proxy'',''dc_admin'',''ServerGroupReaderRole'',
									''db_ssisadmin'',''db_ssisltduser'',''db_ssisoperator'',''ServerGroupAdministratorRole'',''DatabaseMailUserRole'',''RSExecRole'')'

				$(IF ($($SQLProperties.SQLBuild_Major) -ge 11)
				{"INSERT INTO #DatabasePermissions (DatabaseName)
				SELECT name AS DatabaseName
  				  FROM sys.databases d
  				  JOIN sys.dm_hadr_availability_replica_states rs
    				ON d.replica_id = rs.replica_id
 				 WHERE d.replica_id IS NOT NULL
   				   AND rs.role_desc = 'SECONDARY'
				   AND d.name NOT IN (SELECT DISTINCT DatabaseName FROM #DatabasePermissions)
				   AND d.name NOT IN ('master','model','msdb','SSISDB')"})

				SELECT $(IF ($Internal) { "$ProcessID AS ProcessID, " })
				$(IF ($Internal) { "$($SQLInstanceObj.SQLInstanceID) AS InstanceID, " })
				'$ServerInstance' AS ServerInstance, *
				FROM #DatabasePermissions
				WHERE DatabaseName NOT IN ('master','model','msdb','SSISDB')"

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