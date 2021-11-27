<#
.SYNOPSIS
Set-SQLOpSettings

.DESCRIPTION 
Set-SQLOpSettings allows you to update the predefined settings to allow you to control the 
various cleanup settings.

.PARAMETER SettingName
Setting name for SQL Operational Dashboard, get current settings via Get-SQLOpSettings

.PARAMETER Value
Value variant, can be integer, string, or boolen.

.INPUTS
None

.OUTPUTS
Set-SQLOpSettings

.EXAMPLE
Set-SQLOpSettings -SettingName DebugMode_Enabled -Value $False

Disable debug mode.

.Example
Set-SQLOpSettings -SettingName Default_DomainName -Value "contoso.lab.local"

Change default domain name.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2021.11.27 1.00.00 Initial version.
#>
function Set-SQLOpSetting
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [ValidateSet('DebugMode_Enabled','DebugMode_WriteToDB','DebugMode_OutputTSQL',
													    'SQLOpsDB_Logs_Enabled','SQLOpsDB_Logs_CleanUp_Enabled','SQLOpsDB_Logs_CleanUp_Retention_Days',
														'Expired_Objects_Enabled','Expired_Objects_CleanUp_Retention_Days','Trend_Creation_Enabled',
														'Trend_Creation_CleanUp_Enabled','Trend_Creation_CleanUp_Retention_Months','Aggregate_CleanUp_Enabled',
														'Aggregate_CleanUp_Retention_Months','RawData_CleanUp_Enabled','RawData_CleanUp_Retention_Days',
														'ErrorLog_CleanUp_Enabled','ErrorLog_CleanUp_Retention_Days','SQLAgent_Jobs_CleanUp_Enabled',
														'SQLAgent_Jobs_CleanUp_Retention_Days','Default_DomainName')] [string]$SettingName,
    [Parameter(Position=1, Mandatory=$true)] $Value
    )

	if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    $ModuleName = 'Set-SQLOpSettings'
    $ModuleVersion = '1.00.00'
    $ModuleLastUpdated = 'Nov. 27, 2021'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"		   

		switch ($SettingName)
		{			
			"DebugMode_Enabled" {
				$Global:DebugMode = [Bool]([Int]$Value)
			}
			"DebugMode_WriteToDB" {
				$Global:DebugMode_WriteToDB = [Bool]([Int]$Value)
			}
			"DebugMode_OutputTSQL" {
				$Global:DebugMode_OutputTSQL = [Bool]([Int]$Value)
			}
			"SQLOpsDB_Logs_Enabled" {
				$Global:SQLOpsDB_Log_Enabled = [Bool]([Int]$Value)
			}
			"SQLOpsDB_Logs_CleanUp_Enabled" {
				$Global:SQLOpsDB_Log_CleanUp_Enabled = [Bool]([Int]$Value)
			}
			"SQLOpsDB_Logs_CleanUp_Retention_Days" {
				$Global:SQLOpsDB_Logs_CleanUp_Retention_Days = [Int]$Value
				if (($Global:SQLOpsDB_Logs_CleanUp_Retention_Days -le 29) -or ($Global:SQLOpsDB_Logs_CleanUp_Retention_Days -ge 181))
				{
					Write-StatusUpdate -Message "SQLOpsDB_Logs_CleanUp_Retention_Days threshold out of valid range (30 - 180) days. Defaulting to 30." -WriteToDB
					$Global:SQLOpsDB_Logs_CleanUp_Retention_Days = 30
					$Value = 30
				}
			}
			"Expired_Objects_Enabled" {
				$Global:Expired_Objects_Enabled = [Bool]([Int]$Value)
			}
			"Expired_Objects_CleanUp_Retention_Days" {
				$Global:Expired_Objects_CleanUp_Retention_Days = [Int]$Value
				if (($Global:Expired_Objects_CleanUp_Retention_Days -le 89) -or ($Global:Expired_Objects_CleanUp_Retention_Days -ge 121))
				{
					Write-StatusUpdate -Message "Expired_Objects_CleanUp_Retention_Days threshold out of valid range (90 - 120) days. Defaulting to 90." -WriteToDB
					$Global:Expired_Objects_CleanUp_Retention_Days = 90
					$Value = 90
				}
			}
			"Trend_Creation_Enabled" {
				$Global:Trend_Creation_Enabled = [Bool]([Int]$Value)
			}
			"Trend_Creation_CleanUp_Enabled" {
				$Global:Trend_Creation_CleanUp_Enabled = [Bool]([Int]$Value)
			}
			"Trend_Creation_CleanUp_Retention_Months" {
				$Global:Trend_Creation_CleanUp_Retention_Months = [Int]$Value
				if (($Global:Trend_Creation_CleanUp_Retention_Months -le 11) -or ($Global:Trend_Creation_CleanUp_Retention_Months -ge 61))
				{
					Write-StatusUpdate -Message "Trend_Creation_CleanUp_Retention_Months threshold out of valid range (12 - 60) months. Defaulting to 12." -WriteToDB
					$Global:Trend_Creation_CleanUp_Retention_Months = 12
					$Value = 12
				}
			}
			"Aggregate_CleanUp_Enabled" {
				$Global:Aggregate_CleanUp_Enabled = [Bool]([Int]$Value)
			}
			"Aggregate_CleanUp_Retention_Months" {
				$Global:Aggregate_CleanUp_Retention_Months = [Int]$Value
				if (($Global:Aggregate_CleanUp_Retention_Months -le 11) -or ($Global:Aggregate_CleanUp_Retention_Months -ge 61))
				{
					Write-StatusUpdate -Message "Aggregate_CleanUp_Retention_Months threshold out of valid range (12 - 60) months. Defaulting to 12." -WriteToDB
					$Global:Aggregate_CleanUp_Retention_Months = 12
					$Value = 12
				}
			}
			"RawData_CleanUp_Enabled" {
				$Global:RawData_CleanUp_Enabled = [Bool]([Int]$Value)
			}
			"RawData_CleanUp_Retention_Days" {
				[Int]$Global:RawData_CleanUp_Retention_Days = [Int]$Value
				if (($Global:RawData_CleanUp_Retention_Days -le 30) -or ($Global:RawData_CleanUp_Retention_Days -ge 63))
				{
					Write-StatusUpdate -Message "RawData_CleanUp_Retention_Days threshold out of valid range (31 - 62) days. Defaulting to 31." -WriteToDB
					$Global:RawData_CleanUp_Retention_Days = 31
					$Value = 31
				}
			}
			"ErrorLog_CleanUp_Enabled" {
				[Bool]$Global:ErrorLog_CleanUp_Enabled = [Bool]([Int]$Value)
			}
			"ErrorLog_CleanUp_Retention_Days" {
				[Int]$Global:ErrorLog_CleanUp_Retention_Days = [Int]$Value
				if (($Global:ErrorLog_CleanUp_Retention_Days -le 29) -or ($Global:ErrorLog_CleanUp_Retention_Days -ge 181))
				{
					Write-StatusUpdate -Message "ErrorLog_CleanUp_Retention_Days threshold out of valid range (30 - 180) days. Defaulting to 45." -WriteToDB
					$Global:ErrorLog_CleanUp_Retention_Days = 45
					$Value = 45
				}
			}
			"SQLAgent_Jobs_CleanUp_Enabled" {
				[Bool]$Global:SQLAgent_Jobs_CleanUp_Enabled = [Bool]([Int]$Value)
			}
			"SQLAgent_Jobs_CleanUp_Retention_Days" {
				[Int]$Global:SQLAgent_Jobs_CleanUp_Retention_Days = [Int]$Value
				if (($Global:SQLAgent_Jobs_CleanUp_Retention_Days -le 29) -or ($Global:SQLAgent_Jobs_CleanUp_Retention_Days -ge 181))
				{
					Write-StatusUpdate -Message "SQLAgent_Jobs_CleanUp_Retention_Days threshold out of valid range (30 - 180) days. Defaulting to 180." -WriteToDB
					$Global:SQLAgent_Jobs_CleanUp_Retention_Days = 180
					$Value = 180
				}
			}
			"Default_DomainName" {
				$Global:Default_DomainName = [String]$Value				
			}
		}

		If ($SettingName -ne 'Default_DomainName')
		{
			$TSQL = "UPDATE dbo.Setting SET SettingValue = $([Int]$Value) WHERE SettingName='$SettingName'"
		}
		else {
			$TSQL = "UPDATE dbo.Setting SET SettingValue = '$([String]$Value)' WHERE SettingName='$SettingName'"
		}

        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                                    -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                                    -Query $TSQL

		$TSQL = "SELECT SettingName, SettingValue FROM dbo.Setting WHERE SettingName = '$SettingName'"
		Write-StatusUpdate -Message $TSQL -IsTSQL
        
        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                                    -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                                    -Query $TSQL

        # If no result sets are returned return an error; unless return the appropriate result set.
        if (!($Results))
        {
            Write-Output $Global:Error_FailedToComplete
        }
        else
        {
            Write-Output $Results
        }
	}
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Exception" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}