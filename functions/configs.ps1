function PSConfigProjectPath{
    $ParentFolder = Split-Path -Path $PSScriptRoot -Parent
    [pscustomobject]@{Name = $ParentFolder}
}
# given a source, return the corresponding value
function PSConfigVars{
    param([hashtable]$fromSender)

    # if there is an issue with this function, stop.
    $ErrorActionPreference = "Stop"
    if($null -eq $fromSender){
        $fromSender = @{}
    }

    if(-not($fromSender.ContainsKey('Source'))){
        $msgError = "Mandatory parameter 'Source' missing."
        (Write-Error -Message $msgError)
    }

    $source = $fromSender.Source
    $path = switch($source){
        "disk"{
            "configs\disk.json"
        }
        "server"{
            "configs\server.csv"
        }
        "session"{
            "configs\session.json"
        }
        default{
            $configFiles = @(
                "disk"
                "server"
                "session"
            )
            
            $msgError = "The source provided was not found, source value must be '{0}'." -f ($configFiles -join "', '")
            Write-Error -Message $msgError
        }
    }
    "{0}\{1}" -f (PSConfigProjectPath).Name,$path
}
# for powershell v5.1 - recursive function used to properly import json files
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
# function used to get data from config file(s).
function Get-PSConfig{
    param([hashtable]$fromSender)

    # if there is an issue with this function, stop.
    $ErrorActionPreference = "Stop"
    if($null -eq $fromSender){
        $fromSender = @{}
    }

    if(-not($fromSender.ContainsKey('Source'))){
        $msgError = "Mandatory parameter 'Source' missing."
        (Write-Error -Message $msgError)
    }
    $source = PSConfigVars @{Source = ($fromSender.Source)}
    if(-not(Test-Path -path $source)){
        $msgError = "Source path '{0}' does not exist." -f $source
        Write-Error -Message $msgError
    }
    $item = Get-Item -Path $source
    $content = Get-Content -Path $source 
    switch($item.Extension){
        '.json'{
            return ConvertTo-UDFHashtable ($content | ConvertFrom-Json)
        }
        '.csv'{
            return $content | ConvertFrom-Csv
        }
        default{
            $msgError = "Configuration file(s) with extension '{0}', are not supported." -f $_
            Write-Error -Message $msgError
        }
    }
}
function SetPSConfiguration{
    param([hashtable]$fromSender)
    $ErrorActionPreference = "Stop"

    if(-not($fromSender.ContainsKey("ApplyTo"))){
        $msgError = ("Mandatory parameter '{0}' missing." -f "ApplyTo")
        Write-Error -Message $msgError
    }
    $serverList = $fromSender.ApplyTo
    if($serverList.count -eq 0){
        $msgError = ("The server list cannot be empty.")
        Write-Error -Message $msgError
    }

    if(-not($fromSender.ContainsKey("Configuration"))){
        $msgError = ("Mandatory parameter '{0}' missing." -f "Configuration")
        Write-Error -Message $msgError
    }
    $configuration = @($fromSender.Configuration)
    $configurationItems = @($configuration.keys)
    $configurationItemsCount = $configurationItems.count
    if($configurationItemsCount -eq 0){
        $msgError = "The configuration cannont be empty"
        Write-Error -Message $msgError
    }
    $configurationMaxIndex = $configurationItemsCount - 1

    $session = (Get-PSSession)
    foreach($server in $serverList){
        foreach($configIndex in 0..$configurationMaxIndex){
            $config = $configuration[$configIndex]
            switch($config.Keys){
                "Disk"{
                    if(($config.Disk.Disks.count) -eq 0){
                        $msgError = "Disks cannot be empty."
                        Write-Error -Message $msgError
                    }
                    foreach($disk in $config.Disk.Disks){
                        Get-PSConfigDiskProperties @{Server = $server; Disk = $disk}

                        # sessions are always going to be open in the calling scope     
                        Invoke-PSCMD @{
                            Session = ($session | Where-Object {$_.ComputerName -eq $server})
                            FromSender = @{test = 'this'}
                            ScriptBlock = '
                                param([hashtable]$fromSender)
                                $fromSender
                            '
                        }
                    }
                }
                default {
                }
            }
        }
    }
} 