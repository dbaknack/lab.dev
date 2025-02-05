
function Get-UDFProjectFolder{
    $ParentFolder = Split-Path -Path $PSScriptRoot -Parent
    [pscustomobject]@{Name = $ParentFolder}
}
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
function Get-UDFConfig{
    param([hashtable]$fromSender)

    $ErrorActionPreference = "Stop"
    if($null -eq $fromSender){
        $fromSender = @{}
    }

    if(-not($fromSender.ContainsKey('Source'))){
        $msgError = "Mandatory parameter 'Source' missing."
        (Write-Error -Message $msgError)
    }
    $source = $fromSender.Source
    if(-not(Test-Path -path $source)){
        $msgError = "Source path '{0}' does not exist." -f $source
        Write-Error -Message $msgError | Out-Null; return $Error[0]
    }
    $item = Get-Item -Path $Source
    $content = Get-Content -Path $source 
    switch($item.Extension){
        '.json'{
            ConvertTo-UDFHashtable ($content | ConvertFrom-Json)
        }
        '.csv'{
            $content | ConvertFrom-Csv
        }
        default{
            $msgError = "Configuration file(s) with extension '{0}', are not supported." -f $_
            Write-Error -Message $msgError | Out-Null; return $Error[0]
        }
    }
}
