#!/usr/bin/env pwsh
#region    Classes
enum HostOS {
    Windows
    Linux
    MacOS
    UNKNOWN
}
class RGB {
    [ValidateRange(0, 255)]
    [int]$Red
    [ValidateRange(0, 255)]
    [int]$Green
    [ValidateRange(0, 255)]
    [int]$Blue
    RGB() {}
    RGB($r, $g, $b) {
        $this.Red = $r
        $this.Green = $g
        $this.Blue = $b
    }
    [string] ToString() {
        return "$($this.Red),$($this.Green),$($this.Blue)"
    }
}

class CliStyler {
    static [string] $nl
    static [string] $dt
    static [string] $b1
    static [string] $b2
    static [HostOs] $HostOS
    static [string[]] $ompJson
    static [char] $swiglyChar
    static [Hashtable] $colors
    static [PsObject] $PSVersn
    static [char] $DirSeparator
    static [string] $Home_Indic
    static [string] $WindowTitle
    static [string] $leadingChar
    static [string] $trailngChar
    static [IO.FileInfo] $LogFile
    static [string] $Default_Term_Ascii
    static hidden [PsObject] $PROFILE
    static hidden [bool] $CurrExitCode
    static hidden [IO.FileInfo] $OmpJsonFile
    static [string[]] $Default_Dependencies
    static [string] $WINDOWS_TERMINAL_JSON_PATH
    static [Int32] $realLASTEXITCODE = $LASTEXITCODE
    static [PSCustomObject] $TERMINAL_Settings
    static [PSCustomObject] $FontMan = $(Invoke-Command -ScriptBlock {
        if (!(Get-Variable fontman_class_f1b973119b9e -ValueOnly -Scope global -ErrorAction Ignore)) { Set-Variable -Name fontman_class_f1b973119b9e -Scope global -Option ReadOnly -Value $([scriptblock]::Create("$(Invoke-RestMethod -Method Get https://gist.github.com/alainQtec/7d5465b60bf54b7590919e8707cc297a/raw/FontMan.ps1)")) };
        . $(Get-Variable fontman_class_f1b973119b9e -ValueOnly -Scope global)
        return New-Object -TypeName FontMan
    })
    static [CliStyler] Create() {
        [CliStyler]::Set_Defaults()
        return New-Object CliStyler
    }
    static [void] Initialize() {
        [CliStyler]::Initialize(@())
    }
    static [void] Initialize([string[]]$DependencyModules) {
        [CliStyler]::Initialize(@(), $false)
    }
    static [void] Initialize([string[]]$DependencyModules, [bool]$force) {
        Write-Verbose '[CliStyler] Set variable defaults'
        [CliStyler]::Set_Defaults()
        Write-Verbose '[CliStyler] Resolving Requirements ... (a one-time process)'
        # Inspired by: https://dev.to/ansonh/customize-beautify-your-windows-terminal-2022-edition-541l
        if ($null -eq (Get-PSRepository -Name PSGallery -ErrorAction Ignore)) {
            throw 'PSRepository named PSGallery was Not found!'
        }
        Set-PSRepository PSGallery -InstallationPolicy Trusted;
        $PackageProviderNames = (Get-PackageProvider -ListAvailable).Name
        $requiredModules = [CliStyler]::Default_Dependencies + $DependencyModules | Sort-Object -Unique
        foreach ($name in @("NuGet", "PowerShellGet")) {
            if ($force) {
                Install-PackageProvider $name -Force
            } elseif ($PackageProviderNames -notcontains $name) {
                Install-PackageProvider $name -Force
            } else {
                Write-Verbose "PackageProvider '$name' is already Installed."
            }
        }
        # Install requied modules:
        [CliStyler]::Resolve_module($requiredModules) # we could use Install-Module -Name $_ but it fails sometimes
        # BeautifyTerminal :
        if ([CliStyler]::IsTerminalInstalled()) {
            [CliStyler]::AddColorScheme()
        } else {
            Write-Warning "Windows terminal is not Installed!"
        }
        [CliStyler]::InstallNerdFont()
        [CliStyler]::InstallOhMyPosh() # instead of: winget install JanDeDobbeleer.OhMyPosh
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView # Optional
        # WinFetch
        Install-Script -Name winfetch -AcceptLicense

        if (!(Test-Path -Path $env:USERPROFILE/.config/winfetch/config.ps1)) {
            winfetch -genconf
        }
        (Get-Content $env:USERPROFILE/.config/winfetch/config.ps1).Replace('# $ShowDisks = @("*")', '$ShowDisks = @("*")') | Set-Content $env:USERPROFILE/.config/winfetch/config.ps1
        (Get-Content $env:USERPROFILE/.config/winfetch/config.ps1).Replace('# $memorystyle', '$memorystyle') | Set-Content $env:USERPROFILE/.config/winfetch/config.ps1
        (Get-Content $env:USERPROFILE/.config/winfetch/config.ps1).Replace('# $diskstyle', '$diskstyle') | Set-Content $env:USERPROFILE/.config/winfetch/config.ps1
        # RESET current exit code:
        [CliStyler]::CurrExitCode = $true

        Write-Verbose '[CliStyler] Load configuration settings ...'
        [CliStyler]::LoadConfiguration()

        Set-Variable -Name Colors -Value $([CliStyler]::colors) -Scope Global -Visibility Public -Option AllScope
        if ($force) {
            # Invoke-Command -ScriptBlock $Load_Profile_Functions
            [CliStyler]::CurrExitCode = $? -and $([CliStyler]::Create_Prompt_Function())
        } else {
            if (!$([CliStyler]::IsInitialised())) {
                # Invoke-Command -ScriptBlock $Load_Profile_Functions
                [CliStyler]::CurrExitCode = $? -and $([CliStyler]::Create_Prompt_Function())
            } else {
                Write-Debug "[CliStyler] is already Initialized, Skipping ..."
            }
        }
        [void][CliStyler]::GetPsProfile() # create the $profile file if it does not exist
        [CliStyler]::Set_TerminalUI()
        Write-Debug -Message "[CliStyler] Displaying a welcome message/MOTD ..."
        [CliStyler]::Write_Term_Ascii()
    }
    static [bool] IsInitialised() {
        return (Get-Variable -Name IsPromptInitialised -Scope Global).Value
    }
    static [void] LoadConfiguration() {
        [CliStyler]::TERMINAL_Settings = [CliStyler]::GetTerminalSettings();
    }
    static [PSCustomObject] GetTerminalSettings() {
        if ([CliStyler]::IsTerminalInstalled()) {
            if ([IO.Directory]::Exists([CliStyler]::WINDOWS_TERMINAL_JSON_PATH)) {
                return (Get-Content $([CliStyler]::WINDOWS_TERMINAL_JSON_PATH) -Raw | ConvertFrom-Json)
            }
            Write-Warning "Could not find WINDOWS_TERMINAL_JSON_PATH!"
        } else {
            Write-Warning "Windows terminal is not installed!"
        }
        return $null
    }
    static [void] SaveTerminalSettings([PSCustomObject]$settings) {
        # Save changes (Write Windows Terminal settings)
        $settings | ConvertTo-Json -Depth 32 | Set-Content $([CliStyler]::WINDOWS_TERMINAL_JSON_PATH)
    }
    static hidden [void] AddColorScheme() {
        $settings = [CliStyler]::GetTerminalSettings();
        if ($null -ne $settings) {
            $sonokaiSchema = [PSCustomObject]@{
                name                = "Sonokai Shusia"
                background          = "#2D2A2E"
                black               = "#1A181A"
                blue                = "#1080D0"
                brightBlack         = "#707070"
                brightBlue          = "#22D5FF"
                brightCyan          = "#7ACCD7"
                brightGreen         = "#A4CD7C"
                brightPurple        = "#AB9DF2"
                brightRed           = "#F882A5"
                brightWhite         = "#E3E1E4"
                brightYellow        = "#E5D37E"
                cursorColor         = "#FFFFFF"
                cyan                = "#3AA5D0"
                foreground          = "#E3E1E4"
                green               = "#7FCD2B"
                purple              = "#7C63F2"
                red                 = "#F82F66"
                selectionBackground = "#FFFFFF"
                white               = "#E3E1E4"
                yellow              = "#E5DE2D"
            }
            # Check color schema added before or not?
            if ($settings.schemes | Where-Object -Property name -EQ $sonokaiSchema.name) {
                Write-Host "[CliStyler] Terminal Color Theme was added before"
            } else {
                $settings.schemes += $sonokaiSchema
                # Check default profile has colorScheme or not
                if ($settings.profiles.defaults | Get-Member -Name 'colorScheme' -MemberType Properties) {
                    $settings.profiles.defaults.colorScheme = $sonokaiSchema.name
                } else {
                    $settings.profiles.defaults | Add-Member -MemberType NoteProperty -Name 'colorScheme' -Value $sonokaiSchema.name
                }
                [CliStyler]::SaveTerminalSettings($settings);
            }
        } else {
            Write-Warning "[CliStyler] Could not get TerminalSettings, please make sure windowsTerminal is installed."
        }
    }
    static hidden [void] InstallNerdFont() {
        [clistyler]::InstallNerdFont('FiraCode')
    }
    static hidden [void] InstallNerdFont([string]$FontName) {
        #Requires -Version 3.0
        [ValidateNotNullorEmpty()][string]$FontName = $FontName
        if ([clistyler]::FontMan::GetInstalledFonts().Contains("$FontName")) {
            Write-Verbose "[CliStyler] Font '$FontName' is already installed!"
            return
        }
        Write-Host "Install required Font:  ($FontName)" -ForegroundColor Magenta
        [IO.DirectoryInfo]$FiraCodeExpand = [IO.Path]::Combine($env:temp, 'FiraCodeExpand')
        if (![System.IO.Directory]::Exists($FiraCodeExpand.FullName)) {
            $fczip = [IO.FileInfo][IO.Path]::Combine($env:temp, 'FiraCode.zip')
            if (![IO.File]::Exists($fczip.FullName)) {
                Invoke-WebRequest -Uri https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip -OutFile $fczip.FullName
            }
            Expand-Archive -Path $fczip.FullName -DestinationPath $FiraCodeExpand.FullName
            Remove-Item -Path $fczip.FullName -Recurse
        }
        # Install Fonts
        # the Install-Font function is found in PSWinGlue module
        [clistyler]::Resolve_module('PSWinGlue')
        Import-Module -Name PSWinGlue -WarningAction silentlyContinue
        # Elevate to Administrative
        if (![CliStyler]::IsAdministrator()) {
            $command = "Install-Font -Path '{0}'" -f ([IO.Path]::Combine($env:temp, 'FiraCodeExpand'))
            Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command {$command}" -Verb RunAs -Wait -WindowStyle Minimized
        }
        $settings = [CliStyler]::GetTerminalSettings()
        if ($null -ne $settings) {
            # Check default profile has font or not
            if ($settings.profiles.defaults | Get-Member -Name 'font' -MemberType Properties) {
                $settings.profiles.defaults.font.face = 'FiraCode Nerd Font'
            } else {
                $settings.profiles.defaults | Add-Member -MemberType NoteProperty -Name 'font' -Value $(
                    [PSCustomObject]@{
                        face = 'FiraCode Nerd Font'
                    }
                ) | ConvertTo-Json
            }
            [CliStyler]::SaveTerminalSettings($settings);
        } else {
            Write-Warning "Could update Terminal font settings!"
        }
    }
    static hidden [void] InstallWinget() {
        Write-Host "Install winget" -ForegroundColor Magenta
        $wngt = 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
        $deps = ('Microsoft.VCLibs.x64.14.00.Desktop.appx', 'Microsoft.UI.Xaml.x64.appx')
        $PPref = Get-Variable -Name progressPreference -Scope Global; $progressPreference = 'silentlyContinue'
        $IPref = Get-Variable -Name InformationPreference -Scope Global; $InformationPreference = "Continue"
        if ([bool](Get-Command winget -Type Application -ea Ignore) -and !$PSBoundParameters.ContainsKey('Force')) {
            Write-Host "Winget is already Installed." -ForegroundColor Green -NoNewline; Write-Host " Use -Force switch to Overide it."
            return
        }
        # Prevent Error code: 0x80131539
        # https://github.com/PowerShell/PowerShell/issues/13138
        Get-Command Add-AppxPackage -ErrorAction Ignore
        if ($Error[0]) {
            if ($Error[0].GetType().FullName -in ('System.Management.Automation.CmdletInvocationException', 'System.Management.Automation.CommandNotFoundException')) {
                Write-Host "Module Appx is not loaded by PowerShell Core! Importing ..." -ForegroundColor Yellow
                Import-Module -Name Appx -UseWindowsPowerShell -Verbose:$false -WarningAction SilentlyContinue
            }
        }
        Write-Host "[0/3] Downloading WinGet and its dependencies ..." -ForegroundColor Green
        Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile $wngt
        Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile $deps[0]
        Invoke-WebRequest -Uri https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.7.3/Microsoft.UI.Xaml.2.7.x64.appx -OutFile $deps[1];

        Write-Host "[1/3] Installing $($deps[0]) ..." -ForegroundColor Green
        Add-AppxPackage -Path $deps[0]

        Write-Host "[2/3] Installing $($deps[1]) ..." -ForegroundColor Green
        Add-AppxPackage -Path $deps[1]

        Write-Host "[3/3] Installing $wngt ..." -ForegroundColor Green
        Add-AppxPackage -Path $wngt
        # cleanup
        $deps + $wngt | ForEach-Object { Remove-Item ($_ -as 'IO.FileInfo').FullName -Force -ErrorAction Ignore }
        # restore
        $progressPreference = $PPref
        $InformationPreference = $IPref
    }
    static [void] InstallOhMyPosh() {
        [CliStyler]::InstallOhMyPosh($true, $false)
    }
    static [void] InstallOhMyPosh([bool]$AllUsers, [bool]$force) {
        $ompath = Get-Variable OH_MY_POSH_PATH -Scope Global -ValueOnly -ErrorAction Ignore
        if ($null -eq $ompath) { [CliStyler]::Set_Defaults() }
        $ompdir = [IO.DirectoryInfo]::new((Get-Variable OH_MY_POSH_PATH -Scope Global -ValueOnly))
        if (!$ompdir.Exists) { [void][CliStyler]::Create_Directory($ompdir.FullName) }
        if (!$force -and [bool](Get-Command oh-my-posh -Type Application -ErrorAction Ignore)) {
            Write-Verbose "oh-my-posh is already Installed; moing on ..."
            return
        }
        # begin installation
        Write-Host "Install OhMyPosh" -ForegroundColor Magenta
        $installer = ''; $installInstructions = "`nHey friend`n`nThis installer is only available for Windows.`nIf you're looking for installation instructions for your operating system,`nplease visit the following link:`n"
        $Host_OS = [CliStyler]::HostOS.ToString()
        if ($Host_OS -eq "MacOS") {
            Write-Host "`n$installInstructions`n`nhttps://ohmyposh.dev/docs/installation/macos`n"
        } elseif ($Host_OS -eq "Linux") {
            Write-Host "`n$installInstructions`n`nhttps://ohmyposh.dev/docs/installation/linux"
        } elseif ($Host_OS -eq "Windows") {
            $arch = (Get-CimInstance -Class Win32_Processor -Property Architecture).Architecture | Select-Object -First 1
            switch ($arch) {
                0 { $installer = "install-386.exe" }
                5 { $installer = "install-arm64.exe" }
                9 {
                    if ([Environment]::Is64BitOperatingSystem) {
                        $installer = "install-amd64.exe"
                    } else {
                        $installer = "install-386.exe"
                    }
                }
                12 { $installer = "install-arm64.exe" }
            }
            if ([string]::IsNullOrEmpty($installer)) {
                throw "`nThe installer for system architecture ($(@{
                    0  = 'X86'
                    5  = 'ARM'
                    9  = 'AMD64/32'
                    12 = 'Surface'
                }.$arch)) is not available.`n"
            }
            Write-Host "Downloading $installer..."
            $omp_installer = [IO.FileInfo]::new("aux"); $ret_count = 0
            do {
                $omp_installer = [IO.FileInfo]::new([IO.Path]::Combine($env:TEMP, ([System.IO.Path]::GetRandomFileName() -replace '\.\w+$', '.exe'))); $ret_count++
            } while (![IO.File]::Exists($omp_installer.FullName) -and $ret_count -le 10)
            $url = "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/$installer"
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -OutFile $omp_installer.FullName -Uri $url
            Write-Host 'Running installer...'
            $installMode = "/CURRENTUSER"
            if ($AllUsers) {
                $installMode = "/ALLUSERS"
            }

            & "$omp_installer" /VERYSILENT $installMode | Out-Null
            $omp_installer | Remove-Item
            #todo: refresh the shell
        } else {
            throw "Error: Could not determine the Host operating system."
        }
    }
    static [bool] IsTerminalInstalled() {
        $IsInstalled = $true
        # check in wt if added to %PATH%
        $defWtpath = (Get-Command wt.exe -Type Application -ErrorAction Ignore).Source
        if (![string]::IsNullOrWhiteSpace($defWtpath)) {
            return $IsInstalled
        }
        # check generic paths: https://stackoverflow.com/questions/62894666/path-and-name-of-exe-file-of-windows-terminal-preview
        $genericwt = [IO.FileInfo]::new("$env:LocalAppData/Microsoft/WindowsApps/wt.exe")
        $msstorewt = [IO.FileInfo]::new("$env:LocalAppData/Microsoft/WindowsApps/Microsoft.WindowsTerminal_8wekyb3d8bbwe/wt.exe")
        $IsInstalled = $IsInstalled  -and ($genericwt.Exists -or $msstorewt.Exists)
        return $IsInstalled
    }
    static [bool] IsAdministrator() {
        return [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
    }
    static [IO.FileInfo] GetPsProfile() {
        # This method will return the profile file (CurrentUserCurrentHost) and creates a new one if it does not already exist.
        $Documents_Path = [CliStyler]::GetDocumentsPath()
        if (!$Documents_Path.Exists) {
            New-Item -Path $Documents_Path -ItemType Directory
        }
        # Manually get CurrentUserCurrentHost profile file
        $prof = [IO.FileInfo]::new([IO.Path]::Combine($Documents_Path, 'PowerShell', 'Microsoft.PowerShell_profile.ps1'))
        if (!$prof.Exists) { $prof = [CliStyler]::GetPsProfile($prof) }
        return $prof
    }
    static [IO.FileInfo] GetPsProfile([IO.FileInfo]$file) {
        if (!$file.Directory.Exists) { [void][CliStyler]::Create_Directory($file.Directory.FullName) }
        $file = New-Item -ItemType File -Path $file.FullName
        [CliStyler]::Add_OMP_To_Profile($file)
        return $file
    }
    static [IO.DirectoryInfo] GetDocumentsPath() {
        $User_docs_Path = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments)
        $Documents_Path = if (![IO.Path]::Exists($User_docs_Path)) {
            $UsrProfile = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
            $mydocsPath = if (![IO.Path]::Exists($UsrProfile)) {
                $commondocs = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::CommonDocuments)
                if (![IO.Path]::Exists($commondocs)) {
                    $all_spec_docs_paths = (0..61 | ForEach-Object { (New-Object –COM "Shell.Application").NameSpace($_).Self.Path }).Where({ $_ -like "*$([IO.Path]::DirectorySeparatorChar)Documents" }).Foreach({$_})
                    if ($all_spec_docs_paths.count -eq 0) {
                        throw [System.InvalidOperationException]::new("Could not find Documents Path")
                    }
                    $all_spec_docs_paths[0]
                }
                $commondocs
            } else {
                [IO.Path]::Combine($UsrProfile, 'Documents')
            }
            $mydocsPath
        } else {
            $User_docs_Path
        }
        return $Documents_Path -as [IO.DirectoryInfo]
    }
    static [string] Get_omp_Json() {
        if ([string]::IsNullOrWhiteSpace("$([string][cliStyler]::ompJson) ".Trim())) {
            return [CliStyler]::get_omp_Json('omp.json', [uri]::new('https://gist.github.com/alainQtec/b106f0e618bb9bbef86611824fc37825'))
        }
        return [CliStyler]::ompJson
    }
    static [string] Get_omp_Json([string]$fileName, [uri]$gisturi) {
        Write-Host "Fetching the latest $fileName" -ForegroundColor Green;
        $gistId = $gisturi.Segments[-1];
        $jsoncontent = Invoke-WebRequest "https://gist.githubusercontent.com/alainQtec/$gistId/raw/$fileName" -Verbose:$false | Select-Object -ExpandProperty Content
        if ([string]::IsNullOrWhiteSpace("$jsoncontent ".Trim())) {
            Throw [System.IO.InvalidDataException]::NEW('FAILED to get valid json string gtom github gist')
        }
        return $jsoncontent
    }
    static [void] Set_omp_Json() {
        [CliStyler]::set_omp_Json('omp.json', [uri]::new('https://gist.github.com/alainQtec/b106f0e618bb9bbef86611824fc37825'))
    }
    static [void] Set_omp_Json([string]$fileName, [uri]$gisturi) {
        if ($null -eq [CliStyler]::OmpJsonFile.FullName) { [CliStyler]::Set_Defaults() }
        [CliStyler]::OmpJsonFile = [IO.FileInfo]::New([IO.Path]::Combine($(Get-Variable OH_MY_POSH_PATH -Scope Global -ValueOnly -ErrorAction Ignore), 'themes', 'p10k_classic.omp.json'))
        if (![CliStyler]::OmpJsonFile.Exists) {
            if (![CliStyler]::OmpJsonFile.Directory.Exists) { [void][CliStyler]::Create_Directory([CliStyler]::OmpJsonFile.Directory.FullName) }
            [CliStyler]::OmpJsonFile = New-Item -ItemType File -Path ([IO.Path]::Combine([CliStyler]::OmpJsonFile.Directory.FullName, [CliStyler]::OmpJsonFile.Name))
            [CliStyler]::get_omp_Json($fileName, $gisturi) | Out-File ([CliStyler]::OmpJsonFile.FullName) -Encoding utf8
        } else {
            Write-Host "Found $([CliStyler]::OmpJsonFile)" -ForegroundColor Green
        }
        [cliStyler]::ompJson = [IO.File]::ReadAllLines([CliStyler]::OmpJsonFile.FullName)
    }
    static [void] Set_Defaults() {
        Write-Verbose "Set defaults ..."
        [CliStyler]::Default_Dependencies = @('Terminal-Icons', 'PSReadline', 'Pester', 'Posh-git', 'PSWinGlue', 'PowerShellForGitHub');
        [CliStyler]::swiglyChar = [char]126;
        [CliStyler]::DirSeparator = [System.IO.Path]::DirectorySeparatorChar;
        [CliStyler]::nl = [Environment]::NewLine;
        # UTF8 Characters from https://www.w3schools.com/charsets/ref_utf_box.asp
        [CliStyler]::dt = [string][char]8230;
        [CliStyler]::b1 = [string][char]91;
        [CliStyler]::b2 = [string][char]93;
        [CliStyler]::Home_Indic = [CliStyler]::swiglyChar + [IO.Path]::DirectorySeparatorChar;
        [CliStyler]::PSVersn = (Get-Variable PSVersionTable).Value;
        [CliStyler]::leadingChar = [char]9581 + [char]9592;
        [CliStyler]::trailngChar = [char]9584 + [char]9588;
        [CliStyler]::LogFile;
        [CliStyler]::colors = @{
            Red                  = [rgb]::new(255, 0, 0)
            DarkRed              = [rgb]::new(128, 0, 0)
            Green                = [rgb]::new(0, 255, 0)
            DarkGreen            = [rgb]::new(0, 128, 0)
            Blue                 = [rgb]::new(0, 0, 255)
            DarkBlue             = [rgb]::new(0, 0, 128)
            White                = [rgb]::new(255, 255, 255)
            Black                = [rgb]::new(0, 0, 0)
            Yellow               = [rgb]::new(255, 255, 0)
            DarkGray             = [rgb]::new(128, 128, 128)
            Gray                 = [rgb]::new(192, 192, 192)
            LightGray            = [rgb]::new(238, 237, 240)
            Cyan                 = [rgb]::new(0, 255, 255)
            DarkCyan             = [rgb]::new(0, 128, 128)
            Magenta              = [rgb]::new(255, 0, 255)
            PSBlue               = [rgb]::new(1, 36, 86)
            AliceBlue            = [rgb]::new(240, 248, 255)
            AntiqueWhite         = [rgb]::new(250, 235, 215)
            AquaMarine           = [rgb]::new(127, 255, 212)
            Azure                = [rgb]::new(240, 255, 255)
            Beige                = [rgb]::new(245, 245, 220)
            Bisque               = [rgb]::new(255, 228, 196)
            BlanchedAlmond       = [rgb]::new(255, 235, 205)
            BlueViolet           = [rgb]::new(138, 43, 226)
            Brown                = [rgb]::new(165, 42, 42)
            Burlywood            = [rgb]::new(222, 184, 135)
            CadetBlue            = [rgb]::new(95, 158, 160)
            Chartreuse           = [rgb]::new(127, 255, 0)
            Chocolate            = [rgb]::new(210, 105, 30)
            Coral                = [rgb]::new(255, 127, 80)
            CornflowerBlue       = [rgb]::new(100, 149, 237)
            CornSilk             = [rgb]::new(255, 248, 220)
            Crimson              = [rgb]::new(220, 20, 60)
            DarkGoldenrod        = [rgb]::new(184, 134, 11)
            DarkKhaki            = [rgb]::new(189, 183, 107)
            DarkMagenta          = [rgb]::new(139, 0, 139)
            DarkOliveGreen       = [rgb]::new(85, 107, 47)
            DarkOrange           = [rgb]::new(255, 140, 0)
            DarkOrchid           = [rgb]::new(153, 50, 204)
            DarkSalmon           = [rgb]::new(233, 150, 122)
            DarkSeaGreen         = [rgb]::new(143, 188, 143)
            DarkSlateBlue        = [rgb]::new(72, 61, 139)
            DarkSlateGray        = [rgb]::new(47, 79, 79)
            DarkTurquoise        = [rgb]::new(0, 206, 209)
            DarkViolet           = [rgb]::new(148, 0, 211)
            DeepPink             = [rgb]::new(255, 20, 147)
            DeepSkyBlue          = [rgb]::new(0, 191, 255)
            DimGray              = [rgb]::new(105, 105, 105)
            DodgerBlue           = [rgb]::new(30, 144, 255)
            FireBrick            = [rgb]::new(178, 34, 34)
            FloralWhite          = [rgb]::new(255, 250, 240)
            ForestGreen          = [rgb]::new(34, 139, 34)
            GainsBoro            = [rgb]::new(220, 220, 220)
            GhostWhite           = [rgb]::new(248, 248, 255)
            Gold                 = [rgb]::new(255, 215, 0)
            Goldenrod            = [rgb]::new(218, 165, 32)
            GreenYellow          = [rgb]::new(173, 255, 47)
            HoneyDew             = [rgb]::new(240, 255, 240)
            HotPink              = [rgb]::new(255, 105, 180)
            IndianRed            = [rgb]::new(205, 92, 92)
            Indigo               = [rgb]::new(75, 0, 130)
            Ivory                = [rgb]::new(255, 255, 240)
            Khaki                = [rgb]::new(240, 230, 140)
            Lavender             = [rgb]::new(230, 230, 250)
            LavenderBlush        = [rgb]::new(255, 240, 245)
            LawnGreen            = [rgb]::new(124, 252, 0)
            LemonChiffon         = [rgb]::new(255, 250, 205)
            LightBlue            = [rgb]::new(173, 216, 230)
            LightCoral           = [rgb]::new(240, 128, 128)
            LightCyan            = [rgb]::new(224, 255, 255)
            LightGoldenrodYellow = [rgb]::new(250, 250, 210)
            LightPink            = [rgb]::new(255, 182, 193)
            LightSalmon          = [rgb]::new(255, 160, 122)
            LightSeaGreen        = [rgb]::new(32, 178, 170)
            LightSkyBlue         = [rgb]::new(135, 206, 250)
            LightSlateGray       = [rgb]::new(119, 136, 153)
            LightSteelBlue       = [rgb]::new(176, 196, 222)
            LightYellow          = [rgb]::new(255, 255, 224)
            LimeGreen            = [rgb]::new(50, 205, 50)
            Linen                = [rgb]::new(250, 240, 230)
            MediumAquaMarine     = [rgb]::new(102, 205, 170)
            MediumOrchid         = [rgb]::new(186, 85, 211)
            MediumPurple         = [rgb]::new(147, 112, 219)
            MediumSeaGreen       = [rgb]::new(60, 179, 113)
            MediumSlateBlue      = [rgb]::new(123, 104, 238)
            MediumSpringGreen    = [rgb]::new(0, 250, 154)
            MediumTurquoise      = [rgb]::new(72, 209, 204)
            MediumVioletRed      = [rgb]::new(199, 21, 133)
            MidnightBlue         = [rgb]::new(25, 25, 112)
            MintCream            = [rgb]::new(245, 255, 250)
            MistyRose            = [rgb]::new(255, 228, 225)
            Moccasin             = [rgb]::new(255, 228, 181)
            NavajoWhite          = [rgb]::new(255, 222, 173)
            OldLace              = [rgb]::new(253, 245, 230)
            Olive                = [rgb]::new(128, 128, 0)
            OliveDrab            = [rgb]::new(107, 142, 35)
            Orange               = [rgb]::new(255, 165, 0)
            OrangeRed            = [rgb]::new(255, 69, 0)
            Orchid               = [rgb]::new(218, 112, 214)
            PaleGoldenrod        = [rgb]::new(238, 232, 170)
            PaleGreen            = [rgb]::new(152, 251, 152)
            PaleTurquoise        = [rgb]::new(175, 238, 238)
            PaleVioletRed        = [rgb]::new(219, 112, 147)
            PapayaWhip           = [rgb]::new(255, 239, 213)
            PeachPuff            = [rgb]::new(255, 218, 185)
            Peru                 = [rgb]::new(205, 133, 63)
            Pink                 = [rgb]::new(255, 192, 203)
            Plum                 = [rgb]::new(221, 160, 221)
            PowderBlue           = [rgb]::new(176, 224, 230)
            Purple               = [rgb]::new(128, 0, 128)
            RosyBrown            = [rgb]::new(188, 143, 143)
            RoyalBlue            = [rgb]::new(65, 105, 225)
            SaddleBrown          = [rgb]::new(139, 69, 19)
            Salmon               = [rgb]::new(250, 128, 114)
            SandyBrown           = [rgb]::new(244, 164, 96)
            SeaGreen             = [rgb]::new(46, 139, 87)
            SeaShell             = [rgb]::new(255, 245, 238)
            Sienna               = [rgb]::new(160, 82, 45)
            SkyBlue              = [rgb]::new(135, 206, 235)
            SlateBlue            = [rgb]::new(106, 90, 205)
            SlateGray            = [rgb]::new(112, 128, 144)
            Snow                 = [rgb]::new(255, 250, 250)
            SpringGreen          = [rgb]::new(0, 255, 127)
            SteelBlue            = [rgb]::new(70, 130, 180)
            Tan                  = [rgb]::new(210, 180, 140)
            Thistle              = [rgb]::new(216, 191, 216)
            Tomato               = [rgb]::new(255, 99, 71)
            Turquoise            = [rgb]::new(64, 224, 208)
            Violet               = [rgb]::new(238, 130, 238)
            Wheat                = [rgb]::new(245, 222, 179)
            WhiteSmoke           = [rgb]::new(245, 245, 245)
            YellowGreen          = [rgb]::new(154, 205, 50)
        }
        # Prevent tsl errors
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        # Set the default launch ascii : alainQtec. but TODO: add a way to load it from a config instead of hardcoding it.
        [CliStyler]::Default_Term_Ascii = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String('bSUBJQElASVuJW0lbiUgACAAIAAgACAAIAAgAG0lASUBJQElbiVtJW4lCgADJW0lASVuJQMlAyUDJSAAIAAgAG0lbiUgACAAAyVtJQElbiUDJW8lcCVuJQoAAyUDJSAAAyUDJQMlbSUBJQElbiVtJW4lASVuJQMlAyUgAAMlAyVuJW0lbSUBJQElbiUBJQElbiUKAAMlcCUBJW8lAyUDJQMlbSUgAAMlfAADJW0lbiVuJQMlIAADJQMlAyUDJXwAbSVuJQMlbSUBJW8lCgADJW0lASVuJQMlAyVwJXAlbyVwJW4lAyUDJQMlAyVwJQElbyUDJQMlcCVuJQMlASUrJXAlASVuJQoAcCVvJSAAcCVvJXAlASVvJQElASVvJW8lbyVwJW8lASUBJW4lcCUBJQElbyUBJQElbyUBJQElbyUKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIABwJW8lCgAiAFEAdQBpAGMAawAgAHAAcgBvAGQAdQBjAHQAaQB2AGUAIAB0AGUAYwBoACIA'));
        [CliStyler]::WINDOWS_TERMINAL_JSON_PATH = [IO.Path]::Combine($env:LocalAppdata, 'Packages', 'Microsoft.WindowsTerminal_8wekyb3d8bbwe', 'LocalState', 'settings.json');
        # Initialize or Reload $PROFILE and the core functions necessary for displaying your custom prompt.
        $p = [PSObject]::new(); Get-Variable PROFILE -ValueOnly | Get-Member -Type NoteProperty | ForEach-Object {
            $p | Add-Member -Name $_.Name -MemberType NoteProperty -Value ($_.Definition.split('=')[1] -as [IO.FileInfo])
        }
        [CliStyler]::PROFILE = $p
        # Set Host UI DEFAULS
        [CliStyler]::WindowTitle = [CliStyler]::GetWindowTitle()
        if (!(Get-Variable OH_MY_POSH_PATH -ValueOnly -ErrorAction Ignore)) {
            New-Variable -Name OH_MY_POSH_PATH -Scope Global -Option Constant -Value ([IO.Path]::Combine($env:LOCALAPPDATA, 'Programs', 'oh-my-posh')) -Force
        }
        [CliStyler]::HostOS = $(if ($(Get-Variable PSVersionTable -Value).PSVersion.Major -le 5 -or $(Get-Variable IsWindows -Value)) { "Windows" }elseif ($(Get-Variable IsLinux -Value)) { "Linux" }elseif ($(Get-Variable IsMacOS -Value)) { "MacOS" }else { "UNKNOWN" });
        [CliStyler]::OmpJsonFile = [IO.FileInfo]::New([IO.Path]::Combine($(Get-Variable OH_MY_POSH_PATH -Scope Global -ValueOnly), 'themes', 'p10k_classic.omp.json'))
    }
    static [void] Add_OMP_To_Profile() {
        [CliStyler]::Add_OMP_To_Profile([CliStyler]::GetPsProfile())
    }
    static [void] Add_OMP_To_Profile([IO.FileInfo]$File) {
        Write-Host "Checking for OH_MY_POSH in Profile ... " -ForegroundColor Yellow
        if ([string]::IsNullOrWhiteSpace("$([string][cliStyler]::ompJson) ".Trim())) {
            try {
                [CliStyler]::ompJson = [CliStyler]::get_omp_Json()
            } catch [System.Net.Http.HttpRequestException], [System.Net.Sockets.SocketException] {
                throw [System.Exception]::New('gist.githubusercontent.com:443  Please check your internet')
            }
        }
        if (![CliStyler]::OmpJsonFile.Exists) {
            Set-Content -Path ([CliStyler]::OmpJsonFile.FullName) -Value ([CliStyler]::ompJson) -Force
        }
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine('# Enable Oh My Posh Theme Engine')
        [void]$sb.AppendLine('oh-my-posh --init --shell pwsh --config ~/AppData/Local/Programs/oh-my-posh/themes/p10k_classic.omp.json | Invoke-Expression')
        if (!(Select-String -Path $File.FullName -Pattern "oh-my-posh" -SimpleMatch -Quiet)) {
            # TODO: #3 Move configuration to directory instead of manipulating original profile file
            Write-Host "Add OH_MY_POSH to Profile ... " -NoNewline -ForegroundColor DarkYellow
            Add-Content -Path $File.FullName -Value $sb.ToString()
            Write-Host "Done." -ForegroundColor Yellow
        } else {
            Write-Host "OH_MY_POSH is added to Profile." -ForegroundColor Green
        }
    }
    static [void] Set_TerminalUI() {
        (Get-Variable -Name Host -ValueOnly).UI.RawUI.WindowTitle = [CliStyler]::WindowTitle
        (Get-Variable -Name Host -ValueOnly).UI.RawUI.ForegroundColor = "White"
        (Get-Variable -Name Host -ValueOnly).PrivateData.ErrorForegroundColor = "DarkGray"
    }
    static [string] GetWindowTitle() {
        $Title = ([CliStyler]::GetCurrentProces().Path -as [IO.FileInfo]).BaseName
        $user = [Security.Principal.WindowsIdentity]::GetCurrent()
        [void][Security.Principal.WindowsIdentity]::GetAnonymous()
        $ob = [Security.Principal.WindowsPrincipal]::new($user)
        $UserRole = [PSCustomObject]@{
            'HasUserPriv'  = [bool]$ob.IsInRole([Security.Principal.WindowsBuiltinRole]::User)
            'HasAdminPriv' = [bool]$ob.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
            'HasSysPriv'   = [bool]$ob.IsInRole([Security.Principal.WindowsBuiltinRole]::SystemOperator)
            'IsPowerUser'  = [bool]$ob.IsInRole([Security.Principal.WindowsBuiltinRole]::PowerUser)
            'IsGuest'      = [bool]$ob.IsInRole([Security.Principal.WindowsBuiltinRole]::Guest)
        }
        $UserRole.PSObject.TypeNames.Insert(0, 'Security.User.RoleProperties')
        if ($UserRole.IsPowerUser) {
            $Title += $([CliStyler]::b1 + 'E' + [CliStyler]::b2) # IsElevated
        }
        if ($UserRole.HasSysPriv) {
            $Title += $([CliStyler]::b1 + 'S' + [CliStyler]::b2) # IsSYSTEM
        }
        # Admin indicator not neded, since Windows11 build 22557.1
        if ($UserRole.HasAdminPriv) { $Title += ' (Admin)' }
        if ($UserRole.HasUserPriv -and !($UserRole.HasAdminPriv)) { $Title += ' (User)' }
        return $Title
    }
    static [void] Write_Term_Ascii() {
        if ($null -eq ([CliStyler]::PSVersn)) { [CliStyler]::Set_Defaults() }
        [double]$MinVern = 5.1
        [double]$CrVersn = ([CliStyler]::PSVersn | Select-Object @{l = 'vern'; e = { "{0}.{1}" -f $_.PSVersion.Major, $_.PSVersion.Minor } }).vern
        if ($null -ne ([CliStyler]::colors)) {
            Write-Host ''; # i.e: Writing to the console in 24-bit colors can only work with PowerShell versions lower than '5.1'
            if ($CrVersn -gt $MinVern) {
                # Write-ColorOutput -ForegroundColor DarkCyan $([CliStyler]::Default_Term_Ascii)
                Write-Host "$([CliStyler]::Default_Term_Ascii)" -ForegroundColor Green
            } else {
                [CliStyler]::Write_RGB([CliStyler]::Default_Term_Ascii, 'SlateBlue')
            }
            Write-Host ''
        }
    }
    static [void] Resolve_module([string[]]$names) {
        if (!$(Get-Variable Resolve_Module_fn -ValueOnly -Scope global -ErrorAction Ignore)) {
            # Write-Verbose "Fetching the Resolve_Module script (One-time/Session only)";
            Set-Variable -Name Resolve_Module_fn -Scope global -Option ReadOnly -Value ([scriptblock]::Create($((Invoke-RestMethod -Method Get https://api.github.com/gists/7629f35f93ae89a525204bfd9931b366).files.'Resolve-Module.ps1'.content)))
        }
        . $(Get-Variable Resolve_Module_fn -ValueOnly -Scope global)
        Resolve-module -Name $Names
    }
    static [void] Write_RGB([string]$Text, $ForegroundColor) {
        [CliStyler]::Write_RGB($Text, $ForegroundColor, $true)
    }
    static [void] Write_RGB([string]$Text, [string]$ForegroundColor, [bool]$NoNewLine) {
        [CliStyler]::Write_RGB($Text, $ForegroundColor, 'Black')
    }
    static [void] Write_RGB([string]$Text, [string]$ForegroundColor, [string]$BackgroundColor) {
        [CliStyler]::Write_RGB($Text, $ForegroundColor, $BackgroundColor, $true)
    }
    static [void] Write_RGB([string]$Text, [string]$ForegroundColor, [string]$BackgroundColor, [bool]$NoNewLine) {
        $escape = [char]27 + '['; $24bitcolors = [CliStyler]::colors
        $resetAttributes = "$($escape)0m";
        $psBuild = [CliStyler]::PSVersn.PSVersion.Build
        [double]$VersionNum = $([CliStyler]::PSVersn.PSVersion.ToString().split('.')[0..1] -join '.')
        if ([bool]$($VersionNum -le [double]5.1)) {
            [rgb]$Background = [rgb]::new(1, 36, 86);
            [rgb]$Foreground = [rgb]::new(255, 255, 255);
            $f = "$($escape)38;2;$($Foreground.Red);$($Foreground.Green);$($Foreground.Blue)m"
            $b = "$($escape)48;2;$($Background.Red);$($Background.Green);$($Background.Blue)m"
            $f = "$($escape)38;2;$($24bitcolors.$ForegroundColor.Red);$($24bitcolors.$ForegroundColor.Green);$($24bitcolors.$ForegroundColor.Blue)m"
            $b = "$($escape)48;2;$($24bitcolors.$BackgroundColor.Red);$($24bitcolors.$BackgroundColor.Green);$($24bitcolors.$BackgroundColor.Blue)m"
            if ([bool](Get-Command Write-Info -ErrorAction SilentlyContinue)) {
                Write-Info ($f + $b + $Text + $resetAttributes) -NoNewline:$NoNewLine
            } else {
                Write-Host ($f + $b + $Text + $resetAttributes) -NoNewline:$NoNewLine
            }
        } else {
            throw [System.Management.Automation.RuntimeException]::new("Writing to the console in 24-bit colors can only work with PowerShell versions lower than '5.1 build 14931' or above.`nBut yours is '$VersionNum' build '$psBuild'")
        }
    }
    static [PsObject] GetCurrentProces() {
        $chost = Get-Variable Host -ValueOnly; $process = Get-Process -Id $(Get-Variable pid -ValueOnly) | Get-Item
        $versionTable = Get-Variable PSVersionTable -ValueOnly
        return [PsObject]@{
            Path           = $process.Fullname
            FileVersion    = $process.VersionInfo.FileVersion
            PSVersion      = $versionTable.PSVersion.ToString()
            ProductVersion = $process.VersionInfo.ProductVersion
            Edition        = $versionTable.PSEdition
            Host           = $chost.name
            Culture        = $chost.CurrentCulture
            Platform       = $versionTable.platform
        }
    }
    static [void] SetConsoleTitle([string]$Title) {
        $chost = Get-Variable Host -ValueOnly
        $width = ($chost.UI.RawUI.MaxWindowSize.Width * 2)
        if ($chost.Name -ne "ConsoleHost") {
            Write-Warning "This command must be run from a PowerShell console session. Not the PowerShell ISE or Visual Studio Code or similar environments."
        } elseif (($title.length -ge $width)) {
            Write-Warning "Your title is too long. It needs to be less than $width to fit your current console."
        } else {
            $chost.ui.RawUI.WindowTitle = $Title
        }
    }
    static hidden [void] Create_Prompt_Function() {
        # Creates the Custom prompt function & if nothing goes wrong then shows a welcome Ascii Art
        [CliStyler]::CurrExitCode = $true
        try {
            # Creates the prompt function
            $null = New-Item -Path function:prompt -Value $([scriptblock]::Create({
                        if (![CliStyler]::IsInitialised()) {
                            Write-Verbose "[CliStyler] Initializing, Please wait ..."
                            [CliStyler]::Initialize()
                        }
                        try {
                            if ($NestedPromptLevel -ge 1) {
                                [CliStyler]::trailngChar += [string][char]9588
                                # [CliStyler]::leadingChar += [string][char]9592
                            }
                            # Grab th current loaction
                            $location = "$((Get-Variable ExecutionContext).Value.SessionState.Path.CurrentLocation.Path)";
                            $shortLoc = [CliStyler]::Get_Short_Path($location, [CliStyler]::dt)
                            $IsGitRepo = if ([bool]$(try { Test-Path .git -ErrorAction silentlyContinue }catch { $false })) { $true }else { $false }
                            $(Get-Variable Host).Value.UI.Write(([CliStyler]::leadingChar))
                            Write-Host -NoNewline $([CliStyler]::b1);
                            Write-Host $([Environment]::UserName).ToLower() -NoNewline -ForegroundColor Magenta;
                            Write-Host $([string][char]64) -NoNewline -ForegroundColor Gray;
                            Write-Host $([System.Net.Dns]::GetHostName().ToLower()) -NoNewline -ForegroundColor DarkYellow;
                            Write-Host -NoNewline "$([CliStyler]::b2) ";
                            if ($location -eq "$env:UserProfile") {
                                Write-Host $([CliStyler]::Home_Indic) -NoNewline -ForegroundColor DarkCyan;
                            } elseif ($location.Contains("$env:UserProfile")) {
                                $location = $($location.replace("$env:UserProfile", "$([CliStyler]::swiglyChar)"));
                                if ($location.Length -gt 25) {
                                    $location = [CliStyler]::Get_Short_Path($location, [CliStyler]::dt)
                                }
                                Write-Host $location -NoNewline -ForegroundColor DarkCyan
                            } else {
                                Write-Host $shortLoc -NoNewline -ForegroundColor DarkCyan
                            }
                            # add a newline
                            if ($IsGitRepo) {
                                Write-Host $((Write-VcsStatus) + "`n")
                            } else {
                                Write-Host "`n"
                            }
                        } catch {
                            #Do this if a terminating exception happens#
                            # if ($_.Exception.WasThrownFromThrowStatement) {
                            #     [System.Management.Automation.ErrorRecord]$_ | Write-Log $([CliStyler]::LogFile.FullName)
                            # }
                            $(Get-Variable Host).Value.UI.WriteErrorLine("[PromptError] [$($_.FullyQualifiedErrorId)] $($_.Exception.Message) # see the Log File : $([CliStyler]::LogFile.FullName) $([CliStyler]::nl)")
                        } finally {
                            #Do this after the try block regardless of whether an exception occurred or not
                            Set-Variable -Name LASTEXITCODE -Scope Global -Value $([CliStyler]::realLASTEXITCODE)
                        }
                        Write-Host ([CliStyler]::trailngChar)
                    }
                )
            ) -Force
            [CliStyler]::CurrExitCode = [CliStyler]::CurrExitCode -and $?
        } catch {
            [CliStyler]::CurrExitCode = $false
            # Write-Log -ErrorRecord $_
        } finally {
            Set-Variable -Name IsPromptInitialised -Value $([CliStyler]::CurrExitCode) -Visibility Public -Scope Global;
        }
    }
    static hidden [string] Get_Short_Path() {
        $curr_location = $(Get-Variable ExecutionContext).Value.SessionState.Path.CurrentLocation.Path
        return [clistyler]::get_short_Path($curr_location, 2, 2, [CliStyler]::DirSeparator, [char]8230)
    }
    static hidden [string] Get_Short_Path([string]$Path) {
        return [clistyler]::get_short_Path($Path, 2, 2, [CliStyler]::DirSeparator, [char]8230)
    }
    static hidden [string] Get_Short_Path([string]$Path, [char]$TruncateChar) {
        return [clistyler]::get_short_Path($Path, 2, 2, [CliStyler]::DirSeparator, $TruncateChar)
    }
    static hidden [string] Get_Short_Path([string]$Path, [int]$KeepBefore, [int]$KeepAfter, [Char]$Separator, [char]$TruncateChar) {
        # [int]$KeepBefore, # Number of parts to keep before truncating. Default value is 2.
        # [int]$KeepAfter, # Number of parts to keep after truncating. Default value is 1.
        # [Char]$Separator, # Path separator character.
        $Path = (Resolve-Path -Path $Path).Path;
        $Path = $Path.Replace(([System.IO.Path]::DirectorySeparatorChar), [CliStyler]::DirSeparator)
        [ValidateRange(1, [int32]::MaxValue)][int]$KeepAfter = $KeepAfter
        $Separator = $Separator.ToString(); $TruncateChar = $TruncateChar.ToString()
        $splitPath = $Path.Split($Separator, [System.StringSplitOptions]::RemoveEmptyEntries)
        if ($splitPath.Count -gt ($KeepBefore + $KeepAfter)) {
            $outPath = [string]::Empty
            for ($i = 0; $i -lt $KeepBefore; $i++) {
                $outPath += $splitPath[$i] + $Separator
            }
            $outPath += "$($TruncateChar)$($Separator)"
            for ($i = ($splitPath.Count - $KeepAfter); $i -lt $splitPath.Count; $i++) {
                if ($i -eq ($splitPath.Count - 1)) {
                    $outPath += $splitPath[$i]
                } else {
                    $outPath += $splitPath[$i] + $Separator
                }
            }
        } else {
            $outPath = $splitPath -join $Separator
            if ($splitPath.Count -eq 1) {
                $outPath += $Separator
            }
        }
        return $outPath
    }
    static hidden [System.IO.DirectoryInfo] Create_Directory([string]$Path) {
        $nF = @(); $d = [System.IO.DirectoryInfo]::New((Get-Variable ExecutionContext).Value.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path))
        Write-Verbose "Creating Directory '$($d.FullName)' ..."
        while (!$d.Exists) { $nF += $d; $d = $d.Parent }
        [Array]::Reverse($nF); $nF | ForEach-Object { $_.Create() }
        return $d
    }
}

#endregion Classes

$Private = Get-ChildItem ([IO.Path]::Combine($PSScriptRoot, 'Private')) -Filter "*.ps1" -ErrorAction SilentlyContinue
$Public = Get-ChildItem ([IO.Path]::Combine($PSScriptRoot, 'Public')) -Filter "*.ps1" -ErrorAction SilentlyContinue
# Load dependencies
$PrivateModules = [string[]](Get-ChildItem ([IO.Path]::Combine($PSScriptRoot, 'Private')) -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer } | Select-Object -ExpandProperty FullName)
if ($PrivateModules.Count -gt 0) {
    foreach ($Module in $PrivateModules) {
        Try {
            Import-Module $Module -ErrorAction Stop
        } Catch {
            Write-Error "Failed to import module $Module : $_"
        }
    }
}
# Dot source the files
$fns = ($Public, $Private).fullname -as [IO.FileInfo[]]
foreach ($fn in $fns) {
    Try {
        . $fn.FullName
    } Catch {
        Write-Warning "Failed to import function $($fn.BaseName): $_"
        $host.UI.WriteErrorLine($_)
    }
}
# Export Public Functions
$Public | ForEach-Object { Export-ModuleMember -Function $_.BaseName }
#Export-ModuleMember -Alias @('<Aliases>')