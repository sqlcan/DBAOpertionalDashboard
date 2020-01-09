<#
.SYNOPSIS
Write-StatusUpdate

.DESCRIPTION 
Command let writes error log/status details to screen and database; based on the
parameters passed.

.PARAMETER Message
What message needs to be output to screen or database?

.PARAMETER IsTSQL
Used by internal scripts to allow TSQL being executed to be output to screen.
T-SQL is never saved to the database.

.PARAMETER WriteToDB
Not everything is written to database; this is to allow fo minimal logging.
Main information defaults to database is server being processed and any errors
encountered.

.INPUTS
None

.OUTPUTS
Write-StatusUpdate

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2015.08.10 0.01    Inital Development
2016.12.13 0.02    Removed the level attribute from code; as handling that in the
                   various modules was adding extra complexity with minimal benefits.
#>

function Write-StatusUpdate
{

    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$Message,
    [Parameter(Position=1, Mandatory=$false)] [int]$Level=0,   #For Backwards Compatiblity; to be removed serves no purpose.
    [Parameter(Position=2, Mandatory=$false)] [switch]$IsTSQL,
    [Parameter(Position=3, Mandatory=$false)] [switch]$WriteToDB
    )

    $ModuleName = 'Get-CMSServers'
    $ModuleVersion = '0.01'
    $ModuleLastUpdated = 'December 13, 2016'

    try
    {
        if ($Global:DebugMode)
        {

    
            if ((!($IsTSQL)) -or
                (($IsTSQL) -and ($Global:DebugMode_OutputTSQL)))
            {

                if (($host.Name -eq "ConsoleHost") -or ($host.Name -eq "Windows PowerShell ISE Host"))
	            {
                    Write-Host "$Message"
                }
                else
                {
                    Write-Output "$Message"
                }
            }
        }

        if ($WriteToDB)
        {
            $Message = $Message.Replace("'","''")

            $TSQL = "
            INSERT INTO dbo.Logs (DateTimeCaptured, Description)
                 VALUES (GetDate(), '$Message')"


            Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                            -Database $Global:SQLCMDB_DatabaseName `
                            -Query $TSQL -ErrorAction Stop
        }
    }
    catch
    {
        if (($host.Name -eq "ConsoleHost") -or ($host.Name -eq "Windows PowerShell ISE Host"))
	    {
            Write-Host "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expection"
            Write-Host "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)"
        }
        else
        {
            Write-Output "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expection"
            Write-Output "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)"
        }
    }
}