$erroractionpreference = "stop"
$sessions = @();$sessions += new-pssession -computername win16-vdi01 

# mount the iso
$cmdParams = @{
    Session = $sessions
    ScriptBLock = {
        param([hashtable]$fromSender)
        $erroractionpreference = "stop"
    
        $path = $fromSender.iso
    
        try{
            mount-diskimage -imagepath $path -erroraction stop
        }catch{
            $msg = "Error mounting disk image: $($_.Exception.Message)"
            write-error -message $msg
        }
    }
    ArgumentList = @{
        ISO = "C:\dba\en_sql_server_2016_enterprise_x64_dvd_8701793.iso"
    }
    AsJob = $false
    ErrorAction = "Stop"
}; invoke-command @cmdParams

# validate that is has been mounted
$cmdParams = @{
    Session = $sessions
    ScriptBLock = {
        param([hashtable]$fromSender)
        $erroractionpreference = "stop"
    
        $path = $fromSender.iso
        
        Get-DiskImage -ImagePath $path | get-volume
    }
    ArgumentList = @{
        ISO = "C:\dba\en_sql_server_2016_enterprise_x64_dvd_8701793.iso"
    }
    AsJob = $false
    ErrorAction = "Stop"
}
$installDrive = (invoke-command @cmdParams).DriveLetter

# install command
$cmdParams = @{
    Session = $sessions
    ScriptBLock = {
        param([hashtable]$fromSender)
        $erroractionpreference = "stop"
        $content = $fromSender.ini
        $destination = $fromSender.Destination
        $setupPath = $fromSender.SetupPath
        $sqlServicePassword = $fromSender.SQLService.Password
        $sqlAgentPassword = $fromSender.SQLAgent.Password
        $saPassword = $fromSender.SA.Password
        set-content -path $destination -value $content

        $setupCmd = '{0} /SQLSVCPASSWORD="{1}" /SAPWD="{2}" /ConfigurationFile={3} /AGTSVCPASSWORD="{4}" /IACCEPTSQLSERVERLICENSETERMS' -f @(
            $setupPath
            $sqlServicePassword
            $saPassword
            $destination
            $sqlAgentPassword
        )
        &$setupCmd
    }
    ArgumentList = @{
        INI         = (get-content -path "C:\LocalRepo\ps-sandbox\dev\dev-mixed_mode-config01.ini")
        Destination = "C:\DBA\config01.ini"
        SetupPath   = "$($installDrive):\setup.exe"
        SA          = @{Password = "P@55word"}
        SQLService  = @{Password = "P@55word"}
        SQLAgent    = @{Password = "P@55word"}
    }
    AsJob = $false
    ErrorAction = "Stop"
}; invoke-command @cmdParams

# check the feature dependencies
$cmdParams = @{
    Session = $sessions
    ScriptBLock = {
        param([hashtable]$fromSender)
        $erroractionpreference = "stop"
        $feature = $fromSender.feature

        $installed = (get-windowsfeature -name $feature).Installed
        if(-not($status)){
            Install-WindowsFeature -Name $feature -IncludeManagementTools
        }else{
            $installed
        }
    }
    ArgumentList = @{
        feature = "Failover-Clustering"
    }
    AsJob = $false
    ErrorAction = "Stop"
}; invoke-command @cmdParams

# install ssms
$cmdParams = @{
    Session = $sessions
    ScriptBLock = {
        param([hashtable]$fromSender)
        $erroractionpreference = "stop"

        invoke-expression "C:\DBA\SSMS-Setup-ENU.exe /Install /quiet /norestart /log C:\Temp\log.txt"
    }
    ArgumentList = @{}
    AsJob = $false
    ErrorAction = "Stop"
}; invoke-command @cmdParams

# enable dark mode
$cmdParams = @{
    Session = $sessions
    ScriptBLock = {
        param([hashtable]$fromSender)
        $erroractionpreference = "stop"

        $content = get-content -path "C:\Program Files (x86)\Microsoft SQL Server Management Studio 20\Common7\IDE\ssms.pkgundef"
        $new = @()
        for ($i = 0; $i -lt ($content.count -1); $i++) {
            $new += $content[$i]
        }
        set-content -path "C:\Program Files (x86)\Microsoft SQL Server Management Studio 20\Common7\IDE\ssms.pkgundef" -value $new
    }
    ArgumentList = @{}
    AsJob = $false
    ErrorAction = "Stop"
}; invoke-command @cmdParams
