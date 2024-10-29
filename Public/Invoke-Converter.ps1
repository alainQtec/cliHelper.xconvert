function Invoke-Converter {
  # .SYNOPSIS
  #  Convert objects
  # .DESCRIPTION
  #  Creates a custom Converter object and Invokes methods on it.
  # .EXAMPLE
  #  $enc_Pass = "HelloWorld" | Xconvert ToBase32String, ToObfuscated, ToSecurestring
  #  $txt_Pass = $enc_Pass | xconvert ToString, FromObfuscated, FromBase32String, ToInt32, Tostring
  #  $txt_Pass | Should -Be "HelloWorld"
  # Thats chaining methods
  [CmdletBinding()]
  [Alias('xconvert')]
  [OutputType({ [xconvert]::ReturnTypes })]
  param(
    [Parameter(Position = 0)]
    [Alias('m')][ValidateNotNullOrEmpty()]
    [ArgumentCompleter({
        [OutputType([System.Management.Automation.CompletionResult])]
        param(
          [string] $CommandName,
          [string] $ParameterName,
          [string] $WordToComplete,
          [System.Management.Automation.Language.CommandAst] $CommandAst,
          [System.Collections.IDictionary] $FakeBoundParameters
        )
        $CompletionResults = [System.Collections.Generic.List[System.Management.Automation.CompletionResult]]::new()
        $staticMethods = [xconvert].GetMethods().Where({ $_.IsStatic -and !$_.IsHideBySig }) | Sort-Object -Unique Name
        $matchingMethods = $staticMethods | Where-Object { $_.Name -like "$WordToComplete*" }
        foreach ($method in $matchingMethods) {
          $paramst = ($method.GetParameters() | Select-Object @{l = '_'; e = { "[$($_.ParameterType.Name)]`$$($_.Name)" } })._ -join ', '
          $toolTip = "{0}({1}) -> {2}" -f $method.Name, $paramst, $method.ReturnType.Name
          $completionResult = [System.Management.Automation.CompletionResult]::new(
            $method.Name, # CompletionText
            $method.Name, # ListItemText
            'Method',
            $toolTip
          )
          $CompletionResults.Add($completionResult)
        }
        return $CompletionResults
      })]
    [string[]]$Method,

    [Parameter(Position = 1, ValueFromPipeline = $true)]
    [Alias('i')][ValidateNotNullOrEmpty()]
    $object
  )

  begin {
    if ($PSBoundParameters.ContainsKey("Method") -and !$PSBoundParameters.ContainsKey("object")) {
      $PSCmdlet.ThrowTerminatingError(
        [System.Management.Automation.ErrorRecord]::new(
          [System.ArgumentNullException]::new("object", "You must supply a value for -object when using -Method"),
          "Parameter cannot be null or empty",
          "InvalidArgument",
          $null
        )
      )
    }
    $c = [xconvert]::new()
  }

  process {
    if ($object) {
      $r = $object
      $Method.ForEach({ $r = $c::$_($r) })
    } else {
      $r = $c
    }
  }

  end {
    return $r
  }
}