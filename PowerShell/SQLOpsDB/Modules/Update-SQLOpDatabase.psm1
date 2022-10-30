<#
.SYNOPSIS
Update-SQLOpDatabase

.DESCRIPTION 
Update database history based on collection from Get-SIDatabase.

.PARAMETER ServerInstance
SQL Server instance for which the date needs to be updated.

.PARAMETER Data
Data collected via Get-SIDatabase command let.

.INPUTS
None

.OUTPUTS
Success (0) or Failure (-1).

.EXAMPLE
Update-SQLOpDatabase -ServerInstance ContosoSQL -Data $Data

.NOTES
Date        Version Comments
----------  ------- ------------------------------------------------------------------
2022.10.28  0.00.01 Initial Version.
2022.10.29  0.00.03 Fixed minor bug with data-type miss-match.
					Updated how staging tables are created and managed.
2022.10.30	0.00.05 Fixed bug with merge stagement for Database Size updates.
					Fixed bug with SQL Version compare.
#>
function Update-SQLOpDatabase
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
    
    $ModuleName = 'Update-SQLOpDatabase'
    $ModuleVersion = '0.00.05'
    $ModuleLastUpdated = 'October 30, 2022'
   
    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        # Validate sql instance exists. 
		$SQLProperties = Get-SQLOpSQLProperties -ServerInstance $ServerInstance
        IF ($SQLProperties -eq $Global:Error_ObjectsNotFound)
        {
            Write-StatusUpdate "Failed to find SQL Instance [$ServerInstance] in SQLOpsDB." -WriteToDB
            Write-Output $Global:Error_FailedToComplete
            return
        }

        # Step 1 : Validate the Data Object.
		$FirstRecord = $Data[0]

		if (([String]::IsNullOrEmpty($FirstRecord['AGGuid'])) -or ([String]::IsNullOrEmpty($FirstRecord['DatabaseName'])))
		{
            Write-StatusUpdate "Failed to update database information for [$ServerInstance] in SQLOpsDB." -WriteToDB
			Write-StatusUpdate "Dataset provided is invalid." -WriteToDB
            Write-Output $Global:Error_FailedToComplete
            return
		}		

		$ProcessID = $pid
		# Step 1 : Setup Staging Table - If Missing.
		$TSQL = "EXEC Staging.TableUpdates @TableName=N'Databases', @ModuleVersion=N'$ModuleVersion'"
		Write-StatusUpdate -Message $TSQL -IsTSQL

		Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
		  			  -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
		  			  -Query $TSQL

		# Step 2 : Load Staging Table.
		Write-SqlTableData -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                           -DatabaseName $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                           -TableName Databases `
                           -SchemaName Staging `
                           -InputData $Data

		# Step 3 : Database Update.
		$TSQL = "WITH CTE AS
				( SELECT DISTINCT SQLInstanceID, DatabaseName, DatabaseState
					FROM Staging.Databases
				   WHERE ProcessID = $ProcessID)
				MERGE dbo.Databases AS Target
				USING (SELECT SQLInstanceID, DatabaseName, DatabaseState FROM CTE) AS Source (SQLInstanceID, DatabaseName, DatabaseState)
		           ON (Target.SQLInstanceID = Source.SQLInstanceID AND Target.DatabaseName = Source.DatabaseName)
		        WHEN MATCHED THEN
			    UPDATE SET Target.LastUpdated = GETDATE(),
						   Target.DatabaseState = Source.DatabaseState
				WHEN NOT MATCHED THEN
			    	INSERT (SQLInstanceID, DatabaseName, DatabaseState, IsMonitored, DiscoveryOn, LastUpdated) VALUES (Source.SQLInstanceID, Source.DatabaseName, Source.DatabaseState, 1, GetDate(), GetDate());"

		Write-StatusUpdate -Message $TSQL -IsTSQL                    
		Invoke-SQLCMD -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
					  -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
					  -Query $TSQL -ErrorAction Stop

		# Step 4 : Database Size Update.
		if ($SQLProperties.SQLBuild_Major -gt 8)
		{
			# Update database space's catalog, only collect database space information for SQL 2005+.
			$TSQL = "WITH CTE AS (
					SELECT D.DatabaseID, SD.FileSize_mb, SD.FileType
						FROM Staging.Databases SD
						JOIN dbo.Databases D
						ON SD.DatabaseName = D.DatabaseName
						AND SD.SQLInstanceID = D.SQLInstanceID
						AND D.IsMonitored = 1
					  WHERE SD.ProcessID = $ProcessID)
					MERGE dbo.DatabaseSize AS Target
					USING (SELECT DatabaseID, FileSize_mb, FileType FROM CTE) AS Source (DatabaseID, FileSize_mb, FileType)
					ON (Target.DatabaseID = Source.DatabaseID AND Target.DateCaptured = CAST(GetDate() AS DATE) AND Target.FileType = Source.FileType)
					WHEN MATCHED THEN
					UPDATE SET FileSize_mb = Source.FileSize_mb
					WHEN NOT MATCHED THEN
					INSERT (DatabaseID, FileType, DateCaptured, FileSize_mb) VALUES (Source.DatabaseID, Source.FileType, GetDate(), Source.FileSize_mb);"

			Write-StatusUpdate -Message $TSQL -IsTSQL                    
			Invoke-SQLCMD -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
			  			  -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
						  -Query $TSQL -ErrorAction Stop
		}

		# Step 5 : AG Database Update.
		if ($SQLProperties.SQLBuild_Major -ge 11)
		{
			$TSQL = "  WITH CTE
							AS (SELECT AGInstanceID, DatabaseID
								FROM Staging.Databases SD
								JOIN dbo.Databases D
									ON SD.DatabaseName = D.DatabaseName
								AND SD.SQLInstanceID = D.SQLInstanceID
								AND D.IsMonitored = 1
								JOIN dbo.AGs A
								ON SD.AGGuid = A.AGGuid
								JOIN dbo.AGInstances AGI
									ON A.AGID = AGI.AGID
									AND AGI.SQLInstanceID = SD.SQLInstanceID
								WHERE FileType = 'Data'
								  AND SD.ProcessID = $ProcessID)
						MERGE dbo.AGDatabases AS Target
						USING (SELECT AGInstanceID, DatabaseID FROM CTE) AS Source (AGInstanceID, DatabaseID)
							ON (Target.DatabaseID = Source.DatabaseID AND Target.AGInstanceID = Source.AGInstanceID)
						WHEN MATCHED THEN
							UPDATE SET LastUpdated = GetDate()
						WHEN NOT MATCHED THEN
						INSERT (AGInstanceID,DatabaseID,DiscoveryOn,LastUpdated) VALUES (Source.AGInstanceID, Source.DatabaseID,GetDate(),GetDate());"

			Write-StatusUpdate -Message $TSQL -IsTSQL                    
			Invoke-SQLCMD -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
			  			  -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
						  -Query $TSQL -ErrorAction Stop
		}

		
		# Step 6 : Clear Staging Table.
		$TSQL = "DELETE FROM Staging.Databases WHERE ProcessID = $ProcessID"
		Write-StatusUpdate -Message $TSQL -IsTSQL                    
		Invoke-SQLCMD -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
						-Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
					  -Query $TSQL -ErrorAction Stop

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
        return $Global:Error_FailedToComplete
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expectation" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        return $Global:Error_FailedToComplete
    }
}