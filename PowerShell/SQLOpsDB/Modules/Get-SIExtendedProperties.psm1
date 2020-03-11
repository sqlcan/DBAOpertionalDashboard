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

.PARAMETER Object
Server or Database?

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
#>
function Get-SIExtendedProperties
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerInstance,
    [Parameter(Position=1, Mandatory=$true)]
    [ValidateSet('Server','Database')] [string]$Object,
    [Parameter(Position=2, Mandatory=$false)] [String]$Database
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Get-SIExtendedProperties'
    $ModuleVersion = '0.00.01'
    $ModuleLastUpdated = 'March 11, 2020'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        if ([String]::IsNullOrEmpty($Database))
        {
            $Database = 'master'
        }

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

        if (!(($RowCount -ge 4) -and ($Database -eq 'master')))
        {
            Write-StatusUpdate -Message "Failed to find one or more of the required extended properties on [$ServerInstance]." -WriteToDB
            Write-Output $Global:Error_FailedToComplete
            return
        }
        elseif (($RowCount -ne 1) -and ($Database -ne 'master'))
        {
            # Eventually this will be a required property, but for now add code to protect against if it is not supplied.
            # Write-StatusUpdate -Message "Failed to find one or more of the required extended properties on [$ServerInstance]." -WriteToDB
            Write-Output $Global:Error_ObjectsNotFound
            return
        }

        Write-Output $Results
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expectation" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}