<#
.SYNOPSIS
Update-SQLOpSQLErrorLog

.DESCRIPTION 
Update-SQLOpSQLErrorLog

.PARAMETER ServerInstance
SQL Server instance name for which the error log is being uploaded.

.PARAMETER Data
Error log to upload.  Must get the data from Get-SISQLErrorLog first.

.INPUTS
None

.OUTPUTS
Nothing.

.EXAMPLE
Update-SQLOpSQLErrorLog -ServerInstance Contoso -Data $Data

Take the data passed in and save it in SQLOpsDB for ServerInstance.

.NOTES
Date        Version Comments
----------  ------- ------------------------------------------------------------------
2020.02.06  0.00.01 Initial version.
2020.02.13  0.00.02 Updated reference to Get-SQLInstance to use new variable name.
2020.02.19  0.00.04 Updated module name to Update-SQLOpSQLErrorLog.
                    Updated reference to Get-SQLOpSQLInstance.
#>
function Update-SQLOpSQLErrorLog
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
    
    $ModuleName = 'Update-SQLOpSQLErrorLog'
    $ModuleVersion = '0.04'
    $ModuleLastUpdated = 'February 19, 2020'

    # Validate sql instance exists.
    $ServerInstanceObj = Get-SqlOpSQLInstance -ServerInstance $ServerInstance

    IF ($ServerInstanceObj -eq $Global:Error_ObjectsNotFound)
    {
        Write-StatusUpdate "Failed to find SQL Instance [$ServerInstance] in SQLOpsDB." -WriteToDB
        Write-Output $Global:Error_FailedToComplete
        return
    }

    # Validate data is for SQL Services.
    ForEach ($DataRow in $Data)
    {
        $TypeName = $DataRow.GetType().Name
        if ($TypeName -ne 'SQLErrorMsg')
        {
            Write-StatusUpdate "Invalid data set provided.  The results must be from Get-SIErrorLogs. Expecting SQLErrorMsg, received [$TypeName]."
            Write-Output $Global:Error_FailedToComplete
            return
        }
    }

    try
    {

        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        # Create a staging table to store the results.  Using staging table, we can do batch process.
        # Other option would be row-by-row operation.

        $TSQL = "IF EXISTS (SELECT * FROM sys.tables WHERE name = 'SQLErrLog')
                     DROP TABLE Staging.SQLErrLog

                  CREATE TABLE Staging.SQLErrLog (
                                SQLInstanceID int,
                                ServerInstance VARCHAR(255),
                                DateTimeCaptured DATETIME,
                                Message VARCHAR(MAX)
                            )
                            GO"
        Write-StatusUpdate -Message $TSQL -IsTSQL

        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                      -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                      -Query $TSQL

        # Load the Staging table we just created.
        Write-SqlTableData -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
        -DatabaseName $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
        -TableName SQLErrLog `
        -SchemaName Staging `
        -InputData $Data

        $TSQL = "INSERT INTO dbo.SQLErrorLog (SQLInstanceID, DateTime, ErrorMsg)
                 SELECT SQLInstanceID, DateTimeCaptured, Message FROM Staging.SQLErrLog"
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