function Install-NerdFont {
    <#
    .SYNOPSIS
        Install patched nerd fonts (Hack)
    .DESCRIPTION
        Installs all the provided fonts by default.  The FontName
        parameter can be used to pick a subset of fonts to install.
        ... 👨‍💻✨
        More at https://github.com/ryanoasis/nerd-fonts or https://nerdfonts.com/
    .EXAMPLE
        Install-nerdfont
        Installs all the fonts located in the Git repository.
    .EXAMPLE
        Install-nerdfont FiraCode, Hack
        Installs all the FiraCode and Hack fonts.
    .EXAMPLE
        Install-nerdfont DejaVuSansMono -WhatIf
        Shows which fonts would be installed without actually installing the fonts.
        Remove the "-WhatIf" to install the fonts.
    .LINK
        https://github.com/alainQtec/.files/blob/main/Functions/Installers/Install-Nerdfont.ps1
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param ()

    dynamicparam {
        $Attributes = [Collections.ObjectModel.Collection[Attribute]]::new()
        $ParamAttribute = [Parameter]::new()
        $ParamAttribute.Position = 0
        $ParamAttribute.ParameterSetName = '__AllParameterSets'
        $Attributes.Add($ParamAttribute)

        [string[]]$FontNames = Join-Path $PSScriptRoot patched-fonts | Get-ChildItem -Directory -Name
        $Attributes.Add([ValidateSet]::new(($FontNames)))

        $Parameter = [Management.Automation.RuntimeDefinedParameter]::new('FontName', [string[]], $Attributes)
        $RuntimeParams = [Management.Automation.RuntimeDefinedParameterDictionary]::new()
        $RuntimeParams.Add('FontName', $Parameter)

        return $RuntimeParams
    }

    process {
        $PsCmdlet.MyInvocation.BoundParameters.GetEnumerator() | ForEach-Object { New-Variable -Name $_.Key -Value $_.Value -ea 'SilentlyContinue' }
        $fxn = ('[' + $MyInvocation.MyCommand.Name + ']')
        Write-Invocation $MyInvocation
        # Install NerdFonts
        # $(Invoke-WebRequest -Uri "https://github.com/matthewjberger/scoop-nerd-fonts/tree/master/bucket" -UseBasicParsing).Links.href | Where-Object { $_ -like "*FiraCode*" } | ForEach-Object { 'https://github.com' + $_ }
        # ($(New-Object system.net.webclient).downloadstring("https://github.com/matthewjberger/scoop-nerd-fonts/tree/master/bucket") -split "<a\s+") | ForEach-Object { [void]($_ -match "^href=[`'`"]([^`'`">\s]*)"); $matches[1] }
        # Invoke-RestMethod
        $FontName = $PSBoundParameters.FontName
        if (-not $FontName) { $FontName = '*' }
        $fontFiles = [Collections.Generic.List[System.IO.FileInfo]]::new()
        Join-Path $PSScriptRoot patched-fonts | Push-Location
        foreach ($aFontName in $FontName) {
            Get-ChildItem $aFontName -Filter "*.ttf" -Recurse | ForEach-Object { $fontFiles.Add($_) }
            Get-ChildItem $aFontName -Filter "*.otf" -Recurse | ForEach-Object { $fontFiles.Add($_) }
        }
        Pop-Location
        $fonts = $null
        foreach ($fontFile in $fontFiles) {
            if ($PSCmdlet.ShouldProcess($fontFile.Name, "Install Font")) {
                if (!$fonts) {
                    $shellApp = New-Object -ComObject shell.application
                    $fonts = $shellApp.NameSpace(0x14)
                }
                $fonts.CopyHere($fontFile.FullName)
                [clistyler]::FontMan::InstallFont($fontFile.FullName)
            }
        }
    }

    end {
        Out-Verbose $fxn "✅ Done."
    }
}