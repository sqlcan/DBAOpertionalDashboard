<#
.SYNOPSIS
Update-SQLOpDatabasePermission

.DESCRIPTION 
Update-SQLOpDatabasePermission save all explicit permissions.


.PARAMETER ServerInstance
SQL Server instance name for which save explicit permissions for.

.PARAMETER Data
Permissions data from Get-SIDatabasePermission.

.INPUTS
None

.OUTPUTS
Nothing.

.EXAMPLE
Update-SQLOpDatabasePermission -ServerInstance Contoso -Data $Data

.NOTES
Date        Version Comments
----------  ------- ------------------------------------------------------------------
2020.11.03  0.00.01 Initial version.
#>
function Update-SQLOpDatabasePermission
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
    
    $ModuleName = 'Update-SQLOpDatabasePermission'
    $ModuleVersion = '0.01'
    $ModuleLastUpdated = 'November 3, 2022'

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

        $TSQL = "EXEC Staging.TableUpdates @TableName=N'DatabasePermission', @ModuleVersion=N'$ModuleVersion'"	
        Write-StatusUpdate -Message $TSQL -IsTSQL

        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                      -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                      -Query $TSQL

        # Load the Staging table we just created.
        Write-SqlTableData -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
        				   -DatabaseName $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
        				   -TableName DatabasePermission `
        				   -SchemaName Staging `
        				   -InputData $Data

		$ProcessID = $PID

		$TSQL = "MERGE Security.DatabasePermission AS TARGET
				USING (SELECT DP.SQLInstanceID, DatabaseID, GranteeSP.PrincipalID AS GranteeID, GrantorSP.PrincipalID AS GrantorID,
								ObjectType, ObjectName, Access, PermissionName
							FROM Staging.DatabasePermission DP
					LEFT JOIN Security.DatabasePrincipal GranteeSP
							ON DP.GranteeName = GranteeSP.PrincipalName
							AND DP.GranteeType = GranteeSP.PrincipalType
					LEFT JOIN Security.DatabasePrincipal GrantorSP
							ON DP.GrantorName = GrantorSP.PrincipalName
							AND DP.GrantorType = GrantorSP.PrincipalType
					LEFT JOIN dbo.Databases D
							ON D.DatabaseName = DP.DatabaseName
							AND D.SQLInstanceID = DP.SQLInstanceID
				WHERE ProcessID = $ProcessID) AS Source (SQLInstanceID, DatabaseID, GranteeID, GrantorID, ObjectType, ObjectName, Access, PermissionName)
				ON (Target.DatabaseID = Source.DatabaseID AND 
					Target.GranteeID = Source.GranteeID AND 
					Target.GrantorID = Source.GrantorID AND
					Target.ObjectType = Source.ObjectType AND
					Target.ObjectName = Source.ObjectName AND
					Target.Access = Source.Access AND
					Target.PermissionName = Source.PermissionName AND
					Target.IsArchived = 0)
				WHEN MATCHED THEN
					UPDATE SET LastUpdated = GETDATE()
				WHEN NOT MATCHED THEN
					INSERT (DatabaseID, GranteeID, GrantorID, ObjectType, ObjectName, Access, PermissionName) 
					VALUES (Source.DatabaseID, Source.GranteeID, Source.GrantorID, Source.ObjectType, Source.ObjectName, Source.Access, Source.PermissionName);

				 UPDATE Security.DatabasePermission
					SET IsArchived = 1
				  WHERE IsArchived = 0
					AND LastUpdated < CAST(GETDATE() AS DATE)"

		Write-StatusUpdate -Message $TSQL -IsTSQL

		Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
						-Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
						-Query $TSQL

		$TSQL = "DELETE FROM Staging.DatabasePermission WHERE ProcessID = $ProcessID"
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