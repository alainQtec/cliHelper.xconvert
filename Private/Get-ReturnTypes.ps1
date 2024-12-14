function Get-ReturnTypes {
  [CmdletBinding()]
  param ()
  end {
    return [xconvert]::Methods.ReturnType | Sort-Object -Unique Name
  }
}