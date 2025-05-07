function OpenSomeSessions {
    param([hashtable]$fromSender)
    $ErrorActionPreference = "Stop"
    if($null -eq $fromSender){
        $fromSender = @{}
    }
    
    if(-not($fromSender.ContainsKey("To"))){
        $msgError = ("Mandatory parameter '{0}' missing." -f "To")
        Write-Error -Message $msgError
    }

    if(-not($fromSender.ContainsKey("Credential"))){
        $fromSender.Add("Credential",$null)
    }

    $servers = GetThisServer $fromSender.To
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
function LogThis{
    param([hashtable]$fromSender)
    $settings = GetSettings
    $loggingEnabled = $settings.Settings.General.Logging
    $loggingSettings = $settings.Settings.Logging
    $file = $settings.Logging.File
    $headings = $settings.Logging.Headings
    $logfileExists = test-path -path $file

    if(-not($logfileExists)){
        new-item -path $file  -ItemType file -force | Out-Null
        Add-Content -path $file -Value $headings
    }

    if($loggingEnabled){
        if(-not($fromSender.ContainsKey('Message'))){
            $fromSender.Add('Message','')
        }
        $message = $fromSender.Message
        if(-not($fromSender.ContainsKey('CallerName'))){
            $fromSender.Add('CallerName','Unknown')
        }
        $caller = $fromSender.CallerName
        if(-not($fromSender.ContainsKey('Status'))){
            $fromSender.Add('Status','Unknown')
        }
        $status = $fromSender.Status
        $todaysDateTime = (get-date)
        $path = $file

        $interval = $loggingSettings.Interval
        $period = $loggingSettings.RetentionPeriod
        $lastEntryDateTime = $loggingSettings.LastEntryDateTime
        $lastEntryID =  $loggingSettings.LastEntryID
        $entryString = $headings

        $newID = $lastEntryID + 1
        if($lastEntryDateTime.length -ne 0){
            $lastDateTime = [datetime]$lastEntryDateTime
            $lastDateTimePlusInterval = switch($interval){
                "day"{$lastDateTime.AddDays($period)}
                "hour"{$lastDateTime.AddHours($period)}
                "minute"{$lastDateTime.AddMinutes($period)}
                "second"{$lastDateTime.AddSeconds($period)}
            }

            # reset 
            if($todaysDateTime -gt $lastDateTimePlusInterval){
                set-content -path $path -value $entryString
                $newID = 1
            }   
        }
        
        $entryString = $entryString -replace ("RecID",$newID)
        $entryString = $entryString -replace ("DateTime",$todaysDateTime.ToString($properties.DateTimeFormat))
        $entryString = $entryString -replace ("Function",$caller)
        $entryString = $entryString -replace ("Status",$status)
        $entryString = $entryString -replace ("Message",$message)
        add-content -path $path -value $entryString
        
        $settings.Settings.Logging.LastEntryID = $newID
        $settings.Settings.Logging.LastEntryDateTime = ($todaysDateTime.ToString($properties.DateTimeFormat))
        UpdateSettings @{Settings = $settings}
    }
}
function DeleteLog{
    $ErrorActionPreference = "Stop"
    $settings = GetSettings
    $file = $settings.Logging.File
    Remove-Item -path $file -force | Out-Null
    $settings.Settings.Logging.LastEntryID = 0
    UpdateSettings  @{Settings = $settings}
}
function ConvertToHashTable{
    param($object)
    $hashTable = [ordered]@{}
    if(($object.gettype()).name -eq 'pscustomobject'){
        foreach($property in $object.psobject.properties){
            $hashTable[$property.name] = ConvertToHashTable -object $property.value
        }
    }else{
        return $object
    }
   return  $hashtable
}
function Initialize{
    param([hashtable]$fromSender)
    $ErrorActionPreference = "Stop"
    
    if($null -eq $fromSender){
        $fromSender = @{}
    }
    if(-not($fromSender.ContainsKey("RootDirectory"))){
        $msg = "Missing mandatory parameter 'RootDirectory'"
        write-error -message $msg
    }
    $script:rootDirectory = $fromSender.RootDirectory
    $rootFile = "{0}\{1}"-f $rootDirectory,"PSConfig\Settings\Settings.json"

    if(-not($fromSender.ContainsKey("Reinitialize"))){
        $fromSender.Add("Reinitialize",$false)
    }
    $reinitialize = $fromSender.Reinitialize
    $settingsFileExists = (test-path -path $rootFile)
    $ModuleSettings = @{
        Settings = [ordered]@{
            Type = ".json"
            File = $rootFile
            General = @{
                Verbose = $true
                Logging = $true
            }
            Logging = @{
                LastEntryID = 0
                LastEntryDateTime = ''
                Logging = $true
                DateTimeFormat = "yyyy-MM-dd HH:mm:ss"
                RetentionPeriod = 1
                Interval = "hour"
            }
            OpenSomeSessions = @{
                CloseWhenDone = $false
            }
        }
        Functions = @{
            Type = ".json"
            File = "{0}\{1}" -f $rootDirectory,"PSConfig\Functions\Functions.json"
        }
        Logging = @{
            Type = ".csv"
            File = "{0}\{1}" -f $rootDirectory,"PSConfig\Log\Log.csv"
            Headings = '"{0}"' -f (@("RecID","DateTime","Function","Status","Message") -join '","')
        }
        Sources = [ordered]@{
            Servers = @{
                Type = ".csv"
                File = "{0}\{1}" -f $rootDirectory,"PSConfig\Data\Servers.csv"
                Headings = @("RecID","Enclave","DomainName","HostName")
            }
            SQL = @{
                Type = ".csv"
                File = "{0}\{1}" -f $rootDirectory,"PSConfig\Data\Instances.csv"
                Headings = @("RecID","Enclave","DomainName","InstanceName")
            }
            Disks = @{
                Type = ".json"
                File = "{0}\{1}" -f $rootDirectory,"PSConfig\Data\Disks.json"
            }
        }
    }

    if(($settingsFileExists -eq $false) -or ($reinitialize)){
        if($settingsFileExists){
            remove-item -path $rootFile -force | out-null
        }
        $json = $ModuleSettings | convertto-json -Depth 6
        new-item -path $rootFile -value $json -force | Out-Null

        if( test-path $ModuleSettings.Logging.File){
            DeleteLog
        }
    }

    foreach($source in $ModuleSettings.Sources.keys){
        $name = $source
        $file = $ModuleSettings.Sources.$name.File
        $type = $ModuleSettings.Sources.$name.Type
        if($type -eq ".csv"){
            $headings = $ModuleSettings.Sources.$name.Headings
            $content = '"{0}"' -f ($headings -join '","')
            if(-not(test-path -path $file)){
                new-item -path $file -ItemType File -value $content -force | Out-Null
            }
        }
    }

    $function = $ModuleSettings.Functions.File
    if(-not(test-path -path $function)){
        $json = "{}"
        new-item -ItemType file -path $function -Force -Value $json | Out-Null
    }
}
function GetSettings{
    $rootFile = "{0}\{1}" -f $script:rootDirectory,"PSConfig\Settings\Settings.json"
    $object = Get-Content -path $rootFile | convertfrom-json
    ConvertToHashTable $object
}
function UpdateSettings{
    param([hashtable]$fromSender)
    $ErrorActionPreference = "Stop"
    $settings = GetSettings
    $file = $settings.Settings.File
    if($null -eq $fromSender){
        $msg = "Cannot update settings unless new settings are provided."
        Write-Error -Message $msg
    }
    $json  = $fromSender.Settings | ConvertTo-Json -Depth 10
    Set-Content -path $file -Value $json
}
function GetSources{
    param([hashtable]$fromSender)

    if($null -eq $fromSender){
        $fromSender = @{}
    }
    $sources = (GetSettings).Sources
    $keycount = $fromSender.Keys.Count
    if($keycount -eq 0){
        return  $sources
    }
    
    $source = $fromSender.Source
    $sourceList = $sources.keys
    if(-not($sourceList -contains $source)){
        $msg  = "The source provided '$source' is not an valid source."
        write-error -message $msg
    }
    $sources.$source
}
function AddSource{
    param([hashtable]$fromSender)
    $ErrorActionPreference = "Stop"
    if($null -eq $fromSender){
        $fromSender = @{}
    }

    $mandatoryParams = @(
        "Name"
        "File"
        "Type"
    )
    foreach($param in $mandatoryParams){
        if(-not($fromSender.ContainsKey($param))){
            $msg = "Missing mandatory parameter '$param'."
            Write-Error -Message $msg
        }
    }

    $settings = GetSettings
    $sourceList = @($settings.Sources.keys)

    if(-not($fromSender.ContainsKey("Reinitialize"))){
        $fromSender.Add("Reinitialize",$false)
    }
    $reinitialize = $fromSender.Reinitialize

    $name = $fromSender.Name
    if($sourceList -contains $name){
        if($reinitialize -eq $false){
            $msg = "Source '$name' already exists."
            Write-Error -Message $msg
        }
        $settings.Sources.Remove($name)
    }

    $type = $fromSender.Type
    if(($type -eq ".csv") -and (-not($fromSender.ContainsKey("Headings")))){
        $msg = "When the source being added is '.csv', the 'Headings' parameters is required."
        Write-Error -Message $msg
    }
    if($type -eq '.csv'){
        if(-not($fromSender.Headings -contains "RecID")){
            $fromSender.Headings = @("RecID",$fromSender.Headings)
        }
    }
    if(($type -eq ".json") -and ($fromSender.ContainsKey("Headings"))){
        $msg = "When the source being added is '.json', the 'Headings' parameters is not required."
        Write-Error -Message $msg
    }

    $file = $fromSender.File

    $sourceFileExists = test-path -path $file
    if($reinitialize){
        if($sourceFileExists){
            remove-item -path $file -force | out-null
            $sourceFileExists = $false
        }
    }

    if($sourceFileExists){
        $msg = "File '$file' already exists."
        Write-Error -Message $msg
    }

    if($type -eq ".csv"){
        $value = $fromSender.Headings
        $value = '"{0}"' -f ($value -join '","')
        New-Item -ItemType File -Path $file -Value $value -Force | Out-Null
    }
    if($type -eq ".json"){
        $value = $fromSender.Headings
        $value = '"{0}"' -f ($value -join '","')
        New-Item -ItemType File -Path $file -Value $value -Force | Out-Null
    }

    $fromSender.Remove("Reinitialize")
    $settings.Sources.Add($name,$fromSender)
    UpdateSettings @{Settings = $settings}
}
function AddServer{
    param([hashtable]$fromSender)

    $ErrorActionPreference = "Stop"
    $source = GetSources @{Source = "Servers"}
    $userInput = $fromSender.Servers

    foreach($entry in $userInput){

        $item = GetServers
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
        
        $info = [pscustomobject]@{
            Min = $min
            Max = $max
            Count = $item.count
            IDs = $Ids
        }
        $item = GetServers
        $exists = $false
        if($null -ne $item){
            $enclave = $entry.Enclave
            $domainName = $entry.DomainName
            $hostName = $entry.HostName
            if($null -ne ($item | Where-Object {$_.Enclave -eq $enclave -and $_.DomainName -eq $domainName -and $_.HostName -eq $hostName})){
                $exists = $true
            }
        }

        $servers = [PSCustomObject]@(GetServers)
        if(-not($exists)){
            $servers += [pscustomobject]@{
                RecID =  ($info.Max + 1)
                Enclave = $entry.Enclave
                DomainName = $entry.DomainName
                HostName = $entry.HostName
            }
        $newServers = $servers | ConvertTo-Csv -NoTypeInformation
        Set-Content -Path $source.file -Value $newServers
        }
    }
}
function GetServers{
    $settings = GetSettings
    $file =  $settings.Sources.Servers.File
    get-content -path $file | convertfrom-csv
}
function GetThisServer{
    param([hashtable]$fromSender)
    $ErrorActionPreference = "Stop"

    if($null -eq $fromSender){
        $fromSender = @{}
    }

    $fromSenderKeys = @($fromSender.Keys)

    $servers = GetServers
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
function GetFunction{
    param([hashtable]$fromSender)
    $ErrorActionPreference = "Stop"

    $settings = GetSettings
    $file  = $settings.Functions.File
  
    if($null -eq $fromSender){
        $fromSender = @{}
    }

    $content = "{0}" -f (Get-Content -path $file -raw)
    $object = $content | ConvertFrom-Json

    if($object.count -ne 0){
        $item = ConvertToHashTable $object
        
        if(-not($fromSender.ContainsKey("Name"))){
            $msg = "Mandatory Parameter 'Name' is missing."
            Write-Error $msg
        }
 
        if($fromSender.ContainsKey('Creating')){
            return $item
        }else{
            $Function = $item.($fromSender.Name)
            if(-not($null -eq $Function)){
                $scriptPath = $item.($fromSender.Name).ScriptFile
                if(test-path -path $scriptPath){
                    $sb = "{0}" -f (Get-Content -path $scriptPath)
                }else{
                    $sb = ''
                }
                $item.($fromSender.Name).Add("ScriptBlock",$sb)
                return $item.($fromSender.Name)
            }else{
               return  @{}
            }
        }
    }else{
        @{}
    }
}
function RemoveFunction{
    param([hashtable]$fromSender)
    $ErrorActionPreference = "Stop"

    $settings = GetSettings
    $file  = $settings.Functions.File
    
    $json = Get-Content -path $file | ConvertFrom-Json
    $functions = ConvertToHashTable @json

    if(@($functions.Keys) -contains $fromSender.Name){
        $scriptFile = $functions.($fromSender.Name).ScriptFile
        $functions.Remove(($fromSender.Name))
        Remove-Item -path $scriptFile -Force | Out-Null
       

        $json = $functions | ConvertTo-Json -Depth 10
        Set-Content -Path $file -Value $json
    }
}
function AddFunction {
    param([hashtable]$fromSender)
    $ErrorActionPreference = "Stop"

    $settings = GetSettings
    $file  = $settings.Functions.File
    $folder = (get-item $file).Directory.FullName

    $functions = GetFunction @{Name = ($fromSender.Values.Name);Creating = $true}
    if(-not($fromSender.Values.ContainsKey("Name"))){
        $msg = "Mandatory parameter 'Name' is missing"
        Write-Error $msg
    }
    $name = $fromSender.Values.Name

    if($name -match "\s"){
        $msg = "Name cannot have spaces."
        Write-Error $msg
    }
    $tags = $fromSender.Values.Tags
    if(-not($fromSender.Values.ContainsKey("Tags"))){
        $fromSender.Values.Add("Tags",@(''))
    }
    $tags = $fromSender.Values.Tags

    if(-not($fromSender.Values.ContainsKey("Description"))){
        $fromSender.Values.Add("Description",'')
    }
    $Description = $fromSender.Values.Description

    if(-not($fromSender.Values.ContainsKey("Parameters"))){
        $fromSender.Values.Add("Parameters",@(''))
    }
    $Parameters = $fromSender.Values.Parameters

    if(-not($fromSender.Values.ContainsKey("ScriptBlock"))){
        $fromSender.Values.Add("ScriptBlock",{''})
    }
    $ScriptBlock = $fromSender.Values.ScriptBlock
    $sb = "{0}" -f $ScriptBlock

    if(@($functions.Keys) -contains ($fromSender.Values.Name)){
        $msg = "'$($fromSender.Values.Name)' already exists."
        Write-Error -Message $msg
    }
    $functionFile = "{0}\{1}.ps1" -f $folder,$name
    new-item -path $functionFile -Value $sb -force | Out-Null
    $functions.Add($fromSender.Values.Name,[Ordered]@{
        Description = $Description
        Tags = $tags
        Name = $Name
        Parameters = $Parameters
        ScriptFile =  $functionFile
    })


    $json = $functions | ConvertTo-Json
    Set-Content -path $file -Value $json
}
function RunTask{
    param([hashtable]$fromSender)
    $ErrorActionPreference = "Stop"

    if($null -eq $fromSender){
        $fromSender = $null
    }

    #  SequenceTitle:
    #  unique id is assigned when one isn't provided
    if(-not($fromSender.ContainsKey('SequenceTitle'))){
        $fromSender.Add('SequenceTitle',(new-guid).guid)
    }
    $sequenceTitle = $fromSender.SequenceTitle

    # On:
    # there needs to be some session open atleast
    $sessions = Get-PSSession
    if($null -eq $sessions){
        $msg = "There is no session(s) open. Run 'OpenSomeSessions' first."
        write-Error -Message $msg
    }

    # check if there is a session open for the server(s) provided
    if(-not($fromSender.ContainsKey('On'))){
        $msg = "Mandatory parameter 'On' is missing."
        write-Error -Message $msg
    }
    $on = $fromSender.On

    foreach($server in $on){
        if($null -eq ($sessions | Where-Object {$_.ComputerName -eq $server -and $_.State -eq 'Opened'})){
            $msg = " The server name provided '{0}', does not currently have an open sessions." -f $server
            Write-Error -Message $msg
        }
    }

    # check if functions are going to be used
    if(-not($fromSender.ContainsKey('UseFunction'))){
        $fromSender.Add('UseFunction',@())
    }
    $functions = $fromSender.UseFunction

    # not using any functions
    $functionsTable = $null
    if($functions.count -ne 0){
        $functionsTable = [ordered]@{}
        foreach($function in $functions){
            $selectedFunction = (GetFunction @{Name = $function})
            if($selectedFunction.keys.count -eq 0){
                $msg = "Function '{0}' was not found. All functions provided need to exist." -f $function
                write-error -Message $msg
            }
            $functionsTable.Add($function,$selectedFunction)
        }
    }


    # check task(s)
    if(-not($fromSender.ContainsKey('Tasks'))){
        $fromSender.Add('Tasks',@{})
    }
    $tasks = $fromSender.Tasks

    

}