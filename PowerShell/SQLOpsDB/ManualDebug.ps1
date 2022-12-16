# Manual Debugging Script for SQLOpsDB Solution
#
# Not to be published with release.
#
#

Import-Module "C:\Repos\DBAOpertionalDashboard\PowerShell\SQLOpsDB\SQLOpsDB.psd1"

# Forward segment can change depending on what is being debugged.

$Data = Get-SIAvailabilityGroups -ServerInstance SQLAG1 -Internal

Write-SqlTableData -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
        -DatabaseName $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
        -TableName AG `
        -SchemaName Staging `
        -InputData $Data