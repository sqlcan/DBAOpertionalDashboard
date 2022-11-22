<#
.SYNOPSIS
Set-SQLOpReportLogo

.DESCRIPTION 
Set-SQLOpReportLogo allows you to update binary file for report logo.  The logo 
file must exist on the SQLOpsDB server.  Recommend size 225x54 (wxh) pixels.

.PARAMETER FileName
File Name to add or update. Although any name can be given, the reports default
to DefaultReportLogo.

.PARAMETER FilePath
Binary File to Update.

.PARAMETER FileType
File type? png, jpeg, gif, or bmp.

.INPUTS
None

.OUTPUTS
Set-SQLOpReportLogo

.EXAMPLE
Set-SQLOpReportLogo -FilePath C:\Temp\SQLCanadaLogo.jpeg -FileType png

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2022.11.17 0.00.01 Initial version.
#>
function Set-SQLOpReportLogo
{
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [ValidateSet('jpeg','png','gif','bmp')] [string]$FileType,
    [Parameter(Position=1, Mandatory=$false)] [string]$FileName="DefaultReportLogo",
	[Parameter(Position=2, Mandatory=$true)] [string]$FilePath
    )

	if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    $ModuleName = 'Set-SQLOpReportLogo'
    $ModuleVersion = '0.00.01'
    $ModuleLastUpdated = 'November 18, 2022'

    try
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"		   

		$TSQL = "SELECT COUNT(*) AS RwCount FROM Reporting.ReportLogo WHERE LogoFileName = '$FileName'"
        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                                    -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                                    -Query $TSQL

		IF ($Results.RwCount -eq 0)
		{
			$TSQL = "INSERT INTO Reporting.ReportLogo (LogoFileName, LogoFileType, LogoFile)
			            SELECT '$FileName', '$FileType', (SELECT * FROM OPENROWSET(BULK 'c:\temp\SQLCanadaLogo.png', SINGLE_BLOB) AS ReadFile) LogFile"
		}
		else
		{
			$TSQL = "UPDATE Reporting.ReportLogo
			            SET LogoFile = (SELECT * FROM OPENROWSET(BULK '$FilePath', SINGLE_BLOB),
						    LogoFileType = '$FileType'
					  WHERE LogoFileName = '$FileName'"
		}

		Write-StatusUpdate -Message $TSQL -IsTSQL
      
        Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                      -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                      -Query $TSQL

		Write-Output $Global:Error_Successful
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
        Write-Output $Global:Error_FailedToComplete
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Exception" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}