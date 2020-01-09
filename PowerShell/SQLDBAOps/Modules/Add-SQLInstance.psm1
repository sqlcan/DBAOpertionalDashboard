<#
.SYNOPSIS
Add-SQLInstnace

.DESCRIPTION 
Allows a new instance to be added, mapping to a SQL Cluster Name or Server Name.

.PARAMETER ServerVNOName
Left side part of ServerName\InstanceName pair.

.PARAMETER SQLInstanceName
Right side part of ServerName\InstanceName pair.

.PARAMETER SQLVersion
English full name of version; e.g. "Microsoft SQL Server 2012".

.PARAMETER SQLEdition
English full name of the edition; not required full form. But recommended.
E.g. "Enterprise Edition"

.PARAMETER ServerType
Virtual? or Physical?

.PARAMETER ServerEnviornment
Prod? or Test?

.INPUTS
None

.OUTPUTS
None

.EXAMPLE
Add-SQLInstance -SserverVCOName ServerA -SQLInstanceName Inst01
-SQLVersion "Microsoft SQL Server 2008 R2" -SQLServer_Build 4567
-SQLEdition "Enterprise Edition" -ServerType Physical -ServerEnvironment Test

Add a new instance with name Inst01 mapping to ServerA with all the key properties.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
????.??.?? 0.01    Inital Version
2017.02.21 0.02    Added additional checks when adding an instance; if script cannot
                   find server or cluster name, instance addition fails with
                   appropriate recorded in error log.
           0.03    Updated code/documentation to fit new command let template.
#>

function Add-SQLInstance
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerVNOName,
    [Parameter(Position=1, Mandatory=$true)] [string]$SQLInstanceName,
    [Parameter(Position=2, Mandatory=$true)] [string]$SQLVersion,
    [Parameter(Position=3, Mandatory=$true)] [int]$SQLServer_Build,
    [Parameter(Position=4, Mandatory=$true)] [string]$SQLEdition,
    [Parameter(Position=5, Mandatory=$true)] [string]$ServerType,
    [Parameter(Position=6, Mandatory=$true)] [string]$ServerEnviornment
    )

    $ModuleName = 'Add-SQLInstance'
    $ModuleVersion = '0.03'
    $ModuleLastUpdated = 'February 21, 2017'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        $TSQL = "SELECT COUNT(*) AS SvrCnt
                   FROM dbo.SQLInstances SI
                   JOIN dbo.Servers S
                     ON SI.ServerID = S.ServerID
                    AND SI.SQLClusterID IS NULL
                  WHERE S.ServerName = '$ServerVNOName'
                    AND SI.SQLInstanceName = '$SQLInstanceName'"
        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL -ErrorAction Stop

        $StandAloneInstanceCount = $Results.SvrCnt

        $TSQl = "SELECT COUNT(*) AS SvrCnt
                   FROM dbo.SQLInstances SI
                   JOIN dbo.SQLClusters SC
                     ON SI.SQLClusterID = SC.SQLClusterID
                    AND SI.ServerID IS NULL
                  WHERE SC.SQLClusterName = '$ServerVNOName'
                    AND SI.SQLInstanceName = '$SQLInstanceName'"
        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL -ErrorAction Stop

        $ClusteredInstanceCount = $Results.SvrCnt


        $TSQL = "SELECT TOP 1 SQLVersionID
                   FROM dbo.SQLVersions
                  WHERE SQLVersion LIKE '$SQLVersion%'
                    AND SQLBuild <= $SQLServer_Build
               ORDER BY SQLBuild DESC"

        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL -ErrorAction Stop

        if ($Results)
        {
            $SQLVersionID = $Results.SQLVersionID
        }
        else
        {
            $SQLVersionID = 1
        }

        $Results = Get-SQLCluster $ServerVNOName

        if (($ClusteredInstanceCount -eq 0) -and ($Results -ne $Global:Error_ObjectsNotFound))
        { # This is a cluster and the instance defination does not exist.

            $TSQL = "SELECT SQLClusterID
                       FROM dbo.SQLClusters SC
                      WHERE SC.SQLClusterName = '$ServerVNOName'"
            Write-StatusUpdate -Message $TSQL -IsTSQL

            $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                        -Database $Global:SQLCMDB_DatabaseName `
                                        -Query $TSQL -ErrorAction Stop

            if ($Results)
            {
                $TSQL = "INSERT INTO dbo.SQLInstances (SQLInstanceName, ServerID, SQLClusterID, SQLInstanceVersionID, SQLInstanceBuild, SQLInstanceEdition, SQLInstanceType, SQLInstanceEnviornment) VALUES ('$SQLInstanceName', null, $($Results.SQLClusterID), $SQLVersionID, $SQLServer_Build, '$SQLEdition', '$ServerType', '$ServerEnviornment')"
                Write-StatusUpdate -Message $TSQL -IsTSQL

                Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                -Database $Global:SQLCMDB_DatabaseName `
                                -Query $TSQL -ErrorAction Stop

                Write-Output $Global:Error_Successful
            }
            else
            {
                Write-StatusUpdate -Message "Failed to exectue $ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) for cluster [$ServerVNOName] -- Cluster not found in CMDB." -WriteToDB
                Write-Output $Global:Error_FailedToComplete
            }
        }
        elseif (($StandAloneInstanceCount -eq 0) -and ($ClusteredInstanceCount -eq 0))
        {
            $TSQL = "SELECT S.ServerID
                       FROM dbo.Servers S
                      WHERE S.ServerName = '$ServerVNOName'"
            Write-StatusUpdate -Message $TSQL -IsTSQL

            $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                        -Database $Global:SQLCMDB_DatabaseName `
                                        -Query $TSQL -ErrorAction Stop
                 
            if ($Results)
            {
                $TSQL = "INSERT INTO dbo.SQLInstances (SQLInstanceName, ServerID, SQLClusterID, SQLInstanceVersionID, SQLInstanceBuild, SQLInstanceEdition, SQLInstanceType, SQLInstanceEnviornment) VALUES ('$SQLInstanceName', $($Results.ServerID), null, $SQLVersionID, $SQLServer_Build, '$SQLEdition', '$ServerType', '$ServerEnviornment')"
                Write-StatusUpdate -Message $TSQL -IsTSQL

                Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                -Database $Global:SQLCMDB_DatabaseName `
                                -Query $TSQL -ErrorAction Stop

                Write-Output $Global:Error_Successful 
            }
            else
            {
                Write-StatusUpdate -Message "Failed to exectue $ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)for Server [$ServerVNOName] -- Server not found in CMDB." -WriteToDB
                Write-Output $Global:Error_FailedToComplete
            }
        }
        else
        {
            Write-Output $Global:Error_Duplicate
        }
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expection" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}