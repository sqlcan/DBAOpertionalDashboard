﻿<#
.SYNOPSIS
Adds a new AG in the CMDB.

.DESCRIPTION 
Add-AvailabilityGroup connects to the Central Management Database (CMDB) to add a new 
Availability Groups with parameters supplied.

.PARAMETER ServerVNOName
Left side part of ServerName\InstanceName pair.

.PARAMETER SQLInstanceName
Right side part of ServerName\InstanceName pair.

.PARAMETER AGName
Availability group name as it shows up in SQL Server 2012+.

.PARAMETER AGGuid
Availability group name as it shows up in SQL Server 2012+.

.INPUTS
None

.OUTPUTS
Returns success or failure.

.EXAMPLE
Add-AvailabilityGroup -ServerVNOName SQLTest -SQLInstanceName MSSQLServer -AGName AGTest -AGGuid '5EAB1181-6C65-423E-9E68-693FBBA33D92'

Add Availability Group details for a default instance.

.EXAMPLE
Add-AvailabilityGroup -ServerVNOName SCOMServer -SQLInstanceName SCOMInstance -AGName "SCOM Testing" -AGGuid '5EAB1181-6C65-423E-9E68-693FBBA33D92'

Add Availability Group details for a named instance.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2016.07.14 0.00.01 Initial Draft
2016.12.13 0.00.02 Removed -Level from Write-StatusUpdate command let.
2020.02.13 0.02.00 Renamed from Add-AG to Add-AvailabilityGroup.
                   Standardized variable names.
                   Refactored code.
#>
function Add-AvailabilityGroup
{

    [CmdletBinding()] 
    param( 
        [Parameter(Mandatory=$true)] [string] $ServerInstance,
        [Parameter(Mandatory=$true)] [string] $AvailabilityGroupName,
        [Parameter(Mandatory=$true)] [string] $AvailabilityGroupGUID
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    $ModuleName = 'Add-AvailabilityGroup'
    $ModuleVersion = '0.02.00'
    $ModuleLastUpdated = 'February 13, 2020'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        $TSQL = "SELECT COUNT(*) AS AgCnt, AGID
                   FROM dbo.AGs
                  WHERE AGName = '$AGName'
                    AND AGGuid = '$AGGuid'
                  GROUP BY AGID"


        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL -ErrorAction Stop

        if ($Results.AgCnt -gt 0)
        {
            $AGExists = $true
            $AGID = $Results.AGID
        }
        else
        {
            $AGExists = $false
        }

        $TSQL = "   SELECT COUNT(*) AS SQLInstCnt, SI.SQLInstanceID
                      FROM dbo.SQLInstances SI
                 LEFT JOIN dbo.Servers S
                        ON SI.ServerID = S.ServerID
                       AND SI.SQLClusterID IS NULL
                 LEFT JOIN dbo.SQLClusters SC
                        ON SI.SQLClusterID = SC.SQLClusterID
                       AND SI.ServerID IS NULL
                     WHERE SI.SQLInstanceName = '$SQLInstanceName'
                       AND (S.ServerName = '$ServerVNOName' OR
                            SC.SQLClusterName = '$ServerVNOName')
                            GROUP BY SI.SQLInstanceID"


        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL -ErrorAction Stop

        $InstCount = $Results.SQLInstCnt

        if ($InstCount -gt 0)
        {
            $AGInstExists = $true
            $SQLInstanceID = $Results.SQLInstanceID
        }
        else
        {
            $AGInstExists = $false
        }

        If ($AGInstExists)
        {
            If (!($AGExists))
            { #AG does not exist for given AG Name and GUID.  Create new AG.
                $TSQL = "INSERT INTO dbo.AGs (AGName, AGGuid) VALUES ('$AGName','$AGGuid'); SELECT @@IDENTITY AS AGID;"
                Write-StatusUpdate -Message $TSQL -IsTSQL

                $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                            -Database $Global:SQLCMDB_DatabaseName `
                                            -Query $TSQL -ErrorAction Stop

                $AGID = $Results.AGID
            }

            #After AG is created, we need to map the AG to the SQL Instance.
            $TSQL = "INSERT INTO dbo.AGInstances (AGID, SQLInstanceID) VALUES ($AGID,$SQLInstanceID)"
            Write-StatusUpdate -Message $TSQL -IsTSQL

            Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                            -Database $Global:SQLCMDB_DatabaseName `
                            -Query $TSQL -ErrorAction Stop

            Write-Output $Global:Error_Successful
        }
        else
        {
            # Since instance does not exist; we cannot add the AG yet
            # Therefore the mapping with be delayed until instance is discovered.
            Write-Output $Global:Error_NotApplicable
        }

    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expection" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }

}