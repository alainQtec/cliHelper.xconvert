function Get-Methods {
  [CmdletBinding()]
  [OutputType([System.Reflection.MethodInfo[]])]
  param ()
  end {
    return [xconvert].GetMethods().Where({ $_.IsStatic -and !$_.IsHideBySig })
  }
}