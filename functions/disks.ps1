# function used to get disk(s) given a server name
function Get-PSConfigDisk{
    param([hashtable]$fromSender)

    # if there is an issue with this function, stop.
    $ErrorActionPreference = "Stop"

    $item = Get-PSConfig @{Source = "disk"}

    if(-not($fromSender.ContainsKey('Server'))){
        $msgError = "Mandatory parameter 'Server' missing."
        (Write-Error -Message $msgError)
    }

    $servers = @($item.Keys)
    $server = $fromSender.Server
    if(-not($servers -contains $server)){
        $msgError = "The server provided '{0}' does not have any disk(s.)" -f $server
        (Write-Error -Message $msgError)
    }
    
    if($servers -contains $server){
        $item.$server
    }
}
# function used to get the properties of a disk given a server name and disk number (e.i 'Disk N')
function Get-PSConfigDiskProperties{
    param([hashtable]$fromSender)

    $server = $fromSender.Server
    $item = Get-PSConfigDisk @{Server = $server}
    $disks = @($item.Keys)
    $disk = $fromSender.Disk

    if(-not($disks -contains $disk)){
        $msgError = "The disk provided '{0}' does not exists." -f $disk
        (Write-Error -Message $msgError)
    }
    if($disks -contains $disk){
        $item.$disk.properties
    }
}
function Set-PSConfigOSDisk{
    param([hashtable]$fromSender)
    $ErrorActionPreference = "Stop"
    $diskProperties = Get-PSConfigDiskProperties $fromSender

    $server = $diskProperties.Server
    $number = $diskProperties.Number
    $osDisk = (Get-Disk | Where-Object {$_.Number -eq $number})

    # if ther disk does not exists function fails
    if($null -eq $osDisk){
        $msgError = ("Server '{0}' does not have a disk number '{1}' ") -f $server,$number 
        (Write-Error -Message $msgError)
    }

    # online disk when offline'd, and needs to be online'd
    $status = $diskProperties.Status
    $partition = $diskProperties.Partition
    if(($osDisk.OperationalStatus -eq "Offline") -and ($status -eq "Online")){
        Initialize-Disk -Number $number -PartitionStyle $partition | Out-Null
  
        # the status of the disk is re-assesed
        $osDisk = (Get-Disk | Where-Object {$_.Number -eq $number})
    }

    
    $unitSize = PSConfigDiskAllocationUnit @{Size = $diskProperties.AllocationUnitSize}
    $fileSystem = $diskProperties.FileSystem
    $label = $diskProperties.label
    
    # drive letters are only assigned when then drivefilepath is empty and
    # the driveletter property is not
    if(($diskProperties.DriveLetter -ne '') -and ($diskProperties.DriveFilePath -eq '')){
        $driveLetter = $diskProperties.DriveLetter
        # max is always set when true, and size only used whenmax is false
        if($diskProperties.Capacity.Max -eq $true){
            New-Partition -DiskNumber $number -UseMaximumSize -DriveLetter $driveLetter | Out-Null
        }else{
            $size = $diskProperties.Capacity.Size
            New-Partition -DiskNumber $number -Size $size -DriveLetter $driveLetter | Out-Null
        }
        Format-Volume -DriveLetter $driveLetter -FileSystem $fileSystem -AllocationUnitSize $unitSize -NewFileSystemLabel $label -Confirm:$false -Force | Out-Null
    }
    if(($diskProperties.DriveLetter -eq '') -and ($diskProperties.DriveFilePath -ne '')){
        $driveFilePath = "C:\test"
        $tempDriveLetter = 'E'
        if(-not(Test-Path -Path $driveFilePath)){
            New-Item -Path $driveFilePath -ItemType Directory | Out-Null
        }
        
        # max is always set when true, and size only used whenmax is false
        if($diskProperties.Capacity.Max -eq $true){
            New-Partition -DiskNumber $number -UseMaximumSize  -DriveLetter $tempDriveLetter | Out-Null
        }else{
            $size = $diskProperties.Capacity.Size
            New-Partition -DiskNumber $number -Size $size -DriveLetter $tempDriveLetter| Out-Null
        }
        $partitionNumber = ((Get-Disk -Number $number | Get-Partition) | Select-Object * | Where-Object {$_.Type -eq 'basic'}).partitionNumber
        $tempPartition = Get-Partition -DiskNumber $number -PartitionNumber $partitionNumber
        Format-Volume -DriveLetter $tempDriveLetter -FileSystem $fileSystem -AllocationUnitSize $unitSize -NewFileSystemLabel $label -Confirm:$false -Force | Out-Null
        $tempPartition | Remove-PartitionAccessPath -AccessPath "$($tempDriveLetter):" | Out-Null
        Add-PartitionAccessPath -DiskNumber $number -PartitionNumber $partitionNumber -AccessPath $driveFilePath | Out-Null
    }
}

# helper function to convert a allocation unit size to the correct format when setting up a disk
function PSConfigDiskAllocationUnit{
    param([hashtable]$fromSender)

    $ErrorActionPreference = "Stop"
    if($null -eq $fromSender){
        $fromSender = @{}
    }

    if(-not($fromSender.ContainsKey('Size'))){
        $msgError = "Mandatory parameter 'Size' missing."
        (Write-Error -Message $msgError)
    }

    $allocationUnitSizeList = @(
        "Default"
        512
        1024
        2048
        4096
        8192
        "16K"
        "32K"
        "64K"
    )

    $unit = $fromSender.Size
    if($allocationUnitSizeList -notcontains $unit){
        $msgError = "Allocation unit size can only be any one of the following: {0}." -f (
            "'"+($allocationUnitSizeList -join("','")) + "'"
        )
        Write-Error -Message $msgError
    }

    $computed = "Default"
    if(@("16K","32K", "64K") -contains $unit){
        $computed = 1024 * ([int](($unit[0..1] -join "")))
    }else{
        if($unit -ne "Default"){
            $computed = 1024 * $unit
        }
    }
    return $computed
}
function PSConfigureDisk{
    param([hashtable]$fromSender)

    $ErrorActionPreference = "Stop"
    if($null -eq $fromSender){
        $fromSender = @{}
    }
    $parameterList = @(
        "Server"
        "Disk"
    )
    foreach($parameter in $parameterList){
        if(-not($fromSender.ContainsKey($parameter))){
            $msgError = ("Mandatory parameter '{0}' missing." -f $parameter)
            Write-Error -Message $msgError
        }
    }
    $server = $fromSender.Server
    $disk = $fromSender.Disk
    # all, some, or a single disk can be provided. evaluate what kind of 
    # method is being used and get the disk accordingly.
    $disks = Get-ConfigDisk @{Server = $server}
    $myDisks = @{}
    switch($disk){
        {$disk -eq '*'}{
            $disks.GetEnumerator() | ForEach-Object{
                $myDisks.Add($_.Key,$_.value)
            }
            break
        }
        {$disk -is [array]}{
            foreach($item in $disk){
                if($disks.keys -contains $item){
                    $disks.GetEnumerator() | Where-Object { $_.Key -eq $item} | ForEach-Object{
                        $myDisks.Add($_.Key,$_.value)
                    } 
                }
            }
            break
        }
        {$disk -is [string]}{
            $disks.GetEnumerator() | Where-Object { $_.Key -eq $disk} | ForEach-Object{
                $myDisks.Add($_.Key,$_.value)
            } 
            break
        }
    }
    
    # if there isn't any disk returned, fail
    if($myDisks.count -eq 0){
        $msgError = "There is no disks from configuration that match the provided disk number(s)."
        Write-Error -Message $msgError
    }
    
    # clear out the a possibly large variable.
    $disks = $null
    
    # find the mount points from a collection of disks
    $hasMount = $false
    $diskList = New-Object System.Collections.ArrayList
    $mountPoint =  New-Object System.Collections.ArrayList
    foreach($key in @($myDisks.keys)){
        if($myDisks.$key.properties.IsMountPoint){
            $mountPoint.Add($key) | Out-Null
            $hasMount = $true
        }else{
            $diskList.Add($key) | Out-Null
        }
    }
    
    if($hasMount){
        $masterList = @($mountPoint,$diskList)
    }else{
        $masterList = $diskList; $mountPoint = $null
    }
    
    # start configuration of disks
    $masterList | foreach-object{
        Set-OSDisk @{
            Server = "win16-vdi01"
            Disk = $_
        }
    }
}