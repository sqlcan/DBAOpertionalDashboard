<#
.SYNOPSIS
Get-SQLOpErrorDetails

.DESCRIPTION 
Get-SQLOpErrorDetails

.PARAMETER ErrorCode

.INPUTS
None

.OUTPUTS
Provides brief description of the error code and possible reasons.

.EXAMPLE
Get-SQLOpErrorDetails -ErrorCode -3

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2022.10.30 0.00.01 Initial Version
#>
function Get-SQLOpErrorDetails
{
    [CmdletBinding(DefaultParameterSetName='ErrorCode')] 
    param( 
    [Parameter(ParameterSetName='ErrorCode', Mandatory=$true, Position=0)] [int]$ErrorCode
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    $ModuleName = 'Get-SQLOpErrorDetails'
    $ModuleVersion = '0.00.01'
    $ModuleLastUpdated = 'October 30, 2022'

    Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

	# Error codes are limited to -4 to 0 right now.
	if (($ErrorCode -le 0) -and ($ErrorCode -ge -4))
	{
        $HashTable = [ordered]@{}		

		switch ($ErrorCode)
		{
			$Global:Error_Successful
			{
				$HashTable.Add('Internal Variable','$Global:Error_Successful')
				$HashTable.Add('Integer Value',$Global:Error_Successful)
				$HashTable.Add('Description','Command let executed successfully. Information only.')
				$HashTable.Add('Action Required','None.')
			}
			$Global:Error_FailedToComplete
			{
				$HashTable.Add('Internal Variable','$Global:Error_FailedToComplete')
				$HashTable.Add('Integer Value',$Global:Error_FailedToComplete)
				$HashTable.Add('Description','Command failed to complete successfully.')
				$HashTable.Add('Action Required',"Failed to complete can returned due to unexpected issue or data `naerror. Review dbo.Logs or on-screen message for further assistance.")
			}
			$Global:Error_Duplicate
			{
				$HashTable.Add('Internal Variable','$Global:Error_Duplicate')
				$HashTable.Add('Integer Value',$Global:Error_Duplicate)
				$HashTable.Add('Description','Command failed to complete, duplicate data.')
				$HashTable.Add('Action Required',"Failed to complete duplicate data entry was detected in SQLOpDB `ndatabase for given command-let.")
			}
			$Global:Error_ObjectsNotFound
			{
				$HashTable.Add('Internal Variable','$Global:Error_ObjectsNotFound')
				$HashTable.Add('Integer Value',$Global:Error_ObjectsNotFound)
				$HashTable.Add('Description','Missing data.')
				$HashTable.Add('Action Required',"Failed to find the requested object in SQLOpDB database.  This `ncan be error or validation to make sure object does not exist.")
			}
			$Global:Error_NotApplicable
			{
				$HashTable.Add('Internal Variable','$Global:Error_NotApplicable')
				$HashTable.Add('Integer Value',$Global:Error_NotApplicable)
				$HashTable.Add('Description','Information Only.')
				$HashTable.Add('Action Required','Internal Only. If raised submit follow on GitHub for assistance.')
			}
		}

		Write-Output $HashTable
	}

}