<#
.SYNOPSIS
Get-SISQLProperties

.DESCRIPTION 
Get-SISQLProperties collect fixed sql server instance properties to report back.
Such as IsClustered, Edition, and ProductVersion.

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
Get-SISQLProperties -ServerInstance ContosSQL


.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2020.03.12 0.00.01 Initial Version
#>
function Get-SISQLProperties
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerInstance
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Get-SISQLProperties'
    $ModuleVersion = '0.00.01'
    $ModuleLastUpdated = 'March 11, 2020'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        $TSQL = "SELECT   SERVERPROPERTY('IsClustered') AS IsClustered
                        , SERVERPROPERTY('Edition') AS SQLEdition
                        , SERVERPROPERTY('ProductVersion') AS SQLBuild"
        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-SQLCMD -ServerInstance $ServerInstance  `
                                    -Database master `
                                    -Query $TSQL `
                                    -ErrorAction 'Stop'

        # Return an hash table as it will make it easier to access the key value pairs.
        $HashTable = [ordered]@{}

        $HashTable.Add('SQLVersion','')        
        $HashTable.Add('SQLEdition',$Results.SQLEdition)
        $HashTable.Add('IsClustered',$Results.IsClustered)
        $HashTable.Add('SQLBuild_Full',$Results.SQLBuild)

        #Build the SQL Server Version and Windows Version Details
        $TokenizedSQLBuild = $($Results.SQLBuild).Split('.')

        $HashTable.Add('SQLBuild_Major',$TokenizedSQLBuild[0])
        $HashTable.Add('SQLBuild_Minor',$TokenizedSQLBuild[1])
        $HashTable.Add('SQLBuild_Build',$TokenizedSQLBuild[2])

        $SQLVersion = 'Microsoft SQL Server'

        switch ($HashTable['SQLBuild_Major'])
        {
            8
            {
                $SQLVersion += ' 2000'
                break;
            }
            9
            {
                $SQLVersion += ' 2005'
                break;
            }
            10
            {
                $SQLVersion += ' 2008'
                switch ($HashTable['SQLBuild_Minor'])
                {
                    {$_ -ge 50}
                    {
                        $SQLVersion += ' R2'
                    }
                }
                break;
            }
            11
            {
                $SQLVersion += ' 2012'
                break;
            }
            12
            {
                $SQLVersion += ' 2014'
            }
            13
            {
                $SQLVersion += ' 2016'
            }
            14
            {
                $SQLVersion += ' 2017'
            }
            15
            {
                $SQLVersion += ' 2019'
            }
        }

        $HashTable['SQLVersion'] = $SQLVersion

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
        $HashTable = $Global:Error_FailedToComplete
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Exception" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        $HashTable = $Global:Error_FailedToComplete
    }
    finally
    {
        Write-Output $HashTable
    }
}