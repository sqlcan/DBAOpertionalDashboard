<#
.SYNOPSIS
Set-SQLOpSQLPolicy

.DESCRIPTION 
Set-SQLOpSQLPolicy set the short name for a policy.

.PARAMETER PolicyID
Policy to update.

.PARAMETER PolicyName
Policy to update.

.PARAMETER PolicyShortName
Short name to set.

.INPUTS
None

.OUTPUTS
None

.EXAMPLE
Set-SQLOpSQLPolicy -PolicyID 70 -PolicyShortName 'CTOP'

Set short name for Policy ID 70 to CTOP.

.EXAMPLE
Set-SQLOpSQLPolicy -PolicyName 'Cost Threshold of Parallelism Not Set to Default' -PolicyShortName 'CTOP'

Set short name for Policy 'Cost Threshold of Parallelism Not Set to Default' to CTOP.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2022.12.16 0.00.01 Initial Version
#>
function Set-SQLOpSQLPolicy
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true, ParameterSetName='By Name')] [string]$PolicyName,
    [Parameter(Position=0, Mandatory=$true, ParameterSetName='By ID')] [int]$PolicyID,
	[Parameter(Position=1, Mandatory=$true, ParameterSetName='By Name')] 
	[Parameter(Position=1, Mandatory=$true, ParameterSetName='By ID')] [string]$PolicyShortName
    )

	if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    $ModuleName = 'Set-SQLOpSQLPolicy'
    $ModuleVersion = '0.00.01'
    $ModuleLastUpdated = 'December 16, 2022'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        $TSQL = "-- Check if it is missing add it.  If exists update it.
				IF EXISTS (SELECT * FROM Policy.PolicyShortName WHERE Policy_ID IN (SELECT policy_id FROM  msdb.dbo.syspolicy_policies P WHERE P.policy_id = $PolicyID OR P.name = '$PolicyName'))
				BEGIN
					PRINT 'I AM HERE'
					UPDATE Policy.PolicyShortName
					SET Policy_ShortName = '$PolicyShortName'
					WHERE Policy_ID = $PolicyID
				END
				ELSE
				BEGIN
					PRINT 'I AM THERE'
					INSERT INTO Policy.PolicyShortName (Policy_ID, Policy_ShortName)
					SELECT policy_id, '$PolicyShortName'
					FROM msdb.dbo.syspolicy_policies P WHERE P.policy_id = $PolicyID OR P.name = '$PolicyName' 
				END"

        Write-StatusUpdate -Message $TSQL -IsTSQL

        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                      -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                      -Query $TSQL
        
        Get-SQLOpSQLPolicies -PolicyID $PolicyID
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