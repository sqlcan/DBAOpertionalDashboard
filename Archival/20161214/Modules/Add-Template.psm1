<#
.SYNOPSIS
Add-Template

.DESCRIPTION 
Add-Template

.PARAMETER ServerVNOName
Left side part of ServerName\InstanceName pair.

.PARAMETER SQLInstanceName
Right side part of ServerName\InstanceName pair.


.INPUTS
None

.OUTPUTS
Add-Template

.EXAMPLE
PowerShell Command Let

Description

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
#>
function Add-Template
{

    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerVNOName,
    [Parameter(Position=1, Mandatory=$true)] [string]$SQLInstanceName
    )

    $ModuleName = 'Add-Template'
    $ModuleVersion = '0.01'
    $ModuleLastUpdated = 'June 9, 2016'
    $OutputLevel = $Global:OutputLevel_Zero

    try
    {
        $OutputLevel++
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)" -Level $OutputLevel

        #Get total number of objects with same ...
        $TSQL = "SELECT COUNT(*) AS ClusCnt FROM dbo.SQLClusters WHERE SQLClusterName = '$SQLClusterName'"
        $OutputLevel++
        Write-StatusUpdate -Message $TSQL  -Level $OutputLevel -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL -ErrorAction Stop

        #If count value is greater then zero, then object already exists.  If less then zero, object is new.
        if ($Results.ClusCnt -eq 0)
        {

            $TSQL = "INSERT INTO dbo.SQLClusters (SQLClusterName) VALUES ('$SQLClusterName')"
            $OutputLevel++
            Write-StatusUpdate -Message $TSQL  -Level $OutputLevel -IsTSQL

            Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                            -Database $Global:SQLCMDB_DatabaseName `
                            -Query $TSQL -ErrorAction Stop

            Write-Output $Global:Error_Successful

        }
        else
        {
            Write-Output $Global:Error_Duplicate
        }
    }
    catch
    {
        $OutputLevel++
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expection" -Level $OutputLevel -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $OutputLevel -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }

}