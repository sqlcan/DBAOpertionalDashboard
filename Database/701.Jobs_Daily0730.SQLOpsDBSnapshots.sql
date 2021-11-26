USE [msdb]
GO

/****** Object:  Job [Daily0730.SQLOpsDB Snapshots]    Script Date: 11/3/2020 4:06:05 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Data Collector]    Script Date: 11/3/2020 4:06:05 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Data Collector' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Data Collector'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Daily0730.SQLOpsDB Snapshots', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Create Snapshots Various SQL Opertional Dashboards', 
		@category_name=N'Data Collector', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Create Snapshots]    Script Date: 11/3/2020 4:06:05 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Create Snapshots', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'USE [SQLOpsDB]

IF (SELECT OBJECT_ID(''Snapshot.Top15OffendingDisk'')) IS NOT NULL
            DROP TABLE [Snapshot].Top15OffendingDisk;
 
IF (SELECT OBJECT_ID(''Snapshot.SQLJobOverview'')) IS NOT NULL
            DROP TABLE [Snapshot].SQLJobOverview;
 
IF (SELECT OBJECT_ID(''Snapshot.SQLErrors'')) IS NOT NULL
            DROP TABLE [Snapshot].SQLErrors;
 
IF (SELECT OBJECT_ID(''Snapshot.PolicyOverview'')) IS NOT NULL
            DROP TABLE [Snapshot].PolicyOverview;
 
WITH CTE
AS (SELECT DiskVolumeID,
           SpaceUsed_mb AS LastSpaceUsed_mb,
                           TotalSpace_mb AS LastTotalSpace_mb
      FROM dbo.DiskVolumeSpace DVS1
     WHERE SpaceHistoryID = (SELECT MAX(SpaceHistoryID) FROM dbo.DiskVolumeSpace DVS2 WHERE DVS1.DiskVolumeID = DVS2.DiskVolumeID))
 
   SELECT TOP 15 CASE WHEN S.ServerName IS NULL THEN SC.SQLClusterName ELSE S.ServerName END AS ServerVCOName,
          DV.DiskVolumeID, 
          DV.DiskVolumeName,
                  DVSA.SpaceUsed_mb AS AvgSpaceUsed_mb,
                  DVSA.TotalSpace_mb AS AvgTotalSpace_mb,
                          LastSpaceUsed_mb,
                          LastTotalSpace_mb,
                          (LastTotalSpace_mb-LastSpaceUsed_mb) As FreeSpace_mb,
                          (LastSpaceUsed_mb + 1.0)/(LastTotalSpace_mb + 1.0) AS SpaceUsedInPercent,
                  AvgGrowthInPercent,
          CASE WHEN AvgGrowthInPercent > 0 AND LOG(1+AvgGrowthInPercent) > 0.0 THEN
              LOG((LastTotalSpace_mb + 1.0)/(LastSpaceUsed_mb + 1.0)) / LOG(1+AvgGrowthInPercent)
                  ELSE
                    9999999
                  END AS DaysUntilOutOfSpace
             INTO [Snapshot].Top15OffendingDisk
     FROM dbo.DiskVolumes DV
     JOIN dbo.vwDiskVolumeSpaceAverage DVSA
       ON DV.DiskVolumeID = DVSA.DiskVolumeID
     JOIN CTE DVSL
       ON DV.DiskVolumeID = DVSL.DiskVolumeID
LEFT JOIN dbo.Servers S
       ON DV.ServerID = S.ServerID
      AND DV.SQLClusterID IS NULL
LEFT JOIN dbo.SQLClusters SC
       ON DV.SQLClusterID = SC.SQLClusterID
      AND DV.ServerID IS NULL
    WHERE DV.IsMonitored = 1
 ORDER BY DaysUntilOutOfSpace, ServerVCOName, DiskVolumeName;
 
WITH CTE AS (
  SELECT SQLJobID, Max(ExecutionDateTime) AS LastExecution
    FROM dbo.SQLJobHistory
GROUP BY SQLJobID),
CTE2 AS (
SELECT JH.SQLJObID, JobStatus
  FROM dbo.SQLJobHistory JH
  JOIN CTE
    ON JH.SQLJobID = CTE.SQLJobID
   AND JH.ExecutionDateTime = CTE.LastExecution
WHERE JH.ExecutionDateTime >= DATEADD(Day,-1,GETDATE())
)
SELECT JobStatus, COUNT(*) AS TotalCount
  INTO [Snapshot].SQLJobOverview
  FROM CTE2
GROUP BY JobStatus;
 
WITH CTE AS (
  SELECT SQLInstanceID, count(*) TotalErrors
    FROM dbo.SQLErrorLog
   WHERE DateTime >= dateadd(day,-1,cast(GetDate() as date))
GROUP BY SQLInstanceID), CTE2 AS (
   SELECT SI.SQLInstanceEnviornment,
          CASE WHEN CTE.TotalErrors IS NULL THEN
                              ''No Errors''
                          ELSE
                              ''Errors''
                          END AS ErrorStatus,
                          ISNULL(TotalErrors,0) AS TotalErrors
     FROM dbo.SQLInstances SI
LEFT JOIN CTE 
       ON SI.SQLInstanceID = CTE.SQLInstanceID)
SELECT SQLInstanceEnviornment, ErrorStatus, COUNT(*) AS InstanceCount, SUM(TotalErrors) AS TotalErrors
  INTO [Snapshot].SQLErrors
  FROM CTE2
GROUP BY SQLInstanceEnviornment, ErrorStatus;
GO
 
SELECT   REPLACE(REPLACE(PHS.CategoryName,''AHS Best Practices: '',''''),''Microsoft Best Practices: '','''') AS CategoryName
       , PHS.PolicyResult
       , COUNT(*) AS ObjCount
  INTO [Snapshot].PolicyOverview
  FROM [Policy].PolicyHistorySummary PHS
  JOIN [Policy].PolicyShortName PSN
    ON PHS.policy_id = PSN.policy_id
 WHERE NOT EXISTS (SELECT *
                     FROM [Policy].PolicyExclusions PE
                    WHERE PHS.EvaluatedServer LIKE PE.EvaluatedServer
                      AND PHS.ObjectName LIKE PE.ObjectName
                      AND PHS.policy_id = PE.Policy_ID)
GROUP BY PHS.CategoryName, PHS.PolicyResult
ORDER BY 1,2,3
GO', 
		@database_name=N'SQLOpsDB', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Daily0730', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20200311, 
		@active_end_date=99991231, 
		@active_start_time=73000, 
		@active_end_time=235959, 
		@schedule_uid=N'452855b1-2fbd-4628-9729-c609e317edc1'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO


