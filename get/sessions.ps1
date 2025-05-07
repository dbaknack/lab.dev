. .\functions\configs.ps1
. .\functions\servers.ps1
. .\functions\sessions.ps1

PSConfigOpenSessions @{
    ForServers = @{
       ServerName = "sql01"
    }
}