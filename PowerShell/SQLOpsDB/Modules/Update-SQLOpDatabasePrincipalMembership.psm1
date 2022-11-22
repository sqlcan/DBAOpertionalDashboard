<#
.SYNOPSIS
Update-SQLOpDatabasePrincipalMembership

.DESCRIPTION 
Update-SQLOpDatabasePrincipalMembership has following purpose.
1) Update list of database principals with distinct list of users.
2) Update principal to role membership.


.PARAMETER ServerInstance
SQL Server instance name for which the database roles & users are being updated.

.PARAMETER Data
Role data from Get-SIDatabasePrincipalMembership.

.INPUTS
None

.OUTPUTS
Nothing.

.EXAMPLE
Update-SQLOpDatabasePrincipalMembership -ServerInstance Contoso -Data $Data

.NOTES
Date        Version Comments
----------  ------- ------------------------------------------------------------------
2020.11.02  0.00.01 Initial version.
2022.11.17	0.00.02 Updated logic for passive AG replica that are not readable.
#>
function Update-SQLOpDatabasePrincipalMembership
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerInstance,
    [Parameter(Position=1, Mandatory=$true)] $Data
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Update-SQLOpDatabasePrincipalMembership'
    $ModuleVersion = '0.00.02'
    $ModuleLastUpdated = 'November 17, 2022'

    # Validate sql instance exists.
    $ServerInstanceObj = Get-SqlOpSQLInstance -ServerInstance $ServerInstance

    IF ($ServerInstanceObj -eq $Global:Error_ObjectsNotFound)
    {
        Write-StatusUpdate "Failed to find SQL Instance [$ServerInstance] in SQLOpsDB." -WriteToDB
        Write-Output $Global:Error_FailedToComplete
        return
    }

    try
    {

        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        # Create a staging table to store the results.  Using staging table, we can do batch process.
        # Other option would be row-by-row operation.

        $TSQL = "EXEC Staging.TableUpdates @TableName=N'DatabasePrincipalMembership', @ModuleVersion=N'$ModuleVersion'"	
        Write-StatusUpdate -Message $TSQL -IsTSQL

        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                      -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                      -Query $TSQL

        # Load the Staging table we just created.
        Write-SqlTableData -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
        				   -DatabaseName $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
        				   -TableName DatabasePrincipalMembership `
        				   -SchemaName Staging `
        				   -InputData $Data

		$ProcessID = $PID

        $TSQL = "MERGE Security.DatabasePrincipal AS Target
                USING (SELECT DISTINCT UserName, UserType FROM Staging.DatabasePrincipalMembership WHERE ProcessID = $ProcessID AND RoleName IS NOT NULL) AS Source (UserName, UserType)
                ON (Target.PrincipalName = Source.UserName AND Target.PrincipalType=Source.UserType)
                WHEN NOT MATCHED THEN
                    INSERT (PrincipalName, PrincipalType)
                    VALUES (Source.UserName, Source.UserType);"

        Write-StatusUpdate -Message $TSQL -IsTSQL

        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                      -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                      -Query $TSQL

		# The code segment has gotten a bit ugly to handle databases in Availability Group
		# 
		# Databases on passive instances do not get reported by the EXEC sp_MSForEachDB.  Therefore
		# these databases security records get marked archived.  When they "might" not be.
		#
		# Get-SIDatabasePrincipalMembership creates records for databses that are part of AG and secondary
		# replica that have no records in the security tables.
		#
		# Therefore if Staging.DatabasePrincipalMembership has null records for RoleName it means this
		# database is a secondary database that has allow readable secondary turned off.

		$TSQL = "MERGE Security.DatabasePrincipalMembership AS TARGET
		         USING (SELECT D.DatabaseID, RoleP.PrincipalID AS DatabaseRoleID, LoginP.PrincipalID AS DatabaseUserID, SPM.IsOrphaned
						FROM Staging.DatabasePrincipalMembership SPM
					LEFT JOIN Security.DatabasePrincipal RoleP
						ON SPM.RoleName = RoleP.PrincipalName
						AND RoleP.PrincipalType = 'DATABASE_ROLE'
					LEFT JOIN Security.DatabasePrincipal LoginP
						ON SPM.UserName = LoginP.PrincipalName
						AND SPM.UserType = LoginP.PrincipalType
                    LEFT JOIN dbo.Databases D
					    ON D.DatabaseName = SPM.DatabaseName
					   AND D.SQLInstanceID = SPM.SQLInstanceID
					WHERE ProcessID = $ProcessID
					  AND D.IsMonitored = 1
					  AND SPM.RoleName IS NOT NULL) AS Source (DatabaseID, DatabaseRoleID, DatabaseUserID,IsOrphaned)
					ON (Target.DatabaseID = Source.DatabaseID AND Target.DatabaseRoleID = Source.DatabaseRoleID AND Target.DatabaseUserID = Source.DatabaseUserID AND Target.IsArchived = 0)
					WHEN MATCHED THEN
						UPDATE SET LastUpdated = GETDATE(),
							       IsOrphaned = Source.IsOrphaned
					WHEN NOT MATCHED THEN
						INSERT (DatabaseID, DatabaseRoleID, DatabaseUserID, IsOrphaned) VALUES (Source.DatabaseID, Source.DatabaseRoleID, Source.DatabaseUserID, Source.IsOrphaned);

					 UPDATE Security.DatabasePrincipalMembership
						SET IsArchived = 1
					  WHERE IsArchived = 0
						AND LastUpdated < CAST(GETDATE() AS DATE)
						AND DatabaseID IN (SELECT DatabaseID FROM Staging.DatabasePrincipalMembership SPM JOIN dbo.Databases D
							ON D.DatabaseName = SPM.DatabaseName
							AND D.SQLInstanceID = SPM.SQLInstanceID
							WHERE SPM.RoleName IS NOT NULL)"
		Write-StatusUpdate -Message $TSQL -IsTSQL

		Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
						-Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
						-Query $TSQL

		$TSQL = "DELETE FROM Staging.DatabasePrincipalMembership WHERE ProcessID = $ProcessID"
		Write-StatusUpdate -Message $TSQL -IsTSQL
        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                    -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                    -Query $TSQL

        Write-Output $Global:Error_Successful
    }
    catch [System.Data.SqlClient.SqlException]
    {
        if ($($_.Exception.Message) -like '*Could not open a connection to SQL Server*')
        {
            Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Cannot connect to $ServerInstance." -WriteToDB
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