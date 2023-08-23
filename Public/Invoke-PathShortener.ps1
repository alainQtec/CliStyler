#!/usr/bin/env pwsh
<#PSScriptInfo
.VERSION 1.1
.GUID 7efed23e-36e5-4e3b-bffe-f0657ea8e9ee
.AUTHOR Alain Herve
.LICENSEURI https://github.com/alainQtec/CliStyler/blob/main/LICENSE
.TAGS Powershell Profile
#>
Invoke-PathShortener {
    [CmdletBinding()]
    param (
        # Path to shorten.
        [Parameter(Position = 0, Mandatory = $false , ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullorEmpty()]
        [string]$Path = $ExecutionContext.SessionState.Path.CurrentLocation.Path,

        # Number of parts to keep before truncating. Default value is 2.
        [Parameter()]
        [ValidateRange(0, [int32]::MaxValue)]
        [int]$KeepBefore = 2,

        # Number of parts to keep after truncating. Default value is 1.
        [Parameter()]
        [ValidateRange(1, [int32]::MaxValue)]
        [int]$KeepAfter = 1,

        # Path separator character.
        [Parameter()]
        [string]$Separator = [System.IO.Path]::DirectorySeparatorChar,

        # Truncate character(s). Default is '...'
        # Use '[char]8230' to use the horizontal ellipsis character instead.
        [Parameter()]
        [string]$TruncateChar = [char]8230
    )
    process {
        $Path = (Resolve-Path -Path $Path).Path
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
    }
    End {
        return $outPath
    }
}