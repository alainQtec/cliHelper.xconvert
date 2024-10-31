# Contribution guide

We appreciate your thought to contribute to the xconvert project.

If you'd like to suggest a change to methods, workflows, or a new cmdlet :D
please
[raise an issue](https://github.com/alainQtec/cliHelper.XConvert/issues/new).

We can have a discussion to better this module, get more people involved and
help us make it better.

If you are new, here are some things to know:

1. Add a new method to xconvert class. Trust me there are a lot of methods to
   add. you just have to look for them. I mean, For each method added there
   should be counter-method. For example:
   - ToBase32String ↔ FromBase32String

   You can check all missing ones like this:

   ```PowerShell
   $xmethods = [xconvert].GetMethods().Where({ $_.IsStatic -and !$_.IsHideBySig }).name | Sort-Object -Unique;
   $analysis = $nn | select @{l="To"; e={"To"+$_}}, @{l="From"; e={"From"+$_}}, @{l='HasBoth'; e={ $xmethods -contains "To$_" -and $xmethods -contains "From$_" }}
   $analysis.Where({ !$_.HasBoth }) | Select-Object *, @{l="HasTo"; e={ $xmethods -contains $_.To}}, @{l="HasFrom"; e={ $xmethods -contains $_.From } } | Format-Table
   ```

2. Add/improve a github workflow
