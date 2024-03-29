﻿<#
.SYNOPSIS
Get-SISQLService

.DESCRIPTION 
Get-SISQLService

.PARAMETER ComputerName
Server name which will be targeted for get list of services.

.INPUTS
None

.OUTPUTS
List of services installed on the computer name supplied.

.EXAMPLE
Get list of all the services, the command will return an object set with all services
discovered on the server.

Get-SISQLService -ComputerName ContosoServer

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2020.01.08 0.00.01 New Build
2020.02.04 0.00.03 Added check for module is initialized.
				   Fixed a bug in the SSRS version check.
2020.02.05 0.00.05 Renamed Command-Let to Get-SISQLService, because it interacts with
					the infrastructure.
                   Updated service name from SQLAgent to "SQL Agent."
2020.03.02 0.00.08 Excluded additional services from being scanned, AD Helper and SQL Writer.
                   Added check for SQL class required for version under WMI.
                   Fixed some spelling mistakes.
                   (Issue #35)
2020.03.04 0.00.11 Fixed parsing error with service version.
                   Additional error handling for WMI calls and namespace resolutions.
                   Changed the filter for AD Helper service to exclude all versions.
2020.03.06 0.00.13 Expose service status.
                   Refactor code and fixed some spelling mistakes.
2020.03.07 0.00.14 Fixed the field for status if service is running or stopped.
2020.03.09 0.00.17 Two bugs both with SQL Server 2000.  One agent services does not have
                    instance parameters (i).
                   Second bug, WMI name space sqlserver does not exist.
                   Refactor code and fixed some spelling mistakes.
                   SSRS 2005 WMI does not expose build information, defaulted to 9.0.0.0.
2022.10.29 0.00.19 Added Process ID for PowerShell.  To allow to run in multi-threaded env.
				   Fixed error handling to stop after first error.
#>
function Get-SISQLService
{
    [CmdletBinding(DefaultParameterSetName='ComputerName')] 
    param( 
	[Parameter(ParameterSetName='ComputerName', Position=0, Mandatory=$true)]
    [Parameter(ParameterSetName='Internal', Position=0, Mandatory=$true)] [string]$ComputerName,
	[Parameter(ParameterSetName='Internal', Position=1, Mandatory=$true, DontShow)] [Switch]$Internal
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
	
    $ModuleName = 'Get-SISQLService'
    $ModuleVersion = '0.00.19'
    $ModuleLastUpdated = 'October 29, 2022'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

		if ($Internal)
		{
			Class SQLServices{
				[int] $ProcessID;
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
				[string] $Status;
			}
		}
		else {
			Class SQLServices_External {
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
				[string] $Status;
			}
		}

        function Get-SQLVersion ($ServiceName)
        {
            # We can only return version of the $SQLServiceCM was collected successfully. 
            #
            # This function returns the version information from WMI call, function is used to minimize
            # the number of WMI calls.

            $Version = $null

            if (!($SQLWMIClassMissing))
            {
			    ForEach ($SQLServiceCM In $SQLServicesCM)
			    {
				    if ($SQLServiceCM.ServiceName -eq $ServiceName)
				    {
					    $Version = $SQLServiceCM.PropertyStrValue
                        break;
				    }
			    }
            }
            
            if (($Version = '0') -or ([String]::IsNullOrEmpty($Version)))
            {
                $Version = '0.0.0.0'
            }

            return $Version
		}

        function Parse-Version ($Version)
        {
            if ($Version.IndexOf('.') -ne -1)
            {
                return $Version.Substring(0,$Version.IndexOf('.'))
            }
            else
            {
                return 0
            }
        }

		# Get list of all services that have word "SQL" or "PowerBI" in them.  We are using WMI for Win32_Services.  Because WMI for SQL does not provide
		# list of all SQL services.
		$Services = Get-WmiObject -Class Win32_Service -ComputerName $ComputerName -ErrorAction Stop
		$Services = $Services | Where-Object {($_.DisplayName -Like '*SQL*' -OR $_.DisplayName -Like '*PowerBI*'-OR $_.DisplayName -Like '*Power BI*' -OR $_.Name -Like '*MsDts*') -and
                                              ($_.Name -notlike 'MSSQLServerADHelper*' -and $_.Name -ne 'SQLWriter')} | SELECT PSComputerName, DisplayName, Name, PathName, StartName, StartMode, State, Status


		# Get SQL Services Version from WMI -- Get the Latest Name Space available.
		# Newest version should provide listing for all previous version of SQL Services installed.
		#
		# Get-WMIObject -class __Namespace -namespace root\microsoft\sqlserver | select name


        $SQLVersion = 0
        $SQLNameSpace = $null

        if ((Get-WMIObject -class __Namespace -namespace root\microsoft -ComputerName $ComputerName  | ? {$_.Name -eq 'sqlserver'} | Measure-Object).Count -eq 1)
        {
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
        }
        else
        {
            Write-StatusUpdate -Message "WMI Namespace [sqlserver] Missing under Namespace [root\microsoft] - SQL Services' version information not collected." -WriteToDB
        }

        $SQLWMIClassMissing = $true
        if ($SQLVersion -ne 0)
        {            
            $SQLCMNameSpace = "root\microsoft\sqlserver\ComputerManagement$SQLVersion"

            if ((((Get-wmiobject -Namespace $SQLCMNameSpace -ComputerName $ComputerName -List) | ? {$_.Name -eq 'SqlServiceAdvancedProperty'}) | Measure-Object).Count -ne 1)
            {
                # Require SQL class is missing, therefore version information will not be available.  Report it in logs.

                Write-StatusUpdate -Message "WMI Class [SqlServiceAdvancedProperty] Missing under Namespace [$SQLCMNameSpace] - SQL Services' version information not collected." -WriteToDB
            }
            else
            {		    
                $SQLWMIClassMissing = $false
		        $SQLServicesCM = Get-wmiobject -Namespace $SQLCMNameSpace -Class SqlServiceAdvancedProperty -ComputerName $ComputerName | ? {$_.PropertyName -EQ 'Version'} | SELECT PropertyName, PropertyStrValue, ServiceName
            }
        }
        else
        {
            Write-StatusUpdate -Message "WMI Class [ComputerManagement*] Missing under Namespace [root\microsoft\sqlserver] - SQL Services' version information not collected." -WriteToDB
        }

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

			if (!($Internal))
			{
				$SQLService = New-Object SQLServices_External
			}
			else {
				$SQLService = New-Object SQLServices
				$SQLService.ProcessID = $pid
			}
			$AddService = $false
			$SQLService.ServerName = $Service.PSComputerName
			$SQLService.Name = $Service.Name
			$SQLService.DisplayName = $Service.DisplayName
			$SQLService.StartMode = $Service.StartMode
			$SQLService.Path = $Service.PathName
            $SQLService.ServiceAccount = $Service.StartName
            $SQLService.Status = $Service.State

			# SQL Engine || Default Instance
			If ($Service.Name -Like 'MSSQLServer')
			{
				$SQLService.Type = 'Engine'
				$SQLService.InstanceName = 'MSSQLServer'
				$SQLService.Build = Get-SQLVersion $Service.Name
				$AddService = $true        
			}

			# SQL Engine || Named Instance
			ElseIf ($Service.Name -Like 'MSSQL$*')
			{
				$SQLService.Type = 'Engine'
				$SQLService.InstanceName = $($Service.Name).Substring(6)
				$SQLService.Build = Get-SQLVersion $Service.Name
				$AddService = $true
			}

			# SSAS || Default Instance
			ElseIf ($Service.Name -Like 'MSSQLServerOLAPService')
			{
				$SQLService.Type = 'SSAS'
				$SQLService.InstanceName = "MSSQLServerOLAPService"
				$SQLService.Build = Get-SQLVersion $Service.Name
				$AddService = $true
			}

			# SSAS || Named Instance
			ElseIf ($Service.Name -Like 'MSOLAP$')
			{
				$SQLService.Type = 'SSAS'
				$SQLService.InstanceName = $($Service.Name).Substring(7)
				$SQLService.Build = Get-SQLVersion $Service.Name
				$AddService = $true
			}

			# SQL Agent || Default Instance
			ElseIf ($Service.Name -LIke 'SQLServerAgent')
			{
				$SQLService.Type = 'SQLAgent'
				$SQLService.InstanceName = 'MSSQLServer'
                if (($SQLService.Path).IndexOf(' -i') -gt -1)
                {
				    $SQLAgentExe = ($SQLService.Path).Substring(0,($SQLService.Path).IndexOf(' -i')).Replace('"','')
                }
                else
                {
                    $SQLAgentExe = ($SQLService.Path).Replace('"','')
                }
				$SQLAgentExe = $SQLAgentExe.Replace(':\','$\')
				$SQLAgentExe = "\\$($SQLService.ServerName)\$SQLAgentExe"
				$SQLService.Build = ((Get-ChildItem $SQLAgentExe).VersionInfo).ProductVersion
				$AddService = $true
			}

			# SQL Agent || Named Instance
			ElseIf ($Service.Name -LIke 'SQLAgent$*')
			{
				$SQLService.Type = 'SQL Agent'
				$SQLService.InstanceName = $($Service.Name).Substring(9)

				$SQLAgentExe = ($SQLService.Path).Substring(0,($SQLService.Path).IndexOf(' -i')).Replace('"','')
				$SQLAgentExe = $SQLAgentExe.Replace(':\','$\')
				$SQLAgentExe = "\\$($SQLService.ServerName)\$SQLAgentExe"
				$SQLService.Build = ((Get-ChildItem $SQLAgentExe).VersionInfo).ProductVersion
				$AddService = $true
			}

			# PowerBI
			ElseIf (($Service.Name -LIke '*PowerBI*') -or ($Service.Name -LIke '*Power BI*'))
			{
				# Assuming PowerBI Report Server Version will always be 15.
				$SQLService.Type = 'PowerBI (SSRS)'
				$SQLService.InstanceName = 'PBIRS'
				$SQLService.Build = (Get-WMIObject -namespace root\microsoft\sqlserver\ReportServer\RS_PBIRS\V15 -Class MSReportServer_Instance -ComputerName $ComputerName).Version
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
                if ($WMIReport)
                {
                    $WMIReportVersion = (Get-WMIObject -Namespace "root\microsoft\sqlserver\ReportServer\$($WMIReport.Name)" -Class __NAMESPACE -ComputerName $ComputerName)
                    $SQLService.Build =((Get-WMIObject -Namespace "root\microsoft\sqlserver\ReportServer\$($WMIReport.Name)\$($WMIReportVersion.Name)" -Class MSReportServer_Instance -ComputerName $ComputerName) | ? {$_.InstanceName -EQ "$($SQLService.InstanceName)"}).Version
                }
                else
                {
                    $SQLService.Build = '9.0.0.0'
                }
                $AddService = $true
			}
			# SSRS || Named Instance || Only for SQL Server 2016 and older.
			ElseIf (($Service.Name -LIke 'SQLServerReport*') -or ($Service.Name -LIke 'ReportServer*'))
			{
                $SQLService.Type = 'SSRS'
                $SQLService.InstanceName = $($Service.Name).Substring(13)
                $WMIReport = (Get-WMIObject -namespace root\microsoft\sqlserver\ReportServer -Class __NAMESPACE -ComputerName $ComputerName) | ? {$_.Name -EQ "RS_$($SQLService.InstanceName)"}
                if ($WMIReport)
                {
                    $WMIReportVersion = (Get-WMIObject -Namespace "root\microsoft\sqlserver\ReportServer\$($WMIReport.Name)" -Class __NAMESPACE -ComputerName $ComputerName)
                    $SQLService.Build =((Get-WMIObject -Namespace "root\microsoft\sqlserver\ReportServer\$($WMIReport.Name)\$($WMIReportVersion.Name)" -Class MSReportServer_Instance -ComputerName $ComputerName) | ? {$_.InstanceName -EQ "$($SQLService.InstanceName)"}).Version
                }
                else
                {
                    $SQLService.Build = '9.0.0.0'
                }
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
				$AddService = $true
			}

			if ($AddService)
			{
                $SQLService.Version = Parse-Version $SQLService.Build
				$SQLServices += $SQLService
			}
		}
		
		Write-Output $SQLServices
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expecting" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}