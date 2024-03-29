﻿<#
.SYNOPSIS
Updates the last time AG was referenced.

.DESCRIPTION 
Update-SQLOpAvailabilityGroup connects to the SQL Operational Dashboard
database to update current AG meta data.

.PARAMETER ServerInstance
SQL Server instance name for which the availability group information
is being uploaded.

.PARAMETER Data
Availability group meta-data to upload.  Must get the data from Get-SIAvailabilityGroup first.

.INPUTS
None

.OUTPUTS
Returns success or failure code.

.EXAMPLE
Update-SQLOpAvailabilityGroup -ServerInstance ContosSQL -Data $Data
Update availability group information saved in $Data for the SQL Instance.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2016.07.14 0.00.01  Initial Draft
2016.12.13 0.00.02  Removed -Level attribute from Write-StatusUpdate
2022.10.13 1.00.00	Rewrite full module with new standard.
2022.10.29 1.00.02	Updated how staging table is handled.
					Updated error expection reporting.
2022.10.30 1.00.04 	Changed how the AG information is updated from MERGE to
					 UPDATE and INSERT.
					Added handling for Process ID.
#>
function Update-SQLOpAvailabilityGroup
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

    $ModuleName = 'Update-SQLOpAvailabilityGroup'
    $ModuleVersion = '1.00.04'
    $ModuleLastUpdated = 'October 30, 2022'

    try
    {
        
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        $TSQL = "EXEC Staging.TableUpdates @TableName=N'AG', @ModuleVersion=N'$ModuleVersion'"
        Write-StatusUpdate -Message $TSQL -IsTSQL
        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                      -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                      -Query $TSQL

        # Load the Staging table we just created.
        Write-SqlTableData -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
        -DatabaseName $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
        -TableName AG `
        -SchemaName Staging `
        -InputData $Data

		# The staging data loaded for AG is from single point of view of current replica.
		#
		# First Update AG Meta Data.

		$ProcessID = $pid

		$TSQL = " MERGE dbo.AGs AS Target
					USING (SELECT DISTINCT AGName, AGGuid FROM Staging.AG WHERE ProcessID = $ProcessID) AS SOURCE (AGName, AGGuid)
					ON (Target.AGName = Source.AGName AND Target.AGGuid = Source.AGGuid)
					WHEN NOT MATCHED THEN
					INSERT (AGName, AGGuid) VALUES (Source.AGName, Source.AGGuid)
					WHEN MATCHED THEN
					UPDATE SET LastUpdated = GETDATE();"

		Write-StatusUpdate -Message $TSQL -IsTSQL

		Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
						-Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
						-Query $TSQL

		# Update the AG Instance Meta Data.

		# The script below assumes AG will not be deployed on Windows Cluster.
		# Although it is supported configuration, I have yet to see this deployed in field.
		
		# This code first finds the SQL Instance ID of non-current replica.
		# Then it updates either inserts or updates the records using Merge.
		$Primary_TSQL = "WITH OtherReplicas AS (
			SELECT DISTINCT ComputerName, InstanceName
			  FROM Staging.AG
			 WHERE ServerInstance <> (CASE WHEN InstanceName = 'mssqlserver' THEN ComputerName ELSE ComputerName + '\' + InstanceName END) AND ProcessID = $ProcessID),
		   OtherReplicaInstanceID AS (
		   SELECT SQLInstanceID, ORep.ComputerName, ORep.InstanceName
			 FROM OtherReplicas ORep
			 JOIN dbo.Servers S
			   ON ORep.ComputerName = S.ServerName
			 JOIN dbo.SQLInstances SI
			   ON ORep.InstanceName = SI.SQLInstanceName
			  AND S.ServerID = SI.ServerID),
		   FinalStagingAGData AS
		   (
			   SELECT B.AGID, A.ReplicaRole, ISNULL(ORI.SQLInstanceID, A.SQLInstanceID) AS SQLInstanceID
				 FROM Staging.AG A
				 LEFT JOIN OtherReplicaInstanceID ORI
				   ON A.ComputerName = ORI.ComputerName
				  AND A.InstanceName = ORI.InstanceName
				 LEFT JOIN dbo.AGs B
				   ON A.AGGuid = B.AGGuid
				   AND A.AGName = B.AGName
				 WHERE ProcessID = $ProcessID
		   ) "

		# Could not use MERGE because when matching on AGID and InstanceID it results in duplicate rows.
		# replica role can change from one execution to another.

		$TSQL = $Primary_TSQL +
		              "UPDATE AGI
					  SET LastUpdated = GETDATE(),
						  ReplicaRole = SAG.ReplicaRole
					 FROM dbo.AGInstances AGI
					 JOIN FinalStagingAGData SAG
					   ON AGI.AGID = SAG.AGID
					  AND AGI.SQLInstanceID = SAG.SQLInstanceID;"

		Write-StatusUpdate -Message $TSQL -IsTSQL

		Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
						-Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
						-Query $TSQL

		$TSQL = $Primary_TSQL +
						"INSERT INTO dbo.AGInstances (AGID, SQLInstanceID, ReplicaRole)
						SELECT AGID, SQLInstanceID, ReplicaRole
						  FROM FinalStagingAGData SAG
						 WHERE NOT EXISTS (SELECT * FROM dbo.AGInstances AGI WHERE Sag.AGID = AGI.AGID AND SAG.SQLInstanceID = AGI.SQLInstanceID)"
  
		  Write-StatusUpdate -Message $TSQL -IsTSQL
  
		  Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
						  -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
						  -Query $TSQL

		$TSQL = "DELETE FROM Staging.AG WHERE ProcessID = $ProcessID"
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
            Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Cannot connect to SQLOpsDB." -WriteToDB
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