# Key Settings
$Global:CMS_SQLServerName = "WSSQLTOOLS01T\CMS"
$Global:CMS_DatabaseName = "msdb"
$Global:SQLCMDB_SQLServerName = "WSSQLTOOLS01T\CMS"
$Global:SQLCMDB_DatabaseName = "DBA_Resource_Test"

$Global:DebugMode = $true
$Global:DebugMode_OutputTSQL = $false

$Global:Logs_CleanUp_Enabled = $true
$Global:Expired_CleanUp_Enabled = $true
$Global:Trending_CleanUp_Enabled = $true
$Global:Aggregate_CleanUp_Enabled = $true

$Global:RawData_Cleanup = 45                                 # Number of Days before clean up; valid range 31 - 62 Days.
$Global:Aggregate_Cleanup = 60                               # Number of Months before clean up; valid range 12 - 60 Months.
$Global:Trending_Cleanup = 60                                # Number of Months before deleting trending data; valid range 12 - 60 Months.
$Global:Expired_Cleanup = 91                                 # Number of Days before Expired Objects are cleaned up; valid range 90 - 120 Days.
$Global:Logs_CleanUp = 180                                   # Number of Days before Cleanup the Logs; valid range 30 - 180 Days.

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
