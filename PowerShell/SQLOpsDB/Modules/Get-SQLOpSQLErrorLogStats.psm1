<#
.SYNOPSIS
Get-SQLOpSQLErrorLogStats

.DESCRIPTION 
Gets the last date/time error logs were collected.  If this is a new instance
for which no error logs are collected, then it will call Update-SQLErrorLogStats 
to set it to Jan 1, 1900 midnight.

.PARAMETER ServerInstance
Get the last collection date/time for SQL instance. 

.INPUTS
None

.OUTPUTS
Date/time of the last error log collection.

.EXAMPLE
Get-SQLOpSQLErrorLogStats -ServerInstance ContosoSQL

Get details for this instance.

.EXAMPLE
Get-SQLOpSQLErrorLogStats

Get details for all instances and their last collection date/time.

.NOTES
Date        Version Comments
----------  ------- ------------------------------------------------------------------
2020.02.07  0.00.01 Initial Version.
2020.02.13  0.00.04 Updated reference to Get-SQLInstance to use new variable name.
                    Refactored code.
                    Updated T-SQL code to use the view, to make it easier to get instance
                     details.
2020.02.19  0.00.06 Updated module name to Get-SQLOpSQLErrorLogStats.
                    Updated reference to Get-SQLOpSQLInstance.
2020.03.02  0.00.07 Changed how to default data is calculated.  Issue #36.
2022.10.29	0.00.09 Updated the field reference from dbo.SQLErrorLog_Stats to dbo.SQLInstances.
					Updated behavior on returning full resultset.
#>
function Get-SQLOpSQLErrorLogStats
{
    [CmdletBinding(DefaultParameterSetName = 'List')] 
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
    
    $ModuleName = 'Get-SQLOpSQLErrorLogStats'
    $ModuleVersion = '0.09'
    $ModuleLastUpdated = 'October 29, 2022'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        #What is T-SQL Doing?
        $TSQL = "SELECT vSI.ComputerName, vSI.SQLInstanceName, SI.ErrorLog_LastDateTimeCaptured AS LastDateTimeCaptured
                FROM dbo.SQLInstances SI
                JOIN dbo.vSQLInstances vSI
                ON SI.SQLInstanceID = vSI.SQLInstanceID "

        if (!($ListAvailable))
        {
            # Validate sql instance exists.
            $ServerInstanceObj = Get-SqlOpSQLInstance -ServerInstance $ServerInstance -Internal

            IF ($ServerInstanceObj -eq $Global:Error_ObjectsNotFound)
            {
                Write-StatusUpdate "Failed to find SQL Instance [$ServerInstance] in SQLOpsDB." -WriteToDB
                Write-Output $Global:Error_FailedToComplete
                return
            }

            $TSQL += "WHERE SI.SQLInstanceID = $($ServerInstanceObj.SQLInstanceID)"
        }

        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                                    -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                                    -Query $TSQL
        
        # If no result sets are returned return an error; unless return the appropriate result set.
        if (!($Results))
        {
            Write-Output $Global:Error_ObjectsNotFound
        }
        else
        {
            Write-Output $Results
        }
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
        Write-Output $Global:Error_FailedToComplete
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Exception" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}