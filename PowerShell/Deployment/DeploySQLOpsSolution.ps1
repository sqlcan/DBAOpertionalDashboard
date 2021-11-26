<#
.SYNOPSIS
Deploy SQL Operation Dashboard solution.  This script tries to automate
as much of the deployment as possible.

.DESCRIPTION 
Deploying SQLOps solution manual is tedious and leads to missed configuration.
This script will follow systematic approach of installing or updating an 
existing install for almost all components.

This script is designed to deploy the complete SQLOps solution.
1) Compare and update PowerShell realted files
   - Collection Scripts
   - SQLOps Modules Manifesta
   - SQLOps Modules Command Lets
2) Database updates
   - Not sure how to do this yet.  If object exists, most deployments will be ignored.
   - Unless roll forward script can be designed.
3) Deploy reports.
   - This will continued to be deployed using Visual Studio.

.PARAMETER ServerInstance
SQL server instance where the SQLOpsDB is installed or you wish to create the database.

.PARAMETER  DeploymentLocation
Location where PowerShell solution should be deployed.

.PARAMETER ComputerName
Location where Windows Scheduler task jobs will be created for the PowerShell solutions.

.INPUTS
None

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2020.11.11 1.00.00 Initial Version
#>

#Requires -Module SQLServer

param (
	[Parameter(Position=0, Mandatory=$true)] [string]$ServerInstance,
	[Parameter(Position=1, Mandatory=$true)] [string]$ComputerName,
	[Parameter(Position=2, Mandatory=$true)] [string]$DeploymentLocation
)

<#  This function purpose is to copy files from source to destination.

	It has minimal validation, all validation and checks must be completed
	before executing this procedure.
#>
function Copy-Files
{
	param (
		[Parameter(Position=0, Mandatory=$true)] [string]$SrcLocation,
		[Parameter(Position=1, Mandatory=$true)] [string]$DstLocation)

	$SrcFiles = Get-ChildItem $SrcLocation -File
	$DstFiles = Get-ChildItem  $DstLocation -File

	Write-Host "... Copying files from [" -NoNewLine
	Write-Host $SrcLocation -NoNewLine -ForegroundColor Yellow
	Write-Host "]"
	Write-Host "... Copying files to [" -NoNewLine
	Write-Host $DstLocation -NoNewLine -ForegroundColor Yellow
	Write-Host "]"

	foreach ($SrcFile In $SrcFiles)
	{
		$SrcFileHash = (Get-FileHash $SrcFile.FullName).Hash
		$DstFileHash = ""
		$DstFileExists = $false
		$DstFileUpdated = $false

		foreach ($DstFile in $DstFiles) {
			if ($DstFile.Name -eq $SrcFile.Name)
			{
				$DstFileExists = $true
				$DstFileHash = (Get-FileHash $DstFile.FullName).Hash
	
				if ($DstFileHash -ne $SrcFileHash)
				{
					$DstFileUpdated = $true
					Copy-Item $SrcFile.FullName $DstFile.Fullname -Force
				}
	
				break;
			}
		}
	
		if (!($DstFileExists))
		{
			Copy-Item $SrcFile.FullName $DstLocation
		}

		$StatusMsg = ""
		$MsgColor = ""

		if (($DstFileExists) -and ($DstFileUpdated))
		{
			$StatusMsg = " Updated "
			$MsgColor = "Yellow"
		}
		elseif (($DstFileExists) -and !($DstFileUpdated))
		{
			$StatusMsg = "No Change"
			$MsgColor = "Gray"
		}
		elseif (!($DstFileExists))
		{
			$StatusMsg = "Installed"
			$MsgColor = "Green"
		}

		Write-Host "... ... " -NoNewLine -ForegroundColor White
		Write-Host $SrcFile.Name -ForegroundColor Cyan -NoNewline
		Write-Host (" " * (40 - ($($SrcFile.Name).Length))) -NoNewline
		Write-Host " [" -NoNewLine -ForegroundColor White 
		Write-Host $SrcFileHash -NoNewLine -ForegroundColor Yellow 
		Write-Host "][" -NoNewLine -ForegroundColor White
		Write-Host $StatusMsg -ForegroundColor $MsgColor -NoNewLine 
		Write-Host "]" -ForegroundColor White
	}
}

function Create-Folder
{
	param (
		[Parameter(Position=0, Mandatory=$true)] [string]$Path,
		[Parameter(Position=1, Mandatory=$true)] [string]$FolderName)

	$FullPath = Join-Path $Path $FolderName
	$StatusMsg = "Skipped"
	$MsgColor = "Gray"

	if (!(Test-Path $FullPath))
	{
		New-Item -Path $Path -Name FolderName -Type directory | Out-Null
		$StatusMsg = "Created"
		$MsgColor = "Green"
	}

	Write-Host "... ... " -NoNewLine -ForegroundColor White
	Write-Host $FullPath -ForegroundColor Cyan -NoNewline
	Write-Host (" " * (106 - ($FullPath.Length))) -NoNewline
	Write-Host " [" -NoNewLine -ForegroundColor White
	Write-Host $StatusMsg -ForegroundColor $MsgColor -NoNewLine 
	Write-Host "]" -ForegroundColor White

	return $FullPath
}

if ($Host.Name -ne 'ConsoleHost')
{
	#Write-Error "Execute script using the PowerShell console."
	#return
}

$DBExists = $false
$SolutionDeployed = $false

$a = (Get-Host).UI.RawUI
$WindowWidth = $a.WindowSize.Width
$a.WindowTitle = $ModuleName
$Heading = "SQL Server Operational Dashboard Deployment Script"
$Heading_Version = "Version 3.00.17.0002"

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
Write-Host "Deployment Validation"
Write-Host "... Connecting to SQLOpsDB Database Server"
try 
{
	$DBCheck = Invoke-SQLCMD -ServerInstance $ServerInstance `
							 -Database master `
							 -Query "SELECT * FROM sys.databases WHERE name = 'SQLOpsDB'" `
							 -ErrorAction stop

	if ($DBCheck)
	{
		Write-Host "... Database already exists. This is an update!"
		$DBExists = $true
	}
	else {
		Write-Host "... Database does not exists. This is a new install!"
	}
}
catch
{
	Write-Host "... Failed to connect to SQLOpsDB Database Server [$ServerInstance]."
	Write-Error $_
	return
}

Write-Host "... Connecting to PowerShell Server"
#if (!(Test-Connection -ComputerName $ComputerName))
#{
#	Write-Host "... Unable to connect to [$ComputerName]."
#	return
#}
Write-Host "... Connection validated."

Write-Host "... Validating deployment path."

if (!(Test-Path $DeploymentLocation))
{
	Write-Host "... Unable to validate path [$DeploymentLocation]."
	return
}

Write-Host "... Path is valid."
Write-Host "... Checking solution folders."

$Dst_CollectionScriptPath = Create-Folder -Path $DeploymentLocation -FolderName CollectionScript
$Dst_SQLOpsDBPath = Create-Folder -Path $DeploymentLocation -FolderName SQLOpsDB
$Dst_SQLOpsDBConfigPath = Create-Folder -Path $Dst_SQLOpsDBPath -FolderName Config
$Dst_SQLOpsDBModulePath = Create-Folder -Path $Dst_SQLOpsDBPath -FolderName Modules
$Dst_EPMScriptPath = Create-Folder -Path $DeploymentLocation -FolderName EPM

Write-Host " "
Write-Host "Copying & Updating PowerShell Solution"
$ScriptPath = Split-Path $($MyInvocation.MyCommand.Path) -Parent

$Src_CollectionScriptPath = Join-Path $ScriptPath "/../CollectionScript/"
Copy-Files -SrcLocation $Src_CollectionScriptPath -DstLocation $Dst_CollectionScriptPath

$Src_CollectionScriptPath = Join-Path $ScriptPath "/../EPM/"
Copy-Files -SrcLocation $Src_CollectionScriptPath -DstLocation $Dst_EPMScriptPath

$Src_CollectionScriptPath = Join-Path $ScriptPath "/../SQLOpsDB/"
Copy-Files -SrcLocation $Src_CollectionScriptPath -DstLocation $Dst_SQLOpsDBPath

$Src_CollectionScriptPath = Join-Path $ScriptPath "/../SQLOpsDB/Config/"
Copy-Files -SrcLocation $Src_CollectionScriptPath -DstLocation $Dst_SQLOpsDBConfigPath

$Src_CollectionScriptPath = Join-Path $ScriptPath "/../SQLOpsDB/Modules/"
Copy-Files -SrcLocation $Src_CollectionScriptPath -DstLocation $Dst_SQLOpsDBModulePath

Write-Host " "
Write-Host "Setting Up Windows Schedulers Task on [$computerName]"

$CIMSession = New-CIMSession -ComputerName $ComputerName

$StatusMsg = "Skipped"
$MsgColor = "Gray"

if (!(Get-ScheduledTask -CimSession $CIMSession | Where-Object {$_.TaskName -eq 'SQLOpsDB.DataCollection'}))
{

	$taskAction = New-ScheduledTaskAction -Execute 'powershell.exe' `
	-Argument "-File '$Src_CollectionScriptPath/SQLOpsDB_DataCollection.ps1' -ExecutionPolicy Unrestricted" `
	-WorkingDirectory $Src_CollectionScriptPath

	Register-ScheduledTask -TaskName 'SQLOpsDB.DataCollection' `
						   -Action $taskAction `
						   -CIMSession $CIMSession | Out-Null	
	$StatusMsg = "Created"
	$MsgColor = "Green"
}

Write-Host "... " -NoNewLine -ForegroundColor White
Write-Host "Task Name: SQLOpsDB.DataCollection" -ForegroundColor Cyan -NoNewline
Write-Host (" " * 10) -NoNewline
Write-Host " [" -NoNewLine -ForegroundColor White
Write-Host $StatusMsg -ForegroundColor $MsgColor -NoNewLine 
Write-Host "]" -ForegroundColor White

$StatusMsg = "Skipped"
$MsgColor = "Gray"

if (!(Get-ScheduledTask -CimSession $CIMSession | Where-Object {$_.TaskName -eq 'SQLOpsDB.ConfigurationHealth'}))
{

	$taskAction = New-ScheduledTaskAction -Execute 'powershell.exe' `
	-Argument "-File '$Dst_EPMScriptPath/EPM_EnterpriseEvaluation_5.ps1' -ExecutionPolicy Unrestricted" `
	-WorkingDirectory $Dst_EPMScriptPath

	Register-ScheduledTask -TaskName 'SQLOpsDB.ConfigurationHealth' `
						   -Action $taskAction `
						   -CIMSession $CIMSession | Out-Null	
	$StatusMsg = "Created"
	$MsgColor = "Green"
}

Write-Host "... " -NoNewLine -ForegroundColor White
Write-Host "Task Name: SQLOpsDB.ConfigurationHealth" -ForegroundColor Cyan -NoNewline
Write-Host (" " * 5) -NoNewline
Write-Host " [" -NoNewLine -ForegroundColor White
Write-Host $StatusMsg -ForegroundColor $MsgColor -NoNewLine 
Write-Host "]" -ForegroundColor White
					   