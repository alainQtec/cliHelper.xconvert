@{
  ModuleName    = 'cliHelper.xconvert'
  ModuleVersion = [System.Management.Automation.SemanticVersion]::new(0, 1, 1)
  ReleaseNotes  = @"
# Changelog`n`n

- fixed LocalisedData not being found
- more in utility class

`n`n***`n`n## Manual install guide`n`n
1. [Click here](https://github.com/alainQtec/cliHelper.xconvert/releases/download/v<versionToDeploy>/cliHelper.xconvert.zip) to download the *PsImport.zip* file attached to the release.
2. **If on Windows**: Right-click the downloaded zip, select Properties, then unblock the file.
    > _This is to prevent having to unblock each file individually after unzipping._
3. Unzip the archive.
4. (Optional) Place the module folder somewhere in your ``PSModulePath``.
    > _You can view the paths listed by running the environment variable ```$Env:PSModulePath``_
5. Import the module, using the full path to the PSD1 file in place of ``cliHelper.xconvert`` if the unzipped module folder is not in your ``PSModulePath``:
    ``````powershell
    # In Env:PSModulePath
    Import-Module cliHelper.xconvert

    # Otherwise, provide the path to the manifest:
    Import-Module -Path Path\to\cliHelper.xconvert\<versionToDeploy>\cliHelper.xconvert.psd1
    ``````
"@
}