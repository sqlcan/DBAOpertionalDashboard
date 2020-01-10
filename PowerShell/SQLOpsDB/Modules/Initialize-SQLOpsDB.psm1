<#
.SYNOPSIS
Initialize-SQLOpsDB

.DESCRIPTION 
Initialize-SQLOpsDB

.INPUTS
None

.OUTPUTS
Initialize-SQLOpsDB

.EXAMPLE
Initialize-SQLOpsDB
Initialize the initial parameters such as server name & database names.  Also load the configuration settings
from the database.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2020.01.09 0.00.01 Initial Version.
                   Load the settings from the database and initialize the configuration.
                   Validate the range of each setting.
                   If settings are not loaded, then it will use default settings in
                   GlobalSettings.psm1.
2020.01.10 0.00.02 Fixed bug in how global variables are assigned.
#>
function Initialize-SQLOpsDB
{
    [CmdletBinding()] 
    param()

    $ModuleName = 'Initialize-SQLOpsDB'
    $ModuleVersion = '0.01'
    $ModuleLastUpdated = 'January 9, 2020'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        #Load the settings file.
        $JSONFileToLoad = Join-path (Split-Path $PSCommandPath -Parent) $Global:JSONSettingsFile
        Write-Output $JSonFileToLoad
        $Global:SQLOpsDBConnections = (Get-Content $JSONFileToLoad | ConvertFrom-Json)

        Write-StatusUpdate -Message $("SQLOpsDB Connect Settings (SQL: {0} Database: {1})" -f $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance, $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database)
        Write-StatusUpdate -Message $("CMS Connect Settings (SQL: {0} Database: {1})" -f $Global:SQLOpsDBConnections.Connections.CMSServer.SQLInstance, $Global:SQLOpsDBConnections.Connections.CMSServer.Database)

        #Test connections.
        $TSQL = 'SELECT @@ServerName'
        Write-StatusUpdate -Message $TSQL -IsTSQL
        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.CMSServer.SQLInstance `
                                    -Database $Global:SQLOpsDBConnections.Connections.CMSServer.Database `
                                    -Query $TSQL
        
        # We don't care about results from CMS server, we are just confirming connectivity.

        $TSQL = 'SELECT * FROM dbo.Setting'
        Write-StatusUpdate -Message $TSQL -IsTSQL
        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                            -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                            -Query $TSQL

        # Load settings from the database.  If the settings failed to retrieve, move forward with default settings.
        # If this did not trigger a critical error, maybe the dbo.settings table did not get populated with required
        # settings.

        IF ($Results)
        {
            $Global:SQLOpsDBInitialized = $true
            ForEach ($Setting in $Results)
            {
                switch ($Setting.SettingName)
                {
                    "DebugMode" {$Global:DebugMode = [Bool]$Setting.SettingValue}
                    "DebugMode_WriteToDB" {$Global:DebugMode_WriteToDB = [Bool]$Setting.SettingValue}
                    "DebugMode_OutputTSQL" {$Global:DebugMode_OutputTSQL = [Bool]$Setting.SettingValue}
                    "SQLOpsDB_Log_Enabled" {$Global:SQLOpsDB_Log_Enabled = [Bool]$Setting.SettingValue}
                    "SQLOpsDB_Log_CleanUp_Enabled" {$Global:SQLOpsDB_Log_CleanUp_Enabled = [Bool]$Setting.SettingValue}
                    "SQLOpsDB_Logs_CleanUp_Retention_Days" {$Global:SQLOpsDB_Logs_CleanUp_Retention_Days = [Int]$Setting.SettingValue}
                    "Expired_Objects_Enabled" {$Global:Expired_Objects_Enabled = [Bool]$Setting.SettingValue}
                    "Expired_Objects_CleanUp_Retention_Days" {$Global:Expired_Objects_CleanUp_Retention_Days = [Int]$Setting.SettingValue}
                    "Trend_Creation_Enabled" {$Global:Trend_Creation_Enabled = [Bool]$Setting.SettingValue}
                    "Trend_Creation_CleanUp_Enabled" {$Global:Trend_Creation_CleanUp_Enabled = [Bool]$Setting.SettingValue}
                    "Trend_Creation_CleanUp_Retention_Months" {$Global:Trend_Creation_CleanUp_Retention_Months = [Int]$Setting.SettingValue}
                    "Aggregate_CleanUp_Enabled" {$Global:Aggregate_CleanUp_Enabled = [Bool]$Setting.SettingValue}
                    "Aggregate_CleanUp_Retention_Months" {$Global:Aggregate_CleanUp_Retention_Months = [Int]$Setting.SettingValue}
                    "RawData_CleanUp_Enabled" {$Global:RawData_CleanUp_Enabled = [Bool]$Setting.SettingValue}
                    "Default_DomainName" {$Global:Default_DomainName = [String]$Setting.SettingValue}
                }
            }
        }
        else {
            $Global:SQLOpsDBInitialized = $true 
            Write-StatusUpdate -Message "Failed to load settings from dbo.Setting.  Using default settings." -WriteToDB
        }

        # Validate the range of all the settings.

        if (($Global:SQLOpsDB_Logs_CleanUp_Retention_Days -le 29) -or ($Global:SQLOpsDB_Logs_CleanUp_Retention_Days -ge 181))
        {
            $Global:SQLOpsDB_Logs_CleanUp_Retention_Days = 30
        }
        
        if (($Global:Expired_Objects_CleanUp_Retention_Days -le 89) -or ($Global:Expired_Objects_CleanUp_Retention_Days -ge 121))
        {
            $Global:Expired_Objects_CleanUp_Retention_Days = 90
        }

        if (($Global:Trend_Creation_CleanUp_Retention_Months -le 11) -or ($Global:Trend_Creation_CleanUp_Retention_Months -ge 61))
        {
            $Global:Trend_Creation_CleanUp_Retention_Months = 12
        }

        if (($Global:Aggregate_CleanUp_Retention_Months -le 11) -or ($Global:Aggregate_CleanUp_Retention_Months -ge 61))
        {
            $Global:Aggregate_CleanUp_Retention_Months = 12
        }

        if (($Global:RawData_CleanUp_Retention_Days -le 30) -or ($Global:RawData_CleanUp_Retention_Days -ge 63))
        {
            $Global:RawData_CleanUp_Retention_Days = 31
        }
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expectation" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}