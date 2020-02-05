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

.EXAMPLE
Write-StatusUpdate -Message "This is a test message!"
Output the message.  This message is only displayed if debug mode is enabled.

.EXAMPLE
Write-StatusUpdate -Message "This is a test message!" -WriteToDB
Output the message and write it to the database operational logs.

.EXAMPLE
Write-StatusUpdate -Message "SELECT * FROM sys.databases" -IsTSQL
Signals that the message is actually T-SQL code. This message will only output if
global parameter setting DebugMode_OutputTSQL is enabled.

.INPUTS
None

.OUTPUTS
None

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2015.08.10 0.00.01 Initial Development
2016.12.13 0.00.02 Removed the level attribute from code; as handling that in the
                   various modules was adding extra complexity with minimal benefits.
2020.02.03 0.00.07 Created Parameter Sets for the various combinations.
                   Updated variable detail to use new JSON connection string property.
                   Fixed spelling mistakes in output.
                   Removed all Write-Host messages, used only Write-Output.
                   Refactor code to clean up some logic statements.
2020.02.04 0.00.08 Added check to make sure module is initialized.
2020.02.05 0.00.09 Fixed bug, which Write-Output.  Using this command-let caused 
                   all messages to queue up.  My intension was to write to screen,
                   therefore changed it to Write-Host.
#>

function Write-StatusUpdate
{

    [CmdletBinding(DefaultParameterSetName='Message')] 
    param( 
        [Parameter(ParameterSetName='Message', Mandatory=$true, Position=0)]
        [Parameter(ParameterSetName='TSQL', Mandatory=$true, Position=0)] 
        [Parameter(ParameterSetName='WritToDB', Mandatory=$true, Position=0)] [string]$Message,
        [Parameter(ParameterSetName='TSQL', Mandatory=$true, Position=1)] [switch]$IsTSQL,
        [Parameter(ParameterSetName='WritToDB', Mandatory=$true, Position=1)] [switch]$WriteToDB,
        $Level # Leaving it for backward compatibility, until I can remove it from all modules.
    )

    $ModuleName = 'Write-StatusUpdate'
    $ModuleVersion = '0.08'
    $ModuleLastUpdated = 'February 4, 2020'

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    try
    {
        # Only if debug mode is enabled, output to screen.
        if ($Global:DebugMode)
        {

            if ((!($IsTSQL)) -or
                (($IsTSQL) -and ($Global:DebugMode_OutputTSQL)))
            {
                # We can only output to host screen.  If I use Write-Output, it queues up all the messages
                # which break data moving from one module to next.
                if (($host.Name -eq "ConsoleHost") -or ($host.Name -eq "Windows PowerShell ISE Host"))
	            {
                    Write-Host $Message
                }
            }
        }

        # Write to database if message has been flagged by module.  
        # Write will only take place if user requested logging.

        if (($WriteToDB) -and ($Global:SQLOpsDB_Log_Enabled))
        {
            $Message = $Message.Replace("'","''")

            $TSQL = "
            INSERT INTO dbo.Logs (DateTimeCaptured, Description)
                VALUES (GetDate(), '$Message')"

            Invoke-SQLCMD -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                            -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                            -Query $TSQL -ErrorAction Stop
        }
    }
    catch
    {
        Write-Error "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Exception"
        Write-Error "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)"
    }
}