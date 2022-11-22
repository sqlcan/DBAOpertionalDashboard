<#
.SYNOPSIS
Update-SQLOpSQLJobs

.DESCRIPTION 
Update-SQLOpSQLJobs

.PARAMETER ServerInstance
SQL Server instance name for which the error log is being uploaded.

.PARAMETER Data
SQL Jobs details to update.  Must get the data from Get-SISQLJObs first.

.INPUTS
None

.OUTPUTS
Nothing.

.EXAMPLE
Update-SQLOpSQLJobs -ServerInstance Contoso -Data $Data

Take the data passed in and save it in SQLOpsDB for ServerInstance.

.NOTES
Date        Version Comments
----------  ------- ------------------------------------------------------------------
2020.03.06  0.00.01 Initial version.
2021.10.31	0.00.04	Updated how staging table is created.
					Added support for process id.
					Expanded the error handling.
#>
function Update-SQLOpSQLJobs
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
    
    $ModuleName = 'Update-SQLOpSQLJobs'
    $ModuleVersion = '0.04'
    $ModuleLastUpdated = 'October 31, 2022'

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

        $TSQL = "EXEC Staging.TableUpdates @TableName=N'SQLJobs', @ModuleVersion=N'$ModuleVersion'"	
        Write-StatusUpdate -Message $TSQL -IsTSQL

        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                      -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                      -Query $TSQL

        # Load the Staging table we just created.
        Write-SqlTableData -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
        				   -DatabaseName $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
        				   -TableName SQLJobs `
        				   -SchemaName Staging `
        				   -InputData $Data

        # Staging data is loaded now need to process the data incrementally.
        #
        # 1) First update the category list.
        # 2) Then update the job list.
        # 3) Then update the job execution history.

		$ProcessID = $PID

        $TSQL = "MERGE dbo.SQLJobCategory AS Target
                USING (SELECT DISTINCT CategoryName FROM Staging.SQLJobs WHERE ProcessID = $ProcessID) AS Source (CategoryName)
                ON (Target.SQLJobCategoryName = Source.CategoryName)
                WHEN NOT MATCHED THEN
                    INSERT (SQLJobCategoryName)
                    VALUES (Source.CategoryName);"

        Write-StatusUpdate -Message $TSQL -IsTSQL

        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                      -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                      -Query $TSQL

        $TSQL = "MERGE dbo.SQLJobs AS Target
                USING (SELECT DISTINCT SQLInstanceID, C.SQLJobCategoryID, JobName
                        FROM Staging.SQLJobs J
                        JOIN dbo.SQLJobCategory C 
                        ON J.CategoryName = C.SQLJobCategoryName
						WHERE ProcessID = $ProcessID) AS Source (SQLInstanceID, SQLJobCategoryID, JobName)
                ON (Target.SQLInstanceID = Source.SQLInstanceID AND
                    Target.SQLJobName = Source.JobName)
                WHEN MATCHED THEn
                    UPDATE SET SQLJobCategoryID = Source.SQLJobCategoryID,
                            LastUpdated = GETDATE()
                WHEN NOT MATCHED THEN
                    INSERT (SQLInstanceID, SQLJobCategoryID, SQLJobName, LastUpdated, DiscoveredOn)
                    VALUES (Source.SQLInstanceID, Source.SQLJobCategoryID, Source.JobName, GETDATE(), GETDATE());"
                    
        Write-StatusUpdate -Message $TSQL -IsTSQL

        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                    -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                    -Query $TSQL

        #Merge is not needed for this command because, it should always only bring in new records.
        $TSQL = "INSERT INTO dbo.SQLJobHistory (SQLJobID, ExecutionDateTime, Duration, JobStatus)
                SELECT DJ.SQLJobID, SJ.ExecutionDateTime, SJ.Duration, SJ.JobStatus
                FROM Staging.SQLJobs SJ
                JOIN dbo.SQLJobs DJ
                    ON SJ.SQLInstanceID = DJ.SQLInstanceID
                AND SJ.JobName = DJ.SQLJobName
				WHERE ProcessID = $ProcessID"

        Write-StatusUpdate -Message $TSQL -IsTSQL
        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                    -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                    -Query $TSQL

		$TSQL = "DELETE FROM Staging.SQLJobs WHERE ProcessID = $ProcessID"
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