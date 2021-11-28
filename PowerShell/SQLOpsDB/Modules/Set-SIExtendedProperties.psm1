<#
.SYNOPSIS
Set-SIExtendedProperties

.DESCRIPTION 
Set-SIExtendedProperties allows you to update information for a server or database for key
property definitions.  For server required properties are EnvironmentType, 
MachineType, ServerType, ActiveNode, and PassiveNode.  For database only has
single required property, ApplicationName.  There is no validation for extended properties
use a standard that works for your business.

.PARAMETER ServerInstance
Server instance from which to capture the jobs and their execution history..

.PARAMETER Database
If collecting from user database, then what is the name?

.INPUTS
None

.OUTPUTS
List of extended properties and their values.

.EXAMPLE
Set-SIExtendedProperties -ServerInstance ContosSQL -ExtendedPropertyName EnvironmentType -Value Prod

Update extended property on server (master database).

.EXAMPLE
Set-SIExtendedProperties -ServerInstance ContosSQL -ExtendedPropertyName ApplicationName -Value ContosWeb -Database ContosoSQL

Update extended property on user database, ContosSQL, set ApplicationName to ContosoWeb.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2021.11.27 1.00.00 Initial Version
                   Current version has limitation, as it does not support SQL 2000.
		   1.00.01 Small bug, first passive node does not have 01 as part of extnded
		           property name.
#>
function Set-SIExtendedProperties
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerInstance,
	[Parameter(Position=1, Mandatory=$true)] [ValidateSet('EnvironmentType','MachineType','ServerType', 'ActiveNode', 
														  'PassiveNode', 'PassiveNode02', 'PassiveNode03', 'PassiveNode04',
														  'PassiveNode05', 'PassiveNode06', 'PassiveNode07', 'PassiveNode08',
														  'ApplicationName')] [string]$ExtendedPropertyName,
	[Parameter(Position=2, Mandatory=$true)] [string]$Value,
    [Parameter(Position=3, Mandatory=$false)] [String]$Database='master'
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Set-SIExtendedProperties'
    $ModuleVersion = '1.00.01'
    $ModuleLastUpdated = 'Nov. 28, 2021'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        $TSQL = "SELECT id AS TblId FROM sysobjects WHERE name = 'extended_properties'"
        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $ServerInstance  `
                                    -Database master `
                                    -Query $TSQL -ErrorAction Stop

        # This check is required for custom objects created on SQL 2000 that mimic extended properties
        # system table in SQL 2005+.
        if (($Results) -and ($Results.TblId -lt 0))
        {
            $SchemaPrefix = 'sys'
        }
        elseif (($Results) -and ($Results.TblId -gt 0))
        {
            Write-StatusUpdate -Message "Module not supported for SQL Server 2000." -WriteToDB
            Write-Output $Global:Error_FailedToComplete
            return
        }
        else
        {
            Write-StatusUpdate -Message "Missing extended properties table in [$ServerInstance]." -WriteToDB
            Write-Output $Global:Error_FailedToComplete
            return
        }

        if (($Database -eq 'master') -and ($ExtendedPropertyName -eq 'ApplicationName'))
        {
            Write-StatusUpdate -Message "Can't apply application name to master database." -WriteToDB
            Write-Output $Global:Error_FailedToComplete
            return
        }
        elseif (($Database -ne 'master') -and ($ExtendedPropertyName -ne 'ApplicationName'))
        {
            Write-StatusUpdate -Message "Can't apply server extended properties to user database." -WriteToDB
            Write-Output $Global:Error_FailedToComplete
            return
        }

		$TSQL = "EXEC $SchemaPrefix.sp_addextendedproperty @name=N'$ExtendedPropertyName', @value=N'$Value'"

        Write-StatusUpdate -Message $TSQL -IsTSQL

        Invoke-SQLCMD -ServerInstance $ServerInstance  `
                      -Database $Database `
                      -Query $TSQL
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expectation" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}