<#
.SYNOPSIS
Get-SISQLErrorLogs

.DESCRIPTION 
Get-SISQLErrorLogs is a wrapper for Get-SQLErrorLogs to only focus on error messages.

.PARAMETER ServerInstance
Server instance from which to capture the logs.

.PARAMETER After
Date time value from which to capture.

.PARAMETER Before
Date time value from which to capture.

.PARAMETER Internal
For internal processes, it exposes the ID value of the SQL Server instance. 

.INPUTS
None

.OUTPUTS
List of error and interesting messages only.

.EXAMPLE
Get-SISQLErrorLogs -ServerInstance ContosSQL

Get all the errors in the all the error logs.

.EXAMPLE
Get-SISQLErrorLogs -ServerInstance ContosSQL -After "2020/02/01 00:00:00"

Get only the errors after Feb. 1st 12AM.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2020.02.06 0.00.01 Initial Version
2020.02.13 0.00.03 Updated the parameters with parameter set names.
                   Updated reference to Get-SQLInstance to use new variable name.
2020.02.19 0.00.04 Updated command-let name for Get-SQLOpSQLInstance.
2020.03.03 0.00.05 Hid internal parameter in parameter set After.
2020.03.04 0.00.08 Added few more error messages to track.
                   Added functionality to get errors in a time range.
                   Refactored the parameter sets.
2020.03.05 0.00.09 Update to use a custom Error Log collector.
2020.03.06 0.00.10 Bug fix with how new error log collector was called.
#>
function Get-SISQLErrorLogs
{
    [CmdletBinding(DefaultParameterSetName='ServerInstance')] 
    param( 
    [Parameter(ParameterSetName='ServerInstance',Position=0, Mandatory=$true)]
    [Parameter(ParameterSetName='TimeSlice',Position=0, Mandatory=$true)] [string]$ServerInstance,

    [Parameter(ParameterSetName='TimeSlice',Position=1, Mandatory=$false)] [datetime]$After,
    [Parameter(ParameterSetName='TimeSlice',Position=2, Mandatory=$false)] [datetime]$Before,

    [Parameter(Mandatory=$false, DontShow)] [Switch]$Internal
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }
    
    $ModuleName = 'Get-SISQLErrorLogs'
    $ModuleVersion = '0.00.10'
    $ModuleLastUpdated = 'March 6, 2020'

    $ServerInstanceObj = Get-SqlOpSQLInstance -ServerInstance $ServerInstance -Internal:$Internal

    if ($Internal)
    {
        Class SQLErrorMsg {
            [int] $SQLInstanceID;
            [string] $ServerInstance;
            [datetime] $DateTimeCaptured;
            [string] $Message;
        }
    }
    else {
        Class SQLErrorMsg_ex {
            [string] $ServerInstance;
            [datetime] $DateTimeCaptured;
            [string] $Message;
        }
    }

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        if (([String]::IsNullOrEmpty($After)) -and (([String]::IsNullOrEmpty($Before))))
        {
            $SQLErrorLogs = Get-SqlErrorLogs -ServerInstance $ServerInstance
        }
        elseif (!([String]::IsNullOrEmpty($After)) -and (([String]::IsNullOrEmpty($Before))))
        {
            $SQLErrorLogs = Get-SqlErrorLogs -ServerInstance $ServerInstance -After $After
        }
        elseif (([String]::IsNullOrEmpty($After)) -and (!([String]::IsNullOrEmpty($Before))))
        {
            $SQLErrorLogs = Get-SqlErrorLogs -ServerInstance $ServerInstance -Before $Before
        }
        else
        {
            $SQLErrorLogs = Get-SqlErrorLogs -ServerInstance $ServerInstance -After $After -Before $Before
        }

        $CaptureNextLine = $false
        $CompleteMsg = ''
        <#
            This list will most likely grow over time. Might be worth while to make this a configuration option
            to make it easier to modify which errors are worth tracking.

            17187 - SQL Server is not ready to accept new client connections. Wait a few minutes before trying again.
            34052 - Open Message (e.g. Policy Check failed).
            35262 - Skipping the default startup of database '%.*ls' because the database belongs to an availability group.

        #>
        $ErrorToExclude = @(17187,35262,34052)
        
        $ErrorsToReport = @()

        ForEach ($Msg in $SQLErrorLogs)
        {
            if ($CaptureNextLine)
            {

                $CompleteMsg = [String]::Concat($CompleteMsg,' | ',$Msg.Text)

                if ($Internal)
                {
                    $ErrorToReport = New-Object SQLErrorMsg
                    $ErrorToReport.Message = $CompleteMsg
                    $ErrorToReport.DateTimeCaptured = $Msg.Date
                    $ErrorToReport.ServerInstance = $Msg.ServerInstance
                    $ErrorToReport.SQLInstanceID = $ServerInstanceObj.SQLInstanceID
                }
                else {
                    $ErrorToReport = New-Object SQLErrorMsg_ex
                    $ErrorToReport.Message = $CompleteMsg
                    $ErrorToReport.DateTimeCaptured = $Msg.Date
                    $ErrorToReport.ServerInstance = $Msg.ServerInstance                   
                }

                $ErrorsToReport += $ErrorToReport

                $CompleteMsg = ''
                $CaptureNextLine = $false
            }
        
            if ($Msg.Text -match 'Error:\s(?<ErrorNumber>\d*).*Severity:\s(\d*).*State:\s(\d*)')
            {
        
                if ($Matches.ErrorNumber -inotin $ErrorToExclude)
                {
                    $CompleteMsg = $Msg.Text
                    $CaptureNextLine = $true
                }
        
                $Matches = $null
            }
            elseif ($Msg.Text -like 'A significant part of sql server process memory has been paged out.*')
            {
                $CaptureMsg = $true
            }
            elseif ($Msg.Text -like 'AppDomain*due to memory pressure*')
            {
                $CaptureMsg = $true
            }
            elseif ($Msg.Text -like 'SQL Server has encountered*occurrence(s) of I/O requests taking longer than*')
            {
                $CaptureMsg = $true
            }
            elseif ($Msg.Text -like 'Process ID*was killed by hostname*')
            {
                $CaptureMsg = $true
            }
            elseif ($Msg.Text -like '*Stack Dump*')
            {
                $CaptureMsg = $true
            }
        
            if ($CaptureMsg)
            {
                $ErrorToReport = New-Object SQLErrorMsg

                if ($Internal)
                {
                    $ErrorToReport = New-Object SQLErrorMsg
                    $ErrorToReport.Message = $Msg.Text
                    $ErrorToReport.DateTimeCaptured = $Msg.Date
                    $ErrorToReport.ServerInstance = $Msg.ServerInstance
                    $ErrorToReport.SQLInstanceID = $ServerInstanceObj.SQLInstanceID
                }
                else {
                    $ErrorToReport = New-Object SQLErrorMsg_ex
                    $ErrorToReport.Message = $Msg.Text
                    $ErrorToReport.DateTimeCaptured = $Msg.Date
                    $ErrorToReport.ServerInstance = $Msg.ServerInstance                   
                }

                $ErrorsToReport += $ErrorToReport
                $CaptureMsg = $false
            }
        }
        
        Write-Output $ErrorsToReport
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expectation" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}