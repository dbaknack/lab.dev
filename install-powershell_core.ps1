$sharePath = "Z:\lab.vm-fileshare\software"
$software = "PowerShell-7.5.1-win-x64.msi"

$path = join-path $sharePath $software

$cmd = @(
    "msiexec.exe /package {0}" -f $path
    "/quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1"
    "ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1"
    "ENABLE_PSREMOTING=1"
    "REGISTER_MANIFEST=1"
    "USE_MU=1"
    "ENABLE_MU=1"
    "ADD_PATH=1"
) -join " "
invoke-expression $cmd
