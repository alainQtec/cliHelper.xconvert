$script:ModuleName = "cliHelper.xconvert"
$script:ProjectRoot = switch ((Get-Item $PSScriptRoot).BaseName) {
  $ModuleName { $PSScriptRoot; break }
  "Tests" { [IO.Path]::GetDirectoryName($PSScriptRoot); break }
  Default {
    throw "can't resolve project root"
  }
}
Write-Host "[+] ProjectRoot: $ProjectRoot" -f Green
$script:ModulePath = [IO.Path]::Combine($ProjectRoot, "BuildOutput", $ModuleName) | Get-Item
$script:ProjectName = [Environment]::GetEnvironmentVariable($env:RUN_ID + 'ProjectName')
$script:moduleVersion = ((Get-ChildItem $ModulePath).Where({ $_.Name -as 'version' -is 'version' }).Name -as 'version[]' | Sort-Object -Descending)[0].ToString()
$script:ModuleInformation = Import-Module -Name "$ModulePath" -PassThru -Verbose:$false
Write-Host "[+] Imported module:" -ForegroundColor Green
$ModuleInformation | Format-List | Out-String | Write-Host -f Green

# Get the functions present in the Manifest
$ExportedFunctions = $ModuleInformation.ExportedFunctions.Values.Name

# Get the functions present in the Public folder
$PS1Functions = Get-ChildItem -Path "$ModulePath/$moduleVersion/Public/*.ps1"

Describe "Module tests for $ProjectName" -Tag 'Module' {
  Context " Manifest file" {
    It " Should contain RootModule" {
      [string]::IsNullOrWhiteSpace($ModuleInformation.RootModule) | Should -Be $false
    }

    It " Should contain ModuleVersion" {
      [string]::IsNullOrEmpty($ModuleInformation.Version.ToString()) | Should -Be $false
    }

    It " Should contain GUID" {
      $ModuleInformation.Guid | Should -Not -BeNullOrEmpty
    }

    It " Should contain Author" {
      $ModuleInformation.Author | Should -Not -BeNullOrEmpty
    }

    It " Should contain Description" {
      $ModuleInformation.Description | Should -Not -BeNullOrEmpty
    }

    It " Compare the count of Function Exported and the PS1 files found" {
      $status = $PS1Functions.Count -eq $ExportedFunctions.Count
      $status | Should -Be $true
    }

    It " Compare the missing function" {
      If ($ExportedFunctions.count -ne $PS1Functions.count) {
        $Compare = Compare-Object -ReferenceObject $ExportedFunctions -DifferenceObject $PS1Functions.Basename
        $Compare.InputObject -Join ',' | Should -BeNullOrEmpty
      }
    }
  }
  Context " Powershell syntax" {
    $_scripts = $(Get-Item -Path "$ModulePath/$moduleVersion").GetFiles(
      "*", [System.IO.SearchOption]::AllDirectories
    ).Where({ $_.Extension -in ('.ps1', '.psd1', '.psm1') })
    $testCase = $_scripts | ForEach-Object { @{ file = $_ } }
    It "Script <file> Should have valid Powershell sysntax" -TestCases $testCase {
      param($file) $contents = Get-Content -Path $file.fullname -ErrorAction Stop
      $errors = $null; [void][System.Management.Automation.PSParser]::Tokenize($contents, [ref]$errors)
      $errors.Count | Should -Be 0
    }
  }
  Context " Private and public folders" {
    It ' Should have no duplicate functions' {
      $Publc_Dir = Get-Item -Path ([IO.Path]::Combine($ModulePath, $moduleVersion, 'Public'))
      $Privt_Dir = Get-Item -Path ([IO.Path]::Combine($ModulePath, $moduleVersion, 'Private'))
      $funcNames = @(); Test-Path -Path ([string[]]($Publc_Dir, $Privt_Dir)) -PathType Container -ErrorAction Stop
      $Publc_Dir.GetFiles("*", [System.IO.SearchOption]::AllDirectories) + $Privt_Dir.GetFiles("*", [System.IO.SearchOption]::AllDirectories) | Where-Object { $_.Extension -eq '.ps1' } | ForEach-Object { $funcNames += $_.BaseName }
      $($funcNames | Group-Object | Where-Object { $_.Count -gt 1 }).Count | Should -BeLessThan 1
    }
  }
}
Get-Module -Name $ModuleName | Remove-Module