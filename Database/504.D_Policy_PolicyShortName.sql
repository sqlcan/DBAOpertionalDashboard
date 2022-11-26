USE [SQLOpsDB]
GO

CREATE TABLE #ShortPolicyName (FullPolicyName VARCHAR(255), ShortPolicyName VARCHAR(255))
GO

INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Advanced Options Turned On','Server Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('All Data Files are Same Size in TempDB','TempDB')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Allow Updates Turned On','Database Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Auto Create Statistics is Disabled','Database Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Auto Update Statistics Is Disabled','Database Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Backup and Data File Location','File Location')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('CmdExec Rights Secured','Server Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Current Size for TempDB Is Configured Size','TempDB')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Data and Log File Location','File Location')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Database Auto Close','Database Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Database Auto Shrink','Database Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Database Collation','Database Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Database Consistency Check Completed','Database Consistency Check')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Database Data File Growth Setting is Not 1MB','Database File Size')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Database Data File Growth Settings is Not Percent','Database File Size')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Database Log File Growth Setting is Less than 1024MB','Database File Size')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Database Log File Growth Setting is Not 1MB','Database File Size')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Database Log File Growth Setting is Not Percent','Database File Size')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Database Page Status','Database Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Database Page Verification','Database Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Database Recovery Model Is Simple','Database Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Databases Found with Disabled Indexes','Indexes')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Fill Factor Configured','Server Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Guest Permissions','Guest')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Large Number of Virtual Log Files','VLF')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Last Successful Backup Date','Backups')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Last Successful Log Backup Date','Backups')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Login ''sa'' is Enabled','Server Security')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Max Degree of Parallelism Configured','MAXDOP')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Max Memory Not Set to Default Value','Memory')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Max Server Memory is at least 1GB','Memory')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Max Worker Thread Not Set to Default','Server Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Min Memory Does Not Equal Max Server Memory','Memory')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Min Memory Not Set to Default Value','Memory')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Min Server Memory at Least 25% Of Max Memory','Memory')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Number of TempDB Files','TempDB')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Optimize for Ad Hoc Workload Truned Off','Server Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Orphaned Windows NT Logins Found','Server Security')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Public Database Role Has No Access','Database Security')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Read-only Database Recovery Model','Database Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Recovery Interval Setting Changed from Default','Database Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Remote Dedicated Admin Connection is Enabled','Server Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('SQL Server Affinity Mask','Server Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('SQL Server Blocked Process Threshold','Server Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('SQL Server Default Trace','Server Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('SQL Server Dynamic Locks','Server Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('SQL Server Login Mode','Server Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('SQL Server System Tables Updatable','Server Options')
INSERT INTO #ShortPolicyName (FullPolicyName, ShortPolicyName) VALUES ('Transaction Log Bigger then Data Files Size','Database File Size')
GO

INSERT INTO Policy.PolicyShortName
SELECT sp.policy_id, tmp.ShortPolicyName
  FROM #ShortPolicyName tmp
  JOIN msdb.dbo.syspolicy_policies sp
    ON tmp.FullPolicyName = sp.name
GO