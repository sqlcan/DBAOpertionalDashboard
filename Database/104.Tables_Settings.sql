--     Purpose: This table stores the configuration settings for the PowerShell
--              collection script.
--
--              If table already exists settings table is deleted and rereated.
--              Before deleting backup of the existing table will be stored in Settings_BACKUPYYYYMMDD.

--   Script By: Mohit K. Gupta (mogupta@microsoft.com)
--  Script Ver: 1.00
-- Last Tested: Oct. 3, 2020

USE [SQLOpsDB]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'Setting')
BEGIN
	-- Only trigger backup if there is data to be saved.
	IF ((SELECT COUNT(*) FROM dbo.Setting) > 0)
	BEGIN
		DECLARE @NewTableName NVARCHAR(255) = 'Settings_BACKUP' + CONVERT(VARCHAR(8),GETDATE(),112)
		-- If script is run multiple times in a day, do not attempt to make additional backup copies.
		IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = @NewTableName)
		BEGIN
			EXEC ('SELECT *
			         INTO dbo.' + @NewTableName + '
			         FROM dbo.Setting')
			EXEC sys.sp_addextendedproperty @name=N'CreatedBy', @value=N'SQLOpsDB Creation Script' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=@NewTableName
			EXEC sys.sp_addextendedproperty @name=N'Purpose', @value=N'Backup of the settings table. Review the table name for date created.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=@NewTableName
		END
	END
	DROP TABLE dbo.Setting
END

CREATE TABLE [dbo].[Setting](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[SettingName] [varchar](50) NOT NULL,
	[SettingValue] [varchar](255) NOT NULL,
 CONSTRAINT [PK_Setting] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE UNIQUE INDEX Setting_SettingName ON dbo.Setting(SettingName)
GO