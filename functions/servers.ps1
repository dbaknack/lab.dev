# helper function used to get the total number of servers.
function PSConfigHelperServerInfo{
    $item = Get-PSConfig @{Source = "server"}
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

# helper function used to check if a server exists.
function PSConfigHelperServerExists{
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

    $item =  Get-PSConfig @{Source = "server"}
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

# function used to add a server to server config
# Get-PSConfig
function Add-PSConfigServer{
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
        
        $exists = PSConfigHelperServerExists @{
            Enclave = $entry.Enclave
            DomainName = $entry.DomainName
            HostName = $entry.HostName
        }
        $info = PSConfigHelperServerInfo
        $servers = [PSCustomObject]@(Get-PSConfig @{Source = "server"})
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

function Get-PSConfigServer{
    param([hashtable]$fromSender)
    $ErrorActionPreference = "Stop"

    if($null -eq $fromSender){
        $fromSender = @{}
    }

    $fromSenderKeys = @($fromSender.Keys)

    $servers = Get-PSConfig @{Source = "server"}
    # if no keys provided, just return everything
    if($fromSenderKeys.count -eq 0){
        return $servers
    }
    

    # by default all options are set to * 
    if(-not($fromSender.ContainsKey("RecID"))){
        $fromSender.Add("RecID","*")
    }
    $recID = $fromSender.RecID
    if(-not($fromSender.ContainsKey("Enclave"))){
        $fromSender.Add("Enclave","*")
    }
    $enclave = $fromSender.Enclave
    if(-not($fromSender.ContainsKey("DomainName"))){
        $fromSender.Add("DomainName","*")
    }
    $domainName = $fromSender.DomainName
    if(-not($fromSender.ContainsKey("ServerName"))){
        $fromSender.Add("ServerName","*")
    }
    $serverName = $fromSender.ServerName
    
    # asses by recID first
    $servers = switch($recID){
        {$recID -eq '*'}{
            $servers | Where-Object {$_.RecID -like "*"}
            break
        }
        {$recID -is [array]}{
            $servers | Where-Object {$_.RecID -in $recID}
            break
        }
        {$recID -is [string]}{
            $servers | Where-Object {$_.RecID -eq $recID}
            break
        }
    }

    # if all other options are default, then return results here
    if(($enclave -eq '*') -and ($domainName -eq '*') -and ($serverName -eq '*')){
        return $servers
    }

    # asses by enclave second
    $servers = switch($enclave){
        {$enclave -eq '*'}{
            $servers | Where-Object {$_.Enclave -like "*"}
            break
        }
        {$enclave -is [array]}{
            $servers | Where-Object {$_.Enclave -in $enclave}
            break
        }
        {$enclave -is [string]}{
            $servers | Where-Object {$_.Enclave -eq $enclave}
            break
        }
    }
    
    # if all other options are default, then return results here
    if(($domainName -eq '*') -and ($serverName -eq '*')){
        return $servers
    }

    # asses by domain name third
    $servers = switch($domainName){
        {$domainName -eq '*'}{
            $servers | Where-Object {$_.DomainName -like "*"}
            break
        }
        {$domainName -is [array]}{
            $servers | Where-Object {$_.DomainName -in $domainName}
            break
        }
        {$domainName -is [string]}{
            $servers | Where-Object {$_.DomainName -eq $domainName}
            break
        }
    }
    
    # if all other options are default, then return results here
    if(($serverName -eq '*')){
        return $servers
    }


    switch($serverName){
        {$serverName -eq '*'}{
            $servers | Where-Object {$_.DomainName -like "*"}
            break
        }
        {$serverName -is [array]}{
            $servers | Where-Object {$_.HostName -in $serverName}
            break
        }
        {$serverName -is [string]}{
            $servers | Where-Object {$_.HostName -eq $serverName}
            break
        }
    }
}