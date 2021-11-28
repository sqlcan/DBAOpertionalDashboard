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
#>
function Get-SIExtendedProperties
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerInstance,
    [Parameter(Position=2, Mandatory=$false)] [String]$Database='master'
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Get-SIExtendedProperties'
    $ModuleVersion = '0.00.02'
    $ModuleLastUpdated = 'April 3, 2020'

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

        if ($Database -eq 'master')
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
                    AND name in ('ApplicationName')"
        }

        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $ServerInstance  `
                                    -Database $Database `
                                    -Query $TSQL

        $RowCount = $Results.Count

		if ($Database -eq 'master')
		{
			if (!($RowCount -ge 4))
			{
				Write-StatusUpdate -Message "Failed to find one or more of the required extended properties on [$ServerInstance]." -WriteToDB
				Write-Output $Global:Error_FailedToComplete
				return
			}
		}
		else
		{
			if ($RowCount -eq 0)
			{
				# Application Name will not be a required property.  If possible, we would like to collect it to help 
				# catalog databases.  Therefore is no rows are returned SQLOp will assume Unknown.
			}
		}

        # Return an hash table as it will make it easier to access the key value pairs.
        $HashTable = @{}

        ForEach ($Row in $Results)
        {
            if (($Row.PropertyName -in ('EnvironmentType','ServerType','MachineType','ActiveNode','ApplicationName')) -or ($Row.PropertyName -like 'PassiveNode*'))
            {
                $HashTable.Add($($Row.PropertyName), $($Row.Value))
            }
        }

        Write-Output $HashTable
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expectation" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}