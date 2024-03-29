#This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.
#THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
#INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
#
#We grant you a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute
#the object code form of the Sample Code, provided that you agree:
#(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
#(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
#(iii) to indemnify, hold harmless, and defend Us and our suppliers from and against any claims or lawsuits,
#      including attorneys' fees, that arise or result from the use or distribution of the Sample Code. 
#
# Module manifest for module 'SQLOpsDB'
#
# Reference ChangeHistory.txt for details on change of entire module.

@{
    # Script module or binary module file associated with this manifest
    ModuleToProcess = ''

    # Version number of this module.
    ModuleVersion = '3.00.00.0000'

    # ID used to uniquely identify this module
    GUID = '4baba076-b43c-40a3-a483-16eed455f676'

    # Author of this module
    Author = 'Mohit K. Gupta'

    # Company or vendor of this module
    CompanyName = 'Microsoft Corporation'

    # Copyright statement for this module
    Copyright = '2020'

    # Description of the functionality provided by this module
    Description = 'SQL Server Operational Dashboard PowerShell Module'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '4.0'

    # Name of the Windows PowerShell host required by this module
    PowerShellHostName = ''

    # Minimum version of the Windows PowerShell host required by this module
    PowerShellHostVersion = '4.0'

    # Minimum version of the .NET Framework required by this module
    DotNetFrameworkVersion = '4.0'

    # Minimum version of the common language runtime (CLR) required by this module
    CLRVersion = ''

    # Processor architecture (None, X86, Amd64, IA64) required by this module
    ProcessorArchitecture = ''

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @()

    # Assemblies that must be loaded prior to importing this module
    RequiredAssemblies = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module
    ScriptsToProcess = @()

    # Type files (.ps1xml) to be loaded when importing this module
    TypesToProcess = @()

    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess = @()

    # Modules to import as nested modules of the module specified in ModuleToProcess
    NestedModules = @(
    # Internal Command-Lets to Support Solution
    '.\Modules\Initialize-SQLOpsDB.psm1';
    '.\Modules\Write-StatusUpdate.psm1';
    '.\Modules\GlobalSettings.psm1';
	'.\Modules\Get-SQLOpSettings.psm1';
	'.\Modules\Set-SQLOpSettings.psm1';
    # SQL Instance
    '.\Modules\Get-SQLOpSQLInstance.psm1';
	'.\Modules\Add-SQLOpSQLInstance.psm1';
	'.\Modules\Update-SQLOpSQLInstance.psm1';
    '.\Modules\Get-SISQLProperties.psm1';
	'.\Modules\Get-SQLOpSQLProperties.psm1';
	'.\Modules\Get-SISQLVolumeDetails.psm1';
	# SQL Security Modules
	'.\Modules\Get-SIServerPrincipalMembership.psm1';
	'.\Modules\Get-SIServerRole.psm1';
	'.\Modules\Get-SIDatabasePrincipalMembership.psm1';
	'.\Modules\Get-SIDatabaseRole.psm1';
	'.\Modules\Update-SQLOpServerRole.psm1';
	'.\Modules\Update-SQLOpDatabaseRole.psm1';
	'.\Modules\Update-SQLOpServerPrincipalMembership.psm1';
	'.\Modules\Update-SQLOpDatabasePrincipalMembership.psm1';
	'.\Modules\Get-SIServerPermission.psm1';
	'.\Modules\Update-SQLOpServerPermission.psm1';
	'.\Modules\Get-SIDatabasePermission.psm1';
	'.\Modules\Update-SQLOpDatabasePermission.psm1'
	# Availability Group Modules
	'.\Modules\Get-SIAvailabilityGroups.psm1';
	'.\Modules\Update-SQLOpAvailabilityGroup.psm1';
	'.\Modules\Get-SQLOpAvailabilityGroup.psm1';
	# Database Modules
	'.\Modules\Get-SIDatabases.psm1';
	'.\Modules\Update-SQLOpDatabase.psm1';
	# SQL Error Log Modules
	'.\Modules\Get-SISQLErrorLogs.psm1';
	'.\Modules\Get-SQLErrorLogs.psm1';					# REQUIRED NOT DUPLICTE #
	'.\Modules\Update-SQLOpSQLErrorLog.psm1';	
	'.\Modules\Get-SQLOpSQLErrorLogStats.psm1';	
	'.\Modules\Update-SQLOpSQLErrorLogStats.psm1';
	# SQL Jobs Modules
	'.\Modules\Get-SISQLJobs.psm1';
	'.\Modules\Update-SQLOpSQLJobs.psm1';
	'.\Modules\Get-SQLOpSQLJobs.psm1';
	'.\Modules\Update-SQLOpSQLJobStats.psm1';
	'.\Modules\Get-SQLOpSQLJobStats.psm1';
	# Extended Properties Modules
	'.\Modules\Get-SIExtendedProperties.psm1';
	'.\Modules\Set-SIExtendedProperties.psm1';
	'.\Modules\Update-SQLOpExtendedProperties.psm1';	# Update only Custom Extended Properties #
    # Server Modules
    '.\Modules\Get-SIOperatingSystem.psm1';
	'.\Modules\Get-SIProcessor.psm1';
	'.\Modules\Get-SIMemory.psm1';
	'.\Modules\Get-SIDiskVolume.psm1';
    '.\Modules\Get-SQLOpServer.psm1';
    '.\Modules\Get-SQLOpOperatingSystem.psm1';
    '.\Modules\Add-SQLOpOperatingSystem.psm1';
    '.\Modules\Add-SQLOpServer.psm1';
    '.\Modules\Update-SQLOpServer.psm1';
	'.\Modules\Update-DiskVolumes.psm1';    
	# SQL Service
	'.\Modules\Get-SISQLService.psm1';
	'.\Modules\Get-SQLOpSQLService.psm1';
	'.\Modules\Update-SQLOpSQLService.psm1';
	# SQL Cluster Modules
	'.\Modules\Add-SQLOpSQLCluster.psm1';
	'.\Modules\Get-SQLOpSQLCluster.psm1';
	'.\Modules\Get-SQLOpSQLClusterNode.psm1';
	'.\Modules\Add-SQLOpSQLClusterNode.psm1';
	'.\Modules\Update-SQLOpSQLCluster.psm1';
	'.\Modules\Update-SQLOpSQLClusterNode.psm1';
    # CMS Modules
	'.\Modules\Get-SQLOpCMSServerInstance.psm1';
	'.\Modules\Get-SQLOpCMSGroups.psm1';	           
	'.\Modules\Set-SQLOpCMSGroups.psm1';
	# Snapshot, Aggregrate, Cleanup Modules
	'.\Modules\Publish-SQLOpMonthlyAggregate.psm1';
    '.\Modules\Publish-SQLOpTreadData.psm1';
	'.\Modules\Publish-SQLOpSnapshot.psm1';
	'.\Modules\Clear-SQLOpData.psm1';
	# Reporting Modules
	'.\Modules\Set-SQLOpReportLogo.psm1';
    # Support Modules
    '.\Modules\Split-Parts.psm1';
	'.\Modules\Get-SQLOpErrorDetails.psm1';
	'.\Modules\Out-DataTable.psm1';				# This module is not used by SQLOpsDB but is required for Perf Dashboard.
	'.\Modules\Add-SqlTable.psm1';				# This module is not used by SQLOpsDB but is required for Perf Dashboard.
    )

    # Functions to export from this module
    FunctionsToExport = '*'

    # Cmdlets to export from this module
    CmdletsToExport = '*'

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module
    AliasesToExport = '*'

    # List of all modules packaged with this module
    ModuleList = @()

    # List of all files packaged with this module
    FileList = @()

    # Private data to pass to the module specified in ModuleToProcess
    PrivateData = ''

}