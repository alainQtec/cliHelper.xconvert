function New-Converter {
  # .SYNOPSIS
  #   Creates a new [xconvert] object
  # .DESCRIPTION
  #   Creates a custom Converter object.
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = '')]
  [CmdletBinding()]
  [Alias('xconvert')]
  [OutputType([xconvert])]
  param ()

  end {
    return [xconvert]::new()
  }
}