#  This script is designed to call the EPM script to do checks for all the policies.

param([Parameter(Mandatory=$false)] [switch]$IsDailyRun,
      [Parameter(Mandatory=$true)] [String]$CentralManagementServer)

$Versions = @("2005","2008","2012","2014","2016","2017","2019", "2022")

$EPMScriptPath = Join-Path $PSScriptRoot 'EPM_EnterpriseEvaluation_5.ps1'

if ($IsDailyRun)
{
     ForEach ($Version in $Versions)
    {
        .$EPMScriptPath -CentralManagementServer $CentralManagementServer -ConfigurationGroup "$Version" -PolicyCategoryFilter "Maintenance" -EvalMode "Check"
    }
}
else
{
    ForEach ($Version in $Versions)
    {
        .$EPMScriptPath -CentralManagementServer $CentralManagementServer -ConfigurationGroup "$Version" -PolicyCategoryFilter "Database Configuration" -EvalMode "Check"
        .$EPMScriptPath -CentralManagementServer $CentralManagementServer -ConfigurationGroup "$Version" -PolicyCategoryFilter "Security" -EvalMode "Check"
        .$EPMScriptPath -CentralManagementServer $CentralManagementServer -ConfigurationGroup "$Version" -PolicyCategoryFilter "Server Configuration" -EvalMode "Check"
    }
}