<#
.SYNOPSIS
Get-CMSServerInstance

.DESCRIPTION 
Returns a list of Server Instances from which data needs to be collected.

.PARAMETER ServerInstance
Server instance to target for collection.

.PARAMETER GroupName
CMS Group name to target for collection.  Group name value can be any folder name
or nested group.  ParentFolder\ChildFolder.

.INPUTS
None

.OUTPUTS
Server Instance List

.EXAMPLE
Get-CMSServerInstance

Return list of servers instances, instance names, connection string, and computer name.

.EXAMPLE
Get-CMSServerInstance -GroupName '2019\Prod'

Return list of servers instances, instance names, connection string, and computer name
under the CMS folder 2019\Prod.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
2016.12.13 0.01    Initial Version.
2020.03.10 2.00.00 Removed the Include Group Name parameters, it will always be returned
                    user can choose to what they want with the information.
                   Introduced new class ServerInstance to collect all information before
                    reporting.
                   Rename command-let to Get-CMSServerInstance.
                   Standardized parameter from ServerName to ServerInstance.
                   Updated SQL Proc to standard name also CMS.GetCMSServerList.
                   Moved the tokenization code from collection script to here.
                   Moved the validation code from collection script to here.
                   Updated to work with New Global Variables and JSON settings file.
                   Added functionality to filter sql instance list by group name.
2020.03.11 2.00.01 Fixed a minor bug with when no objects are returned, return
                    appropriate error message.
#> 
function Get-CMSServerInstance
{
    [CmdletBinding(DefaultParameterSetName='ServerInstance')] 
    param(     
        [Parameter(ParameterSetName='ServerInstance', Mandatory=$false)] [string]$ServerInstance,
        [Parameter(ParameterSetName='GroupName', Mandatory=$false)] [string]$GroupName
    )

    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    $ModuleName = 'Get-CMSServerInstance'
    $ModuleVersion = '2.00.00'
    $ModuleLastUpdated = 'March 10, 2020'

    # Define the class to collect all the information to export to user.
    Class cServerInstance {
        [string] $ServerInstance;
        [string] $ComputerName;
        [string] $SQLInstanceName;
        [string] $ServerInstanceConnectionString;
        [string] $GroupName;
    }


    try
    {
        
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

        if ([String]::IsNullOrEmpty($ServerInstance) -and [String]::IsNullOrEmpty($GroupName))
        {
            $TSQL = "EXEC CMS.GetServerInstanceList"
        }
        elseif (![String]::IsNullOrEmpty($ServerInstance) -and [String]::IsNullOrEmpty($GroupName))
        {
            $TSQL = "EXEC CMS.GetServerInstanceList @ServerName='$ServerInstance'"
        }
        else
        {
            $TSQL = "EXEC CMS.GetServerInstanceList @GroupName='$GroupName'"
        }

        
        Write-StatusUpdate -Message $TSQL -IsTSQL

        $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.SQLInstance `
                                    -Database $Global:SQLOpsDBConnections.Connections.SQLOpsDBServer.Database `
                                    -Query $TSQL
        
        # If no result sets are returned return an error; unless return the appropriate result set.
        if (!($Results))
        {
            Write-Output $Global:Error_ObjectsNotFound
        }
        else
        {
            $ServerInstances = @()

            ForEach ($Row in $Results)
            {
                $ServerInstanceObj = New-Object cServerInstance

                $ServerInstanceObj.GroupName = $Row.GroupName

                $RV_ServerInstance = $Row.ServerInstance                                  # In Central Management Server this is Display Value.
                $RV_ServerInstanceConnectionString = $Row.ServerInstanceConnectionString  # In Central Management Server this is Connection Value.


                # Validate Code #
                # We want to protect collection script and other scripts from breaking if values supplied are not following standards required.
                #
                # Display Name
                # - Must be in format ComputerName[\InstanceName]
                # - Must not include domain name.
                # - Must not include port information.
                #
                # Connect Value
                # - Must be in format FQDN[\InstanceName][,Port]
                # - Must domain name.
                # - May include port information.

                if ($RV_ServerInstance.IndexOf(',') -gt -1)
                {
                    # User has included the port number in display name.  Strip out the port number.
                    #
                    # Raise a warning in logs to correct CMS configuration.

                    Write-StatusUpdate -Message "Display Name in CMS is misconfigured for [$RV_ServerInstance], port number should not be included." -WriteToDB
                    $RV_ServerInstance = $RV_ServerInstance.SubString(0,$RV_ServerInstance.IndexOf(','))
                }

                $TokenizedRV_ServerInstance = $RV_ServerInstance.Split('\') # Parse out the SQL Instance Name
                $TokenizedRV_ServerInstanceConnectionString = $($RV_ServerInstanceConnectionString.Split(',')).Split('\') # Parse out the SQL Instance Name and Port.

                if ($TokenizedRV_ServerInstance[0].IndexOf('.') -gt -1)
                {
                    # User has fully qualified the server name.  Strip away the domain information.
                    #
                    # Raise a warning in logs to correct CMS configuration.

                    Write-StatusUpdate -Message "Display Name in CMS is misconfigured for [$RV_ServerInstance], domain name should not be included." -WriteToDB
                    $OldComputerName = $TokenizedRV_ServerInstance[0]
                    $TokenizedRV_ServerInstance[0] = $TokenizedRV_ServerInstance[0].Substring(0,$TokenizedRV_ServerInstance[0].IndexOf('.'))
                    $RV_ServerInstance = $RV_ServerInstance.Replace($OldComputerName,$TokenizedRV_ServerInstance[0])
        
                }

                if ($TokenizedRV_ServerInstanceConnectionString[0].IndexOf('.') -eq -1)
                {
                    # User is missing fully qualified domain name for server name.  
                    #
                    # Raise a warning in logs to correct CMS configuration.

                    Write-StatusUpdate -Message "Server Name in CMS is misconfigured for [$RV_ServerInstanceConnectionString], domain name should be included; appending [$Global:Default_DomainName]." -WriteToDB
                    $OldComputerName = $TokenizedRV_ServerInstanceConnectionString[0]
                    $TokenizedRV_ServerInstanceConnectionString[0] = [String]::Concat($TokenizedRV_ServerInstanceConnectionString[0],'.',$Global:Default_DomainName)
                    $RV_ServerInstanceConnectionString = $RV_ServerInstanceConnectionString.Replace($OldComputerName,$TokenizedRV_ServerInstanceConnectionString[0])
                }

                $ServerInstanceObj.ServerInstance = $RV_ServerInstance
                $ServerInstanceObj.ComputerName = $TokenizedRV_ServerInstanceConnectionString[0]
                if ($TokenizedRV_ServerInstance.Count -eq 1)
                {
                    $ServerInstanceObj.SQLInstanceName = 'mssqlserver'
                }
                else
                {
                    $ServerInstanceObj.SQLInstanceName = $TokenizedRV_ServerInstance[1]
                }

                # Combined the Tokenized Values together for connection string.
                $ServerInstanceObj.ComputerName = $TokenizedRV_ServerInstanceConnectionString[0]
                $ServerInstanceObj.ServerInstanceConnectionString = $RV_ServerInstanceConnectionString

                $ServerInstances += $ServerInstanceObj

            }

            Write-Output $ServerInstances
        }
    }
    catch
    {
        
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Exception" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }
}