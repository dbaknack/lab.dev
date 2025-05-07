# initalize the functions required
. .\functions\configs.ps1   # use this to work with functions related to configuration
. .\functions\sessions.ps1  # use this to work with functions realted to sessions
. .\functions\servers.ps1   # use this to work with functions related to servers
. .\functions\disks.ps1     # use this to work with functions related to disks

PSConfigProjectPath
PSConfigVars @{Source = "disk"}
ConvertTo-UDFHashtable (Get-Content -path ".\configs\disk.json" | ConvertFrom-Json)
Get-PSConfig @{Source = "disk"}
SetPSConfiguration @{
    ApplyTo = @("sql01")
    Configuration = [ordered]@{
        Disk = @{
            Disks = @(
                "Disk 1"
                "Disk 2"
                "Disk 3"
                "Disk 4"
                "Disk 5"
                "Disk 6"
                "Disk 7"
            )
        }
    }
}

Get-PSConfigServer @{
    RecID = "1"
}

# given a source key, return the path to that file.
PSConfigVars @{Source = "server"}

# given a source key, return the contents of that file.
Get-PSConfig @{Source = "server"}

# given a server name, return those disk(s).
Get-PSConfigDisk @{Server = "sql01"}

# given a server name and a disk number, return the disk properties
Get-PSConfigDiskProperties @{Server = "sql01"; Disk = "Disk 1"}

# given a server name and disk, configure those disks.
Set-PSConfigOSDisk @{
    Server = "SQL01"
    Disk = "Disk 30"
}