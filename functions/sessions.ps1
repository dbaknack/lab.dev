function PSConfigOpenSessions {
    param([hashtable]$fromSender)
    $ErrorActionPreference = "Stop"
    if($null -eq $fromSender){
        $fromSender = @{}
    }
    
    if(-not($fromSender.ContainsKey("ForServers"))){
        $msgError = ("Mandatory parameter '{0}' missing." -f "ForServers")
        Write-Error -Message $msgError
    }

    if(-not($fromSender.ContainsKey("Credential"))){
        $fromSender.Add("Credential",$null)
    }

    if($fromSender.ForServers.keys.count -eq 0){
        clear-host
        $msg = "Note: When ForServers is set to '@{}', a session to all servers in config\server.csv will attempt to be made."
        Write-host $msg -ForegroundColor Magenta 
        $prompt = "If this is the desired action press 'Y' if not, press 'N'"
        do{
            $userInput = read-host ("{0}" -f $prompt)
            if(($userInput -ne 'Y') -and ($userInput -ne 'N)')){
                Write-Host "Invalid Input" -ForegroundColor Red
            }
        }until($userInput -eq 'Y' -or $userInput -eq 'N')

        if($userInput -eq 'N'){
            $msgError = "User terminated function"
            Write-Error -Message $msgError
        }

        if($userInput -eq 'Y'){
            $servers = Get-PSConfigServer
        }
    }else{
        $servers = Get-PSConfigServer $fromSender.ForServers
    }
    

    if($servers.count -eq 0){
        $msgError = "No server(s) were returned, given your search criteria."
        Write-Error -Message $msgError
    }
    
    # is there any session(s) that are open?
    $sessions = Get-PSSession
    if(-not($null -eq $sessions)){
        Get-PSSession | Remove-PSSession | Out-Null 
        $msg = "'{0}' session(s) closed." -f ($sessions.count)
        Write-Host $msg -ForegroundColor Cyan
    }

    foreach($server in $servers){
        if($null -eq $creds){
            New-PSSession -ComputerName $server.HostName -ErrorAction Stop  | Out-Null
        }else{
            New-PSSession -ComputerName $server.HostName -Credential $creds -ErrorAction Stop  | Out-Null
        }
        
        $msg = "Session to '{0}' opened." -f $server.HostName
        Write-Host $msg -ForegroundColor Cyan
    }
    $msg = "Done!" -f $server.HostName
    Write-Host $msg -ForegroundColor Cyan
}

function Invoke-PSCMD{
    param([hashtable]$Params)
    $ErrorActionPreference = "Stop"

    if(-not($Params.ContainsKey("Session"))){
        $sessions = Get-PSSession
    }else{
        $sessions = $Params.Session
    }
    
    # there needs to a session
    if($sessions.count -eq 0){
        Write-Error  "There is no session(s) currently open."
    }
    foreach($Session in $sessions){
        Invoke-Command -session $session -ScriptBlock {
            param($ArgumentList)
            $ScriptBlock = [scriptblock]::Create($ArgumentList.Function)
            $ArgumentList = $ArgumentList.Paremeters

            Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
        } -ArgumentList @{
            Paremeters = $Params.FromSender
            Function = $Params.ScriptBlock
        }
    }
    $results
}