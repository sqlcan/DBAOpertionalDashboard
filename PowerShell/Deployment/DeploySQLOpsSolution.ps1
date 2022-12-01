<#
.SYNOPSIS
Deploy SQL Operation Dashboard solution.  This script tries to automate
as much of the deployment as possible.

.DESCRIPTION 
Deploying SQLOps solution manual is tedious and leads to missed configuration.
This script will follow systematic approach of installing new deployment.

This script is designed to deploy the complete SQLOps solution.
1) Policies
2) Databases
3) SQL Reports
4) Windows Scheduler Jobs

The deployment solution should be executed on the Server where PowerShell &
Task jobs need to be created.

.PARAMETER ServerInstance
SQL Server instance to deploy the database and all its related components.

.PARAMETER  DeploymentLocation
Location where PowerShell solution should be deployed.

.PARAMETER WorkingDirectory
Location where the zip files will be extracted.

.PARAMETER ComputerName
Location where Windows Scheduler task jobs will be created for the PowerShell solutions.

.PARAMETER ReportLogo
Location where the Report logo exists, the file size should be 225x54 pixcels. If none
is supplied it will default to "SQL Canada" logo.  The path and file must be accessible
from the ServerInstance.

.PARAMETER ReportLogoFileType
File type supported by SSRS, png, jpeg, gif, and bmp. Defaults to png.

.INPUTS
None

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2020.11.11 1.00.00 Initial Version
2022.11.22 2.00.00 Re-Write with RC-0.
2022.11.26 2.00.03 Updated to fix for JSON special characters, copied SSRS reports over
                   to destination, and created a read me folder.
#>

#Requires -Module SQLServer

param (
	[Parameter(Position=0, Mandatory=$true)] [string]$ServerInstance,
	[Parameter(Position=1, Mandatory=$true)] [string]$ComputerName,
	[Parameter(Position=2, Mandatory=$true)] [string]$DeploymentLocation,
    [Parameter(Position=3, Mandatory=$true)] [string]$WorkingDirectory,
    [Parameter(Position=4, Mandatory=$false)] [string]$ReportLogo="SQLCanadaLogo.png",
    [Parameter(Position=5, Mandatory=$false)] [string]$ReportLogoFileType="png"
)

function Write-Status
{
	param ( 
		[Parameter(Position=0, Mandatory=$true)] [int] $Level,
		[Parameter(Position=1, Mandatory=$true)] [string] $Message,
        [Parameter(Position=2, Mandatory=$true)] [string] $Color)

    $Ident = ""
    [int]$I = 0

    For ([int]$I = 0;$I -le $Level;$I++)
    {
        $Ident += "... "
    }
    Write-Host $Ident -NoNewline
    Write-Host $Message -ForegroundColor $Color
}

Import-Module SQLServer

if ($Host.Name -ne 'ConsoleHost')
{
	Write-Status 0, "Execute script using the PowerShell console.", "Red"
	return
}

$SolutionFileHash = "D97AE11E71325E2204D99D36D50345CAEBFB653696A1A0F0B8E05F7E9D2E892E"
$SolutionFileName = "SQLOpDB_Solution_V3.00.00.0000.zip"
$DSPath = $PSScriptRoot

$a = (Get-Host).UI.RawUI
$WindowWidth = $a.WindowSize.Width
$a.WindowTitle = $ModuleName
$Heading = "SQL Server Operational Dashboard Deployment Script"
$Heading_Version = "Version 3.00.00"

Clear-Host
Write-Host " " -NoNewline 
Write-Host ("*" * ($WindowWidth - 2)) -ForegroundColor Yellow
Write-Host " **" -NoNewline -ForegroundColor Yellow
Write-Host (" " * [Math]::Floor(($WindowWidth - 6 - $Heading.Length) / 2)) -NoNewline
Write-Host $Heading -NoNewline -ForegroundColor Cyan
Write-Host (" " * [Math]::Ceiling(($WindowWidth - 6 - $Heading.Length) / 2)) -NoNewline
Write-Host "**" -ForegroundColor Yellow
Write-Host " **" -NoNewline -ForegroundColor Yellow
Write-Host (" " * [Math]::Floor(($WindowWidth - 6 - $Heading_Version.Length) / 2)) -NoNewline
Write-Host $Heading_Version -NoNewline -ForegroundColor Green
Write-Host (" " * [Math]::Ceiling(($WindowWidth - 6 - $Heading_Version.Length) / 2)) -NoNewline
Write-Host "**" -ForegroundColor Yellow
Write-Host " " -NoNewline 
Write-Host ("*" * ($WindowWidth - 2)) -ForegroundColor Yellow
Write-Host " "

Write-Status -Level 0 -Message "Deployment Validation" -Color "White"

Write-Status -Level 1 -Message "Validating deployment package" -Color "White"
$SolutionFile = Join-Path $DSPath $SolutionFileName
if (!(Test-Path $SolutionFile))
{
    Write-Status -Level 2 -Message "Unable to find the solution file [$SolutionFile]." -Color "Red"
    return
}

$FileHash = Get-FileHash $SolutionFile
if ($FileHash.Hash -ne $SolutionFileHash)
{
    Write-Status -Level 2 -Message "File hash does not match released solution." -Color "Red"
    return
}
Write-Status -Level 2 -Message "Deployment package validation completed." -Color "Green"

Write-Status -Level 1 -Message "Validating deployment location." -Color "White"

if (!(Test-Path $DeploymentLocation))
{
    Write-Status -Level 2 -Message "[$DeploymentLocation] path is missing.  Creating the directory." -Color "Yellow"
    New-Item -Path $DeploymentLocation -Type directory | Out-Null
    Write-Status -Level 2 -Message "[$DeploymentLocation] created." -Color "Yellow"
}
Write-Status -Level 2 -Message "Deployment location validation completed." -Color "Green"

Write-Status -Level 1 -Message "Validating working directory location." -Color "White"

if (!(Test-Path $WorkingDirectory))
{
    Write-Status -Level 2 -Message "[$WorkingDirectory] path is missing.  Creating the directory." -Color "Yellow"
    New-Item -Path $WorkingDirectory -Type directory | Out-Null
    Write-Status -Level 2 -Message "[$WorkingDirectory] created." -Color "Yellow"
}
Write-Status -Level 2 -Message "Working directory location validation completed." -Color "Green"

Write-Status -Level 1 -Message "Extracting solution to working directory." -Color "White"
Expand-Archive -Path $SolutionFile -DestinationPath $WorkingDirectory -Force
Write-Status -Level 2 -Message "Extraction completed." -Color "Green"

$Solution_DatabaseScripts = Join-Path $WorkingDirectory "SQLOpDB_Solution_V3.00.00.0000\Database"
$Solution_PowershellScripts = Join-Path $WorkingDirectory "SQLOpDB_Solution_V3.00.00.0000\PowerShell"
$Solution_SQLPolicies =  Join-Path $WorkingDirectory "SQLOpDB_Solution_V3.00.00.0000\SQL Policies"
$Solution_Reports =  Join-Path $WorkingDirectory "SQLOpDB_Solution_V3.00.00.0000\Traditional SSRS"
$Solution_Logo =   Join-Path $WorkingDirectory "SQLOpDB_Solution_V3.00.00.0000\Logo"
$Solution_ReadMe =   Join-Path $WorkingDirectory "SQLOpDB_Solution_V3.00.00.0000\ReadMe"

Write-Status -Level 3 -Message "Solution Database Scripts: $Solution_DatabaseScripts" -Color "Gray"
Write-Status -Level 3 -Message "Solution PowerShell Scripts: $Solution_PowershellScripts" -Color "Gray"
Write-Status -Level 3 -Message "Solution SQL Policies: $Solution_SQLPolicies" -Color "Gray"
Write-Status -Level 3 -Message "Solution SSRS Reports: $Solution_Reports" -Color "Gray"
Write-Status -Level 3 -Message "Solution Report Logo: $Solution_Logo" -Color "Gray"

$Solution_SQLPolicies_ArchiveFile = Join-Path $Solution_SQLPolicies 'SQL Policies.zip'
Write-Status -Level 1 -Message "Extracting SQL policies Solution SQL Policies directory." -Color "White"
Expand-Archive -Path $Solution_SQLPolicies_ArchiveFile -DestinationPath $Solution_SQLPolicies -Force
Write-Status -Level 2 -Message "Extraction completed." -Color "Green"
$TotalPolicies = ((Get-ChildItem -Path $Solution_SQLPolicies -Filter *.xml) | Measure-Object).Count
Write-Status -Level 3 -Message "Total policies extracted: $TotalPolicies" -Color "Gray"

Write-Status -Level 1 -Message "Deploying SQL Policies to [$ServerInstance]" -Color "White"
Write-Status -Level 2 -Message "Deploy the policies located in [$Solution_SQLPolicies] via SQL Server Management Studio, Import functionality." -Color "White"
Write-Status -Level 2 -Message "If you have existing policies deployed these are not required.  However, verify the policy categories do match in the 'EPM\EPMExecution.ps1'" -Color "White"
Write-Status -Level 2 -Message "Press Enter to continue deployment." -Color "Yellow"
Read-Host

Write-Status -Level 1 -Message "Checking of [SQLOpsDB] exists on [$ServerInstance]" -Color "White"
$Results = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database master -Query "SELECT COUNT(*) DBCount FROM sys.databases WHERE name = 'SQLOpsDB'"

if ($Results.DBCount -eq 0)
{
	Write-Status -Level 2 -Message "New database ..." -Color "White"	
	Write-Status -Level 1 -Message "Deploying SQL Scripts to [$ServerInstance]" -Color "White"
	$TotalSQLFiles = ((Get-ChildItem -Path $Solution_DatabaseScripts) | Measure-Object).Count
	Write-Status -Level 2 -Message "Total SQL Scripts found: $TotalSQLFiles" -Color "Gray"
	Write-Status -Level 2 -Message "Starting deployment" -Color "White"
	$SQLFiles = Get-ChildItem -Path $Solution_DatabaseScripts -Filter *.sql
	ForEach ($SQLFile in $SQLFiles)
	{
		$SQLFileName = $SQLFile.FullName  
		$Decision = 0

		if ($SQLFileName -like '*_Ask*')
		{
			Write-Status -Level 3 -Message "[$SQLFileName] has been marked optional." -Color "Yellow"
			$Decision = $Host.UI.PromptForChoice('Do you want to run the optional script? If not sure refer to GitHub for details.','Should the script be deployed?',@('&Yes','&No'),1)
		}

		if ($Decision -eq 0)
		{
			Write-Status -Level 3 -Message "Deploying [$SQLFileName]." -Color "Yellow"

			try
			{        
				Invoke-Sqlcmd -ServerInstance $ServerInstance -Database master -InputFile $SQLFileName
			}
			catch
			{
				Write-Status -Level 4 -Message "Script failed [$SQLFileName]." -Color "Red"
			}
		}
	}
	Write-Status -Level 2 -Message "Database Deployment Completed." -Color "Green"

	if ($ReportLogo -eq "SQLCanadaLogo.png")
	{
		$LogoFile = Join-Path $Solution_Logo $ReportLogo
	}
	else
	{
		$LogoFile = $ReportLogo
	}
	Write-Status -Level 1 -Message "Deploying Report Logo." -Color "White"
	$TSQL = "INSERT INTO Reporting.ReportLogo (LogoFileName, LogoFileType, LogoFile)
			 SELECT 'DefaultReportLogo', 'png', (SELECT * FROM OPENROWSET(BULK '$LogoFile', SINGLE_BLOB) AS ReadFile) LogFile"
	Invoke-Sqlcmd -ServerInstance $ServerInstance -Database SQLOpsDB -Query $TSQL

	Write-Status -Level 2 -Message "Report Logo Deployed." -Color "Green"
}
else
{
	Write-Status -Level 2 -Message "Database already exists.  Database will not be deployed." -Color "Yellow"
}

Write-Status -Level 1 -Message "Deploying the PowerShell Solution." -Color "White"
Copy-Item -Path $Solution_PowershellScripts -Destination $DeploymentLocation -Recurse -Force
Write-Status -Level 2 -Message "Unblocking All Files" -Color "White"
Get-ChildItem $DeploymentLocation -Recurse | Unblock-File
Write-Status -Level 2 -Message "PowerShell Solutions Deployment Completed." -Color "Green"

Write-Status -Level 1 -Message "Updating Configuration Files." -Color White
$JsonConfigFile = Join-Path $DeploymentLocation "PowerShell\SQLOpsDB\Config\SQLOpsDB.json"
$JsonPayload = "{`"Connections`":[{`"SQLOpsDBServer`":{`"SQLInstance`":`"$($ServerInstance.Replace('\', '\\'))`",`"Database`":`"SQLOpsDB`"}}]}"
$JsonPayload | Out-File $JsonConfigFile
Write-Status -Level 2 -Message "Config file updated to [$ServerInstance] value." -Color "Green"

Write-Status -Level 1 -Message "Do you want to deploy the Windows Scheduler Tasks for [SQLOpDB Collection]?" -Color "Yellow"
$Decision = $Host.UI.PromptForChoice('Decision','Deployed?',@('&Yes','&No'),1)

if ($Decision -eq 0)
{
    Write-Status -Level 1 -Message "Deploying SQLOpsDB.DataCollection Windows Scheduler Task" -Color "White"
    $CIMSession = New-CIMSession -ComputerName $ComputerName
    if (!(Get-ScheduledTask -CimSession $CIMSession | Where-Object {$_.TaskName -eq 'SQLOpsDB.DataCollection'}))
    {

        $CollectionScript = Join-Path $DeploymentLocation "PowerShell\CollectionScript\SQLOpsDB_DataCollection.ps1"
	    $taskAction = New-ScheduledTaskAction -Execute 'powershell.exe' `
	    -Argument "-ExecutionPolicy Bypass -File `"$CollectionScript`" " `
	    -WorkingDirectory "$(Join-Path $DeploymentLocation "PowerShell\CollectionScript")"

	    Register-ScheduledTask -TaskName 'SQLOpsDB.DataCollection' `
						       -Action $taskAction `
						       -CIMSession $CIMSession | Out-Null	
    }
    Write-Status -Level 2 -Message "Task deployed, please define the schedule & login name for execution." -Color "Gray"
    Write-Status -Level 2 -Message "Recommended Schedule: Daily 6 AM" -Color "Yellow"
    Write-Status -Level 2 -Message "SQLOpsDB.DataCollection Windows Scheduler Task Deployed!" -Color "Green"
}

Write-Status -Level 1 -Message "Do you want to deploy the Windows Scheduler Tasks for [Daily Policy Collection]?" -Color "Yellow"
$Decision = $Host.UI.PromptForChoice('Decision','Deployed?',@('&Yes','&No'),1)

if ($Decision -eq 0)
{
    Write-Status -Level 1 -Message "Deploying SQLOpsDB.ConfigurationHealth.Daily Windows Scheduler Task" -Color "White"
    $CIMSession = New-CIMSession -ComputerName $ComputerName
    if (!(Get-ScheduledTask -CimSession $CIMSession | Where-Object {$_.TaskName -eq 'SQLOpsDB.ConfigurationHealth.Daily'}))
    {

        $CollectionScript = Join-Path $DeploymentLocation "PowerShell\EPM\EPMExecution.ps1"
	    $taskAction = New-ScheduledTaskAction -Execute 'powershell.exe' `
	    -Argument "-ExecutionPolicy ByPass -File `"$CollectionScript`" -IsDailyRun" `
	    -WorkingDirectory "$(Join-Path $DeploymentLocation "PowerShell\EPM")"

	    Register-ScheduledTask -TaskName 'SQLOpsDB.ConfigurationHealth.Daily' `
						       -Action $taskAction `
						       -CIMSession $CIMSession | Out-Null	
    }
    Write-Status -Level 2 -Message "Task deployed, please define the schedule & login name for execution." -Color "Gray"
    Write-Status -Level 2 -Message "Recommended Schedule: Daily 2 AM" -Color "Yellow"
    Write-Status -Level 2 -Message "SQLOpsDB.ConfigurationHealth.Daily Windows Scheduler Task Deployed!" -Color "Green"
}

Write-Status -Level 1 -Message "Do you want to deploy the Windows Scheduler Tasks for [Weekly Policy Collection]?" -Color "Yellow"
$Decision = $Host.UI.PromptForChoice('Decision','Deployed?',@('&Yes','&No'),1)

if ($Decision -eq 0)
{
    Write-Status -Level 1 -Message "Deploying SQLOpsDB.ConfigurationHealth.Weekly Windows Scheduler Task" -Color "White"
    $CIMSession = New-CIMSession -ComputerName $ComputerName
    if (!(Get-ScheduledTask -CimSession $CIMSession | Where-Object {$_.TaskName -eq 'SQLOpsDB.ConfigurationHealth.Weekly'}))
    {

        $CollectionScript = Join-Path $DeploymentLocation "PowerShell\EPM\EPMExecution.ps1"
	    $taskAction = New-ScheduledTaskAction -Execute 'powershell.exe' `
	    -Argument "-ExecutionPolicy ByPass -File `"$CollectionScript`"" `
	    -WorkingDirectory "$(Join-Path $DeploymentLocation "PowerShell\EPM")"

	    Register-ScheduledTask -TaskName 'SQLOpsDB.ConfigurationHealth.Weekly' `
						       -Action $taskAction `
						       -CIMSession $CIMSession | Out-Null	
    }
    Write-Status -Level 2 -Message "Task deployed, please define the schedule & login name for execution." -Color "Gray"
    Write-Status -Level 2 -Message "Recommended Schedule: Weekly Every Sunday 4 AM" -Color "Yellow"
    Write-Status -Level 2 -Message "SQLOpsDB.ConfigurationHealth.Weekly Windows Scheduler Task Deployed!" -Color "Green"
}

Write-Status -Level 1 -Message "Copying the Read Me files." -Color "White"
Copy-Item -Path $Solution_ReadMe -Destination $DeploymentLocation -Recurse -Force
Write-Status -Level 2 -Message "ReadMe files Copied." -Color "Green"

Write-Status -Level 1 -Message "Copying the SSRS Reports." -Color "White"
Copy-Item -Path $Solution_Reports -Destination $DeploymentLocation -Recurse -Force
Write-Status -Level 2 -Message "SSRS Reports Copied." -Color "Green"
Write-Status -Level 2 -Message "Deploy SQL Server Reports using Visual Studio.  Update the dsMain connection string and SSRS server before deployment." -Color "Gray"
Write-Status -Level 2 -Message "Reports are located in [$Solution_Reports]." -Color "Gray"

Write-Host ""
Write-Host ""

Write-Status -Level 1 -Message "Deployment Completed.  The extracted files and zip are not deleted.  Please clean them manually!" -Color "Green"