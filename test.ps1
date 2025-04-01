function MergeContext{
    param(
        [hashtable]$Target,
        [hashtable]$Defaults
    )

    foreach ($key in $Defaults.Keys) {
        if (-not $Target.ContainsKey($key)) {
            $Target[$key] = $Defaults[$key]
        }
        elseif ($Target[$key] -is [hashtable] -and $Defaults[$key] -is [hashtable]) {
            MergeContext -Target $Target[$key] -Defaults $Defaults[$key]
        }
    }
}
function ContextParameters {
    param (
        [hashtable]$Context,
        [string[]]$Mandatory = @(),
        [hashtable]$Optional = @{}
    )

    $missing = @()

    foreach ($paramName in $Mandatory) {
        if (-not $Context.ContainsKey($paramName)) {
            $missing += $paramName
        }
    }

    if ($missing.Count -gt 0) {
        $msg = "Missing mandatory parameters:`n`n - " + ($missing -join "`n - ")
        throw $msg
    }

    foreach ($key in $Optional.Keys) {
        if (-not $Context.ContainsKey($key)) {
            $Context[$key] = $Optional[$key]
        }
    }
}
function Context{
    param([hashtable]$fromSender)

    if(-not $fromSender){$fromSender = @{}}
    $defaults = @{
        Preferences = @{
            ErrorAction = "Stop"
            Messages = @{
                Enabled = $true
                User = @{ Enabled = $true;  Color = "Cyan" }
                Development = @{ Enabled = $false; Color = "Magenta" }
                Test = @{ Enabled = $false; Color = "Yellow" }
                Informational = @{ Enabled = $true;  Color = "Cyan" }
                Success = @{ Enabled = $true;  Color = "Green" }
                Warning = @{ Enabled = $true;  Color = "Yellow" }
            }
        }
        Message = @{
            Type = "Informational"
            UserName = [System.Environment]::UserName
            From = "NameNotProvided"
            DateTime = {(Get-Date).toString('yyyy-MM-dd HH:mm:ss.fff')}
            Text = "no-message"
        }
    }
    MergeContext -Target $fromSender -Defaults $defaults

    return $fromSender
}
function Message{
    param([hashtable]$fromSender)
    if(-not $fromSender){$fromSender = @{}}; Context $fromSender | out-null
    $ErrorActionPreference = $fromSender.Preferences.ErrorAction
    $preferences = $fromSender.Preferences.Messages
    $message = $fromSender.Message

    $text = '"{0}"' -f $message.Text
    if(($preferences.Enabled) -and ($preferences.($message.Type).Enabled)){
        write-host ("[{0}]::[{1}]::[{2}]::{3}" -f @(
            (&$message.DateTime)
            $message.From
            $message.UserName
            $text
        )) -fore $preferences.($message.Type).color
    }
}
function _helperconverttohashtable{
    param($object)

    $hashTable = @{}
    if(($object.gettype()).name -eq 'pscustomobject'){
        foreach($property in $object.psobject.properties){
            $hashTable[$property.name] = _helperconverttohashtable -object $property.value
        }
    }else{
        return $object
    }
   return  $hashtable
}
function _helperpsstig{
    $hash = [ordered]@{
        root = @{
            path = $psscriptroot
        }
        separator = [string]
    }

    # assuming you are using powershell on windows if
    # not on version 7
    $separator = "\"
    if(((get-host).version.major -eq "7")){
        $separator = "/"
    }
    $hash.separator = $separator
    $hash
}
function PSSTIGGetRoutes{
    param([hashtable]$fromSender)

    # by default all functions should stop on error
    $ErrorActionPreference = "Stop"

    # default user preferences for how this function will work
    # override with user supplied value(s) if any
    $userPreferences = @{
        Verbose = $true 
    }

    if($null -eq $fromSender){
        $fromSender = @{}
    }

    if(-not($fromSender.containskey('Verbose'))){
        $fromSender.Add('Verbose',$userPreferences.Verbose)
    }
    $userPreferences.Verbose = $fromSender.Verbose

    $helper = _helperpsstig
    $separator = $helper.separator
    $root = $helper.root.path
    $path = "{0}{1}routes{1}routes.json" -f $root,$separator
    
    try{
        $object = get-content -path $path -erroraction stop | convertfrom-json -erroraction stop
    }catch{
        $msg = "[PSSTIGGetRoutes]::[Error]::Unable to read from routes.json located in '{0}'" -f $path
        write-error $msg
    }

    if($userPreferences.Verbose){
        $msg = "[PSSTIGGetRoutes]::[Informational]::Returning entry from '{0}'" -f $path
        write-host $msg -fore cyan
    }  

    _helperconverttohashtable $object
}
function PSSTIGAddRoute{
    param([hashtable]$fromSender)
    $ErrorActionPreference = 'Stop'

    if($null -eq $fromSender){
        $fromSender = @{}
    }

    # name: manditory since each name has to be unique
    if(-not($fromSender.containskey('name'))){
        $msg = "Missing manditory parameter 'Name'."
        write-error $msg
    }
    $Name = $fromSender.Name

    # path: manditory since each path is critical to get data
    if(-not($fromSender.containskey('path'))){
        $msg = "Missing manditory parameter 'Path'."
        write-errot $msg
    }
    $path = $fromSender.path

    # description: one isn't required, but can be defined at any time
    if(-not($fromSender.containskey('description'))){
        $fromSender.add('Description','')
    }
    $description = $fromSender.description

    $helper = _helperpsstig
    $root = $helper.root.path
    $separator = $helper.separator

    $routesfile = "{0}{1}{2}{1}{3}" -f $root,$separator,'routes','routes.json'
    # we get the routes from the correct file

    $routes = PSSTIGGetRoutes

    # each entry is a hashtable; the name is the key
    # so names are unique
    $newRoute = @{$name = [ordered]@{
        Description = $description
        Path = $path
    }}

    # if file has no info, then just add whatever
    if($routes.keys.count -eq 0){
        $routes += $newRoute
        $json = $routes | convertto-json -depth 10
    }else{
        $routenames = @($routes.keys)
        # check to make sure that the name is unique
        if($routenames -contains $name){
            $msg = "There is already a route with the name '$name'."
            write-error $msg
        }
        $routes += $newRoute
        $json = $routes | convertto-json -depth 10
    }
    
    set-content -path $routesfile -value $json | out-null
}
function PSSTIGInit{
    param([hashtable]$fromSender)
    $ErrorActionPreference = 'Stop'

    if($null -eq $fromSender){
        $fromSender = @{}
    }

    $helper = _helperpsstig
    $separator = $helper.separator

    # give me a location, or ill use one in the project location
    # hint: provide a location, otherwise you'll end up needing
    #       to move items out and back when updating the module
    $userProvidedRoot = [bool]
    if(-not($fromSender.containskey('root'))){
        $fromSender.add('root',$helper.root.path)
        $userProvidedRoot = $false
    }else{
        $userProvidedRoot = $true
    }
    $root = $fromSender.root

    if($userProvidedRoot){
        $rootfolder = "{0}{1}{2}" -f $root,$separator,'psstig'  
    }
   
    if(-not($userProvidedRoot)){
        $rootfolder = "{0}" -f $root
    }
    
    $folders = @(
        'config'
        'routes'
        'local-stig-library'
        'documentation'
        'checklists'
        'vars'
        'scripts'
        'fixes'
        'main'
        'checkdata'
    )

    $files = @(
        'config{0}config.json' -f $separator
        'routes{0}routes.json' -f $separator
        'vars{0}vars.json' -f $separator
        'checkdata{0}checkdata.json' -f $separator
        'checklists{0}checklists.json' -f $separator
        'main{0}main.json' -f $separator
        'fixes{0}fixes.json' -f $separator
        'documentation{0}documentation.json' -f $separator
        'scripts{0}scripts.json' -f $separator
        'local-stig-library'
    )

    # create the folders for this project
    foreach($folder in $folders){
        $path = "{0}{1}{2}" -f $rootfolder,$separator,$folder
        if(-not(test-path -path $path)){
            new-item -path $path -itemType directory -force | out-null
        } 
    }

    # create the files for this project
    $routespath = ("{0}{1}{2}{1}{3}" -f $rootfolder,$separator,'routes','routes.json')
    $routesfileCreated = $false
    foreach($file in $files){
        $path = "{0}{1}{2}" -f $rootfolder,$separator,$file
        if(-not(test-path -path $path)){
            if($path -match $routespath){
                $routesfileCreated = $true
            }
            new-item -path $path -itemType file -force | out-null
            set-content -path $path  -value "{}"
        }
    }

    if($routesfileCreated){
        write-host  ("{0}{1}{2}{1}{3}" -f $rootfolder,$separator,'local-stig-library','local-stig-library.json')
        PSSTIGAddRoute @{
            Name = 'LocalStigLibrary'
            Description = 'this route points to the loca-stig-library file.'
            Path = ("{0}{1}{2}{1}{3}" -f $rootfolder,$separator,'local-stig-library','local-stig-library.json')
        }
        PSSTIGAddRoute @{
            Name = 'Configuration'
            Description = 'this route points to the configuration file.'
            Path = ("{0}{1}{2}{1}{3}" -f $rootfolder,$separator,'config','config.json')
        }
        PSSTIGAddRoute @{
            Name = 'Main'
            Description = 'this route points to the main json.'
            Path = ("{0}{1}{2}{1}{3}" -f $rootfolder,$separator,'main','main.json')
        }
        PSSTIGAddRoute @{
            Name = 'Vars'
            Description = 'this route points to the vars file.'
            Path = ("{0}{1}{2}{1}{3}" -f $rootfolder,$separator,'vars','vars.json')
        }
        PSSTIGAddRoute @{
            Name = 'CheckData'
            Description = 'this route points to the checklist data file.'
            Path = ("{0}{1}{2}{1}{3}" -f $rootfolder,$separator,'checkdata','checkdata.json')
        }
        PSSTIGAddRoute @{
            Name = 'Checklists'
            Description = 'this route points to the checklists file.'
            Path = ("{0}{1}{2}{1}{3}" -f $rootfolder,$separator,'checklists','checklists.json')
        }
        PSSTIGAddRoute @{
            Name = 'Documentation'
            Description = 'this route points to the documentation file.'
            Path = ("{0}{1}{2}{1}{3}" -f $rootfolder,$separator,'documentation','documentation.json')
        }
        PSSTIGAddRoute @{
            Name = 'Fixes'
            Description = 'This route points to the fixes files.'
            Path = ("{0}{1}{2}{1}{3}" -f $rootfolder,$separator,'fixes','fixes.json')
        }
    }

}
function PSSTIGLibrary{
    param([hashtable]$fromSender)
    $ErrorActionPreference = 'Stop'
    if($null -eq $fromSender){
        $fromSender = @{}
    }
    $name = $fromSender.name
    $location = $fromSender.location
    $path = "{0}/{1}" -f $location, $name
    
    $exists = test-path -path $path
    
    if(-not($exists)){
        $msg = "library '$path' does not exist."
        write-error $msg
    }
    return get-childitem -path $path
}
function PSSTIGListManuals{
    param([hashtable]$fromSender)
    $ErrorActionPreference = 'Stop'

    $library = PSSTIGLibrary $fromSender
    return $library.basename

}
function PSSTIGMoveManualFiles{
    param([hashtable]$fromSender)
    $ErrorActionPreference = 'Stop'

    $sourceLibrary = $fromSender.library.name
    $library = PSSTIGLibrary $fromSender.library

    $sourceManuals = $fromSender.Manual.name
    $allFound = $true
    $missing = @()
    $manualFolders = @()
    foreach($name in $sourceManuals){
        if(-not($library.basename -contains $name)){
            $allFound = $false
            $missing += $name
        }
        if($allFound){
            $library | where-object {$_.basename -eq $name} | foreach-object{
                $manualFolders += $_
            }
        }
    }

    if(-not($allFound)){
        $missingString = [string]
        if($missing.count -gt 1){
            $missingString = "'"+($missing -join "'`n'")+"'"
        }else{
            $missingString = "'" +($missing[0])+"'"
        }
        $msg = @(
            "The following manual name(s) provided dont seem to exists in the library '{0}':" -f $sourceLibrary
            "{0}" -f $missingString
        )
        $msg = $msg -join "`n"
        write-error $msg
    }

    $exportTo = $fromSender.Manual.exportto

    if(($exportTo -eq "./*") -or ($exportTo -eq ".\*")){
        $msg = "Export location cannot be a relative path."
        write-error $msg
    }

    if(-not(test-path -path $exportTo)){
        $msg = "The export to folder path provided '$exportTo' does not exist."
        write-error $msg
    }

    foreach($manual in $manualFolders){
        if($manual.extension -eq '.zip'){
            
            # create a temp folder in that location
            $tempPath = "{0}/{1}" -f $exportTo,"temp"
            if(-not(test-path -path $tempPath)){
                new-item -path $tempPath -itemType Directory | out-null
            }

            try{
                expand-archive -Path $manual.fullname -DestinationPath $tempPath -erroraction 'stop' | out-null
            }catch{
                return $error[0]
            }
            
            $exportedItems = get-childitem -path $tempPath
            $localManual = $manual.basename
            $exportManualPath = "{0}/{1}" -f $exportTo, $sourceLibrary

            # create the local manual directory
            if(-not(test-path -path $exportManualPath)){
                new-item -path $exportManualPath -itemType Directory | out-null
            }
            
            $localManualPath = "{0}/{1}" -f $exportManualPath,$localManual
            if(-not(test-path -path $exportManualPath)){
                new-item -path $localManualPath -itemType Directory | out-null
            }
            
            foreach($item in $localManualPath){
                if(test-path -path $item){
                    $items = get-childitem -path $item
                    foreach($i in $items){
                        remove-item -path $i.fullname -force -recurse
                    }
                }
            }

            foreach($item in $exportedItems){
                copy-item -path $item.fullname -Destination $localManualPath -recurse | out-null
            }
            # remove the temp folder
            if(test-path -path $tempPath){
                remove-item -path $tempPath -force -recurse
            }
        }
    }
}
function PSSTIGGetManualFile{
    param([hashtable]$fromSender)
    $ErrorActionPreference = 'Stop'

    $manualPath = "{0}/{1}" -f $fromSender.Library.location,$fromSender.Library.name

    if(-not(test-path -path $manualPath)){
        $msg = "The path '$manualPath' does not exist."
        write-error $msg
    }

    $manualStigFolder = "{0}/{1}" -f $manualPath,$fromSender.Manual.folder
    if(-not(test-path -path $manualStigFolder)){
        $msg = "The path '$manualStigFolder' does not exist."
        write-error $msg
    }

    $items = get-childitem -path $manualStigFolder -recurse
   
    # look for the item
    foreach($item in $items){
        if($item.basename -eq $fromSender.manual.file){
            $item
        }
    }
}
function PSSTIGGetFileData{
    param([hashtable]$fromSender)
    $ErrorActionPreference = 'Stop'
    $file = PSSTIGGetManualFile $fromSender
    if((Split-Path -Path $file.fullname -Parent) -like '*/*'){
        $parent = ((Split-Path -Path $file.fullname -Parent) -split '/')[-1]
    }

    
    if((Split-Path -Path $file.fullname -Parent) -like '*\*'){
        $parent =((Split-Path -Path $file.fullname -Parent) -split '\')[-1]
    }
    $hash = [ordered]@{
        Parent = $parent
        xmlData = $null
    }
    [xml]$xmlData = get-content -path $file.fullname

    $hash.xmlData = $xmlData
    return $hash
}
# use the router to get to a target
function PSSTIGRoute{
    param([hashtable]$fromSender)
    $ErrorActionPreference = 'Stop'

    if($null -eq $fromSender){
        $fromSender = @{}
    }
    $routes = PSSTIGGetRoutes
    $to = $fromSender.To
    $path = $routes[$to].Path
    
    $object = get-content -path $path | convertfrom-json
    _helperconverttohashtable $object
}
# use to select all items from a target
function PSSTIGSelect{
    param([hashtable]$fromSender)
    # by default all functions should stop on error
    $ErrorActionPreference = "Stop"

    # default user preferences for how this function will work
    # override with user supplied value(s) if any
    $userPreferences = @{
        Verbose = $true 
    }
    
    if($null -eq $fromSender){$fromSender = @{}}
    
    if(-not($fromSender.containskey('Verbose'))){
        $fromSender.Add('Verbose',($userPreferences.Verbose))
    }
    $userPreferences.Verbose = $fromSender.Verbose

    $routes = PSSTIGGetRoutes
    $from = $fromSender.from
    $path = $routes[$from].Path

    try{
        $content = get-content -path $path -erroraction stop
        $object = $content | convertfrom-json -erroraction stop
    }catch{
        return $error[0]
    }
    
    $hashtable = _helperconverttohashtable $object
    return $hashTable
}
# use the router to insert to a target
function PSSTIGInsert{
    param([hashtable]$fromSender)

    # by default all functions should stop on error
    $ErrorActionPreference = "Stop"

    # default user preferences for how this function will work
    # override with user supplied value(s) if any
    $userPreferences = @{
        Verbose = $true 
    }
    if(-not($fromSender.containskey('Verbose'))){
        $fromSender.Add('Verbose',$userPreferences.Verbose)
    }
    $userPreferences.Verbose = $fromSender.Verbose

    if($null -eq $fromSender){
        $fromSender = @{}
    }

    $routes = PSSTIGGetRoutes
    $to = $fromSender.To
    $path = $routes[$to].Path

    $entry = $fromSender.Entry

    try{
        $json = $entry | convertto-json -depth 20  -erroraction stop
        set-content -path $path -value $json -erroraction stop
    }catch{
        $msg = "[PSSTIGInsert]::[Error]::Unable to update '{0}' with new entry"
        write-error $msg
    }

    if($userPreferences.Verbose){
        $msg = "[[PSSTIGInsert]::Informational]::Updated '{0}' registry"  -f $path
        write-host $msg -fore cyan
    }

}
function PSSTIGInsertMain{
    param([hashtable]$fromSender)

    # by default all functions should stop on error
    $ErrorActionPreference = "Stop"

    # user helper

    # default user preferences for how this function will work
    # override with user supplied value(s) if any
    $userPreferences = @{
        Verbose = $true 
    }

    if(-not($fromSender.containskey('Verbose'))){
        $fromSender.Add('Verbose',($userPreferences.Verbose))
    }
    $userPreferences.Verbose = $fromSender.Verbose

    $library = $fromSender.Library
    $manual = $fromSender.Manual
    $file = $fromSender.File

    $hashtable = PSSTIGSelect @{From = "main"}
    $manualFilePath = PSSTIGGetManualFilePath @{
        library = $library
        Manual = $manual
        File = $file
    }
    $entry = @{
        $library = @{
            $manual = @{
                $file = @{
                    DateCreated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                    Path = $manualFilePath
                    Links = @{
                        Check = @{
                            Scripts = @{}
                        }
                        Fix = @{
                            Scripts = @{}
                        }
                        Documentation = @{}
                        Vars = @{}
                        ChecKlists = @{}
                    }
                }
            }
        }
    }

    # when there is nothing in the main.json, just insert the new entry
    if($hashTable.keys.count -eq 0){
        PSSTIGInsert @{To = "Main"; Entry = $entry}
        return
    }

    $libraryExists = [bool]
    if(-not($null -eq $hashtable.$library)){
        $libraryExists = $true
    }else{
        $libraryExists = $false
    }

    $manualExists = [bool]
    if($libraryExists){
        if(-not($null -eq $hashtable.$library.$manual)){
            $manualExists = $true
        }else{
            $manualExists = $false
        }
    }else{
        $manualExists = $false
    }

    $fileExists = [bool]
    if($manualExists){
        if(-not($null -eq $hashtable.$library.$manual.$file)){
            $fileExists = $true
        }else{
            $fileExists = $false
        }
    }else{
        $fileExists = $false
    }


    if(-not($libraryExists)){
        $hashTable += $entry
    }

    if(($libraryExists) -and ($manualExists -eq $false)){
        $hashtable.$library += $entry.$library
    }

    if(($libraryExists) -and ($manualExists) -and ($fileExists -eq $false)){
        $hashtable.$library.$manual += $entry.$library.$manual
    }

    PSSTIGInsert @{To = "Main"; Entry = $hashTable}
}
function PSSTIGGetManualFilePath{
    param([hashtable]$fromSender)
    $ErrorActionPreference = "Stop"

    $helper = _helperpsstig
    $separator = $helper.separator
    $library = $fromSender.Library
    $manual = $fromSender.Manual
    $file = $fromSender.File

    $path = (PSSTIGGetRoutes).LocalStigLibrary.Path

    $filePath = "{0}{1}{2}{1}{3}{1}*{1}{4}.xml" -f $path,$separator,$library,$manual,$file
    return $filePath
}
function PSSTIGGetManual{
    param([hashtable]$fromSender)
    $ErrorActionPreference = "Stop"

    if($null -eq $fromSender){$fromSender = @{}}
    
    if(-not($fromSender.containskey('Verbose'))){
        $fromSender.Add('Verbose',($userPreferences.Verbose))
    }
    $userPreferences.Verbose = $fromSender.Verbose

    if($userPreferences.Verbose){
        $msg = "[PSSTIGGetManual]::[Informational]::Getting manual data..."
        write-host $msg -fore cyan
    }
    $main = PSSTIGSelect @{From = "Main"}

    $library = $fromSender.Library

    if(-not($main.containskey($library))){
        $msg = "Library '$library' does not exists in main."
        write-error $msg
    }

    $manual = $fromSender.manual
    if(-not($main.$library.containskey($manual))){
        $msg = "There is no manual named '$manual' in library '$library'"
        write-error $msg
    }

    $file = $fromSender.file
    if(-not($main.$library.$manual.containskey($file))){
        $msg = "There is no file named '$file' in manual named '$manual' in library '$library'"
        write-error $msg
    }

    $xmlPath = $main.$library.$manual.$file.Path

    $helper = _helperpsstig
    if(@($xmlPath -split $helper.separator) -contains '*'){
        $path = (resolve-path $xmlPath).path
    }else{
        $path = $xmlPath
    }

   if(-not(test-path -path $path)){
    $msg = "The path to the xml file '$file' is invalid"
   }

   [xml]$xmlData = get-content -path $path

   $main.$library.$manual.$file.Add("Data",$xmlData)

   #PSSTIGCExtractManualData ($main.$library.$manual.$file.Data)

   return $main.$library.$manual.$file
}
function PSSTIGCExtractManualData{
    param([hashtable]$fromSender)
    $ErrorActionPreference = "Stop"

    if($null -eq $fromSender){$fromSender = @{}}
    
    if(-not($fromSender.containskey('Verbose'))){
        $fromSender.Add('Verbose',($userPreferences.Verbose))
    }
    $userPreferences.Verbose = $fromSender.Verbose

    if($userPreferences.Verbose){
        $msg = "[PSSTIGCExtractManualData]::[Informational]::Extracting manual data..."
        write-host $msg -fore cyan
    }
    $hashtable = PSSTIGGetManual $fromSender

    $extracted = @{}
    $extracted.add("Dc",$hashtable.Data.Benchmark.dc)
    $extracted.add("Xsi",$hashtable.Data.Benchmark.xsi)
    $extracted.add("Cpe",$hashtable.Data.Benchmark.cpe)
    $extracted.add("Xhtml",$hashtable.Data.Benchmark.xhtml)
    $extracted.add("Dsig",$hashtable.Data.Benchmark.dsig)  
    $extracted.add("SchemaLocation",$hashtable.Data.Benchmark.schemaLocation)  
    $extracted.add("Id",$hashtable.Data.Benchmark.id)  
    $extracted.add("Lang",$hashtable.Data.Benchmark.lang)  
    $extracted.add("Xmlns",$hashtable.Data.Benchmark.xmlns)      
    $extracted.add("Date",$hashtable.Data.Benchmark.status.date)  
    $extracted.add("StatusText",$hashtable.Data.Benchmark.status.'#text') 
    $extracted.add("Title",$hashtable.Data.Benchmark.title) 
    $extracted.add("NoticeID",$hashtable.Data.Benchmark.notice.id) 
    $extracted.add("NoticeLang",$hashtable.Data.Benchmark.notice.lang) 
    $extracted.add("FrontMatterLang",$hashtable.Data.Benchmark.'front-matter'.lang) 
    $extracted.add("RearMatterLang",$hashtable.Data.Benchmark.'rear-matter'.lang) 
    $extracted.add("ReferenceHref",$hashtable.Data.Benchmark.reference.href) 
    $extracted.add("ReferencePublisher",$hashtable.Data.Benchmark.reference.publisher) 
    $extracted.add("ReferenceSource",$hashtable.Data.Benchmark.reference.source)
    $extracted.add("Version",$hashtable.Data.Benchmark.version) 
    
    foreach($ptItem in $hashtable.Data.Benchmark.'plain-text'){
        $extracted.Add($ptItem.id,$ptItem.'#text')
    }

    $flatData = @()
    foreach($group in ($hashtable.Data.Benchmark.group)){
        $flatData += [pscustomobject]@{
            GroupID = $group.id
            XmlVersion = $hashtable.Data.xml
            RuleID = $group.rule.id
            Title = $group.title
            Description = $group.description
            Weight = $group.rule.weight
            Severity =  $group.rule.severity
            Version = $group.rule.version
            RuleTitle = $group.rule.title
            RuleDescription = $group.rule.description
            ReferenceTitle = $group.rule.reference.title
            ReferencePublisher = $group.rule.reference.publisher
            ReferenceType = $group.rule.reference.type
            ReferenceSubject = $group.rule.reference.subject
            ReferenceIdentifier = $group.rule.reference.identifier
            IdentSystem  = $group.rule.ident.system
            IdentText = $group.rule.ident.'#text'
            RuleFixRef = $group.rule.fixText.fixref
            RuleFixText = $group.rule.fixText.'#text'
            RuleFixID = $group.rule.fix.id
            CheckSystem = $group.rule.check.system
            CheckContent = $group.rule.check.'check-content'
            CheckContentHref = $group.rule.check.'check-content-ref'.href
            CheckContentName = $group.rule.check.'check-content-ref'.Name
        }
    }
    $data = @{
        metadata = $extracted
        STIGs = $flatData
    }

    if($userPreferences.Verbose){
        $msg = "[PSSTIGCExtractManualData]::[Informational]::Manual data extracted..."
        write-host $msg -fore cyan
    }
    return $data

}
function _checklistTypeSelect{
    param([hashtable]$fromSender)
    $ErrorActionPreference = "Stop"
    
    $type = $fromSender.Type
    switch($type){
        "cklb"{
            $checklistHash = [ordered]@{
                title = [string]
                id = [string]
                stigs = [array]
                active = [string]
                mode = [string]
                has_path = [string]
                target_data = [ordered]
                cklb_version = [string]
            }
            $targetDataHash = [ordered]@{
                target_type = [string]
                host_name = [string]
                ip_address = [string]
                mac_address = [string]
                fqdn = [string]
                comments = [string]
                role = [string]
                is_web_database = [string]
                technology_area = [string]
                web_db_site = [string]
                web_db_instance = [string]
                classification = [string]
            }
            $stigsHash = [ordered]@{
                stig_name = [string]
                display_name = [string]
                stig_id = [string]
                release_info = [string]
                version = [string]
                uuid = [string]
                reference_identifier = [string]
                size = [int]
                rules = [array]
            }
            $ruleHash  = [ordered]@{
                group_id_scr = [string]
                group_tree = [array]
                group_id = [string]
                severity = [string]
                group_title = [string]
                rule_id_src = [string]
                rule_id = [string]
                rule_version = [string]
                rule_title = [string]
                fix_text = [string]
                weight = [string]
                check_content = [string]
                check_content_ref = [ordered]
                classification = [string]
                discussion = [string]
                false_positives = [string]
                false_negatives = [string]
                documentable = [string]
                security_override_guidance = [string]
                potential_impacts = [string]
                third_party_tools = [string]
                ia_controls = [string]
                responsibility = [string]
                mitigations = [string]
                mitigation_control = [string]
                legacy_ids = [array]
                ccis = [array]
                reference_identifier = [string]
                uuid = [string]
                stig_uuid = [string]
                status = [string]
                overrides =  [ordered]@{}
                comments = [string]
                finding_details = [string]
            }
            $groupTreeHash = [ordered]@{
                id = [string]
                title = [string]
                description = [string]
            }
            $checkContentRefHash = [ordered]@{
                href = [string]
                name = [string]
            }
            $overridesHash = [ordered]@{}

            @{
                checklist = $checklistHash 
                targetdata = $targetDataHash
                stig = $stigsHash
                rules = $ruleHash
                grouptree = $groupTreeHash
                contentRefHash = $checkContentRefHash 
                overrideHash = $overridesHash
            }
        }
        "ckl"{}
        # already handling other types in psstiginsertchecklist
    }  
}
function PSSTIGCreateChecklist{
    param([hashtable]$fromSender)
    $ErrorActionPreference = "Stop"

    if($null -eq $fromSender){$fromSender = @{}}
    
    if(-not($fromSender.containskey('Verbose'))){
        $fromSender.Add('Verbose',($userPreferences.Verbose))
    }
    $userPreferences.Verbose = $fromSender.Verbose

    if($userPreferences.Verbose){
        $msg = "[PSSTIGCreateChecklist]::[Informational]::Creating checklists..."
        write-host $msg -fore cyan
    }

    $manualData = PSSTIGCExtractManualData $fromSender

    if(-not($fromSender.containskey('StigIDs'))){
        $fromSender.Add('StigIDs','All')
    }
    $stigIDs = $fromSender.StigIDs 
    
    # asses the provided rule ids
    $ruleContraintMet = $false
    if($stigIDs -is [array]){
        $validIDs = $true
        $invalidRuleIdList = @()
        foreach($rule in $stigIDs){
            if(-not($manualData.STIGs.GroupID -contains $rule)){
                $validIDs = $false
                $invalidRuleIdList += $rule
            }
        }
        
        if(-not($validIDs)){
            $msg = "[PSSTIGCreateChecklist]::[Error]::Double check that the manual has the following rule id(s):`n{0}"
            $msg = $msg -f ($invalidRuleIdList -join "`n") 
            write-error $msg
        }
        $ruleContraintMet = $true
    }

    if($stigIDs -is [string]){
        if(-not($stigIDs -eq 'All')){
            $msg = "When passing in a string, it can only be 'All', to work with specific rule ids, use an array"
            write-error $msg
        }
        $stigIDs = $manualData.STIGs.GroupID
        $ruleContraintMet = $true
    }

    if(-not($ruleContraintMet)){
        $msg = "[PSSTIGCreateChecklist]::[Error]::StigIDs can only be a string value 'All' or an array of rule ids"
        write-error $msg
    }

    # insert an entry of the checklist into the ledger, if it doesnt already exists
    $checklistExists = PSSTIGInsertCheckList $fromSender.Checklist

    if(-not($checklistExists)){
        if($fromSender.Checklist.type -eq 'cklb'){
            $uuid = (new-guid).guid
            $checklistHash = [ordered]@{
                title = ($fromSender.checklist.Name).trim()
                id = ((new-guid).guid).trim()
                stigs = @(@{
                    stig_name = ($manualData.metadata.Title).trim()
                    display_name = ($manualData.STIGs[0].ReferenceSubject).trim()
                    stig_id = ($manualData.STIGs[0].CheckContentHref -replace (".xml","")).trim()
                    release_info = ($manualData.metadata."release-info").trim()
                    version = ($manualData.metadata.version).trim()
                    uuid = $uuid
                    reference_identifier = $manualData.stigs[0].ReferenceIdentifier
                    size =  $manualData.stigs.count
                    rules = @()
                })
                active = $true
                mode = 2
                hash_path = $false
                target_data = @{
                    target_type = "Computing"
                    host_name = ""
                    ip_address = ""
                    mac_address = ""
                    fqdn = ""
                    comments = ""
                    role = "None"
                    is_web_database = $false
                    technology_area = ""
                    web_db_site = ""
                    web_db_instance = ""
                    classification = $null
                }
                cklb_version =  "1.0"
            }
            foreach($rule in $manualData.stigs){
                $thisRule = @{
                    group_id_src = ($rule.GroupID).trim()
                    group_tree = @()
                    group_id = ($rule.GroupID).trim()
                }
                $thisRule.group_tree += @{
                    id = ($rule.GroupID).trim()
                    title = ($rule.title).trim()
                    description = ($rule.Description).trim()
                }
                $thisRule += @{
                    severity = ($rule.severity).trim()
                    group_title = ($rule.RuleTitle).trim()
                    rule_id_scr = ($rule.RuleID).trim()
                    rule_version = ($rule.version).trim()
                    rule_title = ($rule.RuleTitle).trim()
                    fix_text = ($rule.RuleFixText).trim()
                    weight = ($rule.weight).trim()
                    check_content = ($rule.CheckContent).trim()
                    check_content_ref = @{
                        href = $rule.Check
                        name = $rule.CheckContentName
                    }
                    classification = "Unclassified"
                    discussion = if($rule.RuleDescription -match '(?s)(<VulnDiscussion>)(.*)(</VulnDiscussion>)'){$matches[2]}else{""}
                    false_positives = if($rule.RuleDescription -match '(?s)(<FalsePositives>)(.*)(</FalsePositives>)'){$matches[2]}else{""}
                    false_negatives = if($rule.RuleDescription -match '(?s)(<FalseNegatives>)(.*)(</FalseNegatives>)'){$matches[2]}else{""}
                    documentable = if($rule.RuleDescription -match '(?s)(<Documentable>)(.*)(</Documentable>)'){$matches[2]}else{""}
                    security_override_guidance = if($rule.RuleDescription -match '(?s)(<SeverityOverrideGuidance>)(.*)(</SeverityOverrideGuidance>)'){$matches[2]}else{""}
                    potential_impacts = if($rule.RuleDescription -match '(?s)(<PotentialImpacts>)(.*)(</PotentialImpacts>)'){$matches[2]}else{""}
                    third_party_tools = if($rule.RuleDescription -match '(?s)(<ThirdPartyTools>)(.*)(</ThirdPartyTools>)'){$matches[2]}else{""}
                    ia_controls = if($rule.RuleDescription -match '(?s)(<IAControls>)(.*)(</IAControls>)'){$matches[2]}else{""}
                    responsibility = if($rule.RuleDescription -match '(?s)(<Responsibility>)(.*)(</Responsibility>)'){$matches[2]}else{""}
                    mitigations = if($rule.RuleDescription -match '(?s)(<Mitigations>)(.*)(</Mitigations>)'){$matches[2]}else{""}
                    mitigation_control = if($rule.RuleDescription -match '(?s)(<MitigationControl>)(.*)(</MitigationControl>)'){$matches[2]}else{""}
                    legacy_ids = @()
                }
                $thisRule.legacy_ids += ($rule.IdentText | where-object {$_ -notlike "CCI*"})
                $thisRule += @{
                    ccis = @()
                }
                $thisRule.ccis += ($rule.IdentText | where-object {$_ -like "CCI*"})
                $thisRule += @{
                    reference_identifier = "$(($rule.ReferenceIdentifier).trim())"
                    uuid = (new-guid).guid
                    stig_uuid = $uuid
                    status = "not_reviewed"
                    overrides = @{}
                    comments = ""
                    finding_details = ""
                }
                $checklistHash.stigs[0].rules += $thisRule
            }
                
            $checklistContent = $checklistHash | convertto-json -depth 20
        }
    
        $help = _helperpsstig
        $separator = $help.separator
        $path = $fromSender.ChecKlist.path
    
        $fullPath = "{0}{1}{2}.{3}" -f $path,$separator,($fromSender.checklist.Name),($fromSender.checklist.type)
        new-item -path $fullPath -itemType 'File'  -value $checklistContent -force | out-null
    }

}
function PSSTIGInsertCheckList{
    param([hashtable]$fromSender)

    # by default all functions should stop on error
    $ErrorActionPreference = "Stop"

    # user helper
    $helpers = _helperpsstig

    # default user preferences for how this function will work
    # override with user supplied value(s) if any
    $userPreferences = @{
        Verbose = $true 
    }

    if($null -eq $fromSender){$fromSender = @{}}
    
    if(-not($fromSender.containskey('Verbose'))){
        $fromSender.Add('Verbose',($userPreferences.Verbose))
    }
    $userPreferences.Verbose = $fromSender.Verbose

    $checklistParameters = $fromSender

    # mandatory parameters list
    $mandatorycheckListParameters = @(
        'Name'
        'Type'
        'Path'
    )

    # evaluate for any missing mandatory parameters
    $missingParametersList = @()
    $checkPassed = $true
    foreach($mandatoryParameter in $mandatorycheckListParameters){
        if(-not($checklistParameters.containskey($mandatoryParameter))){
            $checkPassed = $false
            $missingParametersList += $mandatoryParameter
        }
    }

    if(-not($checkPassed)){
        $msg = "[Error] Missing the following madatory parameter(s) for checklist:`n{0}"
        $msg = $msg -f ($missingParametersList -join "`n")
        write-error $msg
    }
    $type = $fromSender.Type

    if(($null -eq $checklistParameters.Path) -or ($checklistParameters.Path.length -eq 0)){
        if($null -eq $checklistParameters.Path){
            $msg = "[Error] Path cannot be null"
            write-error $msg
        }
        if($checklistParameters.Path.length -eq 0){
            $msg = "[Error] Path cannot be an empty string"
            write-error $msg
        }
    }

    $validType = $false
    if(($checklistParameters.Type -eq 'cklb') -or ($checklistParameters.Type -eq 'ckl')){
        $validType = $true
    }
    if(-not($validType)){
        $msg = "[Error] Type can only be either 'cklb' or 'ckl'"
        write-error $msg
    }

    if(($null -eq $checklistParameters.Name) -or ($checklistParameters.Name.length -eq 0)){
        if($null -eq $checklistParameters.Name){
            $msg = "[Error] Name cannot be null"
            write-error $msg
        }
        if($checklistParameters.Name.length -eq 0){
            $msg = "[Error] Name cannot be an empty string"
            write-error $msg
        }
    }

    $path = $checklistParameters.Path
    if(-not(test-path -path $path)){
        $msg = "[Error] The path provided for the checklist is not valid {0}" -f $path
        write-error $msg
    }

    # reference the checklsits.json file
    $hashtable = PSSTIGSelect @{From = "checklists"}

    $name = $checklistParameters.Name
    
    # entry in the reference file is built here
    $entry = @{
        ("$name"+"."+"$type") = [ordered]@{
            Name = $name+".$type"
            Id = (new-guid).guid
            CreatedBy = "null-on-unix"
            DateCreated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            LastUpdated = ""
            Path = $Path
            Type = $Type
        }
    }

    # when there is nothing in the main.json, just insert the new entry
    if($hashTable.keys.count -eq 0){
        if($userPreferences.Verbose){
            $msg = "[PSSTIGInsertCheckList]::[Informational]::Checklist entry created in registry" -f $path,($helper.separator),$name,$type
            write-host $msg -fore cyan
        }
        PSSTIGInsert @{To = "checklists"; Entry = $entry}
        return $false
    }

    $checklistExist = [bool]
    if(-not($null -eq $hashTable.("$name"+"."+"$type"))){
        $checklistExist = $true
    }else{
        $checklistExist = $false
    }

    if(-not($checklistExist)){
        $hashTable += $entry
    }
    if($checklistExist){
        if($userPreferences.Verbose){
            $msg = "[PSSTIGInsertCheckList]::[Informational]::Checklist entry in registry already exists"
            write-host $msg -fore cyan
        }
        return $true
    }else{
        PSSTIGInsert @{To = "checklists"; Entry = $hashTable}
        return $false
    }
}
# -------------------------------------------
function PSSTIGGetCheckList{
    param([hashtable]$fromSender)

    # by default all functions should stop on error
    $ErrorActionPreference = "Stop"

    # user helper
    $helpers = _helperpsstig

    # default user preferences for how this function will work
    # override with user supplied value(s) if any
    $userPreferences = @{
        Verbose = $true 
    }

    if($null -eq $fromSender){$fromSender = @{}}
    
    if(-not($fromSender.containskey('Verbose'))){
        $fromSender.Add('Verbose',($userPreferences.Verbose))
    }
    $userPreferences.Verbose = $fromSender.Verbose

    $path = $fromSender.Path
    
    $data = (get-content -path $path) | convertfrom-json

    if($fromSender.type -eq 'cklb'){
        $data
    }
}

# this is used to create the entry: check script
function psstigBuildCheckScriptEntry {
    param([hashtable]$fromSender)
    $ErrorActionPreference = "stop"

    if($null -eq $fromSender){
        $fromSender = @{}
    }
    
    # handle mandatory parameters
    $mandatoryParametersList = @(
        "Path"
        "Type"
    )

    $missingMandatoryParameters = $false
    $missingMandatoryParametersList = @()

    foreach($parameter in $mandatoryParametersList){
        if(-not($fromSender.containskey("$parameter"))){
            $missingMandatoryParameters = $true
            $missingMandatoryParametersList += $parameter
        }
    }
    if($missingMandatoryParameters){
        $text = ("Missing the following parameters:`n{0}" -f ($missingMandatoryParametersList -join "`n"))
        $msg = $text
        write-error -message $msg
    }
   
    # handle optional parameters
    $optionalParametersList = @(
        @{Owners = @()}
        @{Emails = @()}
        @{GuardDeletion = $true}
        @{Name = ""}
        @{FixScriptIDs = @()}
        @{Documentation = @{Path = "";Type = ""}}
        @{Parameters = @{}}
        @{ReviewedBy = ""}
    )

    foreach($parameter in $optionalParametersList){
        $name = [string]($parameter.keys)
        if(-not($fromSender.containskey($name))){
            $fromSender.Add($name,($optionalParametersList.($name)))
        }
    }

    $changeLog = @()

    # can only link scripts in this list
    $allowedScriptsList = @(
        "ps1"
        "sql"
    )
    $type = $fromSender.Type
    
    if($type -contains "."){
        $type = ($type -replace ".","").trim()
    }
    if(-not($allowedScriptsList -contains ($type))){
        $text = "Script type can only be any one of the following types:`n{0}" -f $allowedScriptsList
        $msg = $text
        write-error -message $msg
    }

    # the script provided has to be to a valid full path
    $path = $fromSender.Path
    if(-not(test-path -path $Path)){
        $text = "The path provided '{0}' does not exist" -f $path
        $msg = $text
        write-error -message $msg
    }

    $documentation = @{
        HasDocumentation = $false
        Path = ""
        Type = ""
    }

    # if providing documentation it has to be valid
    if(-not($fromSender.Documentation.Path.length -eq 0)){
        $documentationPath = $fromSender.Documentation.Path
        if(-not(test-path -path $documentationPath)){
            $text = "When providing documentation to a script, it has to be valid, make sure the path to the documentation is valid"
            $msg = $text
            write-error -message $msg
        }

        $documentation.HasDocumentation = $true
        $documentation.Path = $documentationPath

        if(-not($fromSender.Documentation.Type.length -eq 0)){
            $docType = $fromSender.Documentation.Type
            $documentation.Type = $docType
        }
    }

    $owners = New-Object System.Collections.ArrayList
    foreach($owner in $fromSender.Owners){
        $owners.Add($owner)
    }
    $emails = New-Object system.Collections.ArrayList
    foreach($owner in $fromSender.Emails){
        $owners.Add($owner)
    }

    $enabled = $false
    $reviewed = @{
        ReviewedComplete = $false
        ReviewedDateTime = ""
        ReviewedBy = ""
    }
    # if script is already reaviewed, then it can be enabled 
    if(-not($fromSender.ReviewedBy.length -eq 0)){
        $reviewed.ReviewedComplete = $true
        $reviewed.ReviewedBy = $fromSender.ReviewedBy
        $reviewed.ReviewedDateTime = (get-date).toString("yyyy-MM-dd HH:mm:ss")
        $enabled = $true
    }
    
    $dateTimeAdded = (Get-Date).toString('yyyy-MM-dd HH:mm:ss')
    $scriptID = (new-guid).guid

    $name = $fromSender.Name
    
    if(-not($fromSender.Parameters -is [hashtable])){
        $text = "Parameters must be supplied as a hashtable"
        $msg = $text
        write-error -message $msg
    }

    $parameters = @{
        Required = $false
        Parameters = @{}
    }

    if(-not($fromSender.Parameters.keys.count -eq 0)){
        $parameters.Required = $true
        $parameters.Parameters = $fromSender.Parameters
    }


    # build out the json entry
    $scriptID = @{
        GuardDeletion = $fromSender.GuardDeletion
        Enabled = $enabled
        Type = $type
        Name = $name
        HasFix = @{
            HasFix = $false
            FixScriptIDs = @()
        }
        Path = @{
            Path = $path
        }
        Documentation = $documentation
        Parameters = $parameters
        DateTimeAdded = $DateTimeAdded
        Owners = $owners
        Emails = $emails
        Review = $reviewed
        ChangeLog = @(
            @{$DateTimeAdded = "script initalially added"}
        )
    }
    return $scriptID    
}
