. .\functions\configs.ps1
. .\functions\servers.ps1
. .\functions\sessions.ps1
. .\functions\disks.ps1

# use this to open session(s)
PSConfigOpenSessions @{
    ForServers = @{
       ServerName = "sql01"
    }
}

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