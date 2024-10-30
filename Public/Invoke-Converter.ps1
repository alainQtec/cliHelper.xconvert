using namespace System.Management.Automation
function Invoke-Converter {
  # .SYNOPSIS
  #  Convert objects
  # .DESCRIPTION
  #  Creates a custom Converter object and Invokes methods on it.
  # .EXAMPLE
  #  $enc_Pass = "HelloWorld" | xconvert ToBase32String, ToObfuscated, ToSecurestring
  #  $txt_Pass = $enc_Pass | xconvert ToString, FromObfuscated, FromBase32String, ToInt32, Tostring
  #  $txt_Pass | Should -Be "HelloWorld"
  #  Thats chaining methods
  [CmdletBinding()]
  [Alias('xconvert')]
  [OutputType({ [xconvert]::ReturnTypes })]
  param(
    [Parameter(Mandatory = $false, Position = 0)]
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
        $CompletionResults = [System.Collections.Generic.List[CompletionResult]]::new()
        $matchingMethods = [xconvert]::Methods.Where({ $_.Name -like "$WordToComplete*" })
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

    [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias('i')][ValidateNotNullOrEmpty()]
    $object
  )
  begin {
    $c = [xconvert]::new()
  }
  process {
    $InvalidMethods = $Method.Where({ $_ -notin [xconvert]::Methods.Name })
    if ($InvalidMethods.Count -gt 0) {
      $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new(
          [System.InvalidOperationException]::new("Please use valid method names. Methods ($($InvalidMethods -join ', ')) were not found.",
            [MethodInvocationException]::new("")),
          "METHOD_NOT_FOUND",
          "InvalidArgument",
          $null
        )
      )
    }
    # $PSBoundParameters.GetEnumerator() | ForEach-Object { Write-Debug "$($_.Key) = $($_.Value)" -Debug }
    if ($PSBoundParameters.ContainsKey("Method") -and !$PSBoundParameters.ContainsKey("object")) {
      $PSCmdlet.ThrowTerminatingError(
        [ErrorRecord]::new(
          [System.ArgumentNullException]::new("Object", "You must supply a value for -object when using -Method"),
          "Parameter cannot be null or empty",
          "InvalidArgument",
          $null
        )
      )
    }
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
