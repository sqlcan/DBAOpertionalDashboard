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
2020.03.06 0.00.03 Fixed bug in Write-StatusUpdate parameter.
                   Refactored the parameters code.
           0.00.04 Bug fix with how duration was being calculated.
2022.10.31 0.00.07 Refactored the code for $Internal parameter.
				   Expended the error handling.
				   Added support for Process ID.
#>
function Get-SISQLJobs
{
    [CmdletBinding(DefaultParameterSetName='ServerInstance')] 
    param( 
    [Parameter(ParameterSetName='ServerInstance',Position=0, Mandatory=$true)]
    [Parameter(ParameterSetName='After',Position=0, Mandatory=$true)] [string]$ServerInstance,

    [Parameter(ParameterSetName='After',Position=1, Mandatory=$true)] [datetime]$After,

    [Parameter(Mandatory=$false, DontShow)] [Switch]$Internal
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Get-SISQLJobs'
    $ModuleVersion = '0.00.07'
    $ModuleLastUpdated = 'October 31, 2022'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

		$ProcessID = $pid
		$SQLInstanceObj = Get-SqlOpSQLInstance -ServerInstance $ServerInstance -Internal:$Internal

        $TSQL = "WITH CTE AS (SELECT job_id,
                    msdb.dbo.agent_datetime(run_date,run_time) AS ExecutionDateTime,
                    CASE run_status 
                    WHEN 0 THEN 'Failed'
                    WHEN 1 THEN 'Successful'
                    WHEN 2 THEN 'Retrying'
                    WHEN 3 THEN 'Cancelled'
                    WHEN 4 THEN 'Running'
                    ELSE 'Unknown'
                    END AS JobStatus,
                    CAST(SUBSTRING(RIGHT(REPLICATE('0',8) + CAST(run_duration AS VARCHAR(8)),8),1,2) AS INT) AS NumOfDays,
                    CAST(SUBSTRING(RIGHT(REPLICATE('0',8) + CAST(run_duration AS VARCHAR(8)),8),3,2) AS INT) AS NumOfHr,
                    CAST(SUBSTRING(RIGHT(REPLICATE('0',8) + CAST(run_duration AS VARCHAR(8)),8),5,2) AS INT) AS NumOfMin,
                    CAST(SUBSTRING(RIGHT(REPLICATE('0',8) + CAST(run_duration AS VARCHAR(8)),8),7,2) AS INT) AS NumOfSec
                FROM msdb.dbo.sysjobhistory
               WHERE step_id = 0) 
			   SELECT   $(IF ($Internal) { "$ProcessID AS ProcessID, " })
				  	    $(IF ($Internal) { "$($SQLInstanceObj.SQLInstanceID) AS InstanceID, " })
                         '$ServerInstance' AS ServerInstance
                        , J.name AS JobName
                        , C.name AS CategoryName
                        , ExecutionDateTime
                        , (NumOfDays * 24 * 3600)+(NumOfHr * 3600)+(NumOfMin * 60)+NumOfSec AS Duration
                        , JobStatus
                     FROM msdb.dbo.sysjobs J
                     JOIN CTE JH
                       ON J.job_id = JH.job_id
                     JOIN msdb.dbo.syscategories C
                       ON J.category_id = C.category_id
                    WHERE J.name NOT LIKE 'syspolicy%' "

        if (!([String]::IsNullOrEmpty($After)))
        {
            $TSQL = $TSQL +
                    "AND ExecutionDateTime >= '$After'"
        }

        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-Sqlcmd -ServerInstance $ServerInstance `
                                 -Database 'msdb' `
                                 -Query $TSQL

        Write-Output $Results
    }
    catch [System.Data.SqlClient.SqlException]
    {
        if ($($_.Exception.Message) -like '*Could not open a connection to SQL Server*')
        {
            Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Cannot connect to $ServerInstance." -WriteToDB
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