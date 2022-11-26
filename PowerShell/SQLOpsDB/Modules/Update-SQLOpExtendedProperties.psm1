<#
.SYNOPSIS
Update-SQLOpExtendedProperties

.DESCRIPTION 
Update custom extended properties that can exist on a SQL instance.

.PARAMETER ServerInstance
SQL Server instance for which the date needs to be updated.

.PARAMETER Data
Data collected via Get-SIExtendedProperties with -CustomProperties switch command let.

.INPUTS
None

.OUTPUTS
Success (0) or Failure (-1).

.EXAMPLE
Update-SQLOpExtendedProperties -ServerInstance ContosoSQL -Data $Data

.NOTES
Date        Version Comments
----------  ------- ------------------------------------------------------------------
2022.10.31  0.00.01 Initial Version.
2022.10.24  0.00.02 Removing development code.
#>
function Update-SQLOpExtendedProperties
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
    
    $ModuleName = 'Update-SQLOpExtendedProperties'
    $ModuleVersion = '0.00.02'
    $ModuleLastUpdated = 'November 24, 2022'
   
    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

		$ServerInstanceObj = Get-SqlOpSQLInstance -ServerInstance $ServerInstance -Internal
		IF (($ServerInstanceObj -eq $Global:Error_ObjectsNotFound) -or ($ServerInstanceObj -eq $null))
		{
			Write-StatusUpdate "Failed to find SQL Instance [$ServerInstance] in SQLOpsDB." -WriteToDB
			Write-Output $Global:Error_FailedToComplete
			return
		}
		$ProcessID = $pid

		# Step 1 : Setup Staging Table - If Missing.
		$TSQL = "EXEC Staging.TableUpdates @TableName=N'ExtendedProperties', @ModuleVersion=N'$ModuleVersion'"
		Write-StatusUpdate -Message $TSQL -IsTSQL

		Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
		  			  -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
		  			  -Query $TSQL

		# Step 2 : Load staging table.  It is row-by-row operation.
		#		   However, most servers should not have too many "Custom" extended properties.
		ForEach ($Key IN $Data.Keys)
		{
			$TSQL = "INSERT INTO Staging.ExtendedProperties VALUES ($ProcessID,$($ServerInstanceObj.SQLInstanceID),'$Key','$($Data[$Key])')"
			Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
			              -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
			              -Query $TSQL
		}

		# Step 3 : Load the Custom Extended Properties First
		$TSQL = "WITH CTE AS
				( SELECT DISTINCT ExtendedPropertyName
					FROM Staging.ExtendedProperties
				   WHERE ProcessID = $ProcessID)
				MERGE dbo.ExtendedProperty AS Target
				USING (SELECT ExtendedPropertyName FROM CTE) AS Source (ExtendedPropertyName)
		           ON (Target.ExtendedPropertyName = Source.ExtendedPropertyName)
				WHEN NOT MATCHED THEN
			    	INSERT (ExtendedPropertyName) VALUES (Source.ExtendedPropertyName);"
		Write-StatusUpdate -Message $TSQL -IsTSQL                    
		Invoke-SQLCMD -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
						-Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
						-Query $TSQL -ErrorAction Stop

		# Step 4 : Updated the Extended Properties Data
		$TSQL = "WITH CTE AS
				( SELECT SEP.SQLInstanceID, EP.ExtendedPropertyID, SEP.ExtendedPropertyValue
					FROM Staging.ExtendedProperties SEP
					JOIN dbo.ExtendedProperty EP
					  ON SEP.ExtendedPropertyName = EP.ExtendedPropertyName
				   WHERE ProcessID = $ProcessID)
				MERGE dbo.ExtendedPropertyValues AS Target
				USING (SELECT SQLInstanceID, ExtendedPropertyID, ExtendedPropertyValue FROM CTE) AS Source (SQLInstanceID, ExtendedPropertyID, ExtendedPropertyValue)
		           ON (Target.SQLInstanceID = Source.SQLInstanceID AND Target.ExtendedPropertyID = Source.ExtendedPropertyID)
				WHEN MATCHED THEN
					UPDATE SET ExtendedPropertyValue = Source.ExtendedPropertyValue,
							   LastUpdated = GetDate()
				WHEN NOT MATCHED THEN
			    	INSERT (SQLInstanceID, ExtendedPropertyID, ExtendedPropertyValue) VALUES (Source.SQLInstanceID, Source.ExtendedPropertyID, Source.ExtendedPropertyValue);"
		Write-StatusUpdate -Message $TSQL -IsTSQL            
		Invoke-SQLCMD -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
						-Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
						-Query $TSQL -ErrorAction Stop
		
		# Step 7 : Clear Staging Table.
		$TSQL = "DELETE FROM Staging.ExtendedProperties WHERE ProcessID = $ProcessID"
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
            Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - SQL Exception" -WriteToDB
            Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        }
        return $Global:Error_FailedToComplete
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Exception" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        return $Global:Error_FailedToComplete
    }
}