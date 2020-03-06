<#
.SYNOPSIS
Get-SQLOpSQLJobs

.DESCRIPTION 
Get-SQLOpSQLJobs

.PARAMETER ComputerName

.INPUTS
None

.OUTPUTS
Provide complete list of jobs and their history on a SQL Instance

.EXAMPLE
Get-SQLOpSQLJobs -ServerInstance ContosoSQL
List all the services installed on ContosoSQL.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2020.03.06 0.00.01 Initial Version
#>
function Get-SQLOpSQLJobs
{
    [CmdletBinding(DefaultParameterSetName='ServerInstance')] 
    param( 
    [Parameter(ParameterSetName='ServerInstance', Mandatory=$true, Position=0)] [string]$ServerInstance
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    $ModuleName = 'Get-SQLOpSQLJobs'
    $ModuleVersion = '0.01'
    $ModuleLastUpdated = 'March 6, 2020'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        $ServerInstanceObj = Get-SqlOpSQLInstance -ServerInstance $ServerInstance -Internal

        IF ($ServerInstanceObj -eq $Global:Error_ObjectsNotFound)
        {
            Write-StatusUpdate "Failed to find SQL Instance [$ServerInstance] in SQLOpsDB." -WriteToDB
            Write-Output $Global:Error_FailedToComplete
            return
        }

        # Get list of services for a server and service type.
        $TSQL = "SELECT CASE WHEN SI.SQLInstanceName = 'MSSQLServer' THEN
                        ComputerName
                    ELSE
                        ComputerName + '\' + SI.SQLInstanceName
                    END AS ServerInstance, SJ.SQLJobName, JC.SQLJobCategoryName, JH.ExecutionDateTime, JH.Duration AS Duration_s, JH.JobStatus
                FROM dbo.vSQLInstances SI
                JOIN dbo.SQLJobs SJ
                    ON SI.SQLInstanceID = SJ.SQLInstanceID
                JOIN dbo.SQLJobCategory JC
                    ON SJ.SQLJobCategoryID = JC.SQLJobCategoryID
                JOIN dbo.SQLJobHistory JH
                    ON SJ.SQLJobID = JH.SQLJobID
                WHERE SI.SQLInstanceID = $($ServerInstanceObj.SQLInstanceID)"

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