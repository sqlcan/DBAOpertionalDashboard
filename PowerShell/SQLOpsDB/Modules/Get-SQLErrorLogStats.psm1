<#
.SYNOPSIS
Get-SQLErrorLogStats

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
Get-SQLErrorLogStats -ServerInstance ContosoSQL

Get details for this instance.

.EXAMPLE
Get-SQLErrorLogStats

Get details for all instances and their last collection date/time.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2020.02.07 0.00.01 Initial Version.
#>
function Get-SQLErrorLogStats
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$false)] [string]$ServerInstance
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Get-SQLErrorLogStats'
    $ModuleVersion = '0.01'
    $ModuleLastUpdated = 'February 7, 2020'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        if (!([String]::IsNullOrEmpty($ServerInstance)))
        {
            $ServerInstanceParts = Split-Parts -ServerInstance $ServerInstance

            # Validate sql instance exists.
            $ServerInstanceObj = Get-SQLInstance -ServerVNOName $ServerInstanceParts.ComputerName -SQLInstanceName $ServerInstanceParts.SQLInstanceName

            IF ($ServerInstanceObj -eq $Global:Error_ObjectsNotFound)
            {
                Write-StatusUpdate "Failed to find SQL Instance [$ServerInstance] in SQLOpsDB." -WriteToDB
                Write-Output $Global:Error_FailedToComplete
                return
            }
        }

        #What is T-SQL Doing?
        $TSQL = "SELECT CASE WHEN SI.ServerID IS NULL THEN SC.SQLClusterName ELSE S.ServerName END AS ComputerName, SI.SQLInstanceName, ER.LastDateTimeCaptured
                   FROM dbo.SQLErrorLog_Stats ER
                   JOIN dbo.SQLInstances SI
                     ON ER.SQLInstanceID = SI.SQLInstanceID
              LEFT JOIN dbo.Servers S
                     ON SI.ServerID = S.ServerID
                    AND SI.SQLClusterID IS NULL
              LEFT JOIN dbo.SQLClusters SC
                     ON SI.SQLClusterID = SC.SQLClusterID
                    AND SI.ServerID IS NULL "

        if (!([String]::IsNullOrEmpty($ServerInstance)))
        {
            $TSQL += "WHERE SI.SQLInstanceID = $($ServerInstanceObj.SQLInstanceID)"
        }

        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                                    -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                                    -Query $TSQL
        
        # If no result sets are returned return an error; unless return the appropriate result set.
        if (!($Results))
        {
            # If this is for a SQL instance, then it means there has been no collection for this instance to-date.
            # Create a new default entry in the database and return 1900-01-01 as date.

            if (!([String]::IsNullOrEmpty($ServerInstance)))
            {
                $Results = Update-SQLErrorLogStats -ServerInstance $ServerInstance -DateTime '1900-01-01 00:00:00'
                Write-Output $Results
            }
            else {
                Write-Output $Global:Error_ObjectsNotFound
            }
        }
        else
        {
            Write-Output $Results
        }
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expectation" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}