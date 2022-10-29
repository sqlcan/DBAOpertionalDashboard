<#
.SYNOPSIS
Get-SIDatabases

.DESCRIPTION 
Get-SIDatabases gets all the jobs with their job execution history.  The collection
ignores all jobs starting with syspolicy*.

.PARAMETER ServerInstance
Server instance from which to capture the jobs and their execution history..

.INPUTS
None

.OUTPUTS
List of all the databases.

.EXAMPLE
Get-SIDatabases -ServerInstance ContosSQL

Get all the databases and their size information.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2022.10.14 0.00.01 Initial Version
#>
function Get-SIDatabases
{
    param( 
    [Parameter(Mandatory=$true)][string]$ServerInstance,
    [Parameter(Mandatory=$false, DontShow)] [Switch]$Internal
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Get-SIDatabases'
    $ModuleVersion = '0.00.01'
    $ModuleLastUpdated = 'March 6, 2020'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

		$SQLProperties = Get-SISQLProperties -ServerInstance $ServerInstance
		$SQLServer_Major = $SQLProperties['SQLBuild_Major']
		$SQLInstanceObj = Get-SQLOpSQLInstance -ServerInstance $ServerInstance -Internal
		$ProcessID = $pid


		if (($SQLServer_Major -ge 9) -and ($SQLServer_Major -le 10))
		{
			$TSQL = "   WITH DBDetails
							AS (SELECT   DB_NAME(D.database_id) AS DatabaseName
										, D.state_desc AS DatabaseState
										, CASE WHEN type = 0 THEN 'Data' ELSE 'Log' END AS FileType
										, size/128 AS FileSize_mb
								FROM sys.master_files mf
								JOIN sys.databases D
									ON mf.database_id = D.database_id
								WHERE D.database_id NOT IN (1,3,4))
						SELECT   $(IF ($Internal) { "$ProcessID AS ProcessID, " })
						         $(IF ($Internal) { "$($SQLInstanceObj.SQLInstanceID) AS InstanceID, " })
						         '$ServerInstance' AS ServerInstance
								, CAST('00000000-0000-0000-0000-000000000000' AS uniqueidentifier) AS AGGuid
								, DatabaseName
								, UPPER(DatabaseState) AS DatabaseState 
								, FileType
								, SUM(FileSize_mb) AS FileSize_mb
						FROM DBDetails
					GROUP BY DatabaseName, DatabaseState, FileType"
		}
		else
		{
			$TSQL = "  WITH DBDetails
							AS (SELECT   ISNULL(AG.group_id,CAST('00000000-0000-0000-0000-000000000000' AS uniqueidentifier)) AS AGGuid
									, DB_NAME(MF.database_id) AS DatabaseName
									, D.state_desc AS DatabaseState
									, CASE WHEN type = 0 THEN 'Data' ELSE 'Log' END AS FileType
									, size/128 AS FileSize_mb
								FROM sys.master_files MF
							LEFT JOIN sys.databases D
									ON MF.database_id = D.database_id
							LEFT JOIN sys.availability_replicas AR
									ON D.replica_id = AR.replica_id
							LEFT JOIN sys.availability_groups AG
									ON AR.group_id = AG.group_id
								WHERE MF.database_id NOT IN (1,3,4))
					SELECT   $(IF ($Internal) { "$ProcessID AS ProcessID, " })
							 $(IF ($Internal) { "$($SQLInstanceObj.SQLInstanceID) AS InstanceID, " })
						  	 '$ServerInstance' AS ServerInstance
							, AGGuid
							, DatabaseName
							, UPPER(DatabaseState) AS DatabaseState 
							, FileType
							, SUM(FileSize_mb) AS FileSize_mb
						FROM DBDetails
					GROUP BY AGGuid, DatabaseName, DatabaseState, FileType"
		}

		Write-StatusUpdate -Message $TSQL -IsTSQL                    
		$Results = Invoke-SQLCMD -ServerInstance $ServerInstance `
									-Database 'master' `
									-Query $TSQL -ErrorAction Stop
        Write-Output $Results
    }
    catch [System.Data.SqlClient.SqlException]
    {
        if ($($_.Exception.Message) -like '*Could not open a connection to SQL Server*')
        {
            Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Cannot connect to SQLOpsDB." -WriteToDB
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