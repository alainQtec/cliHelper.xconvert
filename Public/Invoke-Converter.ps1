function Invoke-Converter {
  # .SYNOPSIS
  #   Creates a new [xconvert] object
  # .DESCRIPTION
  #   Creates a custom Converter object.
  # .EXAMPLE
  #  $enc_Pass = "HelloWorld" | xconvert -m ToBase32String, ToObfuscated, ToSecurestring
  #  $txt_Pass = $enc_Pass | xconvert -m ToString, FromObfuscated, FromBase32String, ToInt32, Tostring
  #  $txt_Pass | Should -Be "HelloWorld"
  #  Thats chaining methods
  [CmdletBinding()]
  [Alias('xconvert')]
  [OutputType([xconvert], [object], [object[]])]
  param (
    [Parameter(Position = 0, ValueFromPipeline = $true)]
    [Alias('i')][ValidateNotNullOrEmpty()]
    $object,

    [Parameter(Position = 1)]
    [Alias('m')][ValidateNotNullOrEmpty()]
    [string[]]$Method
  )
  begin {
    $c = [xconvert]::new()
  }
  process {
    if ($object) {
      $r = $object
      $Method.ForEach({
          $r = $c::$_($r)
        }
      )
    } else {
      $r = $c
    }
  }
  end {
    return $r
  }
}