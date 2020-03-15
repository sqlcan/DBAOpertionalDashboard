# 2020.01.09 Going forward this file will only contain settings that required for the solution
#            all other settings will either migration to JSON or in-database table.
#            Until migration is completed, both settings will be used together to prevent solution
#            from breaking.

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

[String]$Global:Default_DomainName = $null # Loaded from dbo.Setting.

# Key Settings
$Global:CMS_SQLServerName = "MOGUPTA-PC01"
$Global:CMS_DatabaseName = "msdb"
$Global:SQLCMDB_SQLServerName = "MOGUPTA-PC01"
$Global:SQLCMDB_DatabaseName = "DBA_Dashboard_PROD"

# Global Settings Below as above, these are kept for backwards compatibility.
# To be removed as the respective modules are updated.
$Global:Logs_CleanUp_Enabled = $true
$Global:Logs_CleanUp = 180
$Global:Expired_CleanUp_Enabled = $true
$Global:Expired_Cleanup = 91
$Global:Trending_CleanUp_Enabled = $true
$Global:Trending_Cleanup = 60
$Global:Aggregate_CleanUp_Enabled = $true
$Global:Aggregate_Cleanup = 60
$Global:RawData_Cleanup = 45

# Constants

$Global:OutputLevel_Zero = 0
$Global:OutputLevel_One = 1
$Global:OutputLevel_Two = 2
$Global:OutputLevel_Three = 3
$Global:OutputLevel_Four = 4
$Global:OutputLevel_Five = 5
$Global:OutputLevel_Six = 6
$Global:OutputLevel_Seven = 7
$Global:OutputLevel_Eight = 8
$Global:OutputLevel_Nine = 9
$Global:OutputLevel_Ten = 10


# Errors
$Global:Error_Successful = 0
$Global:Error_FailedToComplete = -1
$Global:Error_Duplicate = -2
$Global:Error_ObjectsNotFound = -3
$Global:Error_NotApplicable = -4
