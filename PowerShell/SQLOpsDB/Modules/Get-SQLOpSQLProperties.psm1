<#
.SYNOPSIS
Get-SQLOpSQLProperties

.DESCRIPTION 
Get-SQLOpSQLProperties returns the sql server instance properties saved in the 
SQLOps DB.

.PARAMETER ServerInstance
Server instance from which to capture the data.

.INPUTS
None

.OUTPUTS
[HashTable] Key/Value Pair
IsClustered      ....
SQLServerVersion ....
SQLEdition       ....
SQLBuild         ....

.EXAMPLE
Get-SQLOpSQLProperties -ServerInstance ContosSQL


.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2022.10.28 0.00.01 Initial Version
#>
function Get-SQLOpSQLProperties
{
    [CmdletBinding()] 
    param( 
    [Parameter(ParameterSetName='ServerInstance',Position=0, Mandatory=$true)] [string]$ServerInstance,
	[Alias('List','All')]
	[Parameter(ParameterSetName='List',Position=0, Mandatory=$true)] [switch]$ListAvailable
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Get-SQLOpSQLProperties'
    $ModuleVersion = '0.00.01'
    $ModuleLastUpdated = 'October 28, 2022'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

		if (!($ListAvailable))
		{
			$SQLInstanceObj = Get-SQLOpSQLInstance -ServerInstance $ServerInstance

			IF ($SQLInstanceObj -eq $Global:Error_ObjectsNotFound)
			{
				Write-StatusUpdate "Failed to find SQL Instance [$ServerInstance] in SQLOpsDB." -WriteToDB
				Write-Output $Global:Error_ObjectsNotFound
				return
			}
		}

        $TSQL = "SELECT ServerInstance,
						SQLVersion,
						SQLInstanceEdition AS Edition,
						SQLInstanceType AS [Instance Type],
						SQLInstanceEnviornment AS Enviornment,						
						SQLMajorVersion AS SQLBuild_Major,
						SQLMinorVersion AS SQLBuild_Minor,
						SQLInstanceBuild AS SQLBuild_Build
				   FROM dbo.vSQLInstances "

		if (!($ListAvailable))
		{
			$SQLInstObj = Split-Parts -ServerInstance $ServerInstance
			$TSQL += "WHERE ComputerName = '$($SQLInstObj.ComputerName)'
			            AND SQLInstanceName = '$($SQLInstObj.SQLInstanceName)'"
		}

        Write-StatusUpdate -Message $TSQL -IsTSQL                    
		$Results = Invoke-SQLCMD -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
					  			 -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
					  			 -Query $TSQL -ErrorAction Stop
    }
    catch [System.Data.SqlClient.SqlException]
    {
        if ($($_.Exception.Message) -like '*Could not open a connection to SQL Server*')
        {
            Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Cannot connect to $ServerInstance." -WriteToDB
        }
        else
        {
            Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - SQL Expectation" -WriteToDB
            Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        }
        $Results = $Global:Error_FailedToComplete
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expectation" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        $Results = $Global:Error_FailedToComplete
    }
    finally
    {
        Write-Output $Results
    }
}