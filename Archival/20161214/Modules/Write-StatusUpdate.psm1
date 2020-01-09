<# 
.SYNOPSIS 
Write Status Updates.
.DESCRIPTION 
Command let writes error log/status details to screen and database; based on the parameters passed.
.PARAMETER Message
Information that needs to be recorded
.PARAMETER Level
Level defines the deapth of the information; it is strictly used for formatting.
.RETURNVALUE 
integer
.NOTES 
Version History 
2015.08.10 -  1.00 - Mohit K. Gupta - Inital Development of Script
#> 

function Write-StatusUpdate
{

    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$Message,
    [Parameter(Position=1, Mandatory=$false)] [int]$Level=0,
    [Parameter(Position=2, Mandatory=$false)] [switch]$IsTSQL,
    [Parameter(Position=3, Mandatory=$false)] [switch]$WriteToDB
    )

    if ($Global:DebugMode)
    {
        if ((!($IsTSQL)) -or
            (($IsTSQL) -and ($Global:DebugMode_OutputTSQL)))
        {
            $Output = ''

            For ($i = 0;$i -lt $Level; $i++){

                $Output += '.'

            }

            if (($host.Name -eq "ConsoleHost") -or ($host.Name -eq "Windows PowerShell ISE Host"))
	        {
                Write-Host "$Output$Message"
            }
            else
            {
                Write-Output "$Output$Message"
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