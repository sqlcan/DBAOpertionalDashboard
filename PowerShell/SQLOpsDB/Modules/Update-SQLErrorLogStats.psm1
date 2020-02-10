<#
.SYNOPSIS
Update-SQLErrorLogStats

.DESCRIPTION 
Update-SQLErrorLogStats

.PARAMETER ServerVNOName
Left side part of ServerName\InstanceName pair.

.PARAMETER SQLInstanceName
Right side part of ServerName\InstanceName pair.


.INPUTS
None

.OUTPUTS
Update-SQLErrorLogStats

.EXAMPLE
PowerShell Command Let

Description

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
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
    $ModuleLastUpdated = 'June 9, 2016'
   
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