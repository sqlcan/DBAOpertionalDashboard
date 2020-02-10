<#
.SYNOPSIS
Update-SQLErrorLogStats

.DESCRIPTION 
Update the last collection date for SQL Server instance.  This information
is used to make sure we are only selecting errors since last collection.

.PARAMETER ServerInstance
SQL Server instance for which the date needs to be updated.

.PARAMETER DateTime
Specify a specific date that needs to be updated.  If not supplied, it will 
use current date.

.INPUTS
None

.OUTPUTS
Results for current instance.

.EXAMPLE
Update-SQLErrorLogStats -ServerInstance ContosoSQL

Update the collection date/time to now.

.EXAMPLE
Update-SQLErrorLogStats -ServerInstance ContosoSQL -DateTime '2020-01-01 00:00:00'

Set the date time for collect date to Jan 1, 2020 Midnight.  

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2020.02.07 0.00.01 Initial Version.
#>
function Update-SQLErrorLogStats
{
    [CmdletBinding()] 
    param( 
    [Parameter(ParameterSetName='ServerInstance',Position=0, Mandatory=$true)]
    [Parameter(ParameterSetName='DateTime',Position=0, Mandatory=$true)] [string]$ServerInstance,
    [Parameter(ParameterSetName='DateTime',Position=1, Mandatory=$true)] [DateTime]$DateTime
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Update-SQLErrorLogStats'
    $ModuleVersion = '0.01'
    $ModuleLastUpdated = 'February 7, 2020'
   
    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        $ServerInstanceParts = Split-Parts -ServerInstance $ServerInstance

        # Validate sql instance exists.
        $ServerInstanceObj = Get-SQLInstance -ServerVNOName $ServerInstanceParts.ComputerName -SQLInstanceName $ServerInstanceParts.SQLInstanceName
    
        IF ($ServerInstanceObj -eq $Global:Error_ObjectsNotFound)
        {
            Write-StatusUpdate "Failed to find SQL Instance [$ServerInstance] in SQLOpsDB." -WriteToDB
            Write-Output $Global:Error_FailedToComplete
            return
        }

        if ([String]::IsNullOrEmpty($DateTime))
        {
            $DateTime = (Get-Date -format "yyyy-MM-dd HH:mm:ss")
        }

        $TSQL = "SELECT COUNT(*) AS RwCount FROM dbo.SQLErrorLog_Stats WHERE SQLInstanceID = $($ServerInstanceObj.SQLInstanceID)" 
        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                            -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                            -Query $TSQL
        
        if ($Results.RwCount -eq 0)
        {
            $TSQL = "INSERT INTO dbo.SQLErrorLog_Stats (SQLInstanceID,LastDateTimeCaptured) VALUES ($($ServerInstanceObj.SQLInstanceID),'$DateTime')"             
        }
        else
        {
            $TSQL = "UPDATE dbo.SQLErrorLog_Stats SET LastDateTimeCaptured = '$DateTime' WHERE SQLInstanceID = $($ServerInstanceObj.SQLInstanceID)"             
        }

        Write-StatusUpdate -Message $TSQL -IsTSQL
        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                      -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                      -Query $TSQL
        
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
                    AND SI.ServerID IS NULL
                  WHERE SI.SQLInstanceID = $($ServerInstanceObj.SQLInstanceID)"

        Write-StatusUpdate -Message $TSQL -IsTSQL
        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                                    -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                                    -Query $TSQL
                                                                        
        Write-Output $Results
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expectation" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}