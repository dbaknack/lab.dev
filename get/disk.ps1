. .\functions\functions.ps1
$script:source = ".\configs\disk.json"

# configure a disk.
ConfigureDisk @{
    Server = "win16-vdi01"
    Disk = "Disk 1"
}

# configure all disks.
ConfigureDisk @{
    Server = "win16-vdi01"
    Disk = "*"
}

# configure some disks.
ConfigureDisk @{
    Server = "win16-vdi01"
    Disk = @("Disk 1","Disk 2")
}
