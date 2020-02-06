<#
.SYNOPSIS
Get-SQLErrorLogStats

.DESCRIPTION 
Get-SQLErrorLogStats

.PARAMETER ServerVNOName
Left side part of ServerName\InstanceName pair.

.PARAMETER SQLInstanceName
Right side part of ServerName\InstanceName pair.

.INPUTS
None

.OUTPUTS
Get-SQLErrorLogStats

.EXAMPLE
PowerShell Command Let

Description

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
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
    $ModuleLastUpdated = 'June 9, 2016'

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

        Write-StatusUpdate -Message $TSQL

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