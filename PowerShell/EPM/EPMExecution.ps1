#  This script is designed to call the EPM script to do checks for all the policies.

param([Parameter(Mandatory=$false)] [switch]$IsDailyRun,
      [Parameter(Mandatory=$true)] [String]$CentralManagementServer)

$Versions = @("SQL 2005","SQL 2008","SQL 2012","SQL 2014","SQL 2016","SQL 2017","SQL 2019", "SQL 2022")

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