```powershell
Add-ConfigServer @{
    Servers = @(
        [pscustomobject]@{Enclave = "LAB"; DomainName = "Lab.com"; HostName = "win16-vdi01"}
        [pscustomobject]@{Enclave = "LAB"; DomainName = "Lab.com"; HostName = "sql01"}
        [pscustomobject]@{Enclave = "LAB"; DomainName = "Lab.com"; HostName = "sql02"}
        [pscustomobject]@{Enclave = "LAB"; DomainName = "Lab.com"; HostName = "sql03"}
        [pscustomobject]@{Enclave = "LAB"; DomainName = "Lab.com"; HostName = "sql04"}
        [pscustomobject]@{Enclave = "LAB"; DomainName = "Lab.com"; HostName = "app01"}
        [pscustomobject]@{Enclave = "LAB"; DomainName = "Lab.com"; HostName = "app02"}
        [pscustomobject]@{Enclave = "LAB"; DomainName = "Lab.com"; HostName = "dc01"}

    )
}
```

```powershell
# given a server name, return the disks
Get-ConfigDisk @{
    Server = "win16-vdi01"
}

#given a disk return the properties
Get-ConfigDiskProperties @{
    Server = "win16-vdi01"
    Disk = "Disk 1"
}
```
# Add disk