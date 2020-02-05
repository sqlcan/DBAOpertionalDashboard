<#
.SYNOPSIS
Get-SQLService

.DESCRIPTION 
Get-SQLService

.PARAMETER ComputerName
Server name which will be targeted for get list of services.

.INPUTS
None

.OUTPUTS
Get-SQLService

.EXAMPLE
Get list of all the services, the command will return an object set with all services
discovered on the server.

Get-SQLService -ComputerName ContosoServer

Description

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2020.01.08 0.00.01 New Build
2020.02.04 0.00.03 Added check for module is initialized.
                   Fixed a bug in the SSRS version check.
#>
function Get-SQLService
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ComputerName
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
	
    $ModuleName = 'Get-SQLService'
    $ModuleVersion = '0.00.03'
    $ModuleLastUpdated = 'February 4, 2020'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

		Class SQLServices{
			[string] $ServerName;
			[string] $Name;
			[string] $InstanceName;
			[string] $DisplayName;
			[string] $Path;
			[string] $Type;
			[string] $StartMode;
			[string] $ServiceAccount;
			[int] $Version;
			[string] $Build;
		}

		function Get-SQLVersion ($ServiceName) {

			ForEach ($SQLServiceCM In $SQLServicesCM)
			{
				if ($SQLServiceCM.ServiceName -eq $ServiceName)
				{
					return $SQLServiceCM.PropertyStrValue
				}
			}
		}

		# Get list of all services that have word "SQL" or "PowerBI" in them.  We are using WMI for Win32_Services.  Becuase WMI for SQL does not provide
		# list of all SQL services.
		$Services = Get-WmiObject -Class Win32_Service -ComputerName $ComputerName
		$Services = $Services | Where-Object {$_.DisplayName -Like '*SQL*' -OR $_.DisplayName -Like '*PowerBI*'-OR $_.Name -Like '*MsDts*'} | SELECT PSComputerName, DisplayName, Name, PathName, StartName, StartMode, State, Status


		# Get SQL Services Version from WMI -- Get the Latest Name Space available.
		# Newest version should provide listing for all previous version of SQL Services installed.
		#
		# Get-WMIObject -class __Namespace -namespace root\microsoft\sqlserver | select name

		$SQLNameSpaces = Get-WMIObject -class __Namespace -namespace root\microsoft\sqlserver -ComputerName $ComputerName | select name
		$SQLVersion = 0

		ForEach ($SQLNameSpace in $SQLNameSpaces)
		{
			$NameSpaceName = $SQLNameSpace.name

			If ($NameSpaceName -like 'ComputerManagement*')
			{
				If (($NameSpaceName.Substring(18) -as [int]) -gt $SQLVersion)
				{
					$SQLVersion = ($NameSpaceName.Substring(18) -as [int])
				}
			}
		}

		$SQLCMNameSpace = "root\microsoft\sqlserver\ComputerManagement$SQLVersion"
		$SQLServicesCM = Get-wmiobject -Namespace $SQLCMNameSpace -Class SqlServiceAdvancedProperty -ComputerName $ComputerName | ? {$_.PropertyName -EQ 'Version'} | SELECT PropertyName, PropertyStrValue, ServiceName


		# Create an Empty Array to Hold List of Services
		$SQLServices = @()

		ForEach ($Service in $Services)
		{
			# We only need to assess & report following SQL Services
			#
			#   SQL Engine
			#   SQL Agent
			#   Analysis Service
			#   Integration Services
			#   Report Server
			#   Full Text Search

			$SQLService = New-Object SQLServices
			$AddService = $false
			$SQLService.ServerName = $Service.PSComputerName
			$SQLService.Name = $Service.Name
			$SQLService.DisplayName = $Service.DisplayName
			$SQLService.StartMode = $Service.StartMode
			$SQLService.Path = $Service.PathName
			$SQLService.ServiceAccount = $Service.StartName

			# SQL Engine || Default Instance
			If ($Service.Name -Like 'MSSQLServer')
			{
				$SQLService.Type = 'Engine'
				$SQLService.InstanceName = 'MSSQLServer'
				$SQLService.Build = Get-SQLVersion $Service.Name
				$SQLService.Version = ($SQLService.Build).Substring(0,($SQLService.Build).IndexOf('.'))
				$AddService = $true        
			}

			# SQL Engine || Named Instance
			ElseIf ($Service.Name -Like 'MSSQL$*')
			{
				$SQLService.Type = 'Engine'
				$SQLService.InstanceName = $($Service.Name).Substring(6)
				$SQLService.Build = Get-SQLVersion $Service.Name
				$SQLService.Version = ($SQLService.Build).Substring(0,($SQLService.Build).IndexOf('.'))
				$AddService = $true
			}

			# SSAS || Default Instance
			ElseIf ($Service.Name -Like 'MSSQLServerOLAPService')
			{
				$SQLService.Type = 'SSAS'
				$SQLService.InstanceName = "MSSQLServerOLAPService"
				$SQLService.Build = Get-SQLVersion $Service.Name
				$SQLService.Version = ($SQLService.Build).Substring(0,($SQLService.Build).IndexOf('.'))
				$AddService = $true
			}

			# SSAS || Named Instance
			ElseIf ($Service.Name -Like 'MSOLAP$')
			{
				$SQLService.Type = 'SSAS'
				$SQLService.InstanceName = $($Service.Name).Substring(7)
				$SQLService.Build = Get-SQLVersion $Service.Name
				$SQLService.Version = ($SQLService.Build).Substring(0,($SQLService.Build).IndexOf('.'))
				$AddService = $true
			}

			# SQL Agent || Default Instnace
			ElseIf ($Service.Name -LIke 'SQLServerAgent')
			{
				$SQLService.Type = 'SQLAgent'
				$SQLService.InstanceName = 'MSSQLServer'
				$SQLAgentExe = ($SQLService.Path).Substring(0,($SQLService.Path).IndexOf(' -i')).Replace('"','')
				$SQLAgentExe = $SQLAgentExe.Replace(':\','$\')
				$SQLAgentExe = "\\$($SQLService.ServerName)\$SQLAgentExe"
				$SQLService.Build = ((Get-ChildItem $SQLAgentExe).VersionInfo).ProductVersion
				$SQLService.Version = ($SQLService.Build).Substring(0,($SQLService.Build).IndexOf('.'))
				$AddService = $true
			}

			# SQL Agent || Named Instnace
			ElseIf ($Service.Name -LIke 'SQLAgent$*')
			{
				$SQLService.Type = 'SQLAgent'
				$SQLService.InstanceName = $($Service.Name).Substring(9)

				$SQLAgentExe = ($SQLService.Path).Substring(0,($SQLService.Path).IndexOf(' -i')).Replace('"','')
				$SQLAgentExe = $SQLAgentExe.Replace(':\','$\')
				$SQLAgentExe = "\\$($SQLService.ServerName)\$SQLAgentExe"
				$SQLService.Build = ((Get-ChildItem $SQLAgentExe).VersionInfo).ProductVersion
				$SQLService.Version = ($SQLService.Build).Substring(0,($SQLService.Build).IndexOf('.'))
				$AddService = $true
			}

			# PowerBI
			ElseIf ($Service.Name -LIke '*PowerBI*')
			{
				# Assuming PowerBI Report Server Version will always be 15.
				$SQLService.Type = 'PowerBI (SSRS)'
				$SQLService.InstanceName = 'PBIRS'
				$SQLService.Build = (Get-WMIObject -namespace root\microsoft\sqlserver\ReportServer\RS_PBIRS\V15 -Class MSReportServer_Instance -ComputerName $ComputerName).Version
				$SQLService.Version = ($SQLService.Build).Substring(0,($SQLService.Build).IndexOf('.'))
				$AddService = $true
			}
			# SSRS || Default Instance || Starting SQL 2017, you can only have single instance for SSRS per server
			# SSRS 2016 Default Name is RS_MSSQLServer
			# SSRS 2017 Default Name is RS_SSRS
			ElseIf (($Service.Name -LIke 'SQLServerReport*') -or ($Service.Name -LIke 'ReportServer'))
			{
							$SQLService.Type = 'SSRS'
							$SQLService.InstanceName = 'MSSQLServer'
							$WMIReport = (Get-WMIObject -namespace root\microsoft\sqlserver\ReportServer -Class __NAMESPACE -ComputerName $ComputerName) | ? {$_.Name -EQ 'RS_MSSQLServer' -OR $_.Name -EQ 'RS_SSRS'} 
                            if ($WMIReport.Name -eq 'RS_SSRS')
                            {   # SSRS 2017+
                                $SQLService.InstanceName = 'SSRS'
                            }
							$WMIReportVersion = (Get-WMIObject -Namespace "root\microsoft\sqlserver\ReportServer\$($WMIReport.Name)" -Class __NAMESPACE -ComputerName $ComputerName) 
							$SQLService.Build =((Get-WMIObject -Namespace "root\microsoft\sqlserver\ReportServer\$($WMIReport.Name)\$($WMIReportVersion.Name)" -Class MSReportServer_Instance -ComputerName $ComputerName) | ? {$_.InstanceName -EQ $SQLService.InstanceName}).Version
							$SQLService.Version = ($SQLService.Build).Substring(0,($SQLService.Build).IndexOf('.'))
							$AddService = $true
			}
			# SSRS || Named Instance || Only for SQL Server 2016 and older.
			ElseIf (($Service.Name -LIke 'SQLServerReport*') -or ($Service.Name -LIke 'ReportServer*'))
			{
							$SQLService.Type = 'SSRS'
							$SQLService.InstanceName = $($Service.Name).Substring(13)
							$WMIReport = (Get-WMIObject -namespace root\microsoft\sqlserver\ReportServer -Class __NAMESPACE -ComputerName $ComputerName) | ? {$_.Name -EQ "RS_$($SQLService.InstanceName)"}
							$WMIReportVersion = (Get-WMIObject -Namespace "root\microsoft\sqlserver\ReportServer\$($WMIReport.Name)" -Class __NAMESPACE -ComputerName $ComputerName)
							$SQLService.Build =((Get-WMIObject -Namespace "root\microsoft\sqlserver\ReportServer\$($WMIReport.Name)\$($WMIReportVersion.Name)" -Class MSReportServer_Instance -ComputerName $ComputerName) | ? {$_.InstanceName -EQ "$($SQLService.InstanceName)"}).Version
							$SQLService.Version = ($SQLService.Build).Substring(0,($SQLService.Build).IndexOf('.'))
							$AddService = $true
			}
			# SSIS || Single Instance Application
			ElseIf ($Service.Name -LIke 'MsDts*')
			{
				$SQLService.Type = 'SSIS'
				$SQLService.InstanceName = 'N/A'

				$SSISExec = ($SQLService.Path).Replace('"','')
				$SSISExec = $SSISExec.Replace(':\','$\')
				$SSISExec = "\\$($SQLService.ServerName)\$SSISExec"
				$SQLService.Build = ((Get-ChildItem $SSISExec).VersionInfo).ProductVersion
				$SQLService.Version = ($SQLService.Build).Substring(0,($SQLService.Build).IndexOf('.'))
				$AddService = $true
			}
			# MSSQLFDLauncher || Single Instance Application
			ElseIf ($Service.Name -LIke 'MSSQLFD*')
			{
				$SQLService.Type = 'Full-Text Search'
				$SQLService.InstanceName = 'N/A'

				$FTSExec = ($SQLService.Path).Substring(0,($SQLService.Path).IndexOf(' -s')).Replace('"','')
				$FTSExec = $FTSExec.Replace(':\','$\')
				$FTSExec = "\\$($SQLService.ServerName)\$FTSExec"
				$SQLService.Build = ((Get-ChildItem $FTSExec).VersionInfo).ProductVersion
				$SQLService.Version = ($SQLService.Build).Substring(0,($SQLService.Build).IndexOf('.'))
				$AddService = $true
			}

			if ($AddService)
			{
				$SQLServices += $SQLService
			}
		}
		
		Write-Output $SQLServices
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expection" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}