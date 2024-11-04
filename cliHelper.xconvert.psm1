using namespace System.IO
using namespace System.Text
using namespace System.Reflection
using namespace System.Collections
using namespace System.Management.Automation
using namespace System.Runtime.Serialization
using namespace System.Runtime.InteropServices
using module Private/cliHelper.xconvert.Utils
#region    Classes
enum Compression {
  Gzip
  Deflate
  ZLib
  # Zstd # Todo: Add Zstandard. (The one from facebook. or maybe zstd-sharp idk. I just can't find a way to make it work in powershell! no dll nothing!)
}
enum ProtectionScope {
  CurrentUser # The protected data is associated with the current user. Only threads running under the current user context can unprotect the data.
  LocalMachine # The protected data is associated with the machine context. Any process running on the computer can unprotect data. This enumeration value is usually used in server-specific applications that run on a server where untrusted users are not allowed access.
}

enum dateFormat {
  DMTF
  Unix
  FileTime
  ICSDateTime
  ISO8601
  Excel
  UNKNOWN
}

# .SYNOPSIS
#   Convert data from one format to another
# .DESCRIPTION
#   Extended version of built in [convert] class
class xconvert : System.ComponentModel.TypeConverter {
  static hidden [PsObject] $LocalizedData = (Get-xconvertdata)
  static hidden [MethodInfo[]] $Methods = [xconvert].GetMethods().Where({ $_.IsStatic -and !$_.IsHideBySig })
  static hidden [Type[]] $ReturnTypes = ([xconvert]::Methods.ReturnType | Sort-Object -Unique Name)
  xconvert() {}
  static [string] Tostring($Object) {
    if ($null -eq $Object) { return [string]::Empty };
    [string]$ObjtN = $Object.GetType().Name
    $s = @('Object', 'bool', 'char', 'sbyte', 'byte', 'short', 'ushort', 'int', 'uint', 'long', 'ulong', 'float', 'double', 'decimal', 'datetime', 'string')
    if ($ObjtN -notin ($s + ('BitArray', 'byte[]', 'char[]', 'int[]', 'SecureString', 'guid', 'k3y', 'Hashtable', 'OrderedDictionary', 'AXNodeConfiguration', 'PSBoundParametersDictionary'))) {
      throw [System.InvalidOperationException]::new("Object type not upported")
    }
    if ($ObjtN -in $s) { return [convert]::ToString($Object) }
    $r = switch ($ObjtN) {
      'SecureString' {
        [string]$Pstr = [string]::Empty;
        [IntPtr]$zero = [IntPtr]::Zero;
        if ($null -eq $Object -or $Object.Length -eq 0) {
          return [string]::Empty;
        }
        try {
          Set-Variable -Name zero -Scope Local -Visibility Private -Option Private -Value ([Marshal]::SecureStringToBSTR($Object));
          Set-Variable -Name Pstr -Scope Local -Visibility Private -Option Private -Value ([Marshal]::PtrToStringBSTR($zero));
        } finally {
          if ($zero -ne [IntPtr]::Zero) {
            [Marshal]::ZeroFreeBSTR($zero);
          }
        }
        $Pstr; break
      }
      'byte[]' {
        [System.Convert]::ToBase64String([xconvert]::ToBytes($Object));
        break
      }
      'char[]' {
        [string]::Join([string]::Empty, [string[]][xconvert]::ToChars([byte[]][int[]]$Object));
        break
      }
      'BitArray' {
        $b = [BitArray]$Object
        [string]$finalString = [string]::Empty;
        # Manually read the first 8 bits and
        while ($b.Length -gt 0) {
          $ba_tempBitArray = [BitArray]::new($b.Length - 8);
          $int_binaryValue = 0;
          if ($b[0]) { $int_binaryValue += 1 };
          if ($b[1]) { $int_binaryValue += 2 };
          if ($b[2]) { $int_binaryValue += 4 };
          if ($b[3]) { $int_binaryValue += 8 };
          if ($b[4]) { $int_binaryValue += 16 };
          if ($b[5]) { $int_binaryValue += 32 };
          if ($b[6]) { $int_binaryValue += 64 };
          if ($b[7]) { $int_binaryValue += 128 };
          $finalString += [Char]::ConvertFromUtf32($int_binaryValue);
          $int_counter = 0;
          for ($i = 8; $i -lt $b.Length; $i++) {
            $ba_tempBitArray[$int_counter++] = $b[$i];
          }
          $b = $ba_tempBitArray;
        }
        $finalString;
        break
      }
      'guid' {
        [Encoding]::UTF8.GetString([xconvert]::ToBytes($Object.ToString().Replace('-', '')))
        # NOTE: This does not apply on real guids. This is just a way to reverse the ToGuid() method.
        break
      }
      'k3Y' {
        $NotNullProps = ('User', 'UID', 'Expiration');
        $Object | Get-Member -MemberType Properties | ForEach-Object { $Prop = $_.Name; if ($null -eq $Object.$Prop -and $Prop -in $NotNullProps) { throw [System.ArgumentNullException]::new($Prop) } };
        $CustomObject = [xconvert]::ToPSObject($Object);
        [string][xconvert]::ToCompressed([System.Convert]::ToBase64String([xconvert]::ToBytes($CustomObject)));
        break
      }
      Default {
        $sb = [StringBuilder]::New(); [void]$sb.AppendLine('@{');
        foreach ($key in $Object.Keys) {
          if ($Object[$key]) {
            [string]$keytN = $Object[$key].GetType().Name
            switch ($true) {
              $($keytN -eq 'ScriptBlock') {
                [void]$sb.AppendLine("$key = `{$($Object[$key].ToString())`}")
                break
              }
              ### Strings and Enums
              $($keytN -in @('String', 'ActionPreference')) {
                [string]$itemText = "{0} = '{1}'" -f "$key", [xget]::EscapeSpecialCharacters($Object[$key])
                [void]$sb.AppendLine($itemText)
                break
              }
              $($keytN -eq 'String[]') {
                [string]$itemText = "{0} = @({1})" -f "$key", "$($($Object[$key] | ForEach-Object { "'$([xget]::EscapeSpecialCharacters($_))'" }) -join ", ")"
                [void]$sb.AppendLine($itemText)
                break
              }
              $(($keytN -ilike '*int*') -or (@('single', 'double', 'decimal', 'SByte', 'Byte') -icontains $keytN)) {
                [string]$itemText = "{0} = {1}" -f "$key", $($Object[$key]).ToString()
                [void]$sb.AppendLine($itemText)
                break
              }
              $($keytN -in ('Hashtable', 'OrderedDictionary', 'PSBoundParametersDictionary')) {
                [string]$itemText = "{0} = {1}" -f "$key", $(ConvertTo-String -InputObject $Object[$key] -DoNotFormat)
                [void]$sb.AppendLine($itemText)
                break
              }
              $($keytN -in ('Hashtable[]', 'OrderedDictionary[]', 'PSBoundParametersDictionary[]')) {
                $NewLineStr = [Environment]::NewLine
                $JoinSeparator = ",$NewLineStr"
                [string]$itemText = "{0} = @($NewLineStr{1}$NewLineStr)" -f "$key", "$($($Object[$key] | ForEach-Object { ConvertTo-String -InputObject $_ -DoNotFormat }) -join $JoinSeparator)"
                [void]$sb.AppendLine($itemText)
                break
              }
              $($keytN -in ('Boolean', 'SwitchParameter')) {
                [string]$itemText = '{0} = ${1}' -f "$key", $($Object[$key].ToString())
                [void]$sb.AppendLine($itemText)
                break
              }
              $($keytN -eq 'PSCustomObject') {
                # Convert to hashtable
                $propHash = @{}; foreach ($prop in $Object[$key].PSObject.Properties) { $propHash[$prop.Name] = $prop.Value }
                [string]$itemText = '{0} = $([PSCustomObject] {1})' -f "$key", $(ConvertTo-String -InputObject $propHash -DoNotFormat)
                [void]$sb.AppendLine($itemText)
                break
              }
              $($keytN -eq 'DateTime') {
                [string]$itemText = "{0} = '{1}'" -f "$key", $($Object[$key].ToUniversalTime().ToString("dd.MM.yyyy HH.mm:ss UTC", [CultureInfo]::InvariantCulture))
                [void]$sb.AppendLine($itemText)
                break
              }
              Default {
                Write-Warning "Serializing not supported key: $key that contains: $_"
                [string]$itemText = '{0} = {1}' -f "$key", $($Object[$key].ToString())
                [void]$sb.AppendLine($itemText)
              }
            }
          } else {
            [void]$sb.AppendLine('{0} = $null' -f "$key")
          }
        }
        [void]$sb.AppendLine('}')
        $sb.ToString().Trim([environment]::NewLine)
      }
    }
    return $r
  }
  static [string] ToString([int[]]$CharCodes, [string]$separator) {
    return [string]::Join($separator, [xconvert]::ToString($CharCodes));
  }
  static [string] ToString([int]$value, [int]$toBase) {
    [char[]]$baseChars = switch ($toBase) {
      # Binary
      2 { @('0', '1') }
      # Hexadecimal
      16 { @('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f') }
      # Hexavigesimal
      26 { @('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p') }
      # Sexagesimal
      60 { @('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x') }
      Default {
        throw [System.ArgumentException]::new("Invalid Base.")
      }
    }
    return [xconvert]::ToString($value, $baseChars);
  }
  static [string] ToString([Int]$value, [char[]]$baseChars) {
    [int]$i = 32; [char[]]$buffer = [Char[]]::new($i);
    [int]$targetBase = $baseChars.Length;
    do {
      $buffer[--$i] = $baseChars[$value % $targetBase];
      $value = $value / $targetBase;
    } while ($value -gt 0);
    [char[]]$result = [Char[]]::new(32 - $i);
    [Array]::Copy($buffer, $i, $result, 0, 32 - $i);
    return [string]::new($result)
  }
  static [string] ToASCIIstr([byte[]]$bytes) { return [Encoding]::ASCII.GetString($bytes) }
  static [byte[]] FromASCIIstr([string]$s) { return [Encoding]::ASCII.GetBytes($s) }

  static [string] ToUTF7str([byte[]]$bytes) { return [Encoding]::UTF7.GetString($bytes) }
  static [byte[]] FromUTF7str([string]$s) { return [Encoding]::UTF7.GetBytes($s) }

  static [string] ToUTF8str([byte[]]$bytes) { return [Encoding]::UTF8.GetString($bytes) }
  static [byte[]] FromUTF8str([string]$s) { return [Encoding]::UTF8.GetBytes($s) }

  static [string] ToUTF32str([byte[]]$bytes) { return [Encoding]::UTF32.GetString($bytes) }
  static [byte[]] FromUTF32str([string]$s) { return [Encoding]::UTF32.GetBytes($s) }

  static [string] ToLatin1str([byte[]]$bytes) { return [Encoding]::Latin1.GetString($bytes) }
  static [byte[]] FromLatin1str([string]$s) { return [Encoding]::Latin1.GetBytes($s) }

  static [string] ToUnicodestr([byte[]]$bytes) { return [Encoding]::Unicode.GetString($bytes) }
  static [byte[]] FromUnicodestr([string]$s) { return [Encoding]::Unicode.GetBytes($s) }

  static [string] ToBUnicodestr([byte[]]$bytes) { return [Encoding]::BigEndianUnicode.GetString($bytes) }
  static [byte[]] FromBUnicodestr([string]$s) { return [Encoding]::BigEndianUnicode.GetBytes($s) }

  static [guid] ToGuid([string]$text) {
    # Creates a string that passes guid regex checks (ie: not a real guid)
    if ($text.Trim().Length -ne 16) {
      throw [System.InvalidOperationException]::new('$InputText.Trim().Length Should Be exactly 16. Ex: [xconvert]::ToGuid([xget]::RandomName(16))')
    }
    if ([xget]::IsValidHex($text)) {
      return [System.Guid]::new(([byte[]] -split ($text -replace '..', '0x$& ')))
    }
    return [guid]::new([System.BitConverter]::ToString([Encoding]::UTF8.GetBytes($text)).Replace("-", "").ToLower().Insert(8, "-").Insert(13, "-").Insert(18, "-").Insert(23, "-"))
  }
  [string[]] ToRomanNumeral([int[]]$Numbers) {
    [ValidateRange(1, 3999)][int[]]$Numbers = $Numbers
    $res = @()
    $DecimalToRoman = @{
      Thousands = "", "M", "MM", "MMM"
      Hundreds  = "", "C", "CC", "CCC", "CD", "D", "DC", "DCC", "DCCC", "CM"
      Tens      = "", "X", "XX", "XXX", "XL", "L", "LX", "LXX", "LXXX", "XC"
      Ones      = "", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"
    }
    $column = @{
      Thousands = 0
      Hundreds  = 1
      Tens      = 2
      Ones      = 3
    }
    foreach ($n in $Numbers) {
      [int[]]$digits = ($n.ToString().PadLeft(4, "0").ToCharArray()).ForEach({ [Char]::GetNumericValue($_) })
      $RomanNumeral = [string]::Empty
      $RomanNumeral += $DecimalToRoman.Thousands[$digits[$column.Thousands]]
      $RomanNumeral += $DecimalToRoman.Hundreds[$digits[$column.Hundreds]]
      $RomanNumeral += $DecimalToRoman.Tens[$digits[$column.Tens]]
      $RomanNumeral += $DecimalToRoman.Ones[$digits[$column.Ones]]
      $res += $RomanNumeral
    }
    return $res
  }
  [void] ToPtrOrStr([Byte[]]$Buffer, [Type]$Type) {
    # TODO: [wip] return something!
    [ValidateNotNullOrEmpty()][Byte[]]$Buffer = $Buffer
    [ValidateNotNull()][Type]$Type = $Type; $gch = $null
    try {
      $gch = [GCHandle]::Alloc($Buffer, [GCHandleType]::Pinned)
      if ($Type) {
        $gch.AddrOfPinnedObject() -as $Type
      } else {
        $gch.AddrOfPinnedObject()
      }
    } catch { Write-Verbose $_ }
    finally {
      if ($gch) { $gch.Free() }
    }
  }
  static [SecureString] ToSecurestring([string]$String) {
    $SecureString = $null; Set-Variable -Name SecureString -Scope Local -Visibility Private -Option Private -Value ([System.Security.SecureString]::new());
    if (![string]::IsNullOrEmpty($String)) {
      $Chars = $String.toCharArray()
      ForEach ($Char in $Chars) {
        $SecureString.AppendChar($Char)
      }
    }
    $SecureString.MakeReadOnly();
    return $SecureString
  }
  static [int[]] ToInt32([byte[]]$Bytes) {
    return [xconvert]::ToChars($Bytes)
  }
  static [int[]] ToInt32([string[]]$string) {
    return [xconvert]::ToChars([Encoding]::Default.GetBytes($string))
  }
  static [string[]] FromInt32([int[]]$Codes) {
    return [string[]]$Codes
  }
  static [char[]] ToChars([byte[]]$Bytes) {
    return [Encoding]::Default.GetChars($Bytes)
  }
  static [bool] ToBoolean([string]$Text) {
    $Text = switch -Wildcard ($Text) {
      "1*" { "true"; break }
      "0*" { "false"; break }
      "yes*" { "true"; break }
      "no*" { "false"; break }
      "true*" { "true"; break }
      "false*" { "false"; break }
      "*true*" { "true"; break }
      "*false*" { "false"; break }
      "yeah*" { "true"; break }
      "y*" { "true"; break }
      "n*" { "false"; break }
      Default { "false" }
    }
    return [convert]::ToBoolean($Text)
  }
  static [psobject] ToCaesar([string]$Text) {
    return [PsObject][xconvert]::ToCaesar($Text, $(Get-Random (1..25)))
  }
  static [psobject] ToCaesar([string]$Text, [int]$Key) {
    $Text = $Text.ToLower();
    $Cipher = [string]::Empty;
    $alphabet = [string]"abcdefghijklmnopqrstuvwxyz";
    New-Variable -Name alphabet -Value $alphabet -Option Constant -Force;
    for ($i = 0; $i -lt $Text.Length; $i++) {
      if ($Text[$i] -eq " ") {
        $Cipher += " ";
      } else {
        [int]$index = $alphabet.IndexOf($text[$i]) + $Key
        if ($index -gt 26) {
          $index = $index - 26
        }
        $Cipher += $alphabet[$index];
      }
    }
    $Output = [PsObject]::new()
    $Output | Add-Member -Name 'Cipher' -Value $Cipher -Type NoteProperty
    $Output | Add-Member -Name 'key' -Value $Key -Type NoteProperty
    return $Output
  }
  static [string] FromCaesar([string]$Cipher, [int]$Key) {
    $Cipher = $Cipher.ToLower();
    $Output = [string]::Empty;
    $alphabet = [string]"abcdefghijklmnopqrstuvwxyz";
    New-Variable -Name alphabet -Value $alphabet -Option Constant -Force;
    for ($i = 0; $i -lt $Cipher.Length; $i++) {
      if ($Cipher[$i] -eq " ") {
        $Output += " ";
      } else {
        $Output += $alphabet[($alphabet.IndexOf($Cipher[$i]) - $Key)];
      }
    };
    return $Output;
  }
  static [psobject] ToPolybius([String]$Text) {
    $Ciphrkey = Get-Random "abcdefghijklmnopqrstuvwxyz" -Count 25
    return [PsObject][xconvert]::ToPolybius($Text, $Ciphrkey)
  }
  static [psobject] ToPolybius([string]$Text, [string]$Key) {
    $Text = $Text.ToLower();
    $Key = $Key.ToLower();
    [String]$Cipher = [string]::Empty
    [xget]::ValidatePolybius($Text, $Key, "Encrypt")
    [Array]$polybiusTable = New-Object 'string[,]' 5, 5;
    $letter = 0;
    for ($i = 0; $i -lt 5; $i++) {
      for ($j = 0; $j -lt 5; $j++) {
        $polybiusTable[$i, $j] = $Key[$letter];
        $letter++;
      }
    };
    $Text = $Text.Replace(" ", "");
    for ($i = 0; $i -lt $Text.Length; $i++) {
      for ($j = 0; $j -lt 5; $j++) {
        for ($k = 0; $k -lt 5; $k++) {
          if ($polybiusTable[$j, $k] -eq $Text[$i]) {
            $Cipher += [string]$j + [string]$k + " ";
          }
        }
      }
    }
    $Output = [PsObject]::new()
    $Output | Add-Member -Name 'Cipher' -Value $Cipher -Type NoteProperty
    $Output | Add-Member -Name 'key' -Value $Key -Type NoteProperty
    return $Output
  }
  static [string] FromPolybius([string]$Cipher, [string]$Key) {
    $Cipher = $Cipher.ToLower();
    $Key = $Key.ToLower();
    [String]$Output = [string]::Empty
    [xget]::ValidatePolybius($Cipher, $Key, "Decrypt")
    [Array]$polybiusTable = New-Object 'string[,]' 5, 5;
    $letter = 0;
    for ($i = 0; $i -lt 5; $i++) {
      for ($j = 0; $j -lt 5; $j++) {
        $polybiusTable[$i, $j] = $Key[$letter];
        $letter++;
      }
    };
    $SplitInput = $Cipher.Split(" ");
    foreach ($pair in $SplitInput) {
      $Output += $polybiusTable[[convert]::ToInt32($pair[0], 10), [convert]::ToInt32($pair[1], 10)];
    };
    return $Output;
  }
  static [string] ToObfuscated([string]$string) {
    $Inpbytes = [Encoding]::UTF8.GetBytes($string); $rn = [System.Random]::new(); # Hides Byte Array in a random String
    return [string]::Join('', $($Inpbytes | ForEach-Object { [string][char]$rn.Next(97, 122) + $_ }));
  }
  static [string] ToObfuscated([byte[]]$bytes) {
    $rn = [System.Random]::new(); # Hides Byte Array in a random String
    $St = [System.string]::Join('', $($bytes | ForEach-Object { [string][char]$rn.Next(97, 122) + $_ }));
    return $St
  }
  static [byte[]] FromObfuscated ([string]$string) {
    $az = [int[]](97..122) | ForEach-Object { [string][char]$_ };
    $by = [byte[]][string]::Concat($(($string.ToCharArray() | ForEach-Object { if ($_ -in $az) { [string][char]32 } else { [string]$_ } }) | ForEach-Object { $_ })).Trim().split([string][char]32);
    return $by
  }
  static [PSCustomObject[]] ToPSObject([xml]$XML) {
    $Out = @(); foreach ($Object in @($XML.Objects.Object)) {
      $PSObject = [PSCustomObject]::new()
      foreach ($Property in @($Object.Property)) {
        $PSObject | Add-Member NoteProperty $Property.Name $Property.InnerText
      }
      $Out += $PSObject
    }
    return $Out
  }
  static [string] ToCsv([System.Object]$Obj) {
    return [xconvert]::ToCsv($Obj, @('pstypenames', 'BaseType'), 2, 0)
  }
  static [string] ToCsv([System.Object]$Obj, [int]$depth) {
    return [xconvert]::ToCsv($Obj, @('pstypenames', 'BaseType'), $depth, 0)
  }
  static [string] ToCsv([System.Object]$Obj, [string[]]$excludedProps, [int]$depth, [int]$currentDepth = 0) {
    $get_Props = [scriptblock]::Create({
        param([Object]$Objct, [string[]]$excluded)
        $Props = $Objct | Get-Member -Force -MemberType Properties; if ($excluded.Count -gt 0) { $Props = $Props | Where-Object { $_.Name -notin $excluded } }
        $Props = $Props | Select-Object -ExpandProperty Name
        return $Props
      }
    )
    $Props = $get_Props.Invoke($Obj, $excludedProps)
    $csv = [string]::Empty
    $csv += '"' + ($Props -join '","') + '"' + "`n";
    $vals = @()
    foreach ($name in $Props) {
      $_props = $get_Props.Invoke($Obj.$name, $excludedProps)
      if ($null -ne $_props) {
        if ($_props.count -gt 0 -and $currentDepth -lt $depth) {
          $currentDepth++
          $vals += [xconvert]::ToCsv($Obj.$name, $excludedProps, $depth, $currentDepth)
        } elseif ($null -ne $Obj.$name) {
          $vals += $Obj.$name.Tostring()
        } else {
          $vals += $name.Tostring()
        }
      }
    }
    $fs = '"{' + ((0 .. ($vals.Count - 1)) -join '}","{') + '}"';
    $csv += $fs -f $vals
    return $csv
  }
  static [PsObject] FromCsv([string]$text) {
    $obj = $null
    $lines = $text -split "\r?\n"
    if ($lines.Count -lt 2) {
      throw "CSV contains no data"
    }
    $header = $lines[0] -split ','
    $objs = foreach ($line in $lines[1..($lines.Count - 1)]) {
      $values = $line -split ','
      $obj = New-Object psobject
      for ($i = 0; $i -lt $header.Length; $i++) {
        $prop = $header[$i].Trim('"')
        if ($null -ne $values[$i]) {
          $val = $values[$i].Trim('"')
          if (![string]::IsNullOrEmpty($val)) {
            $obj | Add-Member -MemberType NoteProperty -Name $prop -Value $val
          }
        }
      }
      $obj
    }
    return $objs
  }
  Static [PSCustomObject] ToPSObject([System.Object]$Obj) {
    $PSObj = [PSCustomObject]::new();
    $Obj | Get-Member -MemberType Properties | ForEach-Object {
      $Name = $_.Name; $PSObj | Add-Member -Name $Name -MemberType NoteProperty -Value $(if ($null -ne $Obj.$Name) { if ("Deserialized" -in (($Obj.$Name | Get-Member).TypeName.Split('.') | Sort-Object -Unique)) { $([xconvert]::ToPSObject($Obj.$Name)) } else { $Obj.$Name } } else { $null })
    }
    return $PSObj
  }
  static [object] FromPSObject([PSCustomObject]$PSObject) {
    return [xconvert]::FromPSObject($PSObject, $PSObject.PSObject.TypeNames[0])
  }
  static [object] FromPSObject([PSCustomObject]$PSObject, [string]$typeName) {
    # TODO: fix. /!\ not working as expected /!\
    $Type = [Type]::GetType($typeName, $false)
    if ($Type) {
      $Obj = [Activator]::CreateInstance($Type)
      $PSObject.PSObject.Properties | ForEach-Object {
        $Name = $_.Name
        $Value = $_.Value
        if ($Value -is [PSCustomObject]) {
          $Value = [xconvert]::FromPSObject($Value)
        }
        $Obj.$Name = $Value
      }
      return $Obj
    } else {
      return $PSObject
    }
  }
  static [PSCustomObject] ToPSCustomObject($InputObject) {
    $OutputObject = [PSCustomObject]::new()
    $InputObject.PSObject.Properties | ForEach-Object {
      $PropertyName = $_.Name
      $PropertyValue = $_.Value
      if ($_.TypeNameOfValue -is 'Deserialized.System.Management.Automation.PSCustomObject') {
        $OutputObject | Add-Member -Name $PropertyName -MemberType NoteProperty -Value ([xget]::ConvertToPSCustomObject($PropertyValue))
      } else {
        $OutputObject | Add-Member -Name $PropertyName -MemberType NoteProperty -Value $PropertyValue
      }
    }
    return $OutputObject
  }
  static [byte[]] FromBase32([string]$string) {
    return [Base32]::Decode($string)
  }
  static [byte[]] FromBase58([string]$text) {
    return [Base58]::Decode($text)
  }
  static [byte[]] FromBase85([string]$text) {
    return [Base85]::Decode($text)
  }
  static [byte[]] FromBase85([byte[]]$bytes) {
    return [Base85]::Decode([xconvert]::ToUTF8str($bytes))
  }
  static [string] ToBase32([byte[]]$bytes) {
    if ([xget]::IsValidHex($bytes)) {
      return [System.BitConverter]::ToString($bytes).Replace("-", "").ToLower()
    }
    return [Base32]::Encode($bytes)
  }
  static [string] ToBase32([string]$s) {
    return [Base32]::Encode([xconvert]::ToBytes($s))
  }
  static [string] ToBase32([byte[]]$bytes, [bool]$Formatt) {
    return [Base32]::Encode($bytes, $Formatt)
  }
  static [string] ToBase32([string]$s, [bool]$Formatt) {
    return [Base32]::Encode($s, $Formatt)
  }
  static [string] ToBase32([Stream]$Stream, [bool]$Formatt) {
    return [Base32]::Encode($Stream, $Formatt)
  }
  static [string] ToBase58([string]$s) {
    return [Base58]::Encode([xconvert]::ToBytes($s))
  }
  static [string] ToBase58([byte[]]$bytes) {
    return [Base58]::Encode($bytes)
  }
  static [string] ToBase85([string]$s) {
    return [Base85]::Encode([xconvert]::ToBytes($s))
  }
  static [string] ToBase85([byte[]]$bytes) {
    return [Base85]::Encode($bytes)
  }
  static [string] ToProtected([string]$string) {
    $Scope = [ProtectionScope]::CurrentUser
    $Entropy = [Encoding]::UTF8.GetBytes([xget]::UniqueMachineId())[0..15];
    return [xconvert]::Tostring([xconvert]::ToProtected([xconvert]::ToBytes($string), $Entropy, $Scope))
  }
  static [string] ToProtected([string]$string, [ProtectionScope]$Scope) {
    $Entropy = [Encoding]::UTF8.GetBytes([xget]::UniqueMachineId())[0..15];
    return [xconvert]::Tostring([xconvert]::ToProtected([xconvert]::ToBytes($string), $Entropy, $Scope))
  }
  static [string] ToProtected([string]$string, [byte[]]$Entropy, [ProtectionScope]$Scope) {
    return [xconvert]::Tostring([xconvert]::ToProtected([xconvert]::ToBytes($string), $Entropy, $Scope))
  }
  static [byte[]] ToProtected([byte[]]$Bytes) {
    $Scope = [ProtectionScope]::CurrentUser
    $Entropy = [Encoding]::UTF8.GetBytes([xget]::UniqueMachineId())[0..15];
    return [xconvert]::ToProtected($bytes, $Entropy, $Scope)
  }
  static [byte[]] ToProtected([byte[]]$Bytes, [ProtectionScope]$Scope) {
    $Entropy = [Encoding]::UTF8.GetBytes([xget]::UniqueMachineId())[0..15];
    return [xconvert]::ToProtected($bytes, $Entropy, $Scope)
  }
  static [byte[]] ToProtected([byte[]]$Bytes, [byte[]]$Entropy, [ProtectionScope]$Scope) {
    $encryptedData = $null; # Uses the Windows Data Protection API (DPAPI) https://docs.microsoft.com/en-us/dotnet/api/System.Security.Cryptography.ProtectedData.Protect?
    try {
      if (!("System.Security.Cryptography.ProtectedData" -is 'Type')) { Add-Type -AssemblyName System.Security }
      $bytes64str = $null; Set-Variable -Name bytes64str -Scope Local -Visibility Private -Option Private -Value ([convert]::ToBase64String($Bytes))
      $Entropy64str = $null; Set-Variable -Name Entropy64str -Scope Local -Visibility Private -Option Private -Value ([convert]::ToBase64String($Entropy))
      Set-Variable -Name encryptedData -Scope Local -Visibility Private -Option Private -Value $(& ([scriptblock]::Create("[System.Security.Cryptography.ProtectedData]::Protect([convert]::FromBase64String('$bytes64str'), [convert]::FromBase64String('$Entropy64str'), [System.Security.Cryptography.DataProtectionScope]::$($Scope.ToString()))")));
    } catch [System.Security.Cryptography.CryptographicException] {
      throw [System.Security.Cryptography.CryptographicException]::new("Data was not encrypted. An error occurred!`n $($_.Exception.Message)");
    } catch {
      throw $_
    }
    return $encryptedData
  }
  static [string] FromProtected([string]$string) {
    $Scope = [ProtectionScope]::CurrentUser
    $Entropy = [Encoding]::UTF8.GetBytes([xget]::UniqueMachineId())[0..15];
    return [xconvert]::FromBytes([xconvert]::FromProtected([xconvert]::ToBytes($string), $Entropy, $Scope))
  }
  static [string] FromProtected([string]$string, [ProtectionScope]$Scope) {
    $Entropy = [Encoding]::UTF8.GetBytes([xget]::UniqueMachineId())[0..15];
    return [xconvert]::FromBytes([xconvert]::FromProtected([xconvert]::ToBytes($string), $Entropy, $Scope))
  }
  static [string] FromProtected([string]$string, [byte[]]$Entropy, [ProtectionScope]$Scope) {
    return [xconvert]::FromBytes([xconvert]::FromProtected([xconvert]::ToBytes($string), $Entropy, $Scope))
  }
  static [byte[]] FromProtected([byte[]]$Bytes, [byte[]]$Entropy, [ProtectionScope]$Scope) {
    $decryptedData = $null;
    try {
      if (!("System.Security.Cryptography.ProtectedData" -is 'Type')) { Add-Type -AssemblyName System.Security }
      $bytes64str = $null; Set-Variable -Name bytes64str -Scope Local -Visibility Private -Option Private -Value ([convert]::ToBase64String($Bytes))
      $Entropy64str = $null; Set-Variable -Name Entropy64str -Scope Local -Visibility Private -Option Private -Value ([convert]::ToBase64String($Entropy))
      Set-Variable -Name decryptedData -Scope Local -Visibility Private -Option Private -Value $(& ([scriptblock]::Create("[System.Security.Cryptography.ProtectedData]::Unprotect([convert]::FromBase64String('$bytes64str'), [convert]::FromBase64String('$Entropy64str'), [System.Security.Cryptography.DataProtectionScope]::$($Scope.ToString()))")));
    } catch [System.Security.Cryptography.CryptographicException] {
      throw [System.Security.Cryptography.CryptographicException]::new("Data was not decrypted. An error occurred!`n $($_.Exception.Message)");
    } catch {
      throw $_
    }
    return $decryptedData
  }
  static [byte[]] ToCompressed([byte[]]$Bytes) {
    return [xconvert]::ToCompressed($Bytes, 'Gzip');
  }
  static [string] ToCompressed([string]$Plaintext) {
    return [convert]::ToBase64String([xconvert]::ToCompressed([Encoding]::UTF8.GetBytes($Plaintext)));
  }
  static [byte[]] ToCompressed([byte[]]$Bytes, [string]$Compression) {
    if (("$Compression" -as 'Compression') -isnot 'Compression') {
      Throw [System.InvalidCastException]::new("Compression type '$Compression' is unknown! Valid values: $([Enum]::GetNames([compression]) -join ', ')");
    }
    $outstream = [MemoryStream]::new()
    $Comstream = switch ($Compression) {
      "Gzip" { New-Object System.IO.Compression.GzipStream($outstream, [Compression.CompressionLevel]::Optimal) }
      "Deflate" { New-Object System.IO.Compression.DeflateStream($outstream, [Compression.CompressionLevel]::Optimal) }
      "ZLib" { New-Object System.IO.Compression.ZLibStream($outstream, [Compression.CompressionLevel]::Optimal) }
      Default { throw "Failed to Compress Bytes. Could Not resolve Compression!" }
    }
    [void]$Comstream.Write($Bytes, 0, $Bytes.Length); $Comstream.Close(); $Comstream.Dispose();
    [byte[]]$OutPut = $outstream.ToArray(); $outStream.Close()
    return $OutPut;
  }
  static [byte[]] FromCompressed([byte[]]$Bytes) {
    return [xconvert]::FromCompressed($Bytes, 'Gzip');
  }
  static [string] FromCompressed([string]$Base64Text) {
    return [Encoding]::UTF8.GetString([xconvert]::FromCompressed([convert]::FromBase64String($Base64Text)));
  }
  static [byte[]] FromCompressed([byte[]]$Bytes, [string]$Compression) {
    if (("$Compression" -as 'Compression') -isnot 'Compression') {
      Throw [System.InvalidCastException]::new("Compression type '$Compression' is unknown! Valid values: $([Enum]::GetNames([compression]) -join ', ')");
    }
    $inpStream = [MemoryStream]::new($Bytes)
    $ComStream = switch ($Compression) {
      "Gzip" { New-Object System.IO.Compression.GzipStream($inpStream, [Compression.CompressionMode]::Decompress); }
      "Deflate" { New-Object System.IO.Compression.DeflateStream($inpStream, [Compression.CompressionMode]::Decompress); }
      "ZLib" { New-Object System.IO.Compression.ZLibStream($inpStream, [Compression.CompressionMode]::Decompress); }
      Default { throw "Failed to DeCompress Bytes. Could Not resolve Compression!" }
    }
    $outStream = [MemoryStream]::new();
    [void]$Comstream.CopyTo($outStream); $Comstream.Close(); $Comstream.Dispose(); $inpStream.Close()
    [byte[]]$OutPut = $outstream.ToArray(); $outStream.Close()
    return $OutPut;
  }
  static [PSObject[]] ToFlatObject([PSObject[]]$InputObject) {
    $op = [xget]::Options
    return [xconvert]::ToFlatObject($InputObject, $op.PropstoExclude, $op.SkipDefaults, $op.PropstoInclude, $op.Values, $op.MaxDepth)
  }
  static [PSObject[]] ToFlatObject([PSObject[]]$InputObject, [string[]]$PropstoExclude, [bool]$SkipDefaults, [string[]]$PropstoInclude, [string[]]$Values, [int]$MaxDepth) {
    # .DESCRIPTION
    #   flatten an object to simplify discovery of data
    # .EXAMPLE
    #   $qs = Invoke-RestMethod "https://api.stackexchange.com/2.0/questions/unanswered?order=desc&sort=activity&tagged=powershell&pagesize=10&site=stackoverflow"
    #   [xget]::Options.Include = ("Title", "Link", "View_Count")
    #   $ql = [xconvert]::ToFlatObject($qs)
    $result = @(); [xget]::Options = New-Object xObOptions -Property @{
      PropstoExclude = $PropstoExclude
      PropstoInclude = $PropstoInclude
      SkipDefaults   = $SkipDefaults
      MaxDepth       = $MaxDepth
      Values         = $Values
    }
    foreach ($Object in $InputObject) {
      $result += [xget]::RecurseObject($Object, [PSObject]::new())
    }
    return $result
  }
  static [Hashtable] ToHashTable($object) {
    # Converts an object to a hashtable
    # .DESCRIPTION
    # PowerShell v4 seems to have trouble casting some objects to Hashtable.
    $Properties = switch ($object.GetType().Fullname) {
      'System.String' {
        try {
          $obj = ConvertFrom-Json -InputObject $object -ErrorAction Stop
          $obj.PsObject.Properties
        } catch {
          throw [InvalidDataException]::new("Object is not a valid json string")
        }
        break
      }
      default {
        $object.PsObject.Properties
      }
    }
    return [xconvert]::ToHashTable($Properties, 0)
  }
  static [Hashtable] ToHashTable ([PSPropertyInfo[]]$Properties, [int]$CurrentDepth) {
    $DepthThreshold = 32; $CurrentDepth++
    if ($CurrentDepth -ge $DepthThreshold) {
      Write-Error -Message "Converting to Hashtable reached Depth Threshold of 32 on $($Properties.Name -join ',')" -ErrorAction Stop
    }
    $Ht = [hashtable]@{}
    foreach ($Prop in $Properties) {
      if ($Prop.Value -or $prop.TypeNameOfValue -eq 'System.Boolean') {
        switch ($Prop.TypeNameOfValue) {
          'System.String' {
            $ht.Add($Prop.Name, $Prop.Value)
            break
          }
          'System.Boolean' {
            $ht.Add($Prop.Name, $Prop.Value)
            break
          }
          'System.DateTime' {
            $ht.Add($Prop.Name, $Prop.Value.ToString())
            break
          }
          { $_ -ilike '*int*' } {
            $ht.Add($Prop.Name, $Prop.Value)
            break
          }
          default {
            $ht.Add($Prop.Name, [xconvert]::ToHashTable($Prop.Value.psobject.Properties, $CurrentDepth))
          }
        }
      } else {
        $ht.Add($Prop.Name, $null)
      }
    }
    return $Ht
  }
  static [string] ToHexString([byte[]]$Bytes) {
    return [string][System.BitConverter]::ToString($bytes).replace('-', [string]::Empty).Tolower();
  }
  static [string] ToHexString([uint64[]]$Numbers, [int]$MinWidth, [string]$Prefix) {
    [ValidateSet('#', '0x')][string]$Prefix = $Prefix
    [ValidateRange(1, 255)][int] $MinWidth = $MinWidth; $res = @()
    foreach ($Num in $Numbers) {
      if ($MinWidth) {
        $val = "{0:x$MinWidth}" -f $Num
      } else {
        $val = '{0:x}' -f $Num
      }
      if ($Prefix) { $val = $Prefix + $val }
      $res += $val
    }
    return $res
  }
  static [byte[]] FromHexString([string]$HexString) {
    $outputLength = $HexString.Length / 2;
    $output = [byte[]]::new($outputLength);
    $numeral = [char[]]::new(2);
    for ($i = 0; $i -lt $outputLength; $i++) {
      $HexString.CopyTo($i * 2, $numeral, 0, 2);
      $output[$i] = [Convert]::ToByte([string]::new($numeral), 16);
    }
    return $output;
  }
  static [string] ToBase64str([byte[]]$bytes) { return [Convert]::ToBase64String($bytes) }
  static [byte[]] FromBase64str([string]$s) { return [Convert]::FromBase64String($s) }

  static [byte[]] ToBytes([string]$string) {
    $array = switch ($true) {
      $([xget]::IsValidBase64($string)) {
        [convert]::FromBase64String($string);
        break
      }
      $([xget]::IsValidHex($string)) {
        $outputLength = $string.Length / 2;
        $output = [byte[]]::new($outputLength);
        $numeral = [char[]]::new(2);
        for ($i = 0; $i -lt $outputLength; $i++) {
          $string.CopyTo($i * 2, $numeral, 0, 2);
          $output[$i] = [Convert]::ToByte([string]::new($numeral), 16);
        }
        $output;
        break
      }
      Default {
        [encoding]::Default.GetBytes($string);
      }
    }
    return $array
  }
  static [byte[]] ToBytes([object]$obj) {
    return [xconvert]::ToBytes($obj, $false)
  }
  static [byte[]] ToBytes([object]$obj, [bool]$protect) {
    if ($null -eq $obj) { return $null }; $bytes = $null; $type = $obj.GetType();
    $bytes = switch ($type.Name) {
      'byte[]' {
        [byte[]]$obj; break
      }
      'Stream' {
        $ms = [MemoryStream]::new();
        $obj.CopyTo($ms);
        $arr = $ms.ToArray();
        if ($null -ne $ms) { $ms.Flush(); $ms.Close(); $ms.Dispose() } else { Write-Warning "[x] MemoryStream was Not closed!" };
        $arr;
        break
      }
      'BitArray' {
        [xconvert]::FromBitArray([xconvert]::ToBitArrayString($obj));
        break
      }
      Default {
        $str = $(try {
            if ($type -ne [string]) {
              [xconvert]::ToString($obj)
            } else {
              [string]$obj
            }
          } catch { $null }
        );
        if ([string]::IsNullOrEmpty($str)) {
          [xconvert]::ToSerialized($obj)
        } else {
          [xconvert]::ToBytes($str)
        }
      }
    }
    if ($protect) {
      $bytes = [byte[]][xconvert]::ToProtected($bytes);
    }
    return $bytes
  }
  static [byte[]] ToSerialized($Obj) {
    return [xconvert]::ToSerialized($Obj, $false)
  }
  static [byte[]] ToSerialized($Obj, [bool]$Force) {
    $bytes = $null
    # Todo: Run tests to see if [PSSerializer]::Serialize() can do better.
    # When deseri~zr is using: [PSSerializer]::Deserialize() or [PSSerializer]::DeserializeAsList()
    try {
      # Serialize the object using binaryFormatter: https://docs.microsoft.com/en-us/dotnet/api/system.runtime.serialization.formatters.binary.binaryformatter?
      $formatter = New-Object -TypeName System.Runtime.Serialization.Formatters.Binary.BinaryFormatter
      $stream = New-Object -TypeName System.IO.MemoryStream
      $formatter.Serialize($stream, $Obj) # Serialise the graph
      $bytes = $stream.ToArray(); $stream.Close(); $stream.Dispose()
    } catch [MethodInvocationException], [SerializationException] {
      #Object can't be serialized, Lets try Marshalling: https://docs.microsoft.com/en-us/dotnet/api/System.Runtime.InteropServices.Marshal?
      $TypeName = $obj.GetType().Name; $obj = $obj -as $TypeName
      if ($obj -isnot [ISerializable] -and $TypeName -in ("securestring", "Pscredential", "CredManaged")) { throw [MethodInvocationException]::new("Cannot serialize an unmanaged structure") }
      if ($Force) {
        # Import the System.Runtime.InteropServices.Marshal namespace
        Add-Type -AssemblyName System.Runtime
        [int]$size = [Marshal]::SizeOf($obj); $bytes = [byte[]]::new($size);
        [IntPtr]$ptr = [Marshal]::AllocHGlobal($size);
        [void][Marshal]::StructureToPtr($obj, $ptr, $false);
        [void][Marshal]::Copy($ptr, $bytes, 0, $size);
        [void][Marshal]::FreeHGlobal($ptr); # Free the memory allocated for the serialized object
      } else {
        throw [SerializationException]::new("Serialization error. Make sure the object is marked with the [System.SerializableAttribute] or is Serializable.")
      }
    } catch {
      throw $_.Exception
    }
    return $bytes
  }
  static [Object[]] FromBytes([byte[]]$data) {
    # Deserialize the byte array
    if ($null -eq $data) { return $null }
    $bf = [Formatters.Binary.BinaryFormatter]::new()
    $ms = [MemoryStream]::new(); $Obj = $null
    $ms.Write($data, 0, $data.Length);
    [void]$ms.Seek(0, [SeekOrigin]::Begin);
    try {
      $Obj = [object]$bf.Deserialize($ms)
    } catch [MethodInvocationException], [SerializationException] {
      $Obj = $ms.ToArray()
    } catch {
      throw $_.Exception
    } finally {
      $ms.Dispose(); $ms.Close()
    }
    # Output the deserialized object
    return $Obj
  }
  static [Object[]] FromBytes([byte[]]$data, [bool]$Unprotect) {
    if ($null -eq $data) { return $null }
    if ($Unprotect) {
      return [xconvert]::FromBytes([byte[]][xconvert]::FromProtected($data))
    }
    return [xconvert]::FromBytes($data);
  }
  static [BitArray] ToBitArray([string]$string) {
    return [xconvert]::ToBitArray([xconvert]::ToBytes($string))
  }
  static [BitArray] ToBitArray([byte[]]$Bytes) {
    return [BitArray]::new($Bytes)
  }
  static [string] ToBitArrayString([byte[]]$Bytes) {
    return [xconvert]::ToBitArrayString($Bytes, $true);
  }
  static [string] ToBitArrayString([byte[]]$Bytes, [bool]$Tidy) {
    $b = [BitArray]::new($Bytes);
    return [xconvert]::ToBitArrayString($b, $Tidy);
  }
  static [string] ToBitArrayString([BitArray]$binary) {
    $BinStR = [string]::Empty # (Binary String)
    for ($i = 0; $i -lt $binary.Length; $i++) {
      if ($binary[$i]) {
        $BinStR += "1 ";
      } else {
        $BinStR += "0 ";
      }
    }
    return $BinStR.Trim()
  }
  static [string] ToBitArrayString([BitArray]$binary, [bool]$Tidy) {
    [string]$binStr = [xconvert]::ToBitArrayString($binary)
    if ($Tidy) { $binStr = [string]::Join('', $binStr.Split()) }
    return $binStr
  }
  static [string] ToBitArrayString ([string]$string) {
    return [xconvert]::ToBitArrayString($string, $false)
  }
  static [string] ToBitArrayString ([string]$string, [bool]$Tidy) {
    [string]$BinStR = [string]::Empty;
    foreach ($ch In $string.ToCharArray()) {
      $BinStR += [Convert]::ToString([int]$ch, 2).PadLeft(8, '0');
    }
    return [xconvert]::ToBitArrayString([xconvert]::FromBitArray($BinStR), $Tidy)
  }
  static [byte[]] FromBitArray([string]$binary) {
    $binary = [string]::Join('', $binary.Split())
    $length = $binary.Length; if ($length % 8 -ne 0) {
      Throw [InvalidDataException]::new("Your string is invalid. Make sure it has no typos.")
    }
    $list = [Generic.List[Byte]]::new()
    for ($i = 0; $i -lt $length; $i += 8) {
      [string]$binStr = $binary.Substring($i, 8)
      [void]$list.Add([Convert]::ToByte($binStr, 2));
    }
    return $list.ToArray();
  }
  static [Object[]] ToOrdered($InputObject) {
    $obj = $InputObject
    $convert = [scriptBlock]::Create({
        Param($obj)
        if ($obj -is [PSCustomObject]) {
          # a custom object: recurse on its properties
          $oht = [ordered]@{}
          foreach ($prop in $obj.psobject.Properties) {
            $oht.Add($prop.Name, $(Invoke-Command -ScriptBlock $convert -ArgumentList $prop.Value))
          }
          return $oht
        } elseif ($obj -isnot [string] -and $obj -is [IEnumerable] -and $obj -isnot [IDictionary]) {
          # A collection of sorts (other than a string or dictionary (hash table)), recurse on its elements.
          return @(foreach ($el in $obj) { Invoke-Command -ScriptBlock $convert -ArgumentList $el })
        } else {
          # a non-custom object, including .NET primitives and strings: use as-is.
          return $obj
        }
      }
    )
    return $(Invoke-Command -ScriptBlock $convert -ArgumentList $obj)
  }
  static [object] ToObject([IO.FileInfo]$File) {
    return [xconvert]::ToObject($File.FullName, $false)
  }
  static [object] ToObject([IO.FileInfo]$File, [string]$Type) {
    return [xconvert]::ToObject($File.FullName, $Type, $false);
  }
  static [object] ToObject([IO.FileInfo]$File, [bool]$Decrypt) {
    $FilePath = [xget]::ResolvedPath($File.FullName); $Object = $null
    try {
      if ($Decrypt) { $(Get-Item $FilePath).Decrypt() }
      $Object = Import-Clixml -Path $FilePath
    } catch {
      Write-Error $_
    }
    return $Object
  }
  static [object] ToObject([IO.FileInfo]$File, [string]$Type, [bool]$Decrypt) {
    $FilePath = [xget]::ResolvedPath($File.FullName); $Object = $null
    try {
      if ($Decrypt) { $(Get-Item $FilePath).Decrypt() }
      $Object = (Import-Clixml -Path $FilePath) -as "$Type"
    } catch {
      Write-Error $_
    }
    return $Object
  }
  static [IO.FileInfo] FromObject($Object, [string]$OutFile) {
    return [xconvert]::FromObject($Object, $OutFile, $false);
  }
  static [IO.FileInfo] FromObject($Object, [string]$OutFile, [bool]$encrypt) {
    $OutFile = $null
    try {
      $OutFile = [xget]::UnResolvedPath($OutFile)
      try {
        $resolved = [xget]::ResolvedPath($OutFile);
        if ($?) { $OutFile = $resolved }
      } catch [ItemNotFoundException] {
        New-Item -Path $OutFile -ItemType File | Out-Null
      } catch {
        throw $_
      }
      Export-Clixml -InputObject $Object -Path $OutFile
      $OutFile = Get-Item $OutFile
      if ($encrypt) { $OutFile.Encrypt() }
    } catch {
      Write-Error $_
    }
    return $OutFile
  }
  static [string] ToAnsi([string]$HtmlCode) {
    [ValidatePattern('^#\w{6}$')][string]$HtmlCode = $HtmlCode
    $code = [System.Drawing.ColorTranslator]::FromHtml($htmlCode)
    $ansi = '[38;2;{0};{1};{2}m' -f $code.R, $code.G, $code.B
    return $ansi
  }
  static [string] FromAnsi([string]$AnsiCode) {
    # Validate and extract RGB values from ANSI code
    if ($AnsiCode -notmatch '^\[38;2;(\d{1,3});(\d{1,3});(\d{1,3})m$') {
      throw [System.ArgumentException]::new("Invalid ANSI color code format. Expected format: [38;2;R;G;B]m")
    }
    # Extract RGB values
    $r = [int]$Matches[1]
    $g = [int]$Matches[2]
    $b = [int]$Matches[3]
    # Validate RGB ranges
    if (($r -lt 0 -or $r -gt 255) -or ($g -lt 0 -or $g -gt 255) -or ($b -lt 0 -or $b -gt 255)) {
      throw [System.ArgumentException]::new("RGB values must be between 0 and 255")
    }
    # Convert to HTML hex code
    $color = [System.Drawing.Color]::FromArgb($r, $g, $b)
    $htmlCode = [System.Drawing.ColorTranslator]::ToHtml($color)
    return $htmlCode
  }
  static [datetime] ToUtcDate([datetime]$Date) {
    return [xconvert]::ToUtcDate(@($Date))[0]
  }
  static [datetime[]] ToUtcDate([datetime[]]$Date) {
    $strCurrentTimeZone = (Get-CimInstance -ClassName win32_timezone).StandardName
    Write-Verbose "Your local timezone is '$((Get-CimInstance -ClassName win32_timezone).Description)'"
    $TZ = [TimeZoneInfo]::FindSystemTimeZoneById($strCurrentTimeZone); $result = @()
    foreach ($currentDate in $Date) {
      $newUTCTime = Get-Date -Date $currentDate
      Write-Verbose -Message "You entered a UTC Time of: [$currentDate]"
      $result += [TimeZoneInfo]::ConvertTimeFromUtc($newUTCTime, $TZ)
    }
    return $result
  }
  static [datetime] FromUtcDate([datetime]$Date) {
    return [xconvert]::FromUtcDate(@($Date))[0]
  }
  static [datetime[]] FromUtcDate([datetime[]]$Date) {
    # [xconvert]::FromUT("1/25/2018 1:34:31 PM")
    $strCurrentTimeZone = (Get-CimInstance -ClassName win32_timezone).StandardName
    Write-Verbose "Your local timezone is '$((Get-CimInstance -ClassName win32_timezone).Description)'"
    $TZ = [TimeZoneInfo]::FindSystemTimeZoneById($strCurrentTimeZone); $result = @()
    foreach ($currentDate in $Date) {
      $newUTCTime = Get-Date -Date $currentDate
      $result += [TimeZoneInfo]::ConvertTimeFromUtc($newUTCTime, $TZ)
    }
    return $result
  }
  static [datetime] ToDateTime([String]$DateString) {
    return [xconvert]::ToDateTime(@($DateString), $false)[0]
  }
  static [datetime[]] ToDateTime([String[]]$DateString, [bool]$UTC) {
    return [xconvert]::ToDateTime($DateString, [dateFormat]::UNKNOWN, $UTC)
  }
  static [datetime[]] ToDateTime([String[]]$DateString, [dateFormat]$Format, [bool]$UTC) {
    # .LINK
    # https://docs.microsoft.com/en-us/windows/desktop/wmisdk/cim-datetime
    $BeginUnixEpoch = New-Object -TypeName DateTime -ArgumentList 1970, 1, 1, 0, 0, 0, ([DateTimeKind]::Utc)
    #$DmtfRegex = '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\.[0-9][0-9][0-9][0-9][0-9][0-9][+-][0-9][0-9][0-9]'
    $DmtfRegex = '^(\d{14})\.(\d{6})[+-](\d{3})$'
    $MaxTicks = 2650467743999999999
    $Never = 9223372036854775807
    $ICSDateTimeregexp = '^(\d{8})(T)(\d{6})(Z)?$'
    $ISOregex = '^(\d{4}\.\d{2}\.\d{2})(T)(\d{2}:\d{2}:\d{2})(Z)?$'
    # Your local timezone is : $strCurrentTimeZone = (Get-CimInstance -ClassName win32_timezone -Verbose:$false).Description
    $result = @();
    foreach ($DS in $DateString) {
      $ReturnVal = switch ($Format.ToString()) {
        'DMTF' {
          if ($DS -match $DmtfRegex) {
            $ReturnVal = ([Management.ManagementDateTimeConverter]::ToDateTime("$DS"))
          } else {
            Out-Verbose "The DMTF date time should be of the form 'YYYYMMDDHHmmss.ffffff+###'"
          }
          break
        }
        'Unix' {
          [xconvert]::FromUtcDate($BeginUnixEpoch.AddSeconds($DS))
          break
        }
        'FileTime' {
          if ([int64]$DS -gt $MaxTicks ) {
            if ([int64]$DS -eq $Never ) {
              [datetime]::MaxValue
            } else {
              'Invalid'
            }
          } else {
            [datetime]::FromFileTime($DS)
          }
          break
        }
        'ICSDateTime' {
          if ($DS -match $IcsDateTimeregexp) {
            if ( $matches[4]) {
              # the ICS datetime ends with 'Z'
              [datetime]::parseexact($DS, 'yyyyMMddTHHmmssZ', $null)
            } else {
              [datetime]::parseexact($DS, 'yyyyMMddTHHmmss', $null)
            }
          } else {
            Write-Verbose "The ICS date time should be of the form 'yyyymmddTHHMMSSZ'"
            'Invalid'
          }
          break
        }
        'ISO8601' {
          if ($DS -match $ISOregex) {
            if ( $matches[4]) {
              [datetime]::parseexact($DS, 'yyyy.MM.ddTHH:mm:ssZ', $null)
            } else {
              [datetime]::parseexact($DS, 'yyyy.MM.ddTHH:mm:ss', $null)
            }
          } else {
            'Invalid'
          }
          break
        }
        'Excel' {
          (Get-Date -Date 1/1/1900 ) + [timespan]::FromDays($DS)
          break
        }
        Default {
          $r = $DS -as [DateTime]
          if ($r -is [DateTime]) { $r } else {
            # Dynamically detect the system's date and time format and use it to parse the $dateString.
            [string[]]$dateFormats = [System.Threading.Thread]::CurrentThread.CurrentCulture.DateTimeFormat.GetAllDateTimePatterns()
            [System.IFormatProvider]$formatProvider = [System.Globalization.CultureInfo]::InvariantCulture
            $dateFormats.ForEach({
                try {
                  [datetime]::ParseExact($DS, $_, $formatProvider)
                } catch {
                  $null
                }
              }
            ).where({ $null -ne $_ })[0]
          }
        }
      }
      if ($ReturnVal -ne 'Invalid' -and $UTC) {
        $ReturnVal = [xconvert]::ToUtcDate($ReturnVal)
      }
      $result += $ReturnVal
    }
    return $result
  }
  [string[]] ToUrlEncode([string[]]$URLs) {
    $Encoded = @(); foreach ($str in $URLs) {
      $Encoded += [System.Web.HttpUtility]::UrlEncode($str)
    }
    return $Encoded
  }
  [string[]] ToUncPath([string]$Path) {
    # Convert a local file path and a computer name to a network UNC path.
    [string[]] $CN = @(); $CN += $env:COMPUTERNAME; $UNC = @()
    foreach ($Computer in $CN) {
      $RemoteFilePathDrive = ($Path | Split-Path -Qualifier).TrimEnd(':')
      $UNC += "\\$Computer\$RemoteFilePathDrive`$$($Path | Split-Path -NoQualifier)"
    }
    return $UNC
  }
  [string] ToTitleCase([string]$Text) {
    $low = $text.toLower()
    return (Get-Culture).TextInfo.ToTitleCase($low)
  }
  [string] ToIndented([string]$ScriptText) {
    $CurrentLevel = 0
    $ParseError = $null
    $Tokens = $null
    [void][Language.Parser]::ParseInput($ScriptText, [ref]$Tokens, [ref]$ParseError)
    if ($ParseError) {
      $ParseError | Write-Error
      throw 'The parser will not work properly with errors in the script, please modify based on the above errors and retry.'
    }
    for ($t = $Tokens.Count - 2; $t -ge 1; $t--) {
      $Token = $Tokens[$t]
      $NextToken = $Tokens[$t - 1]
      if ($token.Kind -match '(L|At)Curly') {
        $CurrentLevel--
      }
      if ($NextToken.Kind -eq 'NewLine' ) {
        # Grab Placeholders for the Space Between the New Line and the next token.
        $Rem_Start = $NextToken.Extent.EndOffset
        $RemoveEnd = $Token.Extent.StartOffset - $Rem_Start
        $_Indented = "`t" * $CurrentLevel
        $ScriptText = $ScriptText.Remove($Rem_Start, $RemoveEnd).Insert($Rem_Start, $_Indented)
      }
      if ($token.Kind -eq 'RCurly') { $CurrentLevel++ }
    }
    return $ScriptText
  }
  [System.TimeSpan[]] ToTimeSpan([string[]]$timespanStr) {
    return ($timespanStr | Select-Object *, @{name = 'Hour'; Expression = { $_.Split(":")[0] } }, @{name = 'Minute'; Expression = { $_.Split(":")[1] } }, @{name = 'Second'; Expression = { $_.Split(":")[2] } } | Select-Object @{n = 'timeSpan'; e = { New-TimeSpan -Hours $_.Hour -Minutes $_.Minute -Seconds $_.Second } }).timeSpan
  }
  static [string] ToReverse([string]$text) {
    [char[]]$array = $text.ToCharArray(); [array]::Reverse($array);
    return [String]::new($array);
  }
}
# Install   ....
# Uninstall: cmd.exe /c del /f/q "%USERPROFILE%\AppData\Roaming\Microsoft\Windows\SendTo\xconvert.bat"
#endregion Classes

#region    functions
function script:Get-xconvertdata {
  # .SYNOPSIS
  # Gets values for [xconvert]::LocalizedData
  [CmdletBinding()]
  [OutputType([PsObject])]
  param (
    [Parameter(Position = 0, Mandatory = $false, ValueFromPipeline = $true)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$Path,

    [Parameter(Position = 1, Mandatory = $false)]
    [AllowNull()][Alias('Property')]
    [string]$PropertyName = $null
  )
  begin {
    if (!$PSBoundParameters.ContainsKey("Path")) {
      # [void][Directory]::SetCurrentDirectory($PSScriptRoot)
      $CultureName = [System.Threading.Thread]::CurrentThread.CurrentCulture.Name
      $Path = [IO.Path]::Combine($PSScriptRoot, $CultureName, 'cliHelper.xconvert.strings.psd1')
    }
  }
  process {
    if ([string]::IsNullOrWhiteSpace($PropertyName)) {
      $null = Get-Item -Path $Path -ErrorAction Stop
      $data = New-Object PsObject; $text = [IO.File]::ReadAllText("$Path")
      $data = [scriptblock]::Create("$text").Invoke()
      return $data
    }
    $Tokens = $Null; $ParseErrors = $Null
    # search the Manifest root properties, and also the nested hashtable properties.
    if ([IO.Path]::GetExtension($_) -ne ".psd1") { throw "Path must point to a .psd1 file" }
    if (!(Test-Path $Path)) {
      $Error_params = @{
        ExceptionName    = "ItemNotFoundException"
        ExceptionMessage = "Can't find file $Path"
        ErrorId          = "PathNotFound,Metadata\Import-Metadata"
        Caller           = $PSCmdlet
        ErrorCategory    = "ObjectNotFound"
      }
      Write-TerminatingError @Error_params
    }
    $AST = [Parser]::ParseFile($Path, [ref]$Tokens, [ref]$ParseErrors)
    $KeyValue = $Ast.EndBlock.Statements
    $KeyValue = @([xget]::FindHashKeyValue($PropertyName, $KeyValue))
    if ($KeyValue.Count -eq 0) {
      $Error_params = @{
        ExceptionName    = "ItemNotFoundException"
        ExceptionMessage = "Can't find '$PropertyName' in $Path"
        ErrorId          = "PropertyNotFound,Metadata\Get-Metadata"
        Caller           = $PSCmdlet
        ErrorCategory    = "ObjectNotFound"
      }
      Write-TerminatingError @Error_params
    }
    if ($KeyValue.Count -gt 1) {
      $SingleKey = @($KeyValue | Where-Object { $_.HashKeyPath -eq $PropertyName })
      if ($SingleKey.Count -gt 1) {
        $Error_params = @{
          ExceptionName    = "System.Reflection.AmbiguousMatchException"
          ExceptionMessage = "Found more than one '$PropertyName' in $Path. Please specify a dotted path instead. Matching paths include: '{0}'" -f ($KeyValue.HashKeyPath -join "', '")
          ErrorId          = "AmbiguousMatch,Metadata\Get-Metadata"
          Caller           = $PSCmdlet
          ErrorCategory    = "InvalidArgument"
        }
        Write-TerminatingError @Error_params
      } else {
        $KeyValue = $SingleKey
      }
    }
    $KeyValue = $KeyValue[0]
    # $KeyValue.SafeGetValue()
    return $KeyValue
  }
}
#endregion functions

# Types that will be available to users when they import the module.
$typestoExport = @(
  [EncodKit],
  [xconvert],
  [Base85],
  [Base58],
  [Base32],
  [xget]
)
$TypeAcceleratorsClass = [psobject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
foreach ($Type in $typestoExport) {
  if ($Type.FullName -in $TypeAcceleratorsClass::Get.Keys) {
    $Message = @(
      "Unable to register type accelerator '$($Type.FullName)'"
      'Accelerator already exists.'
    ) -join ' - '

    throw [ErrorRecord]::new(
      [System.InvalidOperationException]::new($Message),
      'TypeAcceleratorAlreadyExists',
      [ErrorCategory]::InvalidOperation,
      $Type.FullName
    )
  }
}
# Add type accelerators for every exportable type.
foreach ($Type in $typestoExport) {
  $TypeAcceleratorsClass::Add($Type.FullName, $Type)
}
# Remove type accelerators when the module is removed.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
  foreach ($Type in $typestoExport) {
    $TypeAcceleratorsClass::Remove($Type.FullName)
  }
}.GetNewClosure();

$Private = @(); # $Private = Get-ChildItem ([IO.Path]::Combine($PSScriptRoot, 'Private')) -Filter "*.ps1" -ErrorAction SilentlyContinue
$Public = Get-ChildItem ([IO.Path]::Combine($PSScriptRoot, 'Public')) -Filter "*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $($Public, $Private)) {
  Try {
    if ([string]::IsNullOrWhiteSpace($file.fullname)) { continue }
    . "$($file.fullname)"
  } Catch {
    Write-Warning "Failed to import function $($file.BaseName): $_"
    $host.UI.WriteErrorLine($_)
  }
}

Export-ModuleMember -Function $Public.BaseName -Alias * -Verbose
