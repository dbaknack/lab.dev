. .\new\module.ps1
Initialize @{
    RootDirectory = $env:ProgramFiles
    Reinitialize = $false
}


OpenSomeSessions @{
    To = @{
        ServerName = "sql01"
        Description:: 
            Credentials = @{
            Enable = [bool]
            myCreds = 'Get-Credential'
            Protocol = [string]
        }   
    }
}

Get-PSSession | Remove-PSSession
RunTask @{
    SequenceTitle = [string]
    On = @("sql01")     # ------------- or "" or *  , there the session needs to be open
    UseFunction = @('Test','Test2')   # ----------- or "" or * 
    UseSource = @()     # ----------- or "" or * 
    Tasks = [ordered]@{
        # tasks can run one at a time or seperate...
        "Task1" = @{
            Description = [string]
            ArgumentList = @{
                Args = @('')
                UseLastTaskOutput = @{
                    Enable = [bool]
                }          
            } # -- this can be $null or an empty array or empty string. this will be used in the script
            Script = @{
                Type = [string] # by default its PowerShell
                Block = [string] # or file
            }
            Wait = @{
                Enable = [bool]
                On = @{
                    ServerReboot = @{
                        Enable = [bool]
                    }
                    LastTask = @{
                        Enable = [bool]
                        Status = @{}
                    }
                    UserAction = @{
                        Enable = [bool]
                        Status = @{}
                    }
                }
            }
            Message = @{
                Enable = [bool]
                Text = [string]
            }
        }
        "Task2" = @{
            Use = @{
                Enable = [bool]
                Source = @()
            }
            Description = [string]
            ArgumentList = @{
                Args = @('')
                UseLastTaskOutput = @{
                    Enable = [bool]
                }          
            } # -- this can be $null or an empty array or empty string. this will be used in the script
            Script = @{
                Type = [string] # by default its PowerShell
                Block = [string] # or file
            }
            Wait = @{
                Enable = [bool]
                On = @{
                    ServerReboot = @{
                        Enable = [bool]
                    }
                    LastTask = @{
                        Enable = [bool]
                        Status = @{}
                    }
                    UserAction = @{
                        Enable = [bool]
                        Status = @{}
                    }
                }
            }
            Message = @{
                Enable = [bool]
                Text = [string]
            }
        }
    }
    Log = [bool]
    CloseWhenDone = [bool]
}
