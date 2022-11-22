<#
.SYNOPSIS
Update-SQLOpServerPrincipalMembership

.DESCRIPTION 
Update-SQLOpServerPrincipalMembership has following purpose.
1) Update list of server principals with distinct list of logins.
2) Update principal to role membership.


.PARAMETER ServerInstance
SQL Server instance name for which the server roles & logins are being updated.

.PARAMETER Data
Role data from Get-SIServerPrincipalMembership.

.INPUTS
None

.OUTPUTS
Nothing.

.EXAMPLE
Update-SQLOpServerPrincipalMembership -ServerInstance Contoso -Data $Data

.NOTES
Date        Version Comments
----------  ------- ------------------------------------------------------------------
2020.11.02  0.00.01 Initial version.
#>
function Update-SQLOpServerPrincipalMembership
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
    
    $ModuleName = 'Update-SQLOpServerPrincipalMembership'
    $ModuleVersion = '0.01'
    $ModuleLastUpdated = 'November 2, 2022'

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

        $TSQL = "EXEC Staging.TableUpdates @TableName=N'ServerPrincipalMembership', @ModuleVersion=N'$ModuleVersion'"	
        Write-StatusUpdate -Message $TSQL -IsTSQL

        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                      -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                      -Query $TSQL

        # Load the Staging table we just created.
        Write-SqlTableData -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
        				   -DatabaseName $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
        				   -TableName ServerPrincipalMembership `
        				   -SchemaName Staging `
        				   -InputData $Data

		$ProcessID = $PID

        $TSQL = "MERGE Security.ServerPrincipal AS Target
                USING (SELECT DISTINCT LoginName, LoginType FROM Staging.ServerPrincipalMembership WHERE ProcessID = $ProcessID) AS Source (LoginName, LoginType)
                ON (Target.PrincipalName = Source.LoginName AND Target.PrincipalType=Source.LoginType)
                WHEN NOT MATCHED THEN
                    INSERT (PrincipalName, PrincipalType)
                    VALUES (Source.LoginName, Source.LoginType);"

        Write-StatusUpdate -Message $TSQL -IsTSQL

        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                      -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                      -Query $TSQL

		$TSQL = "MERGE Security.ServerPrincipalMembership AS TARGET
		         USING (SELECT SPM.SQLInstanceID, RoleP.PrincipalID AS ServerRoleID, LoginP.PrincipalID AS ServerLoginID
						FROM Staging.ServerPrincipalMembership SPM
					LEFT JOIN Security.ServerPrincipal RoleP
						ON SPM.RoleName = RoleP.PrincipalName
						AND RoleP.PrincipalType = 'SERVER_ROLE'
					LEFT JOIN Security.ServerPrincipal LoginP
						ON SPM.LoginName = LoginP.PrincipalName
						AND SPM.LoginType = LoginP.PrincipalType
					WHERE ProcessID = $ProcessID) AS Source (SQLInstanceID, ServerRoleID, ServerLoginID)
					ON (Target.SQLInstanceID = Source.SQLInstanceID AND Target.ServerRoleID = Source.ServerRoleID AND Target.ServerLoginID = Source.ServerLoginID AND Target.IsArchived = 0)
					WHEN MATCHED THEN
						UPDATE SET LastUpdated = GETDATE()
					WHEN NOT MATCHED THEN
						INSERT (SQLInstanceID, ServerRoleID, ServerLoginID) VALUES (Source.SQLInstanceID, Source.ServerRoleID, Source.ServerLoginID);
								   
					UPDATE Security.ServerPrincipalMembership
					   SET IsArchived = 1
					 WHERE IsArchived = 0
					   AND LastUpdated < CAST(GETDATE() AS DATE)"
		Write-StatusUpdate -Message $TSQL -IsTSQL

		Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
						-Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
						-Query $TSQL

		$TSQL = "DELETE FROM Staging.ServerPrincipalMembership WHERE ProcessID = $ProcessID"
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