<#
.SYNOPSIS
Returns AG details from the SQLOpsDB.

.DESCRIPTION 
Get-SQLOpAvailabilityGroup connects to the SQL Opertional Dashboard Database (SQLOpsDB) to retrive
the current Availability Groups registered based on paramters passed.

.PARAMETER ServerInstance
ServerName\InstanceName.

.PARAMETER AGName
Availability group name as it shows up in SQL Server 2012+.

.PARAMETER AGGuid
Availability group name as it shows up in SQL Server 2012+.

.INPUTS
None

.OUTPUTS
Returns a result set with AG Name, AG Discovery Date, AG Last Update Date,
and SQL Instance Name (ServerName\InstanceName).

.EXAMPLE
Get-SQLOpAvailabilityGroup -ServerInstance SQLTest -AGName AGTest

Get Availability Group details for a default instance.


.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2016.06.09 0.01    Initial Draft
2016.07.14 0.02    Added AG Guid field as internal parameter to check if AG exists.
2016.12.13 0.03    Removed the -Level attribute from Write-StatusUpdate
2022.10.14 0.01.00 Rewrote the module to meet new standards.	
#>
function Get-SQLOpAvailabilityGroup
{

    [CmdletBinding()] 
    param( 
    [Parameter(ParameterSetName='AG', Mandatory=$true, Position=0)]
	[Parameter(ParameterSetName='Internal', Mandatory=$true, Position=0)] [string]$ServerInstance,
	[Alias('AGName')]
	[Parameter(ParameterSetName='AG', Mandatory=$true, Position=1)]
	[Parameter(ParameterSetName='Internal', Mandatory=$true, Position=1)] [string]$AvailabilityGroupName,
	[Alias('AGGuid')]
	[Parameter(ParameterSetName='AG', Mandatory=$true, Position=2)]
	[Parameter(ParameterSetName='Internal', Mandatory=$true, Position=2)] [string]$AvailabilityGroupGUID,
	[Parameter(ParameterSetName='Internal', Mandatory=$true, DontShow)] [Switch]$Internal
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    $ModuleName = 'Get-SQLOpAvailabilityGroup'
    $ModuleVersion = '0.01.00'
    $ModuleLastUpdated = 'October 14, 2022'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

		$ServerInstanceObj = Split-Parts -ServerInstance $ServerInstance

        if ($Internal)
        {
			#Get list of all AGs and their Replicas details.
			$TSQL = "SELECT   A.AGID
							, A.AGName AS AvailabilityGroupName
							, A.AGGuid AS AvailabilityGroupGUID
							, SI.ServerInstance AS ReplicaName
							, AGI.ReplicaRole
							, A.DiscoveryOn AS AvailabilityGroupDiscoveryDate
							, A.LastUpdated AS AvailabilityGroupLastUpdateDate
							, AGI.DiscoveryOn AS ReplicaDiscoveryDate
							, AGI.LastUpdated AS ReplicaLastUpdateDate
					FROM dbo.AGs A
					JOIN dbo.AGInstances AGI
						ON A.AGID = AGI.AGID
					JOIN dbo.vSQLInstances SI
						ON AGI.SQLInstanceID = SI.SQLInstanceID"
		}
		else {
			$TSQL = "SELECT   A.AGName AS AvailabilityGroupName
							, A.AGGuid AS AvailabilityGroupGUID
							, SI.ServerInstance AS ReplicaName
							, AGI.ReplicaRole
							, A.DiscoveryOn AS AvailabilityGroupDiscoveryDate
							, A.LastUpdated AS AvailabilityGroupLastUpdateDate
							, AGI.DiscoveryOn AS ReplicaDiscoveryDate
							, AGI.LastUpdated AS ReplicaLastUpdateDate
					FROM dbo.AGs A
					JOIN dbo.AGInstances AGI
						ON A.AGID = AGI.AGID
					JOIN dbo.vSQLInstances SI
						ON AGI.SQLInstanceID = SI.SQLInstanceID "
		}

		$TSQL += "WHERE SI.ComputerName = '$($ServerInstanceObj.ComputerName)'
				    AND SI.SQLInstanceName = '$($ServerInstanceObj.SQLInstanceName)'
                    AND A.AGName = '$AvailabilityGroupName'
                    AND A.AGGuid = '$AvailabilityGroupGUID'
			   ORDER BY AvailabilityGroupName, CASE WHEN (ReplicaRole='Primary') THEN 1 ELSE 2 END, ReplicaRole"

        Write-StatusUpdate -Message $TSQL -IsTSQL

		$Results = Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
						-Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
						-Query $TSQL
        
        # If no result sets are returned return an error; unless return the appropriate resultset.
        if (!($Results))
        {
            Write-Output $Global:Error_ObjectsNotFound
        }
        else
        {
            Write-Output $Results
        }
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