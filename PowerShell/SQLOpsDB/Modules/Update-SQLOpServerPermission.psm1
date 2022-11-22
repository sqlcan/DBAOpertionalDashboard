<#
.SYNOPSIS
Update-SQLOpServerPermission

.DESCRIPTION 
Update-SQLOpServerPermission save all explicit permissions.


.PARAMETER ServerInstance
SQL Server instance name for which save explicit permissions for.

.PARAMETER Data
Permissions data from Get-SIServerPermission.

.INPUTS
None

.OUTPUTS
Nothing.

.EXAMPLE
Update-SQLOpServerPermission -ServerInstance Contoso -Data $Data

.NOTES
Date        Version Comments
----------  ------- ------------------------------------------------------------------
2020.11.02  0.00.01 Initial version.
#>
function Update-SQLOpServerPermission
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
    
    $ModuleName = 'Update-SQLOpServerPermission'
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

        $TSQL = "EXEC Staging.TableUpdates @TableName=N'ServerPermission', @ModuleVersion=N'$ModuleVersion'"	
        Write-StatusUpdate -Message $TSQL -IsTSQL

        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                      -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                      -Query $TSQL

        # Load the Staging table we just created.
        Write-SqlTableData -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
        				   -DatabaseName $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
        				   -TableName ServerPermission `
        				   -SchemaName Staging `
        				   -InputData $Data

		$ProcessID = $PID

		$TSQL = "MERGE Security.ServerPermission AS TARGET
		         USING (SELECT SQLInstanceID, GranteeSP.PrincipalID AS GranteeID, GrantorSP.PrincipalID AS GrantorID,
									ObjectType, ObjectID, Access, PermissionName
								FROM Staging.ServerPermission SP
						LEFT JOIN Security.ServerPrincipal GranteeSP
								ON SP.GranteeName = GranteeSP.PrincipalName
								AND SP.GranteeType = GranteeSP.PrincipalType
						LEFT JOIN Security.ServerPrincipal GrantorSP
								ON SP.GrantorName = GrantorSP.PrincipalName
								AND SP.GranteeType = GrantorSP.PrincipalType
					WHERE ProcessID = $ProcessID) AS Source (SQLInstanceID, GranteeID, GrantorID, ObjectType, ObjectID, Access, PermissionName)
					ON (Target.SQLInstanceID = Source.SQLInstanceID AND 
					    Target.GranteeID = Source.GranteeID AND 
						Target.GrantorID = Source.GrantorID AND
						Target.ObjectType = Source.ObjectType AND
						Target.ObjectID = Source.ObjectID AND
						Target.Access = Source.Access AND
						Target.PermissionName = Source.PermissionName AND
						Target.IsArchived = 0)
					WHEN MATCHED THEN
						UPDATE SET LastUpdated = GETDATE()
					WHEN NOT MATCHED THEN
						INSERT (SQLInstanceID, GranteeID, GrantorID, ObjectType, ObjectID, Access, PermissionName) 
						VALUES (Source.SQLInstanceID, Source.GranteeID, Source.GrantorID, Source.ObjectType, Source.ObjectID, Source.Access, Source.PermissionName);

					UPDATE Security.ServerPermission
					   SET IsArchived = 1
					 WHERE IsArchived = 0
					   AND LastUpdated < CAST(GETDATE() AS DATE)"
		Write-StatusUpdate -Message $TSQL -IsTSQL

		Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
						-Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
						-Query $TSQL

		$TSQL = "DELETE FROM Staging.ServerPermission WHERE ProcessID = $ProcessID"
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