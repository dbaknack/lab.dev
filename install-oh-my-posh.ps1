
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://ohmyposh.dev/install.ps1'))

# install font
# --- Set your paths ---
$zipPath     = "z:\lab.vm-fileshare\fonts\Fira_Code_v6.2.zip"
$extractPath = "$env:TEMP\FiraCodeFonts"
$fontsPath   = "$env:SystemRoot\Fonts"

# --- Extract the ZIP ---
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

# --- Get all TTF/OTF files ---
$fontFiles = Get-ChildItem -Path $extractPath -Recurse -Include *.ttf, *.otf

# --- Install each font ---
foreach ($font in $fontFiles) {
    $dest = Join-Path -Path $fontsPath -ChildPath $font.Name
    Copy-Item -Path $font.FullName -Destination $dest -Force

    # Register the font (adds it to registry)
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    $fontName = $font.BaseName
    $fontType = if ($font.Extension -eq ".ttf") { " (TrueType)" } else { " (OpenType)" }
    Set-ItemProperty -Path $regPath -Name "$fontName$fontType" -Value $font.Name
}

# --- Refresh font cache (optional, not always needed) ---
Write-Output "Fonts installed. You may need to restart applications or reboot for them to appear."

# add font to vscode
# "terminal.integrated.fontFamily": "MesloLGM Nerd Font"


# update path
$env:Path += ";C:\Users\user\AppData\Local\Programs\oh-my-posh\bin"

# configure terminal
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://ohmyposh.dev/install.ps1'))

Get-ChildItem -Path "C:\" -Recurse -Include "oh-my-posh.exe" -ErrorAction SilentlyContinue -Force

[Environment]::SetEnvironmentVariable(
    "Path",
    [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine) + ";C:\Program Files\oh-my-posh\bin",
    [EnvironmentVariableTarget]::Machine
)

oh-my-posh