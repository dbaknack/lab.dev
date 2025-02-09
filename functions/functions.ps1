
function Get-UDFProjectFolder{
    $ParentFolder = Split-Path -Path $PSScriptRoot -Parent
    [pscustomobject]@{Name = $ParentFolder}
}
function ConvertTo-UDFHashtable{
    param($object)

    $hashTable = [ordered]@{}
    if(($object.gettype()).name -eq 'pscustomobject'){
        foreach($property in $object.psobject.properties){
            $hashTable[$property.name] = ConvertTo-UDFHashtable -object $property.value
        }
    }else{
        return $object
    }
   return  $hashtable
}
function Get-UDFConfig{
    param([hashtable]$fromSender)

    $ErrorActionPreference = "Stop"
    if($null -eq $fromSender){
        $fromSender = @{}
    }

    if(-not($fromSender.ContainsKey('Source'))){
        $msgError = "Mandatory parameter 'Source' missing."
        (Write-Error -Message $msgError)
    }
    $source = $fromSender.Source
    if(-not(Test-Path -path $source)){
        $msgError = "Source path '{0}' does not exist." -f $source
        Write-Error -Message $msgError | Out-Null; return $Error[0]
    }
    $item = Get-Item -Path $source
    $content = Get-Content -Path $source 
    switch($item.Extension){
        '.json'{
            ConvertTo-UDFHashtable ($content | ConvertFrom-Json)
        }
        '.csv'{
            $content | ConvertFrom-Csv
        }
        default{
            $msgError = "Configuration file(s) with extension '{0}', are not supported." -f $_
            Write-Error -Message $msgError | Out-Null; return $Error[0]
        }
    }
}
#  disk related function(s)
function Get-ConfigHostDisk{
    param([hashtable]$fromSender)

    $ErrorActionPreference = "Stop"
    if($null -eq $fromSender){
        $fromSender = @{}
    }
    if(-not($fromSender.ContainsKey('HostName'))){
        $msgError = "Mandatory parameter 'HostName' missing."
        (Write-Error -Message $msgError)
    }
    $hostName = $fromSender.HostName

    if(-not($script:configDisk.keys -contains $hostName)){
        $msgError = ("Hostname '{0}' is not listed in the disk.json file.") -f $hostName
        (Write-Error -Message $msgError)
    }

    return $script:configDisk[$hostName]
}
function Get-UDFAllocationUnit{
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
# given a server name, return disks
function Get-ConfigDisk{
    param([hashtable]$fromSender)
    $item = (Get-UDFConfig @{Source = $script:source})

    if(-not($fromSender.ContainsKey('Server'))){
        $msgError = "Mandatory parameter 'Server' missing."
        (Write-Error -Message $msgError)
    }

    $Servers = @($item.Keys)
    $server = $fromSender.Server
    if($Servers -contains $server){
        $item.$server
    }
}
# given a server name and a disk, return config
function Get-ConfigDiskProperties{
    param([hashtable]$fromSender)

    $server = $fromSender.Server
    $item = Get-ConfigDisk @{Server = $server}
    $disks = @($item.Keys)
    $disk = $fromSender.Disk
    if($disks -contains $disk){
        $item.$disk.properties
    }
}
Function Set-OSDisk{
    param([hashtable]$fromSender)
    $ErrorActionPreference = "Stop"
    $diskProperties = Get-ConfigDiskProperties $fromSender

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

    
    $unitSize = Get-UDFAllocationUnit @{Size = $diskProperties.AllocationUnitSize}
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
function ConfigureDisk{
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
#------------------------
# used to get a count of servers in server config
function Get-InternalServerInfo{
    $item = Get-UDFConfig @{Source = $script:Server}
    $min = ($item | Measure-Object -Property RecID -min).Minimum
    if($null -eq $min){
        $min = 0
    }

    $max = ($item | Measure-Object -Property RecID -max).Maximum
    if($null -eq $max){
        $max = 0
    }

    if($item.count -eq 0){
        $Ids = $null
    }else{
        $Ids = $item.RecID
    }
    [pscustomobject]@{
        Min = $min
        Max = $max
        Count = $item.count
        IDs = $Ids
    }
}

# used to check if a given server properties exists in server config
function Get-InternalServerExists{
    param([hashtable]$fromSender)

    $ErrorActionPreference = "Stop"
    if($null -eq $fromSender){
        $fromSender = @{}
    }
    $parameterList = @(
        "Enclave"
        "DomainName"
        "HostName"
    )
    foreach($parameter in $parameterList){
        if(-not($fromSender.ContainsKey($parameter))){
            $msgError = ("Mandatory parameter '{0}' missing." -f $parameter)
            Write-Error -Message $msgError
        }
    }

    $item =  Get-UDFConfig @{Source = $script:Server}
    $exists = $false
    if($null -ne $item){
        $enclave = $fromSender.Enclave
        $domainName = $fromSender.DomainName
        $hostName = $fromSender.HostName
        if($null -ne ($item | Where-Object {$_.Enclave -eq $enclave -and $_.DomainName -eq $domainName -and $_.HostName -eq $hostName})){
            $exists = $true
        }
    }
   
    return $exists
}

#used to add a server to server config
function Add-ConfigServer{
    param([hashtable]$fromSender)

    $ErrorActionPreference = "Stop"
    if($null -eq $fromSender){
        $fromSender = @{}
    }
    $parameterList = @(
        "Servers"
    )
    foreach($parameter in $parameterList){
        if(-not($fromSender.ContainsKey($parameter))){
            $msgError = ("Mandatory parameter '{0}' missing." -f $parameter)
            Write-Error -Message $msgError
        }
    }


    # check to make sure all the properties required are provided for each entry
    $propertiesList = @(
        "Enclave"
        "DomainName"
        "HostName"
    )

    $userInput = $fromSender.Servers
    foreach($entry in $userInput){
        $properties = $entry | Get-Member | Where-Object {$_.memberType -eq "NoteProperty"} | Select-Object "Name"
        foreach($property in $properties){
            if(-not($propertiesList -contains $property.Name)){
                $msgError = "Missing property '{0}'" -f $property.Name
                Write-Error -Message $msgError | Out-Null; return $Error[0]
            }
        }
    }

    # by default let the user choose if they want feed back about action
    if(-not($fromSender.ContainsKey('FeedBack'))){
        $fromSender.Add("FeedBack",$true)
    }
    $FeedBack = $fromSender.FeedBack

    # check to see if any entry provided already exists
    foreach($entry in $userInput){
        
        $exists = Get-InternalServerExists @{
            Enclave = $entry.Enclave
            DomainName = $entry.DomainName
            HostName = $entry.HostName
        }
        $info = Get-InternalServerInfo
        $servers = [PSCustomObject]@(Get-UDFConfig @{Source = $script:Server})
        if(-not($exists)){
            $servers += [pscustomobject]@{
                RecID =  ($info.Max + 1)
                Enclave = $entry.Enclave
                DomainName = $entry.DomainName
                HostName = $entry.HostName
            }
            $newServers = $servers | ConvertTo-Csv -NoTypeInformation
            Set-Content -Path ("{0}\{1}\{2}" -f (Get-UDFProjectFolder).Name,'configs','server.csv') -Value $newServers
        }else{
            if($FeedBack){
                $msg = "Entry with Enclave '{0}', DomainName '{1}', and HostName '{2}' already exists." -f
                $entry.Enclave,
                $entry.DomainName,
                $entry.HostName
                Write-host $msg -ForegroundColor Yellow
            }
        }
    }
}