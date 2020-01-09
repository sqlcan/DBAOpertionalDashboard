function Update-DiskVolumes
{

    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)] [string]$ServerName,
    [Parameter(Position=1, Mandatory=$true)] [string]$FQDN,
    [Parameter(Position=2, Mandatory=$false)] [string]$SQLClusterName,
    [Parameter(Position=3, Mandatory=$false)] $DBFolderList,
    [Parameter(Position=4, Mandatory=$false)] $BackupFolderList
    )

    Write-StatusUpdate -Message "Update-DiskVolumes" -Level $Global:OutputLevel_Six

    $ServerID = 0
    $SQLClusterID = 0

    $Results = Get-Server $ServerName

    if ($Results -ne $Global:Error_FailedToComplete)
    {
        $ServerID = $Results.ServerID
    }

    if ($SQLClusterName)
    {
        $Results = Get-SQLCluster $SQLClusterName

        if ($Results -ne $Global:Error_FailedToComplete)
        {
            $SQLClusterID = $Results.SQLClusterID
        }

    }

    $IsServerAccessible = $true

    try
    {
        $WMIComputerName = "$ServerName.$FQDN"
        $Volumes = Get-WmiObject -Class Win32_Volume -ComputerName $WMIComputerName -Filter "DriveType='3'" -ErrorAction Stop
    }
    catch [System.Runtime.InteropServices.COMException]
    {
       Write-StatusUpdate -Message "Could not complete WMI Call to server [$WMIComputerName]; server not found." -Level $Global:OutputLevel_Seven -WriteToDB
       $IsServerAccessible = $false
    }
    catch [System.UnauthorizedAccessException]
    {
       Write-StatusUpdate -Message "Could not complete WMI Call to server [$WMIComputerName]; access deined." -Level $Global:OutputLevel_Seven -WriteToDB
       $IsServerAccessible = $false
    }
    catch [System.Management.ManagementException]
    {
       Write-StatusUpdate -Message "Could not complete WMI Call to server [$WMIComputerName]; WMI call failed." -Level $Global:OutputLevel_Seven -WriteToDB
       $IsServerAccessible = $false
    }
    catch
    {
        Write-StatusUpdate -Message "Could not complete WMI Call to server [$WMIComputerName] (unhandled expection)." -Level $Global:OutputLevel_Seven -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $Global:OutputLevel_Eight -WriteToDB
        $IsServerAccessible = $false
    }

    if (!($IsServerAccessible))
    {
        Write-Output $Global:Error_FailedToComplete
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
            $DiskVolumeDetails = $null

            if ($VolumeName -like '*\')
            {
                $VolumeName = $VolumeName.SubString(0,$VolumeName.Length-1)
            }

            $TSQL = "SELECT COUNT(*) AS DrvCnt FROM dbo.DiskVolumes DV WHERE DiskVolumeName = '$VolumeName' AND ServerID = $ServerID"
            Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

            $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                        -Database $Global:SQLCMDB_DatabaseName `
                                        -Query $TSQL -ErrorAction Stop

            $ServerVolumeCount = $Results.DrvCnt

            # Get the number of volumes assigned to cluster; if the current $SQLServer is not a clustered instance the current node can still belong to a cluster
            # Therefore we must check to make sure the volume discovered is not part of a clustered instance already before attempting to add to server.

            if ($SQLClusterName -ne $null)
            {

                $TSQL = "SELECT COUNT(*) AS DrvCnt FROM dbo.DiskVolumes DV WHERE DiskVolumeName = '$VolumeName' AND SQLClusterID = $SQLClusterID"
                Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

                $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                            -Database $Global:SQLCMDB_DatabaseName `
                                            -Query $TSQL -ErrorAction Stop

                $ClusterVolumeCount = $Results.DrvCnt
            }


            # A volume can belong to server, current sql instance (FCI) being checked, or another FCI running on same node.  However if it is another FCI
            # we do not know the SQL Cluster Name, therefore it must be found stickly based on Server Name and Volume Name pair.  
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
            Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

            $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                        -Database $Global:SQLCMDB_DatabaseName `
                                        -Query $TSQL -ErrorAction Stop

            $OtherClusterVolumeCount = $Results.DrvCnt


            if (($VolumeName -eq 'C:') -or ($VolumeName -eq 'D:'))
            {
                if ($ServerVolumeCount -eq 0)
                {

                    $TSQL = "INSERT INTO dbo.DiskVolumes (DiskVolumeName, ServerID) VALUES ('$VolumeName',$ServerID)"
                    Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

                    Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL -ErrorAction Stop
                }

                $TSQL = "SELECT DiskVolumeID, IsMonitored FROM dbo.DiskVolumes DV WHERE DiskVolumeName = '$VolumeName' AND ServerID = $ServerID"
                Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

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

                    if ($SQLClusterName -ne $null)
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
                        Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

                        Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                                      -Database $Global:SQLCMDB_DatabaseName `
                                      -Query $TSQL -ErrorAction Stop

                        $TSQL = "SELECT DiskVolumeID, IsMonitored FROM dbo.DiskVolumes DV WHERE DiskVolumeName = '$VolumeName' AND ServerID = $ServerID"
                        Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

                        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                                 -Database $Global:SQLCMDB_DatabaseName `
                                                 -Query $TSQL -ErrorAction Stop
                    }
                    elseif ($DriveBelongsTo -eq "Cluster")
                    {

                        $TSQL = "INSERT INTO dbo.DiskVolumes (DiskVolumeName,SQLClusterID) VALUES ('$VolumeName',$SQLClusterID)"
                        Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

                        Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                                      -Database $Global:SQLCMDB_DatabaseName `
                                      -Query $TSQL -ErrorAction Stop

                        $TSQL = "SELECT DiskVolumeID, IsMonitored FROM dbo.DiskVolumes DV WHERE DiskVolumeName = '$VolumeName' AND SQLClusterID = $SQLClusterID"
                        Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

                        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                                 -Database $Global:SQLCMDB_DatabaseName `
                                                 -Query $TSQL -ErrorAction Stop
                    }

                    $VolumeID = $Results.DiskVolumeID
                    $VolumeIsMonitored = $Results.IsMonitored

                }
                elseif (($ServerVolumeCount -ne 0) -and ($ClusterVolumeCount -eq 0))
                {
                    if ($SQLClusterName -ne $null)
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
                        Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

                        $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                                 -Database $Global:SQLCMDB_DatabaseName `
                                                 -Query $TSQL -ErrorAction Stop
                    }
                    elseif ($DriveBelongsTo -eq "Cluster")
                    {

                        $TSQL = "UPDATE dbo.DiskVolumes SET ServerID = NULL, SQLClusterID = $SQLClusterID WHERE DiskVolumeName = '$VolumeName' AND ServerID = $ServerID"
                        Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

                        Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                                      -Database $Global:SQLCMDB_DatabaseName `
                                      -Query $TSQL -ErrorAction Stop

                        $TSQL = "SELECT DiskVolumeID, IsMonitored FROM dbo.DiskVolumes DV WHERE DiskVolumeName = '$VolumeName' AND SQLClusterID = $SQLClusterID"
                        Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

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
                    Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

                    $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                                -Database $Global:SQLCMDB_DatabaseName `
                                                -Query $TSQL -ErrorAction Stop

                    $VolumeID = $Results.DiskVolumeID
                    $VolumeIsMonitored = $Results.IsMonitored
                }
                elseif (($ServerVolumeCount -ne 0) -and ($ClusterVolumeCount -ne 0))
                {
                    # Drive belongs to both Server and VCO.  Which is incorrect.  This can happen because the order the drive was scanned into the system.
                    # VCO mapping takes presidence over Server mapping.  Therefore we need to move all the space historical data from Server drive
                    # to VCO drive, merging data where information already exists.
                    #
                    # Phase 1 - Delete Data from History.DiskVolumeSpace for Server mapping
                    # Phase 2 - Delete Data from dbo.DiskVOlumeSpace for Server mapping 

                    $TSQL = "SELECT DiskVolumeID FROM dbo.DiskVolumes DV WHERE DiskVolumeName = '$VolumeName' AND ServerID = $ServerID"
                    Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

                    $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                                -Database $Global:SQLCMDB_DatabaseName `
                                                -Query $TSQL -ErrorAction Stop

                    $VolumeID = $Results.DiskVolumeID

                    $TSQL = "DELETE FROM dbo.DiskVolumeSpace WHERE DiskVolumeID = $VolumeID"
                    Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

                    $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                                -Database $Global:SQLCMDB_DatabaseName `
                                                -Query $TSQL -ErrorAction Stop

                    $TSQL = "DELETE FROM History.DiskVolumeSpace WHERE DiskVolumeID = $VolumeID"
                    Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

                    $Results = Invoke-SQLCMD -ServerInstance $Global:SQLCMDB_SQLServerName `
                                                -Database $Global:SQLCMDB_DatabaseName `
                                                -Query $TSQL -ErrorAction Stop

                    $TSQL = "DELETE FROM dbo.DiskVolumes WHERE DiskVolumeID = $VolumeID"
                    Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

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
                Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

                $Results = Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                                            -Database $Global:SQLCMDB_DatabaseName `
                                            -Query $TSQL -ErrorAction Stop

                $SpaceUsed = ($($Volume.Capacity) - $($Volume.FreeSpace))/1024/1024
                $TotalSpace = $($Volume.Capacity)/1024/1024

                if ($Results.RowCnt -eq 0)
                {

                    $TSQL = "INSERT INTO dbo.DiskVolumeSpace (DiskVolumeID, DateCaptured, SpaceUsed_mb, TotalSpace_mb) VALUES ($VolumeID,CAST(GETDATE() AS DATE),$SpaceUsed,$TotalSpace)"
                    Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

                    Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL -ErrorAction Stop
                }
                else
                {

                    $TSQL = "UPDATE dbo.DiskVolumeSpace SET SpaceUsed_mb = (SpaceUsed_mb + $SpaceUsed) / 2, TotalSpace_mb = (TotalSpace_mb + $TotalSpace) / 2 WHERE DiskVolumeID = $VolumeID AND DateCaptured = CAST(GETDATE() AS DATE)"
                    Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

                    Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                                    -Database $Global:SQLCMDB_DatabaseName `
                                    -Query $TSQL -ErrorAction Stop
                }

                $TSQL = "UPDATE dbo.DiskVolumes SET LastUpdated = CAST(GETDATE() AS DATE) WHERE DiskVolumeID = $VolumeID"
                Write-StatusUpdate -Message $TSQL -Level $Global:OutputLevel_Seven -IsTSQL

                Invoke-Sqlcmd -ServerInstance $Global:SQLCMDB_SQLServerName `
                                -Database $Global:SQLCMDB_DatabaseName `
                                -Query $TSQL -ErrorAction Stop
            }

        }

        Write-Output $Global:Error_Successful
        
    }
    catch
    {
        Write-StatusUpdate -Message "Failed to Update-DiskVolumes (unhandled expection)." -Level $Global:OutputLevel_Seven -WriteToDB
        Write-StatusUpdate -Message "[$($_.Exception.GetType().FullName)]: $($_.Exception.Message)" -Level $Global:OutputLevel_Seven -WriteToDB
        Write-Output $Global:Error_FailedToComplete
    }

}