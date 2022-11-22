<#
.SYNOPSIS
Get-SIDatabasePrincipalMembership

.DESCRIPTION 
Get-SIDatabasePrincipalMembership get list of database principal and their memebership
details.

.PARAMETER ServerInstance
Server instance from which to capture server role information.
The command-let pulls list of all databases that are online.

.INPUTS
None

.OUTPUTS
All server role information

.EXAMPLE
Get-SIDatabasePrincipalMembership -ServerInstance ContosSQL

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2022.11.02 0.00.01 Initial Version
2022.11.17 0.00.02 Updated logic for passive AG replica that are not readable.
#>
function Get-SIDatabasePrincipalMembership
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
    
    $ModuleName = 'Get-SIDatabasePrincipalMembership'
    $ModuleVersion = '0.00.02'
    $ModuleLastUpdated = 'November 17, 2022'

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

		$TSQL = "CREATE TABLE #DatabaseMembership (DatabaseName VARCHAR(255), DatabaseRoleName VARCHAR(255), UserName VARCHAR(255), UserType VARCHAR(255), IsOrphaned bit)

				INSERT INTO #DatabaseMembership (DatabaseName, DatabaseRoleName, UserName, UserType, IsOrphaned)
				EXEC sp_MSForeachdb '
				SELECT  ''?'' AS DatabaseName
					, DR.name AS RoleName
					, DP.name AS PrincipalName
					, DP.type_desc AS PrincipalType
					, CASE WHEN (SP.name IS NULL) THEN 1 ELSE 0 END
				FROM [?].sys.database_principals DR
				JOIN [?].sys.database_role_members DRM
				ON DR.principal_id = DRM.role_principal_id
				JOIN [?].sys.database_principals DP
				ON DP.principal_id = DRM.member_principal_id
				LEFT JOIN sys.server_principals SP
				ON DP.sid = SP.sid
				WHERE DP.type IN (''U'',''S'', ''G'')
				
				UNION ALL
				
				SELECT  ''?'' AS DatabaseName
					, ''public'' AS RoleName
					, DP.name AS PrincipalName
					, DP.type_desc AS PrincipalType
					, CASE WHEN (SP.name IS NULL) THEN 1 ELSE 0 END
				FROM [?].sys.database_principals DP
				LEFT JOIN sys.server_principals SP
				ON DP.sid = SP.sid
				WHERE DP.type IN (''U'',''S'') 
				AND DP.name NOT IN (''sys'',''INFORMATION_SCHEMA'')'
				
				INSERT INTO #DatabaseMembership (DatabaseName)
				SELECT name AS DatabaseName
  				  FROM sys.databases d
  				  JOIN sys.dm_hadr_availability_replica_states rs
    				ON d.replica_id = rs.replica_id
 				 WHERE d.replica_id IS NOT NULL
   				   AND rs.role_desc = 'SECONDARY'
				   AND d.name NOT IN (SELECT DISTINCT DatabaseName FROM #DatabaseMembership)
				   AND d.name NOT IN ('master','model','msdb','SSISDB')		

				  SELECT $(IF ($Internal) { "$ProcessID AS ProcessID, " })
						 $(IF ($Internal) { "$($SQLInstanceObj.SQLInstanceID) AS InstanceID, " })
						 '$ServerInstance' AS ServerInstance, *
					FROM #DatabaseMembership
				WHERE ((UserName NOT IN ('sa','public','##MS_SQLResourceSigningCertificate##','##MS_SQLReplicationSigningCertificate##',
										'##MS_SQLAuthenticatorCertificate##','##MS_PolicySigningCertificate##','##MS_SmoExtendedSigningCertificate##',
										'##MS_PolicyTsqlExecutionLogin##','NT AUTHORITY\SYSTEM','NT SERVICE\SQLSERVERAGENT','NT SERVICE\ReportServer',
										'NT Service\MSSQLSERVER','NT SERVICE\SQLWriter','NT SERVICE\Winmgmt','##MS_AgentSigningCertificate##',
										'##MS_PolicyEventProcessingLogin##','NT SERVICE\SQLTELEMETRY','NT SERVICE\PowerBIReportServer','NT Service\HealthService',
										'##MS_SSISServerCleanupJobLogin##','##MS_SSISServerCleanupJobUser##','MS_DataCollectorInternalUser',
										'AllSchemaOwner')
					AND UserName NOT LIKE 'NT SERVICE\MSSQL$%'
					AND UserName NOT LIKE 'NT SERVICE\SQLAGENT$%')
					OR (UserName IS NULL))
					AND DatabaseName NOT IN ('master','model','msdb','SSISDB')"		
		

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