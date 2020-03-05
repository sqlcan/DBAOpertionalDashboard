<#
.SYNOPSIS
Get-SQLErrorLogs

.DESCRIPTION 
Get-SQLErrorLogs is custom command to mimic the functionality of Get-SQLErrorLog.
Get-SQLErrorLog does not scale well with large error log files because
date time filters are done on client side.

.PARAMETER ServerInstance
Server instance from which to capture the logs.

.PARAMETER After
Date time value from which to capture.

.PARAMETER Before
Date time value from which to capture.

.INPUTS
None

.OUTPUTS
List of error and interesting messages only.

.EXAMPLE
Get-SQLErrorLogs -ServerInstance ContosSQL

Get all the errors in the all the error logs.

.EXAMPLE
Get-SQLErrorLogs -ServerInstance ContosSQL -After "2020/02/01 00:00:00"

Get only the errors after Feb. 1st 12AM.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2020.03.05 0.00.01 Initial Version
#>
function Get-SQLErrorLogs
{
    [CmdletBinding(DefaultParameterSetName='ServerInstance')] 
    param( 
    [Parameter(ParameterSetName='ServerInstance',Position=0, Mandatory=$true)]
    [Parameter(ParameterSetName='TimeSlice',Position=0, Mandatory=$true)] [string]$ServerInstance,

    [Parameter(ParameterSetName='TimeSlice',Position=1, Mandatory=$false)] [datetime]$After,
    [Parameter(ParameterSetName='TimeSlice',Position=2, Mandatory=$false)] [datetime]$Before
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Get-SQLErrorLogs'
    $ModuleVersion = '0.00.01'
    $ModuleLastUpdated = 'March 5, 2020'

    $TSQL = "DECLARE @StartDateTime DATETIME
    DECLARE @EndDateTime DATETIME
    DECLARE @ArchiveNo INT
    
    IF object_id('tempdb..#err_log_tmp','U') IS NOT NULL
        DROP TABLE #err_log_tmp
    
    IF object_id('tempdb..#err_log_text_tmp_final','U') IS NOT NULL
        DROP TABLE #err_log_text_tmp_final
    
    CREATE TABLE #err_log_tmp(ArchiveNo int, LastModified datetime, Size int);
    INSERT #err_log_tmp (ArchiveNo, LastModified, Size) exec master.dbo.sp_enumerrorlogs;
    ALTER TABLE #err_log_tmp ADD ScanLog Bit NOT NULL Default (0);
    
    WITH CTE AS (
      SELECT *, ROW_NUMBER() OVER (ORDER BY LastModified DESC) AS RowNum
        FROM #err_log_tmp),
        CTE2 AS (
    SELECT T1.ArchiveNo, T2.LastModified AS CreationDate, T1.LastModified  AS ModifiedDate
      FROM CTE T1
      JOIN CTE T2
        ON T1.RowNum = T2.RowNum-1)
    UPDATE #err_log_tmp
       SET ScanLog = 1
      FROM #err_log_tmp m1
      JOIN CTE2 m2
        ON m1.ArchiveNo = m2.ArchiveNo
     WHERE (ModifiedDate >= '`$(StartDateTime)' AND CreationDate <= '`$(EndDateTime)');
    
    CREATE TABLE #err_log_text_tmp_final(LogDate datetime null, ProcessInfo nvarchar(100) null, Text nvarchar(4000));
    
    DECLARE crs INSENSITIVE CURSOR 
        FOR ( SELECT er.ArchiveNo AS [ArchiveNo]
                FROM #err_log_tmp er
               WHERE er.ScanLog = 1)
        FOR READ ONLY ;
    
    OPEN crs;
    FETCH crs into @ArchiveNo;
    
    WHILE @@fetch_status >= 0 
    BEGIN 
        INSERT #err_log_text_tmp_final (LogDate, ProcessInfo, Text)
        EXEC master.dbo.xp_readerrorlog @ArchiveNo, 1, Null, Null, '`$(StartDateTime)', '`$(EndDateTime)', N'asc'
    
        FETCH crs INTO @ArchiveNo
    END 
    CLOSE crs
    DEALLOCATE crs
    
    SELECT *
      FROM #err_log_text_tmp_final"

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        if ([String]::IsNullOrEmpty($After))
        {
            $After = '1900-01-01 00:00:00'
        }

        if ([String]::IsNullOrEmpty($Before))
        {
            $Before = '2100-01-01 00:00:00'
        }

        $Parameters = "StartDateTime=$After", "EndDateTime=$Before"

        $TSQL
        $Parameters

        $SQLErrorLogs = Invoke-Sqlcmd -ServerInstance $ServerInstance `
                                      -Database master `
                                      -Query $TSQL `
                                      -Variable $Parameters -Verbose

        
        Write-Output $SQLErrorLogs
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expectation" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}