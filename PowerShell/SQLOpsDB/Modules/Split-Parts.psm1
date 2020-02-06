<#
.SYNOPSIS
Split-Parts

.DESCRIPTION 
Split-Parts

.PARAMETER ServerVNOName
Left side part of ServerName\InstanceName pair.

.PARAMETER SQLInstanceName
Right side part of ServerName\InstanceName pair.


.INPUTS
None

.OUTPUTS
Split-Parts

.EXAMPLE
PowerShell Command Let

Description

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
#>
function Split-Parts
{
    [CmdletBinding()] 
    param( 
    [Parameter(ParameterSetName='ServerInstance', Position=0, Mandatory=$true)] [string]$ServerInstance,
    [Parameter(ParameterSetName='ComputerName', Position=0, Mandatory=$true)] [string]$ComputerName
    )
    
    if ((Initialize-SQLOpsDB) -eq $Global:Error_FailedToComplete)
    {
        Write-Error "Unable to initialize SQLOpsDB.  Cannot continue with collection."
        return
    }

    $ModuleName = 'Split-Parts'
    $ModuleVersion = '0.01'
    $ModuleLastUpdated = 'June 9, 2016'

    Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)"

    Class ComputerName {
        [String] $ComputerName
        [String] $DomainName
    }

    Class ServerInstance {
        [String] $ComputerName
        [String] $DomainName
        [String] $SQLInstanceName
        [Int] $Port
    }

    # Request is to get parts for SQL Instance Name
    # Expecting format:
    #   Server.Domain\Instance[,Port]

    if ([String]::IsNullOrEmpty($ComputerName))
    {        
        $SQLServerFQDN = $ServerInstance.ToLower()
        $TokenizedSQLInstanceNameFQDN = $($SQLServerFQDN.Split(',')).Split('\')
        $ComputerName = $TokenizedSQLInstanceNameFQDN[0]

        if ($SQLServerFQDN.IndexOf('\') -gt -1)
        {
            $SQLInstanceName = $TokenizedSQLInstanceNameFQDN[1]

            if ($SQLServerFQDN.IndexOf(',') -gt -1)
            {
                $PortNumber = $TokenizedSQLInstanceNameFQDN[2]
            }
            else {
                $PortNumber = 0
            }
        }
        else {
            $SQLInstanceName = 'mssqlserver'
            if ($SQLServerFQDN.IndexOf(',') -gt -1)
            {
                $PortNumber = $TokenizedSQLInstanceNameFQDN[1]
            }
            else {
                $PortNumber = 0
            }
        }
    }

    
    if ($ComputerName.IndexOf('.') -eq -1)
    {
        $DomainName = ""
    }
    else {
        $DomainName = $ComputerName.Substring($ComputerName.IndexOf('.')+1)
        $ComputerName = $ComputerName.Substring(0,$ComputerName.IndexOf('.'))        
    }

    if ([String]::IsNullOrEmpty($ServerInstance))
    {
        $OutputObject = New-Object ComputerName

        $OutputObject.ComputerName = $ComputerName
        $OutputObject.DomainName = $DomainName
    }
    else {
        $OutputObject = New-Object ServerInstance

        $OutputObject.ComputerName = $ComputerName
        $OutputObject.DomainName = $DomainName
        $OutputObject.SQLInstanceName = $SQLInstanceName
        $OutputObject.Port = $PortNumber
    }

    Write-Output $OutputObject
}