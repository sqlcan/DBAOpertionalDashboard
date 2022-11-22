<#
.SYNOPSIS
Get-SIExtendedProperties

.DESCRIPTION 
Get-SIExtendedProperties collect information from server or database for key
property definitions.  For server required properties are EnvironmentType, 
MachineType, ServerType, ActiveNode, and PassiveNode.  For database only has
single required property, ApplicationName.

.PARAMETER ServerInstance
Server instance from which to capture the jobs and their execution history..

.PARAMETER Database
If collecting from user database, then what is the name?

.INPUTS
None

.OUTPUTS
List of extended properties and their values.

.EXAMPLE
Get-SIExtendedProperties -ServerInstance ContosSQL

Get all the extended properties.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2020.03.11 0.00.01 Initial Version
2020.04.03 0.00.02 Error with property name for Extended Properties.  Causing
                    PassiveNode extended property was being skipped.
2022.10.31 0.00.04 Added support to pull custom extended properties on master
                   database.
				   Expended the error handling reporting.
#>
function Get-SIExtendedProperties
{

    [CmdletBinding(DefaultParameterSetName='SupportedExProp')] 
    param( 
    [Parameter(ParameterSetName='SupportedExProp',Position=0, Mandatory=$true)]
	[Parameter(ParameterSetName='CustomExProp',Position=0, Mandatory=$true)][string]$ServerInstance,
    [Parameter(ParameterSetName='SupportedExProp',Position=1, Mandatory=$false)] [String]$Database='master',
	[Parameter(ParameterSetName='CustomExProp',Position=1, Mandatory=$true)][switch]$CustomProperties
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Get-SIExtendedProperties'
    $ModuleVersion = '0.00.04'
    $ModuleLastUpdated = 'October 31, 2022'

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
            $SchemaPrefix = 'dbo'
        }
        else
        {
            Write-StatusUpdate -Message "Missing extended properties table in [$ServerInstance]." -WriteToDB
            Write-Output $Global:Error_FailedToComplete
            return
        }

		if ($CustomProperties)
		{
			# When executing with swithc CustomProperties, we do not want user to 
			# change database name from default 'master'.
			$Database = 'master'
		}

        if ($Database -eq 'master')
        {
			if (!($CustomProperties))
			{
				$TSQL = "SELECT name AS PropertyName, value AS Value
						   FROM $SchemaPrefix.extended_properties
						  WHERE class = 0
						    AND name in ('EnvironmentType','MachineType','ServerType', 'ActiveNode')
						     OR name like 'PassiveNode%'"
			}
			else
			{
				$TSQL = "SELECT name AS PropertyName, value AS Value
				           FROM $SchemaPrefix.extended_properties
				          WHERE class = 0
				            AND name NOT in ('EnvironmentType','MachineType','ServerType', 'ActiveNode')
				            AND name NOT like 'PassiveNode%'"
			}
        }
        else
        {
            $TSQL = "SELECT name AS PropertyName, value AS Value
                    FROM $SchemaPrefix.extended_properties
                    WHERE class = 0
                    AND name in ('ApplicationName')"
        }

        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $ServerInstance  `
                                    -Database $Database `
                                    -Query $TSQL

        $RowCount = $Results.Count

		if ($Database -eq 'master')
		{
			if (!($RowCount -ge 4) -and !($CustomProperties))
			{
				Write-StatusUpdate -Message "Failed to find one or more of the required extended properties (EnvironmentType, MachineType, ServerType, and ActiveNode) on [$ServerInstance]." -WriteToDB
				Write-Output $Global:Error_FailedToComplete
				return
			}
		}
		else
		{
			if ($RowCount -eq 0)
			{
				# Application Name will not be a required property.  ApplicationName is collected
				# with Get-SIDatabase.   This command-let supports it for query purpose nothing more.
			}
		}

        # Return an hash table as it will make it easier to access the key value pairs.
        $HashTable = @{}

        ForEach ($Row in $Results)
        {
			$HashTable.Add($($Row.PropertyName), $($Row.Value))
        }

        Write-Output $HashTable
    }
    catch [System.Data.SqlClient.SqlException]
    {
        if ($($_.Exception.Message) -like '*Could not open a connection to SQL Server*')
        {
            Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Cannot connect to $ServerInstance." -WriteToDB
        }
        else
        {
            Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - SQL Exception" -WriteToDB
            Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        }
        return $Global:Error_FailedToComplete
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Exception" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        return $Global:Error_FailedToComplete
    }
}