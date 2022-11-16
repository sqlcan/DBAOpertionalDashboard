# 2020.01.09 Going forward this file will only contain settings that required for the solution
#            all other settings will either migration to JSON or in-database table.
#            Until migration is completed, both settings will be used together to prevent solution
#            from breaking.
#
# 2022.10.30 Removed all the old settings, only global settings that are populated by JSON file
#			 will be consumed.
#
# 2022.11.15 Added setting for Policy Results Clean up.

# By default connection information will be loaded from JSON File.
$Global:JSONSettingsFile = '\..\Config\SQLOpsDB.json'
$Global:SQLOpsDBConnections = $null # Loaded via Initialize-SQLOpsDB
$Global:SQLOpsDBInitialized = $false

# Below are the defaults applied when failed to load from database.
[Bool]$Global:DebugMode = $true
[Bool]$Global:DebugMode_WriteToDB = $false
[Bool]$Global:DebugMode_OutputTSQL = $false

[Bool]$Global:SQLOpsDB_Log_Enabled = $true
[Bool]$Global:SQLOpsDB_Log_CleanUp_Enabled = $true
[Int]$Global:SQLOpsDB_Logs_CleanUp_Retention_Days = 180          # Number of Days before Cleanup the Logs; valid range 30 - 180 Days.
                                                                 # If value is higher, it will be enforced to the lower limit.

[Bool]$Global:Expired_Objects_Enabled = $true
[Int]$Global:Expired_Objects_CleanUp_Retention_Days = 91         # Number of Days before Expired Objects are cleaned up; valid range 90 - 120 Days.

[Bool]$Global:Trend_Creation_Enabled = $true
[Bool]$Global:Trend_Creation_CleanUp_Enabled = $true
[Int]$Global:Trend_Creation_CleanUp_Retention_Months = 60        # Number of Months before deleting trending data; valid range 12 - 60 Months.

[Bool]$Global:Aggregate_CleanUp_Enabled = $true
[Int]$Global:Aggregate_CleanUp_Retention_Months = 60             # Number of Months before clean up; valid range 12 - 60 Months.

[Bool]$Global:RawData_CleanUp_Enabled = $true
[Int]$Global:RawData_CleanUp_Retention_Days = 45                 # Number of Days before clean up; valid range 31 - 62 Days.

[Bool]$Global:ErrorLog_CleanUp_Enabled = $true
[Int]$Global:ErrorLog_CleanUp_Retention_Days = 45                # Number of Days before clean up; valid range 30 - 180 Days.

[Bool]$Global:SQLAgent_Jobs_CleanUp_Enabled = $true
[Int]$Global:SQLAgent_Jobs_CleanUp_Retention_Days = 180          # Number of Days before clean up; valid range 30 - 180 Days.

[Bool]$Global:PolicyResult_CleanUp_Enabled = $true
[Int]$Global:PolicyResult_CleanUp_Retention_Days = 7          # Number of Days before clean up; valid range 1 - 15 Days.

[String]$Global:Default_DomainName = $null # Loaded from dbo.Setting.

# Errors
$Global:Error_Successful = 0
$Global:Error_FailedToComplete = -1
$Global:Error_Duplicate = -2
$Global:Error_ObjectsNotFound = -3
$Global:Error_NotApplicable = -4
