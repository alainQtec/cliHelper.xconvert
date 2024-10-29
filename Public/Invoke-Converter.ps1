function Invoke-Converter {
  # .SYNOPSIS
  #   Creates a new [xconvert] object
  # .DESCRIPTION
  #   Creates a custom Converter object.
  # .EXAMPLE
  #  $der_Pass = "HelloWorld" | Xconvert ToBase32String, ToObfuscated, ToSecurestring
  #  Thats chaining methods
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = '')]
  [CmdletBinding()]
  [Alias('Xconvert', 'New-Converter')]
  [OutputType([xconvert], [object], [object[]])]
  param (
    [Parameter(Position = 0, ValueFromPipeline = $true)]
    [string[]]$InputObject,

    [Parameter(Position = 1)]
    [string[]]$MethodName,

    [Parameter(Position = 2, ValueFromRemainingArguments = $true)]
    [Object[]]$Arguments
  )

  begin {
    $result = [xconvert]::new()
  }
  process {}
  end {
    return $result
  }
}