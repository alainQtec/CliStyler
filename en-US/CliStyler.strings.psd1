@{
    ModuleName    = 'CliStyler'
    ModuleVersion = [version]::new(0, 1, 0)
    ReleaseNotes  = @"
# Changelog`n`n

* Added funtion Initialize-PsProfile used to Load/reload PowerShell $Profile
* Added function Write-ColorOutput

`n`n***`n`n# Install guide:`n`n
1. [Click here](https://github.com/alainQtec/CliStyler/releases/download/v<versionToDeploy>/CliStyler.zip) to download the *CliStyler.zip* file attached to the release.
2. **If on Windows**: Right-click the downloaded zip, select Properties, then unblock the file.
    > _This is to prevent having to unblock each file individually after unzipping._
3. Unzip the archive.
4. (Optional) Place the module folder somewhere in your ``PSModulePath``.
    > _You can view the paths listed by running the environment variable ```$Env:PSModulePath``_
5. Import the module, using the full path to the PSD1 file in place of ``CliStyler`` if the unzipped module folder is not in your ``PSModulePath``:
    ``````powershell
    # In Env:PSModulePath
    Import-Module CliStyler

    # Otherwise, provide the path to the manifest:
    Import-Module -Path Path\to\CliStyler\<versionToDeploy>\CliStyler.psd1
    ``````
"@
}