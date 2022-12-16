<#
.SYNOPSIS
Get-SQLOpSQLPolicies

.DESCRIPTION 
Get-SQLOpSQLPolicies returns all the policies currently registered on CMS server.
It also highlights policies missing short name.

.PARAMETER List
Provide complete list (default)

.PARAMETER PolicyID
Policy for which to pull the detail.

.PARAMETER PolicyName
Policy for which to pull the detail.

.INPUTS
None

.OUTPUTS
Policy Details

.EXAMPLE
Get-SQLOpSQLPolicies -PolicyID 12

.EXAMPLE
Get-SQLOpSQLPolicies -PolicyName 'Cost Threshold of Parallelism Not Set to Default'

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2022.12.16 0.00.01 Initial Version
#>

function Get-SQLOpSQLPolicies
{ 
    [CmdletBinding(DefaultParameterSetName='List')] 
    param(
	[Alias('List','All')]
	[Parameter(ParameterSetName='List', Mandatory=$false)] [switch] $ListAvailable, 
    [Parameter(ParameterSetName='PolicyID', Mandatory=$false)] [int] $PolicyID, 
    [Parameter(ParameterSetName='PolicyName', Mandatory=$false)] [string]$PolicyName
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Get-SQLOpSQLPolicies'
    $ModuleVersion = '0.00.01'
    $ModuleLastUpdated = 'December 16, 2022'
	$ListAvailable = $false

    if (($PSCmdlet.ParameterSetName -eq 'List') -and (!($PSBoundParameters.ListAvailable)))
    {
        $ListAvailable = $true
    }

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"        

		$TSQL = "   SELECT P.policy_id AS PolicyID, PC.name PolicyCategory, P.name AS PolicyName,
							CASE WHEN PSN.Policy_ShortName IS NULL THEN '<MISSING>' ELSE PSN.Policy_ShortName END AS PolicyShortName,
							P.date_created AS DateCreated, P.date_modified AS DateModified, P.created_by AS CreatedBy
					FROM msdb.dbo.syspolicy_policies P
					JOIN msdb.dbo.syspolicy_policy_categories PC
						ON P.policy_category_id = PC.policy_category_id
					LEFT JOIN Policy.PolicyShortName PSN
						ON PSN.Policy_ID = P.policy_id
					WHERE P.created_by <> 'sa'"
        
        if (!($ListAvailable))
        {
            $TSQL += " AND P.policy_id = '$PolicyID' OR P.name = '$PolicyName'"
        }

		$TSQL += ' ORDER BY PolicyCategory, PolicyName'
        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                                 -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                                 -Query $TSQL `
                                 -ErrorAction Stop

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