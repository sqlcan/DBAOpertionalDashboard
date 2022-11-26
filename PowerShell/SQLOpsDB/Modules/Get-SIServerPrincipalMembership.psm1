<#
.SYNOPSIS
Get-SIServerPrincipalMembership

.DESCRIPTION 
Get-SIServerPrincipalMembership get list of all server logins and their membership.

.PARAMETER ServerInstance
Server instance from which to capture principal memberships.

.INPUTS
None

.OUTPUTS
All logins and their respective memberships.

.EXAMPLE
Get-SIServerPrincipalMembership -ServerInstance ContosSQL

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2022.11.02 0.00.01 Initial Version
2022.11.25 0.00.02 Fixing cases with aliase names for case sensetive.
#>
function Get-SIServerPrincipalMembership
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
    
    $ModuleName = 'Get-SIServerPrincipalMembership'
    $ModuleVersion = '0.00.02'
    $ModuleLastUpdated = 'November 25, 2022'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

		$SQLInstanceObj = Get-SQLOpSQLInstance -ServerInstance $ServerInstance -Internal
		$ProcessID = $pid

		$TSQL = "WITH CTE AS (
					SELECT 'public' as RoleName, name as LoginName, type_desc AS LoginType
					FROM sys.server_principals 
					WHERE type <> 'R'
					UNION ALL
					SELECT SR.name AS RoleName, SP.name AS LoginName, SP.type_desc AS LoginType
						FROM sys.server_principals SR
						JOIN sys.server_role_members SRM
						ON SR.principal_id = SRM.role_principal_id                                   
						JOIN sys.server_principals SP
						ON SP.principal_id = SRM.member_principal_id                                 
						WHERE SR.type = 'R'                                                           
						AND SP.principal_id <> 1)
					SELECT $(IF ($Internal) { "$ProcessID AS ProcessID, " })
					       $(IF ($Internal) { "$($SQLInstanceObj.SQLInstanceID) AS InstanceID, " })
					       '$ServerInstance' AS ServerInstance,
					       *
					  FROM CTE
					  WHERE LoginName NOT IN ('sa','public','##MS_SQLResourceSigningCertificate##','##MS_SQLReplicationSigningCertificate##',
					  					'##MS_SQLAuthenticatorCertificate##','##MS_PolicySigningCertificate##','##MS_SmoExtendedSigningCertificate##',
										'##MS_PolicyTsqlExecutionLogin##','NT AUTHORITY\SYSTEM','NT SERVICE\SQLSERVERAGENT','NT SERVICE\ReportServer',
										'NT Service\MSSQLSERVER','NT SERVICE\SQLWriter','NT SERVICE\Winmgmt','##MS_AgentSigningCertificate##',
										'##MS_PolicyEventProcessingLogin##','NT SERVICE\SQLTELEMETRY','NT SERVICE\PowerBIReportServer','NT Service\HealthService',
										'##MS_SSISServerCleanupJobLogin##')
					    AND LoginName NOT LIKE 'NT SERVICE\MSSQL$%'
					    AND LoginName NOT LIKE 'NT SERVICE\SQLAGENT$%'"		
		

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