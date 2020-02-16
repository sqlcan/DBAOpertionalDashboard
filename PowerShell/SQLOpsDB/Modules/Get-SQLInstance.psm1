<#
.SYNOPSIS
Get of all the instances currently registered in SQLOpsDB with their respective
discovery data. 

.DESCRIPTION 
Provide detail list of all the SQL Server instance, if it is monitored, when it
was discovered and the date last updated.

.PARAMETER ServerInstance
Server instance from which to capture the logs.

.PARAMETER ListAvailable
Provide a complete list of all the instances. Aliased to All and List.

.PARAMETER Internal
For internal processes, it exposes the ID value of the SQL Server instance. 

.INPUTS
None

.OUTPUTS
List of SQL instance details.

.EXAMPLE
Get-SQLInstance -ServerInstance ContosSQL

Return SQL instance if found, if not it will return error not found (-3).

.EXAMPLE
Get-SQLInstance -ListAvailable

Return list of all instances.

.NOTES
Date        Version Comments
----------  ------- ------------------------------------------------------------------
????.??.??  0.00.01 Initial Version
2020.02.13  0.01.06 Updated the parameters with parameter set names.
                    Standardized parameter names.
                    Updated to JSON variables.
                    Updated references to write-StatusUpdate.
                    Refactored code.
                    Added documentation.
                    Added support to list all the instances if needed.
#>
function Get-SQLInstance
{
    [CmdletBinding(DefaultParameterSetName='List')] 
    param( 
        [Alias('List','All')]
        [Parameter(ParameterSetName='List', Mandatory=$false)] [switch] $ListAvailable,
        [Parameter(ParameterSetName='ServerInstance', Mandatory=$true)] [string]
        [Parameter(ParameterSetName='Internal', Mandatory=$true)] $ServerInstance,
        [Parameter(ParameterSetName='Internal', Mandatory=$true, DontShow)] [Switch]$Internal
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    if (($PSCmdlet.ParameterSetName -eq 'List') -and (!($PSBoundParameters.ListAvailable)))
    {
        $ListAvailable = $true
    }

    $ModuleName = 'Get-SQLInstance'
    $ModuleVersion = '0.01.05'
    $ModuleLastUpdated = 'February 13, 2020'

    Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

    if ($Internal)
    {
        $TSQL = "SELECT SI.SQLInstanceID, SI.ComputerName, SI.SQLInstanceName, SI.IsMonitored, SI.DiscoveryOn, SI.LastUpdated
                   FROM dbo.vSQLInstances SI "
    }
    else
    {
        $TSQL = "SELECT SI.ComputerName, SI.SQLInstanceName, SI.IsMonitored, SI.DiscoveryOn, SI.LastUpdated
                   FROM dbo.vSQLInstances SI "
    }

    if (!($ListAvailable))
    {
        $ServerInstanceParts = Split-Parts -ServerInstance $ServerInstance
        $TSQL += "WHERE SI.ComputerName ='$($ServerInstanceParts.ComputerName)' AND SI.SQLInstanceName = '$($ServerInstanceParts.SQLInstanceName)'"
    }

    Write-StatusUpdate -Message "TSQL: $TSQL" -IsTSQL

    try
    {
        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                                 -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                                 -Query $TSQL

        if (!($Results))
        {
            Write-Output $Global:Error_ObjectsNotFound
        }
        else
        {
            Write-Output $Results
        }
    }
    catch
    {
        Write-StatusUpdate -Message "Failed to Get-SQLInstance (unhandled exception)." -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}