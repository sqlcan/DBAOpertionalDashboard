<#
.SYNOPSIS
Get-SQLService

.DESCRIPTION 
Get-SQLService

.PARAMETER ComputerName

.INPUTS
None

.OUTPUTS
List of services installed on a computer as per SQLOpsDB data set.  This command let
will only return results if data has been collected.

.EXAMPLE
Get-SQLService -ComputerName ContosoSQL
List all the services installed on ContosoSQL.

.EXAMPLE
Get-SQLService -ComputerName ContosoSQL -ServiceType SSRS
Get list of all the SSRS instances installed on ContosoSQL.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2020.02.05 0.00.01 Initial Version
#>
function Get-SQLService
{
    [CmdletBinding(DefaultParameterSetName='ComputerName')] 
    param( 
    [Parameter(ParameterSetName='ComputerName', Mandatory=$true, Position=0)]
    [Parameter(ParameterSetName='ServiceType', Mandatory=$true, Position=0)] [string]$ComputerName,
    [Parameter(ParameterSetName='ServiceType', Mandatory=$true)]
    [ValidateSet('SSIS','SSRS','Engine','SSAS','SQL Agent','PowerBI (SSRS)','Full-Text Search')] [string]$ServiceType
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    $ModuleName = 'Get-SQLService'
    $ModuleVersion = '0.01'
    $ModuleLastUpdated = 'February 5, 2020'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        # Get list of services for a server and service type.
        $TSQL = "SELECT   S.ServerName
                        , SS.ServiceName
                        , SS.InstanceName
                        , SS.DisplayName
                        , SS.FilePath
                        , SS.ServiceType
                        , SS.StartMode
                        , SS.ServiceAccount
                        , SS.ServiceVersion
                        , SS.ServiceBuild
                   FROM dbo.SQLService SS
                   JOIN dbo.Servers S
                     ON SS.ServerID = S.ServerID
                  WHERE S.ServerName = '$ComputerName' "

        IF (!([String]::IsNullOrEmpty($ServiceType)))
        {
            $TSQL += " AND SS.ServiceType = '$ServiceType'"
        }

        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                                    -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                                    -Query $TSQL
        
        # If no result sets are returned return an error; unless return the appropriate result set.
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
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expectation" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}