<#
$json.'lab.com'.dev.vm.desktop
$json.'lab.com'.dev.vm.servers
$json.'lab.com'.dev.vm.servers.domancontroller
$json.'lab.com'.dev.vm.servers.sqlserver
$json.'lab.com'.dev.vm.servers.sqlserver.sql01
#>

class Management{
    [string]$source
    [psobject]$info

    # constructor
    Management([hashtable]$fromSender){
        $this.source = $fromSender.Source
        $this.info = $this.GetData()
    }

    # private method
    [psobject]GetData(){
        $path = $this.source
        return (Get-Content -Path $path) | ConvertFrom-Json
    }

    # getters
    [psobject]GetDomain([hashtable]$fromSender){
        if($null -eq $fromSender){
            $fromSender = @{}
        }
        if(-not($fromSender.ContainsKey('name'))){
            $fromSender.Add('Name',"*")
        }
        $name = $fromSender.Name
        $comp = @{Name = "Name";Expression={$_.Name}}
        $object = $this.info.psobject.properties
        $domain = $object| Where-Object {$_.Name -like "$name"} 
        if($null -eq $domain){
            return Write-Error ("no domains found that matches '{0}'" -f $domain)
        }
        return $domain | Select-Object $comp
    }
    [psobject]GetEnviornment([hashtable]$fromSender){
        $comp = @{Name = "Name";Expression={$_.Name}}
        $enviorment = @()
        foreach($domain in ($this.GetDomain())){
            $enviorment += ($this.info.$domain.psobject.properties | Select-Object $comp)
        }
        return $enviorment
    }
    [psobject]GetResourceType([hashtable]$fromSender){

        $comp = @{Name = "Name";Expression={$_.Name}}
        $resourcetype = @()
        foreach($domain in ($this.GetDomain())){
            foreach($enviorment in ($this.GetEnviornment())){
                $resourcetype += ($this.info.$domain.$enviorment.psobject.properties | Select-Object $comp)
            }

        }
        return $resourcetype
    }
}

$Management = [Management]::new(@{
    Source = ".\management.setup\lab.configuration.json"
})


$Management.GetDomain(@{Name = "ddfs"})
$Management.GetEnviornment()
function Get-UDFDomain{
    $object = Get-Content .\management.setup\lab.configuration.json | ConvertFrom-Json 
    $comp = @{Name = "Name";Expression={$_.Name}}
    $object.psobject.properties | Select-Object $comp
}
Get-UDFDomain

function Get-UDFEnviornment{
    param([hashtable]$fromSender)

    $domain = $fromSender.Domain
    $object = $script:json.$domain
    $comp = @{Name = "Name";Expression={$_.Name}}
    $object.psobject.properties | Select-Object $comp
}
Get-UDFEnviornment @{Domain = 'lab.com'}

function Get-UDFVMType{
    param([hashtable]$fromSender)

    $enviornment = Get-UDFEnviornment @{Domain = $fromSender.Domain}

    $enviornment = $fromSender.Enviornment
    $object = $script:json..$enviornment
    $comp = @{Name = "VMType";Expression={$_.Name}}
    $object.psobject.properties | Select-Object $comp
}
Get-UDFVMType @{
    Domain = 'lab.com'
    Enviornment = 'dev'
}
$json.'lab.com'.dev.vm.desktop.'win16-vdi01'.osconfiguration.network.netadapter.ethernet0