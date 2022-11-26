#  This script is designed to call the EPM script to do checks for all the policies.
param([Parameter(Mandatory=$false)] [switch]$IsDailyRun)

Import-Module '..\SQLOpsDB\SQLOpsDB.psd1'
Initialize-SQLOpsDB | Out-Null
 
$EPMScriptPath = Join-Path $PSScriptRoot 'EPM_EnterpriseEvaluation_5.ps1'
$CentralManagementServer = $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance
$HistoryDatabase = $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database
$CMSGroups = Get-SQLOpCMSGroups | ? {$_.IsMonitored -eq $true}
 
if ($IsDailyRun)
{
    ForEach ($CMSGroup in $CMSGroups)
    {
        .$EPMScriptPath -CentralManagementServer $CentralManagementServer -HistoryDatabase $HistoryDatabase -ConfigurationGroup "$($CmsGroup.GroupName)" -PolicyCategoryFilter "Maintenance" -EvalMode "Check"
    }
}
else
{
    ForEach ($CMSGroup in $CMSGroups)
    {
        .$EPMScriptPath -CentralManagementServer $CentralManagementServer -HistoryDatabase $HistoryDatabase -ConfigurationGroup "$($CmsGroup.GroupName)" -PolicyCategoryFilter "Database Configuration" -EvalMode "Check"
        .$EPMScriptPath -CentralManagementServer $CentralManagementServer -HistoryDatabase $HistoryDatabase -ConfigurationGroup "$($CmsGroup.GroupName)" -PolicyCategoryFilter "Security" -EvalMode "Check"
        .$EPMScriptPath -CentralManagementServer $CentralManagementServer -HistoryDatabase $HistoryDatabase -ConfigurationGroup "$($CmsGroup.GroupName)" -PolicyCategoryFilter "Server Configuration" -EvalMode "Check"
    }
}