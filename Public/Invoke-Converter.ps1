using namespace System.Management.Automation
function Invoke-Converter {
  #.SYNOPSIS
  #  Convert objects
  #.DESCRIPTION
  #  Creates a custom Converter object and Invokes methods on it.
  #.EXAMPLE
  #  $enc_Pass = "HelloWorld" | xconvert ToBase32, ToObfuscated, ToSecurestring
  #  $txt_Pass = $enc_Pass | xconvert ToString, FromObfuscated, FromBase32, ToInt32, Tostring
  #  $txt_Pass | Should -Be "HelloWorld"
  #  Thats chaining methods
  #.EXAMPLE
  #  $txt = "awesome!" | xconvert ToBase32, ToObfuscated | xconvert FromObfuscated, ToUTF8str, FromBase32, ToUTF8str
  #  $txt | Should -Be "awesome!"
  #.NOTES
  # If you want more control you can directly use the [xconvert] class :)
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
        $matchingMethods = [xconvert]::Methods.Where({ $_.Name -like "$WordToComplete*" -and $_.CustomAttributes.AttributeType.Name -notContains "HiddenAttribute" })
        foreach ($method in $matchingMethods) {
          $paramst = ($method.GetParameters() | Select-Object @{l = '_'; e = { "[$($_.ParameterType.Name)]`$$($_.Name)" } })._ -join ', '
          $toolTip = "[{0}] {1}({2})" -f $method.ReturnType.Name, $method.Name, $paramst
          $CompletionResults.Add([System.Management.Automation.CompletionResult]::new($method.Name, $toolTip, 'Method', $toolTip))
        }
        return $CompletionResults
      })]
    [string[]]$Method,

    [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias('i')][ValidateNotNullOrEmpty()]
    $object
  )
  begin {
    $convert = [xconvert]::new()
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
    if ($Object) {
      $result = $Object
      $Method.ForEach({ $result = $convert::$_($result) })
    } else {
      $result = $convert
    }
  }
  end {
    return $result
  }
}
