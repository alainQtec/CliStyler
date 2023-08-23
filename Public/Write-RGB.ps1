#!/usr/bin/env pwsh
<#PSScriptInfo
.VERSION 1.1
.GUID b60fe8c4-46bb-4b5a-8279-4a0006f82b79
.AUTHOR Alain Herve
.LICENSEURI https://github.com/alainQtec/CliStyler/blob/main/LICENSE
.TAGS Powershell Profile
#>
Write-RGB {
    <#
    .SYNOPSIS
        Write to the console in 24-bit colors!
    .DESCRIPTION
        This function lets you write to the console using 24-bit color depth.
        You can specify colors using its RGB values.
    .EXAMPLE
        Write-RGB 'Hello World'
        Will write the text using the default colors.
    .EXAMPLE
        Write-RGB 'Hello world' -ForegroundColor Pink
        Will write the text in a pink foreground color.
    .EXAMPLE
        Write-RGB 'Hello world' -ForegroundColor violet -BackgroundColor Olive
        Will write the text in a pink foreground color and an olive background color.
    .EXAMPLE
        Write-RGB $Default_Term_Ascii -ForegroundColor SlateBlue -BackgroundColor black ; $Host.UI.WriteLine([Environment]::NewLine)
    .LINK
        Online version : https://github.com/alainQtec/CliStyler/blob/main/src/scripts/Console/Writers/Write-RGB.ps1
    #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    param (
        # The text you want to write.
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = '__AllParameterSets')]
        [ValidateNotNullOrEmpty()]
        [string]$Text,

        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'Name')]
        $ForegroundColor,

        # The foreground color of the text. Defaults to white.
        [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'Code')]
        [rgb]$Foreground = [rgb]::new(255, 255, 255),

        [Parameter(Mandatory = $true, Position = 2, ParameterSetName = 'Name')]
        $BackgroundColor,

        # The background color of the text. Defaults to PowerShell Blue.
        [Parameter(Mandatory = $false, Position = 2, ParameterSetName = 'Code')]
        [rgb]$Background = [rgb]::new(1, 36, 86),

        # No newline after the text.
        [switch]$NoNewLine
    )
    Begin {
        $escape = [char]27 + '['
        $resetAttributes = "$($escape)0m"
        $fxn = ('[' + $MyInvocation.MyCommand.Name + ']')
    }
    Process {
        $psBuild = $PSVersionTable.PSVersion.Build
        [double]$VersionNum = $($PSVersionTable.PSVersion.ToString().split('.')[0..1] -join '.')
        if ([bool]$($VersionNum -le [double]5.1)) {
            if ($PsCmdlet.ParameterSetName -eq 'Name') {
                $f = "$($escape)38;2;$($colors.$ForegroundColor.Red);$($colors.$ForegroundColor.Green);$($colors.$ForegroundColor.Blue)m"
                $b = "$($escape)48;2;$($colors.$BackgroundColor.Red);$($colors.$BackgroundColor.Green);$($colors.$BackgroundColor.Blue)m"
            } elseif ($PsCmdlet.ParameterSetName -eq 'Code') {
                $f = "$($escape)38;2;$($Foreground.Red);$($Foreground.Green);$($Foreground.Blue)m"
                $b = "$($escape)48;2;$($Background.Red);$($Background.Green);$($Background.Blue)m"
            }
            if ([bool](Get-Command  Write-Info -ErrorAction SilentlyContinue)) {
                Write-Info ($f + $b + $Text + $resetAttributes) -NoNewline:$NoNewLine
            } else {
                Write-Host ($f + $b + $Text + $resetAttributes) -NoNewline:$NoNewLine
            }
        } else {
            throw "$fxn This function can only work with PowerShell versions lower than '5.1 build 14931' or above.`nBut yours is '$VersionNum' build '$psBuild'"
        }
    }
}