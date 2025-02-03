class Management{
    [string]$source
    [psobject]$info

    # constructor
    Management([hashtable]$fromSender){
        $this.source = $fromSender.Source
        $this.info = $this.GetData()
    }

    # private method(s)
    [psobject]GetData(){
        $path = $this.source
        return (Get-Content -Path $path) | ConvertFrom-Json
    }
    [void]ReloadData(){
        $path = $this.source
        $this.info = (Get-Content -Path $path) | ConvertFrom-Json
    }
    [psobject]GetDomain(){
        $object = $this.info
        return ($object.psobject.properties) | Select-Object Name
    }
    [psobject]GetEnviornment(){
        $object = $this.info
        $domains = $this.GetDomain()
        $enviornments = @()
            
        foreach($domain in $domains){
            ((($object)."$($domain.name)").psobject.properties).Name | foreach-object{
                $enviornments += [pscustomobject]@{
                    Name = $_
                }
            }
        }
        return $enviornments
    }
    [psobject]GetDeviceType(){
        $object = $this.info
        $domains = $this.GetDomain()
        $enviornments = $this.GetEnviornment()
        $deviceType = @()
        foreach($domain in $domains){
            foreach($enviornment in $enviornments){
                ((($object)."$($domain.name)"."$($enviornment.name)").psobject.properties).Name | foreach-object{
                    $deviceType += [pscustomobject]@{
                        Name = $_
                    }
                }
            }
        }
        return $deviceType
    }
    [psobject]GetDeviceGroup(){
        $object = $this.info
        $domains = $this.GetDomain()
        $enviornments = $this.GetEnviornment()
        $deviceTypes = $this.GetDeviceType()
        $deviceGroups = @()
        foreach($domain in $domains){
            foreach($enviornment in $enviornments){
                foreach($type in $deviceTypes){
                    ((($object)."$($domain.name)"."$($enviornment.name)"."$($type.name)").psobject.properties).Name | foreach-object{
                        $deviceGroups += [pscustomobject]@{
                            Name = $_
                        }
                    }
                }
            }
        }
        return $deviceGroups
    }
    [psobject]GetDevice(){
        $object = $this.info
        $domains = $this.GetDomain()
        $enviornments = $this.GetEnviornment()
        $deviceTypes = $this.GetDeviceType()
        $deviceGroups = $this.GetDeviceGroup()
        $devices = @()
        foreach($domain in $domains){
            foreach($enviornment in $enviornments){
                foreach($type in $deviceTypes){
                    foreach($group in $deviceGroups){
                        ((($object)."$($domain.name)"."$($enviornment.name)"."$($type.name)"."$($group.Name)").psobject.properties).Name | foreach-object{
                            $devices += [pscustomobject]@{
                                Name = $_
                            }
                        }
                    }
                }
            }
        }
        return $devices
    }
    [psobject]GetConfigurationType(){
        $object = $this.info
        $domains = $this.GetDomain()
        $enviornments = $this.GetEnviornment()
        $deviceTypes = $this.GetDeviceType()
        $deviceGroups = $this.GetDeviceGroup()
        $devices = $this.GetDevice()
        $configurationTypes = @()
        foreach($domain in $domains){
            foreach($enviornment in $enviornments){
                foreach($type in $deviceTypes){
                    foreach($group in $deviceGroups){
                        foreach($device in $devices){
                            ((($object)."$($domain.name)"."$($enviornment.name)"."$($type.name)"."$($group.Name)"."$($device.Name)".configuration).psobject.properties).Name | foreach-object{
                                if($null -ne $_){
                                    $configurationTypes += [pscustomobject]@{
                                        Name = $_
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        return $configurationTypes | Sort-Object -Property Name -Unique
    }
    [psobject]GetConfiguration([hashtable]$fromSender){

        # by default data is not reloaded
        if(-not($fromSender.ContainsKey('Reload'))){
            $fromSender.Add("Reload",$false)
        }
        $reloadData = $fromSender.Reload

        if($reloadData){
            Write-Host "Data reloaded" -ForegroundColor Cyan
            $this.ReloadData()
        }

        $msgError = [string]

        if($this.GetDomain().name -notcontains $fromSender.DomainName){
            $msgError = "There is no domain named '{0}' in '{1}'." -f $fromSender.DomainName, $this.source
            Write-Error -Message $msgError; return $Error[0]
        }

        if($this.GetEnviornment().name -notcontains $fromSender.Enviornment){
            $msgError = "There is no enviornment named '{0}' in '{1}'." -f $fromSender.Enviornment, $this.source
            Write-Error -Message $msgError; return $Error[0]
        }

        if($this.GetDeviceType().name -notcontains $fromSender.DeviceType){
            $msgError = "There is no enviornment named '{0}' in '{1}'." -f $fromSender.DeviceType, $this.source
            Write-Error -Message $msgError; return $Error[0]
        }

        if($this.GetDeviceGroup().name -notcontains $fromSender.DeviceGroup){
            $msgError = "There is no device group '{0}' in '{1}'." -f $fromSender.DeviceGroup, $this.source
            Write-Error -Message $msgError; return $Error[0]
        }

        if($this.GetDevice().name -notcontains $fromSender.DeviceName){
            $msgError = "There is no device group '{0}' in '{1}'." -f $fromSender.DeviceName, $this.source
            Write-Error -Message $msgError; return $Error[0]
        }

        if($this.GetConfigurationType().name -notcontains $fromSender.Level){
            $msgError = "There is no configuration level '{0}' in '{1}'." -f $fromSender.Level, $this.source
            Write-Error -Message $msgError; return $Error[0]
        }


        $object = $this.info
        return $object."$($fromSender.DomainName)".`
        "$($fromSender.Enviornment)".`
        "$($fromSender.DeviceType)".`
        "$($fromSender.DeviceGroup)".`
        "$($fromSender.DeviceName)".configuration.`
        "$($fromSender.Level)"
    }
}

# initalize class
$Management = [Management]::new(@{Source = ".\management.setup\lab.configuration.json"})

# test methods
$Management.GetData()
$Management.ReloadData()
$Management.GetDomain()
$Management.GetEnviornment()
$Management.GetDeviceType()
$Management.GetDeviceGroup()
$Management.GetDevice()
$Management.GetConfigurationType()

$Management.GetConfiguration(@{
    DomainName  = "lab.com"
    Enviornment = "dev"
    DeviceType  = "VM"
    DeviceGroup = "VDI"
    DeviceName  = "win16-vdi01"
    Level       = "vm"
    Reload = $true
}).resources