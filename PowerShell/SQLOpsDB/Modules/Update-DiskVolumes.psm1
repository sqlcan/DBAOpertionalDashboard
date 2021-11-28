<#
.SYNOPSIS
Update-DiskVolumes

.DESCRIPTION 
This script drives all aspects to updating disk volume information; discovery &
updating storage information.  If volume is missing it will be added; if volume
exists, then space information will be updated.

.PARAMETER ComputerName
Server name in question where the disk volumes are being scanned.

.PARAMETER ClusterName
Server cluster name in question where the disk volumes are being scanned.

.INPUTS
None

.OUTPUTS
None

.EXAMPLE
Update-DiskVolumes -ComputerName ContosoSQL

Discover all volumes on ContosoSQL; if already exists grab new disk space consumption
details.

.NOTES
Date       Version Comments
---------- ------- ------------------------------------------------------------------
????.??.?? 0.01    Initial Version
2017.02.21 0.02    Added additional checks when adding an instance; if script cannot
                   find server or cluster name, instance addition fails with
                   appropriate recorded in error log.
           0.03    Updated code/documentation to fit new command let template.
2017.02.23 0.04    Introduced a new bug with validation checks; where code was
                   exiting execution even when Servers/Cluster objects existed.
           0.05    Update error reporting to include the fail server information
                   in the context.
2020.03.12 0.06    Updated to to use Get-SQLOpServer vs Get-Server.
2020.03.15 0.00.07 Updated to use Get-SQLOpSQLCluster.
2020.03.16 0.00.08 Rewriting the whole procedure is not possible right now.  Due to
				   the complex logic of how disks are mapped to a server vs cluster.
				   I instead chose to make minor updates for future.
		   0.00.09 Spelling fixes.
		   0.00.10 Updated parameter names with alias.
		   0.00.11 Updated references to required modules.
2021.11.28 0.01.00 Updated multiple bugs introduced after adding Get-SQLOpServer
                   and Get-SQLOpSQLCluster.  Because this module suports both
				   these command-lets it is now enabled for FQDN also.
#>

<# Side Notes for Future Direction

Get-SIDiskVolume should not be called from this module.  The results should be
passed in via class object similar to other Get-SI* / Update-SQLOp* command-lets.

Need to build additional command lets for Get-SQLOpDiskVolume etc.

#>
function Update-DiskVolumes
{

    [CmdletBinding(DefaultParameterSetName='ComputerName')] 
    param( 
		[Alias('ServerName','Computer','Server','NodeName')]
		[Parameter(ParameterSetName='Name', Position=0, Mandatory=$true)]
		[Parameter(ParameterSetName='ComputerName', Position=0, Mandatory=$true)] [string] $ComputerName,
		[Parameter(ParameterSetName='Name', Position=1, Mandatory=$true)] [string]$ClusterName,
	    [Parameter(ParameterSetName='Name', Position=2, Mandatory=$true)] $FolderList
    )

    $ModuleName = 'Update-DiskVolumes'
    $ModuleVersion = '0.01.00'
    $ModuleLastUpdated = 'Nov. 28, 2021'

    Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated)" 

    $ServerID = 0
    $SQLClusterID = 0

    $ServerObj = Get-SQLOpServer -ComputerName $ComputerName -Internal

	if ($ServerObj -eq $Global:Error_FailedToComplete)
	{
		Write-Output $Global:Error_FailedToComplete
		return
	}
	elseif ($ServerObj -eq $Global:Error_ObjectsNotFound)
    {
		Write-Output $Global:Error_ObjectsNotFound
		return
    }

	$ServerID = $ServerObj.ServerID

    if (!([String]::IsNullOrEmpty($ClusterName)))
    {
        $ClusterObj = Get-SQLOpSQLCluster -Name $ClusterName -Internal

		if ($ClusterObj -eq $Global:Error_FailedToComplete)
		{
			Write-Output $Global:Error_FailedToComplete
			return
		}
		elseif ($ClusterObj -eq $Global:Error_ObjectsNotFound)
		{
			Write-Output $Global:Error_ObjectsNotFound
			return
		}

		$SQLClusterID = $ClusterObj.SQLClusterID
    }	

	$Volumes = Get-SIDiskVolume -ComputerName $ComputerName
	if ($Volumes -eq $Global:Error_FailedToComplete)
	{
		Write-Output $Global:Error_FailedToComplete
		return
	}
	elseif ($Volumes -eq $Global:Error_ObjectsNotFound)
	{
		Write-Output $Global:Error_ObjectsNotFound
		return
	}

    try
    {
        ForEach ($Volume in $Volumes)
        {
            $VolumeID = 0
            $ServerVolumeCount = 0
            $ClusterVolumeCount = 0
            $OtherClusterVolumeCount = 0
            $DriveBelongsTo = 'Server'
            $VolumeName = $($Volume.Name).ToLower()

            if ($VolumeName -like '*\')
            {
                $VolumeName = $VolumeName.SubString(0,$VolumeName.Length-1)
            }

            $TSQL = "SELECT COUNT(*) AS DrvCnt FROM dbo.DiskVolumes DV WHERE DiskVolumeName = '$VolumeName' AND ServerID = $ServerID"
            Write-StatusUpdate -Message $TSQL  -IsTSQL

            $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                        -Database $Global:SQLCMDB_DatabaseName `
                                        -Query $TSQL -ErrorAction Stop

            $ServerVolumeCount = $Results.DrvCnt

            # Get the number of volumes assigned to cluster; if the current $SQLServer is not a clustered instance the current node can still belong to a cluster
            # Therefore we must check to make sure the volume discovered is not part of a clustered instance already before attempting to add to server.

            if ($SQLClusterID -ne 0)
            {

                $TSQL = "SELECT COUNT(*) AS DrvCnt FROM dbo.DiskVolumes DV WHERE DiskVolumeName = '$VolumeName' AND SQLClusterID = $SQLClusterID"
                Write-StatusUpdate -Message $TSQL  -IsTSQL

                $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                            -Database $Global:SQLCMDB_DatabaseName `
                                            -Query $TSQL -ErrorAction Stop

                $ClusterVolumeCount = $Results.DrvCnt

				# A volume can belong to server, current sql instance (FCI) being checked, or another FCI running on same node.  However if it is another FCI
				# we do not know the SQL Cluster Name, therefore it must be found based on Server Name and Volume Name pair.  
				$TSQL = "SELECT COUNT(*) AS DrvCnt
						FROM dbo.DiskVolumes DV
						JOIN dbo.SQLClusters SC
							ON DV.SQLClusterID = SC.SQLClusterID
							AND DV.ServerID IS NULL
						JOIN dbo.SQLClusterNodes CN
							ON SC.SQLClusterID = CN.SQLClusterID
							AND CN.SQLNodeID = $ServerID
						WHERE DiskVolumeName = '$VolumeName'
							AND SC.SQLClusterID <>  $SQLClusterID"
				Write-StatusUpdate -Message $TSQL  -IsTSQL

				$Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
											-Database $Global:SQLCMDB_DatabaseName `
											-Query $TSQL -ErrorAction Stop

				$OtherClusterVolumeCount = $Results.DrvCnt
            }


            if (($VolumeName -eq 'C:') -or ($VolumeName -eq 'D:'))
            {
                if ($ServerVolumeCount -eq 0)
                {

                    $TSQL = "INSERT INTO dbo.DiskVolumes (DiskVolumeName, ServerID) VALUES ('$VolumeName',$ServerID)"
                    Write-StatusUpdate -Message $TSQL  -IsTSQL

                    Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL -ErrorAction Stop
                }

                $TSQL = "SELECT DiskVolumeID, IsMonitored FROM dbo.DiskVolumes DV WHERE DiskVolumeName = '$VolumeName' AND ServerID = $ServerID"
                Write-StatusUpdate -Message $TSQL  -IsTSQL

                $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                            -Database $Global:SQLCMDB_DatabaseName `
                                            -Query $TSQL -ErrorAction Stop

                $VolumeID = $Results.DiskVolumeID
                $VolumeIsMonitored = $Results.IsMonitored
            }
            elseif ($OtherClusterVolumeCount -eq 0)
            {

                # This volume is either a new volume that has not been discovered to date. Therefore it belongs to 
                # a) Server
                # b) current FCI
                #
                # If it belongs to the other FCI running on this node we do not need to update the volume information
                # as the information will be updated when we scan that FCI.

                if (($ServerVolumeCount -eq 0) -and ($ClusterVolumeCount -eq 0))
                {

                    if ($SQLClusterID -ne 0)
                    {
                        ForEach ($Folder IN $DBFolderList)
                        {
                            if ($($Folder.FolderName) -Like "*$VolumeName*")
                            {
                                $DriveBelongsTo = "Cluster"
                                break;
                            }
                        }

                        if ($DriveBelongsTo -eq "Server")
                        {
                            ForEach ($Folder IN $BackupFolderList)
                            {
                                if ($($Folder.FolderName) -Like "*$VolumeName*")
                                {
                                    $DriveBelongsTo = "Cluster"
                                    break;
                                }
                            }
                        }
                    }

                    if ($DriveBelongsTo -eq "Server")
                    {

                        $TSQL = "INSERT INTO dbo.DiskVolumes (DiskVolumeName,ServerID) VALUES ('$VolumeName',$ServerID)"
                        Write-StatusUpdate -Message $TSQL  -IsTSQL

                        Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                                      -Database $Global:SQLCMDB_DatabaseName `
                                      -Query $TSQL -ErrorAction Stop

                        $TSQL = "SELECT DiskVolumeID, IsMonitored FROM dbo.DiskVolumes DV WHERE DiskVolumeName = '$VolumeName' AND ServerID = $ServerID"
                        Write-StatusUpdate -Message $TSQL  -IsTSQL

                        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                                 -Database $Global:SQLCMDB_DatabaseName `
                                                 -Query $TSQL -ErrorAction Stop
                    }
                    elseif ($DriveBelongsTo -eq "Cluster")
                    {

                        $TSQL = "INSERT INTO dbo.DiskVolumes (DiskVolumeName,SQLClusterID) VALUES ('$VolumeName',$SQLClusterID)"
                        Write-StatusUpdate -Message $TSQL  -IsTSQL

                        Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                                      -Database $Global:SQLCMDB_DatabaseName `
                                      -Query $TSQL -ErrorAction Stop

                        $TSQL = "SELECT DiskVolumeID, IsMonitored FROM dbo.DiskVolumes DV WHERE DiskVolumeName = '$VolumeName' AND SQLClusterID = $SQLClusterID"
                        Write-StatusUpdate -Message $TSQL  -IsTSQL

                        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                                 -Database $Global:SQLCMDB_DatabaseName `
                                                 -Query $TSQL -ErrorAction Stop
                    }

                    $VolumeID = $Results.DiskVolumeID
                    $VolumeIsMonitored = $Results.IsMonitored

                }
                elseif (($ServerVolumeCount -ne 0) -and ($ClusterVolumeCount -eq 0))
                {
                    if ($SQLClusterID -ne 0)
                    {
                        ForEach ($Folder IN $DBFolderList)
                        {
                            if ($($Folder.FolderName) -Like "*$VolumeName*")
                            {
                                $DriveBelongsTo = "Cluster"
                                break;
                            }
                        }

                        ForEach ($Folder IN $BackupFolderList)
                        {
                            if ($($Folder.FolderName) -Like "*$VolumeName*")
                            {
                                $DriveBelongsTo = "Cluster"
                                break;
                            }
                        }
                    }


                    if ($DriveBelongsTo -eq "Server")
                    {

                        $TSQL = "SELECT DiskVolumeID, IsMonitored FROM dbo.DiskVolumes DV WHERE DiskVolumeName = '$VolumeName' AND ServerID = $ServerID"
                        Write-StatusUpdate -Message $TSQL  -IsTSQL

                        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                                 -Database $Global:SQLCMDB_DatabaseName `
                                                 -Query $TSQL -ErrorAction Stop
                    }
                    elseif ($DriveBelongsTo -eq "Cluster")
                    {

                        $TSQL = "UPDATE dbo.DiskVolumes SET ServerID = NULL, SQLClusterID = $SQLClusterID WHERE DiskVolumeName = '$VolumeName' AND ServerID = $ServerID"
                        Write-StatusUpdate -Message $TSQL  -IsTSQL

                        Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                                      -Database $Global:SQLCMDB_DatabaseName `
                                      -Query $TSQL -ErrorAction Stop

                        $TSQL = "SELECT DiskVolumeID, IsMonitored FROM dbo.DiskVolumes DV WHERE DiskVolumeName = '$VolumeName' AND SQLClusterID = $SQLClusterID"
                        Write-StatusUpdate -Message $TSQL  -IsTSQL

                        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                                 -Database $Global:SQLCMDB_DatabaseName `
                                                 -Query $TSQL -ErrorAction Stop
                    }

                    $VolumeID = $Results.DiskVolumeID
                    $VolumeIsMonitored = $Results.IsMonitored

                }
                elseif (($ServerVolumeCount -eq 0) -and ($ClusterVolumeCount -ne 0))
                {

                    $TSQL = "SELECT DiskVolumeID, IsMonitored FROM dbo.DiskVolumes DV WHERE DiskVolumeName = '$VolumeName' AND SQLClusterID = $SQLClusterID"
                    Write-StatusUpdate -Message $TSQL  -IsTSQL

                    $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                                -Database $Global:SQLCMDB_DatabaseName `
                                                -Query $TSQL -ErrorAction Stop

                    $VolumeID = $Results.DiskVolumeID
                    $VolumeIsMonitored = $Results.IsMonitored
                }
                elseif (($ServerVolumeCount -ne 0) -and ($ClusterVolumeCount -ne 0))
                {
                    # Drive belongs to both Server and VCO.  Which is incorrect.  This can happen because the order the drive was scanned into the system.
                    # VCO mapping takes presidencies over Server mapping.  Therefore we need to move all the space historical data from Server drive
                    # to VCO drive, merging data where information already exists.
                    #
                    # Phase 1 - Delete Data from History.DiskVolumeSpace for Server mapping
                    # Phase 2 - Delete Data from dbo.DiskVolumeSpace for Server mapping 

                    $TSQL = "SELECT DiskVolumeID FROM dbo.DiskVolumes DV WHERE DiskVolumeName = '$VolumeName' AND ServerID = $ServerID"
                    Write-StatusUpdate -Message $TSQL  -IsTSQL

                    $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                                -Database $Global:SQLCMDB_DatabaseName `
                                                -Query $TSQL -ErrorAction Stop

                    $VolumeID = $Results.DiskVolumeID

                    $TSQL = "DELETE FROM dbo.DiskVolumeSpace WHERE DiskVolumeID = $VolumeID"
                    Write-StatusUpdate -Message $TSQL  -IsTSQL

                    $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                                -Database $Global:SQLCMDB_DatabaseName `
                                                -Query $TSQL -ErrorAction Stop

                    $TSQL = "DELETE FROM History.DiskVolumeSpace WHERE DiskVolumeID = $VolumeID"
                    Write-StatusUpdate -Message $TSQL  -IsTSQL

                    $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                                -Database $Global:SQLCMDB_DatabaseName `
                                                -Query $TSQL -ErrorAction Stop

                    $TSQL = "DELETE FROM dbo.DiskVolumes WHERE DiskVolumeID = $VolumeID"
                    Write-StatusUpdate -Message $TSQL  -IsTSQL

                    $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                                -Database $Global:SQLCMDB_DatabaseName `
                                                -Query $TSQL -ErrorAction Stop

                    $VolumeID = 0
                }
            }

            if (($VolumeID -ne 0) -and ($VolumeIsMonitored -eq 1))
            {

                # Only do these updates if we have the volume ID.  We might not have Volume ID if there was error above or if this volume belonged to another FCI that is not being
                # evaluated right now.  

                # Only update the drive usage statistics if volume is setup for monitoring.

                $TSQL = "SELECT COUNT(*) AS RowCnt FROM dbo.DiskVolumeSpace WHERE DiskVolumeID = $VolumeID AND DateCaptured = CAST(GETDATE() AS DATE)"
                Write-StatusUpdate -Message $TSQL  -IsTSQL

                $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                                            -Database $Global:SQLCMDB_DatabaseName `
                                            -Query $TSQL -ErrorAction Stop

                $SpaceUsed = ($($Volume.Capacity) - $($Volume.FreeSpace))/1024/1024
                $TotalSpace = $($Volume.Capacity)/1024/1024

                if ($Results.RowCnt -eq 0)
                {

                    $TSQL = "INSERT INTO dbo.DiskVolumeSpace (DiskVolumeID, DateCaptured, SpaceUsed_mb, TotalSpace_mb) VALUES ($VolumeID,CAST(GETDATE() AS DATE),$SpaceUsed,$TotalSpace)"
                    Write-StatusUpdate -Message $TSQL  -IsTSQL

                    Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL -ErrorAction Stop
                }
                else
                {

                    $TSQL = "UPDATE dbo.DiskVolumeSpace SET SpaceUsed_mb = (SpaceUsed_mb + $SpaceUsed) / 2, TotalSpace_mb = (TotalSpace_mb + $TotalSpace) / 2 WHERE DiskVolumeID = $VolumeID AND DateCaptured = CAST(GETDATE() AS DATE)"
                    Write-StatusUpdate -Message $TSQL  -IsTSQL

                    Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL -ErrorAction Stop
                }

                $TSQL = "UPDATE dbo.DiskVolumes SET LastUpdated = CAST(GETDATE() AS DATE) WHERE DiskVolumeID = $VolumeID"
                Write-StatusUpdate -Message $TSQL  -IsTSQL

                Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                                -Database $Global:SQLCMDB_DatabaseName `
                                -Query $TSQL -ErrorAction Stop
            }

        }

        Write-Output $Global:Error_Successful
        
    }
    catch
    {
        Write-StatusUpdate -Message "$ModuleName [Version $ModuleVersion] - Last Updated ($ModuleLastUpdated) - Unhandled Expection" -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }

}