# Contribution guide

We appreciate your thought to contribute to the xconvert project.

If you'd like to suggest a change to methods, workflows, or a new cmdlet :D
please
[raise an issue](https://github.com/alainQtec/cliHelper.XConvert/issues/new).

We can have a discussion to better this module, get more people involved and
help us make it better.

If you are new, here are some things to know:

1. Add a new method to xconvert class. Trust me there are a lot of methods to
   add. you just have to look for them. I mean, For each method you add there
   should be counter-method for it. For example:
   - ToBase32 💱 FromBase32

   You can get a quick overview by running `show-MethodsOverview`:

   ```PowerShell
   function show-MethodsOverview() {
     $mark = @{ True = "✅"; False = "😒"}
     $xmethods = [xconvert].GetMethods().Where({ $_.IsStatic -and !$_.IsHideBySig }).name | Sort-Object -Unique;
     $analysis = $xmethods | % { $_.Replace('To', "").Replace('From', "") } | Sort-Object -Unique | Select-Object @{l="Name"; e={$_} }, @{l='HasBoth'; e={ $xmethods -contains "To$_" -and $xmethods -contains "From$_" }};
     $hasBoth = $analysis.Where({ $_.HasBoth }); $doesNotHaveBoth = $analysis.Where({ !$_.HasBoth });
     Write-Host "`nAnalysis: Overview of all static methods for [xconvert]" -f Green;
     ($hasBoth + $doesNotHaveBoth) | Select-Object Name, @{l="To"; e={ $mark[[string]($xmethods -contains "To$($_.Name)")] }}, @{l="From"; e={ $mark[[string]($xmethods -contains "From$($_.Name)")] } } | Format-Table
   }
   ```

2. Add/improve a github workflow
