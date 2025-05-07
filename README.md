```powershell
. .\new\module.ps1
Initialize @{RootDirectory = $env:ProgramFiles}
<#Description::    
AddSource @{
    Name = "Files"
    File = "$env:ProgramData\Data\Files.csv"
    Type = ".csv"
    Headings = @("Path")
}
#>

DeleteLog
LogThis @{
    CallerName = "implementation_1"
    Status  = "Informational"
    Message = "module initalized"
}

# GetServers

AddServer @{
    Servers = @(
        [pscustomobject]@{Enclave = "LAB"; DomainName = "Lab.com"; HostName = "win16-vdi01"}
        [pscustomobject]@{Enclave = "LAB"; DomainName = "Lab.com"; HostName = "sql01"}
        [pscustomobject]@{Enclave = "LAB"; DomainName = "Lab.com"; HostName = "sql02"}
        [pscustomobject]@{Enclave = "LAB"; DomainName = "Lab.com"; HostName = "sql03"}
        [pscustomobject]@{Enclave = "LAB"; DomainName = "Lab.com"; HostName = "sql04"}
        [pscustomobject]@{Enclave = "LAB"; DomainName = "Lab.com"; HostName = "app01"}
        [pscustomobject]@{Enclave = "LAB"; DomainName = "Lab.com"; HostName = "app02"}
    )
}

LogThis @{
    CallerName = "implementation_1"
    Status  = "Informational"
    Message = "added some servers to the server list"
}

# get servers by some filter
GetThisServer @{
    RecID = "1"
}

GetThisServer @{
    RecID = @("1","2")
}

GetThisServer @{
    Enclave = @("LAB")
}

# get all servers
GetServers

OpenSomeSessions @{
    To = @{
        ServerName = "sql01"
    }
    CloseWhenDone = $true # not implemented
}
Get-PSSession
RunRemotely @{
    On = @("sql01") # ------------- or "" or * 
    UseFunction = @() # ----------- or "" or * 
    Tasks = [ordered]@{
        "Configure-Disks" = @{
            ArgumentList = @() # -- this can be $null or an empty array or empty string. 
            Script = @{
                Type = "PowerShell" # by default its PowerShell
                Text = "" # or file
            }
        }
    }
}


GetFunction @{Name = "Test2"}
RemoveFunction @{
    Name = "Test"
}

AddFunction @{
    Test = @{
        Name ="Test"
        Tags = @('')
        Description = "This is a test function."
        Parameters = @('')
        ScriptBlock = {HostName}
    }
}
```