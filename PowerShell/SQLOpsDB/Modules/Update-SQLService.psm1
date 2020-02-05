<#
.SYNOPSIS
Update-SQLService

.DESCRIPTION 
Update-SQLService

.PARAMETER ComputerName
Target server name.

.PARAMETER Data
Result set from Get-SISQLService

.INPUTS
None

.OUTPUTS
Update-SQLService

.EXAMPLE
PowerShell Command Let

Description

.NOTES
Date       Version  Comments
---------- -------- ------------------------------------------------------------------
2020.02.05 00.00.01 Initial Version
#>
function Update-SQLService
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
    
    $ModuleName = 'Update-SQLService'
    $ModuleVersion = '0.01'
    $ModuleLastUpdated = 'June 9, 2016'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        # Validate server exists.
        $Server = Get-Server -ServerName $ComputerName

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

        $TSQL = "IF EXISTS (SELECT * FROM sys.tables WHERE name = 'SQLServiceDetails')
                     DROP TABLE Staging.SQLServiceDetails

                  CREATE TABLE Staging.SQLServiceDetails (
                                ServerName varchar(255) NULL,
                                ServiceName varchar(255) NULL,
                                InstanceName varchar(255) NULL,
                                DisplayName varchar(255) NULL,
                                FilePath varchar(512) NULL,
                                ServiceType varchar(25) NULL,
                                StartMode varchar(25) NULL,
                                ServiceAccount varchar(50) NULL,
                                ServiceVersion int NULL,
                                ServiceBuild varchar(25) NULL
                            )
                            GO"
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
                ServiceVersion, ServiceBuild
          FROM Staging.SQLServiceDetails SSS
          JOIN dbo.Servers S
            ON SSS.ServerName = S.ServerName) AS Source (ServerID, ServiceName, InstanceName, DisplayName,
                FilePath, ServiceType, StartMode, ServiceAccount,
                ServiceVersion, ServiceBuild)
            ON (Target.ServerID = Source.ServerID and Target.ServiceName = Source.ServiceName)
        WHEN MATCHED THEN
            UPDATE SET LastUpdated = GETDATE(),
                       ServiceAccount = Source.ServiceAccount,
                       ServiceVersion = Source.ServiceVersion,
                       ServiceBuild = Source.ServiceBuild
        WHEN NOT MATCHED THEN
            INSERT (ServerID, ServiceName, InstanceName, DisplayName,
                FilePath, ServiceType, StartMode, ServiceAccount,
                ServiceVersion, ServiceBuild)
        VALUES (Source.ServerID, Source.ServiceName, Source.InstanceName, Source.DisplayName,
                Source.FilePath, Source.ServiceType, Source.StartMode, Source.ServiceAccount,
                Source.ServiceVersion, Source.ServiceBuild);"

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