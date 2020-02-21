<#
.SYNOPSIS
Get-SISQLJobs

.DESCRIPTION 
Get-SISQLJobs gets all the jobs with their job execution history.  The collection
ignores all jobs starting with syspolicy*.

.PARAMETER ServerInstance
Server instance from which to capture the jobs and their execution history..

.PARAMETER After
Date time value from which to capture.

.PARAMETER Internal
For internal processes, it exposes the ID value of the SQL Server instance. 

.INPUTS
None

.OUTPUTS
List of error and interesting messages only.

.EXAMPLE
Get-SISQLJobs -ServerInstance ContosSQL

Get all the job and their history.

.EXAMPLE
Get-SISQLJobs -ServerInstance ContosSQL -After "2020/02/01 00:00:00"

Get only the job and history after Feb. 1st 12AM.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2020.02.21 0.00.01 Initial Version
#>
function Get-SISQLJobs
{
    [CmdletBinding(DefaultParameterSetName='ServerInstance')] 
    param( 
    [Parameter(ParameterSetName='ServerInstance',Position=0, Mandatory=$true)]
    [Parameter(ParameterSetName='After',Position=0, Mandatory=$true)]
    [Parameter(ParameterSetName='Internal', Position=0, Mandatory=$true)] [string]$ServerInstance,

    [Parameter(ParameterSetName='After',Position=1, Mandatory=$true)] [datetime]$After,

    [Parameter(ParameterSetName='After',Position=2, Mandatory=$false, DontShow)]
    [Parameter(ParameterSetName='Internal', Position=1, Mandatory=$false, DontShow)] [Switch]$Internal
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Get-SISQLJobs'
    $ModuleVersion = '0.00.01'
    $ModuleLastUpdated = 'February 21, 2020'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        if (!($PSBoundParameters.Internal))
        {            
            $TSQL = "SELECT   '$ServerInstance' AS ServerInstance
                            , J.name AS JobName "
        }
        else
        {
            $ServerInstanceObj = Get-SqlOpSQLInstance -ServerInstance $ServerInstance -Internal:$Internal
            $TSQL = "SELECT   $($ServerInstanceObj.SQLInstanceID) AS SQLInstanceID 
                            , '$ServerInstance' AS ServerInstance
                            , J.name AS JobName "   
        }

        $TSQL = $TSQL + ", C.name AS CategoryName
                        , msdb.dbo.agent_datetime(JH.run_date,JH.run_time) AS ExecutionDateTime
                        , JH.run_duration AS Duration
                        , CASE JH.run_status 
                          WHEN 0 THEN 'Failed'
                          WHEN 1 THEN 'Successful'
                          WHEN 2 THEN 'Retrying'
                          WHEN 3 THEN 'Cancelled'
                          WHEN 4 THEN 'Running'
                          ELSE 'Unknown'
                          END AS JobStatus
                     FROM msdb.dbo.sysjobs J
                     JOIN msdb.dbo.sysjobhistory JH
                       ON J.job_id = JH.job_id
                     JOIN msdb.dbo.syscategories C
                       ON J.category_id = C.category_id
                    WHERE JH.step_id = 0
                      AND J.name NOT LIKE 'syspolicy%' "

        if (!([String]::IsNullOrEmpty($After)))
        {
            $TSQL = $TSQL +
                    "AND msdb.dbo.agent_datetime(JH.run_date,JH.run_time) >= '$After'"
        }

        Write-StatusUpdate -Message $TSQL -TSQL

        $Results = Invoke-Sqlcmd -ServerInstance $ServerInstance `
                                 -Database 'msdb' `
                                 -Query $TSQL

        Write-Output $Results
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expectation" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}