USE [SQLOpsDB]
GO

-- I insert into @Settings first to allow for Merge command.  If the settings tables already exist,
-- I don't want to over-write the settings.

SET NOCOUNT ON

DECLARE @Setting AS TABLE (SettingName VARCHAR(50), SettingValue VARCHAR(255))

INSERT INTO @Setting (SettingName,SettingValue) 
     VALUES ('DebugModeEnabled','1'),
			('DebugMode_WriteToDB','0'),
	        ('DebugMode_OutputTSQL','0'),
			('SQLOpsDB_Logs_Enabled','1'),
			('SQLOpsDB_Logs_CleanUp_Enabled','1'),
			('SQLOpsDB_Logs_CleanUp_Retention_Days','180'),
			('Expired_Objects_Enabled','1'),
			('Expired_Objects_CleanUp_Retention_Days','91'),
			('Trend_Creation_Enabled','1'),
			('Trend_Creation_CleanUp_Enabled','1'),
			('Trend_Creation_CleanUp_Retention_Months','60'),
			('Aggregate_CleanUp_Enabled','1'),
			('Aggregate_CleanUp_Retention_Months','60'),
			('RawData_CleanUp_Enabled','1'),
			('RawData_CleanUp_Retention_Days','45'),
			('ErrorLog_CleanUp_Enabled','1'),
			('ErrorLog_CleanUp_Retention_Days','90'),
			('SQLAgent_Jobs_CleanUp_Enabled','1'),
			('SQLAgent_Jobs_CleanUp_Retention_Days','180'),
			('PolicyResult_CleanUp_Enabled','1'),
			('PolicyResult_CleanUp_Retention_Days','7'),
			('Default_DomainName','Contoso.lab.com')


MERGE dbo.Setting AS Target
USING (SELECT SettingName, SettingValue FROM @Setting) AS Source (SettingName, SettingValue)
ON (Target.SettingName = Source.SettingName)
WHEN NOT MATCHED THEN
	INSERT (SettingName,SettingValue)
	VALUES (Source.SettingName, Source.SettingValue);
GO