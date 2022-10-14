<#
.SYNOPSIS
Get-SIAvailabilityGroups

.DESCRIPTION 
Get-SIAvailabilityGroups collects list of all availability groups and their replica
details.

.PARAMETER ServerInstance
Server instance from which to capture the jobs and their execution history..

.PARAMETER Database
If collecting from user database, then what is the name?

.INPUTS
None

.OUTPUTS
List of extended properties and their values.

.EXAMPLE
Get-SIAvailabilityGroups -ServerInstance ContosSQL

Get all the extended properties.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2020.03.11 0.00.01 Initial Version
2020.04.03 0.00.02 Error with property name for Extended Properties.  Causing
                    PassiveNode extended property was being skipped.
2022.07.06 0.00.03 Added primary and secondary node information.
2022.10.13 0.00.04 Added internal switch to allow me to return SQL Instance ID
                   when updating the AG in SQLOpsDB.
#>
function Get-SIAvailabilityGroups
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerInstance,
	[Parameter(Mandatory=$false, DontShow)] [Switch]$Internal
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Get-SIAvailabilityGroups'
    $ModuleVersion = '0.00.04'
    $ModuleLastUpdated = 'October 13, 2022'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        $TSQL = "WITH CTE AS (
			SELECT AG.Group_id AS AGGuid,
				AG.name AS AGName,
				AR.replica_id AS ReplicaID,
				lower(AR.replica_server_name) AS ReplicaName,
				charindex('\',AR.replica_server_name) AS SlashLocation,
				len(AR.replica_server_name) - charindex('\',AR.replica_server_name) AS LenInstanceName
			FROM sys.availability_groups AG
			JOIN sys.availability_replicas AR
				ON AG.group_id = AR.group_id) "
			
        Write-StatusUpdate -Message $TSQL -IsTSQL

		if (!($PSBoundParameters.Internal))
        {            
            $TSQL += "SELECT   '$ServerInstance' AS ServerInstance, "
        }
        else
        {
            $ServerInstanceObj = Get-SqlOpSQLInstance -ServerInstance $ServerInstance -Internal:$Internal
            $TSQL += "SELECT   $($ServerInstanceObj.SQLInstanceID) AS SQLInstanceID 
                            , '$ServerInstance' AS ServerInstance, "
        }

		$TSQL += "      AGGuid,
						AGName,
						CASE WHEN SlashLocation > 0 THEN
							SUBSTRING(ReplicaName,1,SlashLocation-1)
						ELSE
							ReplicaName
						END AS ComputerName,
						CASE WHEN SlashLocation > 0 THEN
							SUBSTRING(ReplicaName,SlashLocation+1,LenInstanceName)
						ELSE
							'mssqlserver'
						END AS InstanceName,
						CASE WHEN (rs.role_desc IS NULL) THEN 'PRIMARY' ELSE rs.role_desc END AS ReplicaRole
					FROM CTE C
					LEFT JOIN sys.dm_hadr_availability_replica_states rs
						ON c.ReplicaID = rs.replica_id"

		Write-Debug $TSQL

        $Results = Invoke-SQLCMD -ServerInstance $ServerInstance  `
                                    -Database master `
                                    -Query $TSQL -ErrorAction Stop

		if ($Results)
		{
			Write-Output $Results
			return
		}
        else
        {
            Write-Output $Global:Error_ObjectsNotFound
            return
        }

    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expectation" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}