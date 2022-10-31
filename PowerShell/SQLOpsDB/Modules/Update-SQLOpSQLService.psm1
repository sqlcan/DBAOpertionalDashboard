<#
.SYNOPSIS
Update-SQLOpSQLService

.DESCRIPTION 
Update-SQLOpSQLService

.PARAMETER ComputerName
Target server name.

.PARAMETER Data
Result set from Get-SISQLService

.INPUTS
None

.OUTPUTS
Update-SQLOpSQLService

.EXAMPLE
PowerShell Command Let

Description

.NOTES
Date       Version  Comments
---------- -------- ------------------------------------------------------------------
2020.02.05 00.00.01 Initial Version
2020.03.06 00.00.02 Saved the services current status.
2020.03.12 00.00.03 Updated reference to Get-SQLOpServer vs Get-Server.
2021.11.28 00.00.04 Command-let name updated Update-SQLOpSQLService.
		   00.00.05 Added multiple execution possiblity by allowing SQL Services to be
		            saved per PowerShell process ID.
2022.10.29 00.00.08 Added post excution cleanup of staging table.
					Fixed a minor bug on how table name is checked for staging table.
					Re-wrote how the staging tables are checked and recreated based
					 on extended events properties against command let version.
2022.10.31 00.00.09 The service start mode is updated if service already exists.
#>
function Update-SQLOpSQLService
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ComputerName,
    [Parameter(Position=1, Mandatory=$true)] $Data
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Update-SQLOpSQLService'
    $ModuleVersion = '00.00.09'
    $ModuleLastUpdated = 'October 31, 2022'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        # Validate server exists.
        $Server = Get-SQLOpServer -ServerName $ComputerName

        IF ($Server -eq $Global:Error_ObjectsNotFound)
        {
            Write-StatusUpdate "Failed to find server [$ComputerName] in SQLOpsDB." -WriteToDB
            Write-Output $Global:Error_FailedToComplete
            return
        }

        # Validate data is for SQL Services.
        ForEach ($DataRow in $Data)
        {
            $TypeName = $DataRow.GetType().Name
            if ($TypeName -ne 'SQLServices')
            {
                Write-StatusUpdate "Invalid data set provided.  The results must be from Get-SISQLService. Expecting SQLServices, received [$TypeName]."
                Write-Output $Global:Error_FailedToComplete
                return
            }
        }

        # Create a staging table to store the results.  Using staging table, we can do batch process.
        # Other option would be row-by-row operation.

		$ProcessID = $pid

        $TSQL = "EXEC Staging.TableUpdates @TableName =N'SQLServiceDetails', @ModuleVersion=N'$ModuleVersion'"
        Write-StatusUpdate -Message $TSQL -IsTSQL

        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                      -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                      -Query $TSQL

        # Load the Staging table we just created.
        Write-SqlTableData -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                           -DatabaseName $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                           -TableName SQLServiceDetails `
                           -SchemaName Staging `
                           -InputData $Data

        # Take the data just loaded an either insert data into dbo.SQLServices or update it.

        $TSQL = "MERGE dbo.SQLService AS Target
        USING
        (SELECT S.ServerID, ServiceName, InstanceName, DisplayName,
                FilePath, ServiceType, StartMode, ServiceAccount,
                ServiceVersion, ServiceBuild, Status
          FROM Staging.SQLServiceDetails SSS
          JOIN dbo.Servers S
            ON SSS.ServerName = S.ServerName
		 WHERE ProcessID = $ProcessID) AS Source (ServerID, ServiceName, InstanceName, DisplayName,
                FilePath, ServiceType, StartMode, ServiceAccount,
                ServiceVersion, ServiceBuild, Status)
            ON (Target.ServerID = Source.ServerID and Target.ServiceName = Source.ServiceName)
        WHEN MATCHED THEN
            UPDATE SET LastUpdated = GETDATE(),
                       ServiceAccount = Source.ServiceAccount,
                       ServiceVersion = Source.ServiceVersion,
                       ServiceBuild = Source.ServiceBuild,
                       Status = Source.Status,
					   StartMode = Source.StartMode
        WHEN NOT MATCHED THEN
            INSERT (ServerID, ServiceName, InstanceName, DisplayName,
                FilePath, ServiceType, StartMode, ServiceAccount,
                ServiceVersion, ServiceBuild, Status)
        VALUES (Source.ServerID, Source.ServiceName, Source.InstanceName, Source.DisplayName,
                Source.FilePath, Source.ServiceType, Source.StartMode, Source.ServiceAccount,
                Source.ServiceVersion, Source.ServiceBuild, Source.Status);"

        Write-StatusUpdate -Message $TSQL -IsTSQL

        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                        -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                        -Query $TSQL
        
		$TSQL = "DELETE FROM Staging.SQLServiceDetails WHERE ProcessID = $ProcessID"
		Write-StatusUpdate -Message $TSQL -IsTSQL

        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                        -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                        -Query $TSQL

        Write-Output $Global:Error_Successful
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expectation" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}