using namespace System.IO
using namespace System.Text

enum EncodingName {
  Base85
  Base58
  Base16
}

class EncodingBase : System.Text.ASCIIEncoding {
  EncodingBase() {}
  static [byte[]] GetBytes([string] $text) {
    return [EncodingBase]::new().GetBytes($text)
  }
  static [string] GetString([byte[]]$bytes) {
    return [EncodingBase]::new().GetString($bytes)
  }
  static [char[]] GetChars([byte[]]$bytes) {
    return [EncodingBase]::new().GetChars($bytes)
  }
}
#region    Base85
# .SYNOPSIS
#     Base85 encoding
# .DESCRIPTION
#     A binary-to-text encoding scheme that uses 85 printable ASCII characters to represent binary data
# .EXAMPLE
#     $b = [System.Text.Encoding]::UTF8.GetBytes("Hello world")
#     [base85]::Encode($b)
#     [System.Text.Encoding]::UTF8.GetString([base85]::Decode("87cURD]j7BEbo7"))
# .EXAMPLE
#     [Base85]::GetString([Base85]::Decode([Base85]::Encode('Hello world!'))) | Should -Be 'Hello world!'
class Base85 : EncodingBase {
  static [String] $NON_A85_Pattern = "[^\x21-\x75]"

  Base85() {}
  static [string] Encode([string]$text) {
    return [Base85]::Encode([Base85]::new().GetBytes($text), $false)
  }
  static [string] Encode([byte[]]$Bytes) {
    return [Base85]::Encode($Bytes, $false)
  }
  static [string] Encode([byte[]]$Bytes, [bool]$Format) {
    # Using Format means we'll add "<~" Prefix and "~>" Suffix marks to output text
    [System.IO.Stream]$InputStream = New-Object -TypeName System.IO.MemoryStream(, $Bytes)
    [System.Object]$Timer = [System.Diagnostics.Stopwatch]::StartNew()
    [System.Object]$BinaryReader = New-Object -TypeName System.IO.BinaryReader($InputStream)
    [System.Object]$Ascii85Output = New-Object -TypeName System.Text.StringBuilder
    if ($Format) {
      [void]$Ascii85Output.Append("<~")
      [System.UInt16]$LineLen = 2
    }
    $EncodedString = [string]::Empty
    Try {
      Write-Verbose "[base85] Encoding started at $([Datetime]::Now.Add($timer.Elapsed).ToString()) ..."
      While ([System.Byte[]]$BytesRead = $BinaryReader.ReadBytes(4)) {
        [System.UInt16]$ByteLength = $BytesRead.Length
        if ($ByteLength -lt 4) {
          [System.Byte[]]$WorkingBytes = , 0x00 * 4
          [System.Buffer]::BlockCopy($BytesRead, 0, $WorkingBytes, 0, $ByteLength)
          [System.Array]::Resize([ref]$BytesRead, 4)
          [System.Buffer]::BlockCopy($WorkingBytes, 0, $BytesRead, 0, 4)
        }
        if ([BitConverter]::IsLittleEndian) {
          [Array]::Reverse($BytesRead)
        }
        [System.Char[]]$A85Chars = , 0x00 * 5
        [System.UInt32]$Sum = [BitConverter]::ToUInt32($BytesRead, 0)
        [System.UInt16]$ByteLen = [Math]::Ceiling(($ByteLength / 4) * 5)
        if ($ByteLength -eq 4 -And $Sum -eq 0) {
          [System.Char[]]$A85Chunk = "z"
        } else {
          [System.Char[]]$A85Chunk = , 0x00 * $ByteLen
          $A85Chars[0] = [Base85]::GetChars([Math]::Floor(($Sum / [Math]::Pow(85, 4)) % 85) + 33)[0]
          $A85Chars[1] = [Base85]::GetChars([Math]::Floor(($Sum / [Math]::Pow(85, 3)) % 85) + 33)[0]
          $A85Chars[2] = [Base85]::GetChars([Math]::Floor(($Sum / [Math]::Pow(85, 2)) % 85) + 33)[0]
          $A85Chars[3] = [Base85]::GetChars([Math]::Floor(($Sum / 85) % 85) + 33)[0]
          $A85Chars[4] = [Base85]::GetChars([Math]::Floor($Sum % 85) + 33)[0]
          [System.Array]::Copy($A85Chars, $A85Chunk, $ByteLen)
        }
        forEach ($A85Char in $A85Chunk) {
          [void]$Ascii85Output.Append($A85Char)
          if (!$Format) {
            if ($LineLen -eq 64) {
              [void]$Ascii85Output.Append("`r`n")
              $LineLen = 0
            } else {
              $LineLen++
            }
          }
        }
      }
      if ($Format) {
        if ($LineLen -le 62) {
          [void]$Ascii85Output.Append("~>")
        } else {
          [void]$Ascii85Output.Append("~`r`n>")
        }
      }
      $EncodedString = $Ascii85Output.ToString()
    } catch {
      Write-Error "Exception: $($_.Exception.Message)"
      break;
    } finally {
      $BinaryReader.Close()
      $BinaryReader.Dispose()
      $InputStream.Close()
      $InputStream.Dispose()
      $Timer.Stop()
      [String]$TimeLapse = "[base85] Encoding completed in $($Timer.Elapsed.Hours) hours, $($Timer.Elapsed.Minutes) minutes, $($Timer.Elapsed.Seconds) seconds, $($Timer.Elapsed.Milliseconds) milliseconds"
      Write-Verbose $TimeLapse
    }
    return $EncodedString
  }
  static [byte[]] Decode([string]$text) {
    $text = $text.Replace(" ", "").Replace("`r`n", "").Replace("`n", "")
    $decoded = $null; if ($text.StartsWith("<~") -or $text.EndsWith("~>")) {
      $text = $text.Replace("<~", "").Replace("~>", "")
    }
    if ($text -match $([Base85]::NON_A85_Pattern)) {
      Throw "Invalid Ascii85 data detected in input stream."
    }
    [System.Object]$InputStream = New-Object -TypeName System.IO.MemoryStream([System.Text.Encoding]::ASCII.GetBytes($text), 0, $text.Length)
    [System.Object]$BinaryReader = New-Object -TypeName System.IO.BinaryReader($InputStream)
    [System.Object]$OutputStream = New-Object -TypeName System.IO.MemoryStream
    [System.Object]$BinaryWriter = New-Object -TypeName System.IO.BinaryWriter($OutputStream)
    [System.Object]$Timer = [System.Diagnostics.Stopwatch]::StartNew()
    Try {
      Write-Verbose "[base85] Decoding started at $([Datetime]::Now.Add($timer.Elapsed).ToString()) ..."
      While ([System.Byte[]]$BytesRead = $BinaryReader.ReadBytes(5)) {
        [System.UInt16]$ByteLength = $BytesRead.Length
        if ($ByteLength -lt 5) {
          [System.Byte[]]$WorkingBytes = , 0x75 * 5
          [System.Buffer]::BlockCopy($BytesRead, 0, $WorkingBytes, 0, $ByteLength)
          [System.Array]::Resize([ref]$BytesRead, 5)
          [System.Buffer]::BlockCopy($WorkingBytes, 0, $BytesRead, 0, 5)
        }
        [System.UInt16]$ByteLen = [Math]::Floor(($ByteLength * 4) / 5)
        [System.Byte[]]$BinChunk = , 0x00 * $ByteLen
        if ($BytesRead[0] -eq 0x7A) {
          $BinaryWriter.Write($BinChunk)
          [bool]$IsAtEnd = ($BinaryReader.BaseStream.Length -eq $BinaryReader.BaseStream.Position)
          if (!$IsAtEnd) {
            $BinaryReader.BaseStream.Position = $BinaryReader.BaseStream.Position - 4
            Continue
          }
        } else {
          [System.UInt32]$Sum = 0
          $Sum += ($BytesRead[0] - 33) * [Math]::Pow(85, 4)
          $Sum += ($BytesRead[1] - 33) * [Math]::Pow(85, 3)
          $Sum += ($BytesRead[2] - 33) * [Math]::Pow(85, 2)
          $Sum += ($BytesRead[3] - 33) * 85
          $Sum += ($BytesRead[4] - 33)
          [System.Byte[]]$A85Bytes = [System.BitConverter]::GetBytes($Sum)
          if ([BitConverter]::IsLittleEndian) {
            [Array]::Reverse($A85Bytes)
          }
          [System.Buffer]::BlockCopy($A85Bytes, 0, $BinChunk, 0, $ByteLen)
          $BinaryWriter.Write($BinChunk)
        }
      }
      $decoded = $OutputStream.ToArray()
    } catch {
      Write-Error "Exception: $($_.Exception.Message)"
      break
    } finally {
      $BinaryReader.Close()
      $BinaryReader.Dispose()
      $BinaryWriter.Close()
      $BinaryWriter.Dispose()
      $InputStream.Close()
      $InputStream.Dispose()
      $OutputStream.Close()
      $OutputStream.Dispose()
      $Timer.Stop()
      [String]$TimeLapse = "[base85] Decoding completed after $($Timer.Elapsed.Hours) hours, $($Timer.Elapsed.Minutes) minutes, $($Timer.Elapsed.Seconds) seconds, $($Timer.Elapsed.Milliseconds) milliseconds"
      Write-Verbose $TimeLapse
    }
    return $decoded
  }
}

#endregion Base85

#region    base16
class Base16 : EncodingBase {
  static [string] Encode([string]$text) {
    return [Base16]::Encode([System.Text.Encoding]::ASCII.GetBytes($text))
  }
  static [string] Encode([byte[]]$ba) {
    $encoded = $null; $Timer = [System.Diagnostics.Stopwatch]::StartNew();
    Write-Verbose "[Base16] Encoding started at $([Datetime]::Now.Add($timer.Elapsed).ToString()) ..."
    #
    # Base32 encode logic & code goes here
    #
    Write-Verbose "[Base16] Encoding completed in $($Timer.Elapsed.Hours) hours, $($Timer.Elapsed.Minutes) minutes, $($Timer.Elapsed.Seconds) seconds, $($Timer.Elapsed.Milliseconds) milliseconds"
    return $encoded
  }
  static [byte[]] Decode([string]$text) {
    $decoded = $null; $Timer = [System.Diagnostics.Stopwatch]::StartNew();
    Write-Verbose "[Base16] Decoding started at $([Datetime]::Now.Add($timer.Elapsed).ToString()) ..."
    #
    # Base32 decode logic & code goes here
    #
    Write-Verbose "[Base16] Decoding completed in $($Timer.Elapsed.Hours) hours, $($Timer.Elapsed.Minutes) minutes, $($Timer.Elapsed.Seconds) seconds, $($Timer.Elapsed.Milliseconds) milliseconds"
    return $decoded
  }
}
#endregion base16

# .SYNOPSIS
#   Base 32
# .EXAMPLE
#   $e = [Base32]::Encode("Hello world again!")
#   $d = [Base32]::GetString([Base32]::Decode($e))
#   ($d -eq "Hello world again!") -should be $true
class Base32 : EncodingBase {
  static [string] $charset = "abcdefghijklmnopqrstuvwxyz234567"
  static [string] Encode([byte[]]$bytes) {
    return [Base32]::Encode($bytes, $false)
  }
  static [string] Encode([string]$String) {
    return [Base32]::Encode($String, $false)
  }
  static [string] Encode([byte[]]$bytes, [bool]$Formatt) {
    return [Base32]::Encode([MemoryStream]::New($bytes), $Formatt)
  }
  static [string] Encode([string]$String, [bool]$Formatt) {
    return [Base32]::Encode([Encoding]::ASCII.GetBytes($String), $Formatt)
  }
  static [string] Encode([Stream]$Stream, [bool]$Formatt) {
    # .EXAMPLE
    # $b32 = [Base32]::Encode("hello world!")
    # $text = [String]::Join([string]::Empty, [Base32]::ToString([int[]][Base32]::FromBase32String($b32)))
    $BinaryReader = [BinaryReader]::new($Stream); $B32CHARSET = [Base32]::charset
    $Base32Output = [StringBuilder]::new(); $result = [string]::Empty
    # Write-Verbose "[Base32] Encoding started at $([Datetime]::Now.Add($timer.Elapsed).ToString()) ..."
    Try {
      While ([byte[]]$BytesRead = $BinaryReader.ReadBytes(5)) {
        [System.Boolean]$AtEnd = ($BinaryReader.BaseStream.Length -eq $BinaryReader.BaseStream.Position)
        [System.UInt16]$ByteLength = $BytesRead.Length
        if ($ByteLength -lt 5) {
          [byte[]]$WorkingBytes = , 0x00 * 5
          [System.Buffer]::BlockCopy($BytesRead, 0, $WorkingBytes, 0, $ByteLength)
          [Array]::Resize([ref]$BytesRead, 5)
          [System.Buffer]::BlockCopy($WorkingBytes, 0, $BytesRead, 0, 5)
        }
        [System.Char[]]$B32Chars = , 0x00 * 8
        [System.Char[]]$B32Chunk = , "_" * 8
        $B32Chars[0] = ($B32CHARSET[($BytesRead[0] -band 0xF8) -shr 3])
        $B32Chars[1] = ($B32CHARSET[(($BytesRead[0] -band 0x07) -shl 2) -bor (($BytesRead[1] -band 0xC0) -shr 6)])
        $B32Chars[2] = ($B32CHARSET[($BytesRead[1] -band 0x3E) -shr 1])
        $B32Chars[3] = ($B32CHARSET[(($BytesRead[1] -band 0x01) -shl 4) -bor (($BytesRead[2] -band 0xF0) -shr 4)])
        $B32Chars[4] = ($B32CHARSET[(($BytesRead[2] -band 0x0F) -shl 1) -bor (($BytesRead[3] -band 0x80) -shr 7)])
        $B32Chars[5] = ($B32CHARSET[($BytesRead[3] -band 0x7C) -shr 2])
        $B32Chars[6] = ($B32CHARSET[(($BytesRead[3] -band 0x03) -shl 3) -bor (($BytesRead[4] -band 0xE0) -shr 5)])
        $B32Chars[7] = ($B32CHARSET[$BytesRead[4] -band 0x1F])
        [Array]::Copy($B32Chars, $B32Chunk, ([Math]::Ceiling(($ByteLength / 5) * 8)))
        if ($BinaryReader.BaseStream.Position % 8 -eq 0 -and $Formatt -and !$AtEnd) {
          [void]$Base32Output.Append($B32Chunk)
          [void]$Base32Output.Append("`r`n")
        } else {
          [void]$Base32Output.Append($B32Chunk)
        }
      }
      [string]$result = $Base32Output.ToString()
    } catch {
      Write-Error "Exception: $($_.Exception.Message)"
      Break
    } finally {
      $BinaryReader.Close()
      $BinaryReader.Dispose()
      $Stream.Close()
      $Stream.Dispose()
    }
    # Write-Verbose "[Base32] Encoding completed in $($Timer.Elapsed.Hours) hours, $($Timer.Elapsed.Minutes) minutes, $($Timer.Elapsed.Seconds) seconds, $($Timer.Elapsed.Milliseconds) milliseconds"
    return $result
  }
  static [byte[]] Decode([string]$string) {
    [ValidateNotNullOrEmpty()][string]$string = $string;
    $string = $string.ToLower(); $B32CHARSET = [Base32]::charset
    $B32CHARSET_Pattern = "^[A-Z2-7 ]+_*$"; [byte[]]$result = $null
    if (!($string -match $B32CHARSET_Pattern)) {
      Throw "Invalid Base32 data encountered in input stream."
    }
    # Write-Verbose "[Base32] Decoding started at $([Datetime]::Now.Add($timer.Elapsed).ToString()) ..."
    $InputStream = [MemoryStream]::new([Encoding]::UTF8.GetBytes($string), 0, $string.Length)
    $BinaryReader = [BinaryReader]::new($InputStream)
    $OutputStream = [MemoryStream]::new()
    $BinaryWriter = [BinaryWriter]::new($OutputStream)
    Try {
      While ([System.Char[]]$CharsRead = $BinaryReader.ReadChars(8)) {
        [System.Byte[]]$B32Bytes = , 0x00 * 5
        [System.UInt16]$CharLen = 8 - ($CharsRead -Match "_").Count
        [System.UInt16]$ByteLen = [Math]::Floor(($CharLen * 5) / 8)
        [System.Byte[]]$BinChunk = , 0x00 * $ByteLen
        if ($CharLen -lt 8) {
          [System.Char[]]$WorkingChars = , "a" * 8
          [Array]::Copy($CharsRead, $WorkingChars, $CharLen)
          [Array]::Resize([ref]$CharsRead, 8)
          [Array]::Copy($WorkingChars, $CharsRead, 8)
        }
        $B32Bytes[0] = (($B32CHARSET.IndexOf($CharsRead[0]) -band 0x1F) -shl 3) -bor (($B32CHARSET.IndexOf($CharsRead[1]) -band 0x1C) -shr 2)
        $B32Bytes[1] = (($B32CHARSET.IndexOf($CharsRead[1]) -band 0x03) -shl 6) -bor (($B32CHARSET.IndexOf($CharsRead[2]) -band 0x1F) -shl 1) -bor (($B32CHARSET.IndexOf($CharsRead[3]) -band 0x10) -shr 4)
        $B32Bytes[2] = (($B32CHARSET.IndexOf($CharsRead[3]) -band 0x0F) -shl 4) -bor (($B32CHARSET.IndexOf($CharsRead[4]) -band 0x1E) -shr 1)
        $B32Bytes[3] = (($B32CHARSET.IndexOf($CharsRead[4]) -band 0x01) -shl 7) -bor (($B32CHARSET.IndexOf($CharsRead[5]) -band 0x1F) -shl 2) -bor (($B32CHARSET.IndexOf($CharsRead[6]) -band 0x18) -shr 3)
        $B32Bytes[4] = (($B32CHARSET.IndexOf($CharsRead[6]) -band 0x07) -shl 5) -bor ($B32CHARSET.IndexOf($CharsRead[7]) -band 0x1F)
        [System.Buffer]::BlockCopy($B32Bytes, 0, $BinChunk, 0, $ByteLen)
        $BinaryWriter.Write($BinChunk)
      }
      $result = $OutputStream.ToArray()
    } catch {
      Write-Error "Exception: $($_.Exception.Message)"
      Break
    } finally {
      $BinaryReader.Close()
      $BinaryReader.Dispose()
      $BinaryWriter.Close()
      $BinaryWriter.Dispose()
      $InputStream.Close()
      $InputStream.Dispose()
      $OutputStream.Close()
      $OutputStream.Dispose()
    }
    # Write-Verbose "[Base32] Decoding completed in $($Timer.Elapsed.Hours) hours, $($Timer.Elapsed.Minutes) minutes, $($Timer.Elapsed.Seconds) seconds, $($Timer.Elapsed.Milliseconds) milliseconds"
    return $result
  }
}
class Base36 : EncodingBase {
  static [string] $alphabet = "0123456789abcdefghijklmnopqrstuvwxyz"

  static [string] Encode([int]$decNum) {
    $base36Num = ''
    do {
      $remainder = ($decNum % 36)
      $char = [Base36]::alphabet.substring($remainder, 1)
      $base36Num = '{0}{1}' -f $char, $base36Num
      $decNum = ($decNum - $remainder) / 36
    } while ($decNum -gt 0)
    return $base36Num
  }
  static [long] Decode([int]$base36Num) {
    [ValidateNotNullOrEmpty()]$base36Num = $base36Num # Alphadecimal string
    $inputarray = $base36Num.tolower().tochararray()
    [array]::reverse($inputarray)
    [long]$decNum = 0; $pos = 0
    foreach ($c in $inputarray) {
      $decNum += [Base36]::alphabet.IndexOf($c) * [long][Math]::Pow(36, $pos)
      $pos++
    }
    return $decNum
  }
  static [string] Encode([string]$text) {
    return [Base36]::Encode([System.Text.Encoding]::ASCII.GetBytes($text))
  }
  static [string] Encode([byte[]]$ba) {
    $encoded = $null; $Timer = [System.Diagnostics.Stopwatch]::StartNew();
    Write-Verbose "[Base36] Encoding started at $([Datetime]::Now.Add($timer.Elapsed).ToString()) ..."
    #
    # base36 encode logic & code goes here
    #
    Write-Verbose "[Base36] Encoding completed in $($Timer.Elapsed.Hours) hours, $($Timer.Elapsed.Minutes) minutes, $($Timer.Elapsed.Seconds) seconds, $($Timer.Elapsed.Milliseconds) milliseconds"
    return $encoded
  }
  static [byte[]] Decode([string]$text) {
    $decoded = $null
    $Timer = [System.Diagnostics.Stopwatch]::StartNew();
    Write-Verbose "[Base36] Decoding started at $([Datetime]::Now.Add($timer.Elapsed).ToString()) ..."
    #
    # base36 decode logic & code goes here
    #
    Write-Verbose "[Base36] Decoding completed in $($Timer.Elapsed.Hours) hours, $($Timer.Elapsed.Minutes) minutes, $($Timer.Elapsed.Seconds) seconds, $($Timer.Elapsed.Milliseconds) milliseconds"
    return $decoded
  }
}

# .SYNOPSIS
#     Base 58
# .EXAMPLE
#     $e = [Base58]::Encode("Hello world!!")
#     $d = [Base58]::GetString([Base58]::Decode($e))
#     ($d -eq "Hello world!!") -should be $true
class Base58 : EncodingBase {
  static [byte[]] $Bytes = [Base58]::GetBytes('123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz');
  static [string] Encode([string]$text) {
    return [Base58]::Encode([Base58]::GetBytes($text))
  }
  static [string] Encode([byte[]]$ba) {
    $encoded = $null; $b58_size = 2 * ($ba.length)
    $encoded = [byte[]]::New($b58_size)
    $leading_zeroes = [regex]::New("^(0*)").Match([string]::Join([string]::Empty, $ba)).Groups[1].Length
    # $Timer = [System.Diagnostics.Stopwatch]::StartNew();
    # Write-Verbose "[Base58] Encoding started at $([Datetime]::Now.Add($timer.Elapsed).ToString()) ..."
    for ($i = 0; $i -lt $ba.length; $i++) {
      [System.Numerics.BigInteger]$dec_char = $ba[$i]
      for ($z = $b58_size; $z -gt 0; $z--) {
        $dec_char = $dec_char + (256 * $encoded[($z - 1)])
        $encoded[($z - 1)] = $dec_char % 58
        $dec_char = $dec_char / 58
      }
    }
    $mapped = [byte[]]::New($encoded.length)
    for ($i = 0; $i -lt $encoded.length; $i++) {
      $mapped[$i] = [Base58]::Bytes[$encoded[$i]]
    }
    $encoded = [Base58]::GetString($mapped)
    # Write-Verbose "[Base58] Encoding completed in $($Timer.Elapsed.Hours) hours, $($Timer.Elapsed.Minutes) minutes, $($Timer.Elapsed.Seconds) seconds, $($Timer.Elapsed.Milliseconds) milliseconds"
    if ([regex]::New("(1{$leading_zeroes}[^1].*)").Match($encoded).Success) {
      # $encoded equals [regex]::New("(1{$leading_zeroes}[^1].*)").Match($encoded).Groups[1].Value
      return $encoded
    } else {
      throw "error: " + $encoded
    }
  }
  static [byte[]] Decode([string]$text) {
    $leading_ones = [regex]::New("^(1*)").Match($text).Groups[1].Length
    $_bytes = [Base58]::GetBytes($text)
    $mapped = [byte[]]::New($_bytes.length);
    # $Timer = [System.Diagnostics.Stopwatch]::StartNew();
    # Write-Verbose "[Base58] Decoding started at $([Datetime]::Now.Add($timer.Elapsed).ToString()) ..."
    for ($i = 0; $i -lt $_bytes.length; $i++) {
      $char = $_bytes[$i]
      $mapped[$i] = [Base58]::Bytes.IndexOf($char)
    }
    $decoded = [byte[]]::New($_bytes.length)
    for ($i = 0; $i -lt $mapped.length; $i++) {
      [System.Numerics.BigInteger]$b58_char = $mapped[$i]
      for ($z = $_bytes.length; $z -gt 0; $z--) {
        $b58_char = $b58_char + (58 * [Int32]::Parse($decoded[($z - 1)].ToString()))
        $decoded[($z - 1)] = $b58_char % 256
        $b58_char = $b58_char / 256
      }
    }
    $leading_zeroes = [regex]::New("^(0*)").Match([string]::Join([string]::Empty, $decoded)).Groups[1].Length
    $(1..($leading_zeroes - $leading_ones)).ForEach({
        $decoded = $decoded[1..($decoded.Length - 1)]
      }
    )
    # Write-Verbose "[Base58] Decoding completed in $($Timer.Elapsed.Hours) hours, $($Timer.Elapsed.Minutes) minutes, $($Timer.Elapsed.Seconds) seconds, $($Timer.Elapsed.Milliseconds) milliseconds"
    return $decoded
  }
}

# .SYNOPSIS
#     Unix to Unix aka UU Encoding
# .DESCRIPTION
#     The built-in .NET class: System.Net.Mail.Attachment
#     provides support for UUEncoding through the TransferEncoding property,
#     which can be set to TransferEncoding.UUEncode
# .EXAMPLE
#     Test-MyTestFunction -Verbose
#     Explanation of the function or its result. You can include multiple examples with additional .EXAMPLE lines
class UnixtoUnix {
  static [string] Encode([string]$text) {
    return [UnixtoUnix]::Encode([System.Text.Encoding]::ASCII.GetBytes($text))
  }
  static [string] Encode([byte[]]$ba) {
    $encoded = $null; $Timer = [System.Diagnostics.Stopwatch]::StartNew();
    Write-Verbose "[UnixtoUnix] Encoding started at $([Datetime]::Now.Add($timer.Elapsed).ToString()) ..."
    $lineLength = 45  # Specify the desired line length

    for ($i = 0; $i -lt $ba.Length; $i += 3) {
      $chunk = $ba[$i..($i + 2)]
      # Encode the 3 bytes into 4 ASCII characters
      $encoded += [string]::Join('', $(foreach ($b in $chunk) {
            $b += 32
            [char]($b + ($b -band 63))
          }))
    }

    # Add line length character at the beginning of each line
    $encoded = $encoded -split "(.{1,$lineLength})" | ForEach-Object {
      $lineLengthChar = [char]($_.Length + 32)
      "$lineLengthChar$_"
    } -join "`r`n"

    Write-Verbose "[UnixtoUnix] Encoding completed in $($Timer.Elapsed.Hours) hours, $($Timer.Elapsed.Minutes) minutes, $($Timer.Elapsed.Seconds) seconds, $($Timer.Elapsed.Milliseconds) milliseconds"
    return $encoded
  }
  static [byte[]] Decode([string]$text) {
    $decoded = $null
    $Timer = [System.Diagnostics.Stopwatch]::StartNew();
    Write-Verbose "[UnixtoUnix] Decoding started at $([Datetime]::Now.Add($timer.Elapsed).ToString()) ..."
    $lines = $text -split "`r`n"

    foreach ($line in $lines) {
      $lineLength = [int][char]$line[0] - 32
      $lineData = $line.Substring(1)

      for ($i = 0; $i -lt $lineLength; $i += 4) {
        $chunk = $lineData.Substring($i, 4)

        $decoded += $chunk | ForEach-Object {
          [byte](($_[0] - 32) -bor ($_[1] - 32) -shl 6 -bor ($_[2] - 32) -shl 12 -bor ($_[3] - 32) -shl 18)
        }
      }
    }
    Write-Verbose "[UnixtoUnix] Decoding completed in $($Timer.Elapsed.Hours) hours, $($Timer.Elapsed.Minutes) minutes, $($Timer.Elapsed.Seconds) seconds, $($Timer.Elapsed.Milliseconds) milliseconds"
    return $decoded
  }
}


# .SYNOPSIS
#   Fast encoder/decoder toolkit for power-users.
# .DESCRIPTION
#   - Fast encoder/Decoder for
#     - Bat 85 - 91
#     - Base64
#   - Converts file or folder to .bat via makecab.exe compression
#   Why? -> Having a custom data encoder & decoder can be pretty handy.
#   For now its just data-to-txt but in the Future this will be data-to-txt-to-video
#   (as I learn more cool agorithms & tools)
#   With a tool like this You can store your data in a compressed format at a lower
#   cloud storage price.
# .EXAMPLE
#     "some R4ndom text 123`n`t`n432`n!@#$%$ ..." | Out-File file1.txt
#     $file = Get-Item file1.txt
#     [EncodKit]::EncodeFile($file.FullName, $false, "file2.txt")
#     [EncodKit]::DecodeFile("file2.txt")
#     Now contents of file2.txt should be the same as those of file1.txt
# .Notes
#   Keep in mind that encoding a file to a string will increase its size, as the
#   original binary data is being converted to a text representation.
#   This may not be practical for very large files, as it may result in a
#   significantly larger string and
#   may consume more memory. In these cases, it may be more efficient to use a
#   different approach,
#   such as streaming the file in small chunks and encoding each chunk separately.
class EncodKit {
  static [EncodingName] $DefaultEncoding = 'Base85'

  static [void] EncodeFile([string]$FilePath) {
    [EncodKit]::EncodeFile($FilePath, $false, $FilePath);
  }
  static [void] EncodeFile([string]$FilePath, [bool]$obfuscate) {
    [EncodKit]::EncodeFile($FilePath, $obfuscate, $FilePath)
  }
  static [void] EncodeFile([string]$FilePath, [bool]$obfuscate, [string]$OutFile) {
    [EncodKit]::EncodeFile($FilePath, $obfuscate, $OutFile, [EncodKit]::DefaultEncoding)
  }
  static [void] EncodeFile([string]$FilePath, [bool]$obfuscate, [string]$OutFile, [EncodingName]$encoding) {
    [ValidateNotNullOrEmpty()][string]$FilePath = [EncodKit]::GetResolvedPath($FilePath);
    [ValidateNotNullOrEmpty()][string]$OutFile = [EncodKit]::GetUnResolvedPath($OutFile);
    $streamReader = [System.IO.FileStream]::new($FilePath, [System.IO.FileMode]::Open)
    $ba = [byte[]]::New($streamReader.Length)
    [void]$streamReader.Read($ba, 0, [int]$streamReader.Length);
    [void]$streamReader.Close();
    $encodedString = $(switch ($encoding.ToString()) {
        'Base85' { [Base85]::Encode($ba) }
        'Base58' { [Base58]::Encode($ba) }
        'Base32' {}
        'Base16' {}
        Default {
          [Base85]::Encode($ba)
        }
      }
    )
    $encodedBytes = [EncodKit]::GetBytes($encodedString);
    if ($obfuscate) { [array]::Reverse($encodedBytes) }
    $streamWriter = [System.IO.FileStream]::new($OutFile, [System.IO.FileMode]::OpenOrCreate);
    [void]$streamWriter.Write($encodedBytes, 0, $encodedBytes.Length);
    [void]$streamWriter.Close()
  }
  static [void] DecodeFile([string]$FilePath) {
    [EncodKit]::DecodeFile($FilePath, $false, $FilePath);
  }
  static [void] DecodeFile([string]$FilePath, [bool]$obfuscate) {
    [EncodKit]::DecodeFile($FilePath, $obfuscate, $FilePath)
  }
  static [void] DecodeFile([string]$FilePath, [bool]$obfuscate, [string]$OutFile) {
    [EncodKit]::DecodeFile($FilePath, $obfuscate, $OutFile, [EncodKit]::DefaultEncoding)
  }
  static [void] DecodeFile([string]$FilePath, [bool]$deObfuscate, [string]$OutFile, [EncodingName]$encoding) {
    [ValidateNotNullOrEmpty()][string]$FilePath = [EncodKit]::GetResolvedPath($FilePath);
    [ValidateNotNullOrEmpty()][string]$OutFile = [EncodKit]::GetUnResolvedPath($OutFile);
    $ba = [byte[]][IO.FILE]::ReadAllBytes($FilePath)
    if ($deObfuscate) { [array]::Reverse($ba) }
    $encodedString = [EncodKit]::GetString($ba)
    [void][IO.FILE]::WriteAllBytes($OutFile, $(switch ($encoding.ToString()) {
          'Base85' { [Base85]::Decode($encodedString) }
          'Base58' { [Base58]::Decode($encodedString) }
          'Base32' {}
          'Base16' {}
          Default {
            [Base85]::Decode($encodedString)
          }
        }
      )
    )
  }
  static [string] GetResolvedPath([string]$Path) {
    return [EncodKit]::GetResolvedPath($((Get-Variable ExecutionContext).Value.SessionState), $Path)
  }
  static [string] GetResolvedPath([System.Management.Automation.SessionState]$session, [string]$Path) {
    $paths = $session.Path.GetResolvedPSPathFromPSPath($Path);
    if ($paths.Count -gt 1) {
      throw [System.IO.IOException]::new([string]::Format([cultureinfo]::InvariantCulture, "Path {0} is ambiguous", $Path))
    } elseif ($paths.Count -lt 1) {
      throw [System.IO.IOException]::new([string]::Format([cultureinfo]::InvariantCulture, "Path {0} not Found", $Path))
    }
    return $paths[0].Path
  }
  static [string] GetUnResolvedPath([string]$Path) {
    return [EncodKit]::GetUnResolvedPath($((Get-Variable ExecutionContext).Value.SessionState), $Path)
  }
  static [string] GetUnResolvedPath([System.Management.Automation.SessionState]$session, [string]$Path) {
    return $session.Path.GetUnresolvedProviderPathFromPSPath($Path)
  }
  static [byte[]] GetBytes([string]$text) {
    return [EncodingBase]::new().GetBytes($text)
  }
  static [string] GetString([byte[]]$bytes) {
    return [EncodingBase]::new().GetString($bytes)
  }
}

class xObOptions {
  [bool]$SkipDefaults = $true
  [string[]]$PropstoExclude
  [string[]]$PropstoInclude
  hidden [string[]]$Values
  [int]$MaxDepth = 10
}

class xgen {
  static [xObOptions] $Options = [xObOptions]::new()
  # Use a cryptographic hash function (SHA-256) to generate a unique machine ID
  static [string] UniqueMachineId() {
    $Id = [string]($Env:MachineId)
    $vp = (Get-Variable VerbosePreference).Value
    try {
      Set-Variable VerbosePreference -Value $([System.Management.Automation.ActionPreference]::SilentlyContinue)
      $sha256 = [System.Security.Cryptography.SHA256]::Create()
      $HostOS = $(if ($(Get-Variable PSVersionTable -Value).PSVersion.Major -le 5 -or $(Get-Variable IsWindows -Value)) { "Windows" }elseif ($(Get-Variable IsLinux -Value)) { "Linux" }elseif ($(Get-Variable IsMacOS -Value)) { "macOS" }else { "UNKNOWN" });
      if ($HostOS -eq "Windows") {
        if ([string]::IsNullOrWhiteSpace($Id)) {
          $machineId = Get-CimInstance -ClassName Win32_ComputerSystemProduct | Select-Object -ExpandProperty UUID
          Set-Item -Path Env:\MachineId -Value $([convert]::ToBase64String($sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($machineId))));
        }
        $Id = [string]($Env:MachineId)
      } elseif ($HostOS -eq "Linux") {
        # $Id = (sudo cat /sys/class/dmi/id/product_uuid).Trim() # sudo prompt is a nono
        # Lets use mac addresses
        $Id = ([string[]]$(ip link show | grep "link/ether" | awk '{print $2}') -join '-').Trim()
        $Id = [convert]::ToBase64String($sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Id)))
      } elseif ($HostOS -eq "macOS") {
        $Id = (system_profiler SPHardwareDataType | Select-String "UUID").Line.Split(":")[1].Trim()
        $Id = [convert]::ToBase64String($sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Id)))
      } else {
        throw "Error: HostOS = '$HostOS'. Could not determine the operating system."
      }
    } catch {
      throw $_
    } finally {
      $sha256.Clear(); $sha256.Dispose()
      Set-Variable VerbosePreference -Value $vp
    }
    return $Id
  }
  static [string[]] ListProperties([System.Object]$Obj) {
    return [xgen]::ListProperties($Obj, '')
  }
  static [string[]] ListProperties([System.Object]$Obj, [string]$Prefix = '') {
    $Properties = @()
    $Obj.PSObject.Properties | ForEach-Object {
      $PropertyName = $_.Name
      $FullPropertyName = if ([string]::IsNullOrEmpty($Prefix)) {
        $PropertyName
      } else {
        "$Prefix,$PropertyName"
      }
      $PropertyValue = $_.Value
      $propertyType = $_.TypeNameOfValue
      # $BaseType = $($propertyType -as 'type').BaseType.FullName
      if ($propertyType -is [System.ValueType]) {
        Write-Verbose "vt <= $propertyType"
        $Properties += $FullPropertyName
      } elseif ($propertyType -is [System.Object]) {
        Write-Verbose "ob <= $propertyType"
        $Properties += [xgen]::ListProperties($PropertyValue, $FullPropertyName)
      }
    }
    return $Properties
  }
  static [Object[]] ExcludeProperties($Object) {
    return [xgen]::ExcludeProperties($Object, [xgen]::Options.PropstoExclude)
  }
  static [Object[]] ExcludeProperties($Object, [string[]]$PropstoExclude) {
    $DefaultTypeProps = @()
    if ([xgen]::Options.SkipDefaults) {
      try {
        $DefaultTypeProps = @( $Object.GetType().GetProperties() | Select-Object -ExpandProperty Name -ErrorAction Stop )
      } Catch {
        $null
      }
    }
    $allPropstoExclude = @( $PropstoExclude + $DefaultTypeProps ) | Select-Object -Unique
    return $Object.psobject.properties | Where-Object { $allPropstoExclude -notcontains $_.Name }
  }
  static [PSObject] RecurseObject($Object, [PSObject]$Output) {
    return [xgen]::RecurseObject($Object, '$Object', $Output, 0)
  }
  static [PSObject] RecurseObject($Object, [string[]]$Path, [PSObject]$Output, [int]$Depth) {
    $Depth++
    #Get the children we care about, and their names
    $Children = [xgen]::ExcludeProperties($Object);
    #Loop through the children properties.
    foreach ($Child in $Children) {
      $ChildName = $Child.Name
      $ChildValue = $Child.Value
      # Handle special characters...
      $FriendlyChildName = $(if ($ChildName -match '[^a-zA-Z0-9_]') {
          "'$ChildName'"
        } else {
          $ChildName
        }
      )
      $IsInInclude = ![xgen]::Options.PropstoInclude -or @([xgen]::Options.PropstoInclude).Where({ $ChildName -like $_ })
      $IsInValue = ![xgen]::Options.Value -or (@([xgen]::Options.Value).Where({ $ChildValue -like $_ }).Count -gt 0)
      if ($IsInInclude -and $IsInValue -and $Depth -le [xgen]::Options.MaxDepth) {
        $ThisPath = @( $Path + $FriendlyChildName ) -join "."
        $Output | Add-Member -MemberType NoteProperty -Name $ThisPath -Value $ChildValue
      }
      if ($null -eq $ChildValue) {
        continue
      }
      if (($ChildValue.GetType() -eq $Object.GetType() -and $ChildValue -is [datetime]) -or ($ChildName -eq "SyncRoot" -and !$ChildValue)) {
        Write-Debug "Skipping $ChildName with type $($ChildValue.GetType().FullName)"
        continue
      }
      # Check for arrays by checking object type (this is a fix for arrays with 1 object) otherwise check the count of objects
      $IsArray = $(if (($ChildValue.GetType()).basetype.Name -eq "Array") {
          $true
        } else {
          @($ChildValue).count -gt 1
        }
      )
      $count = 0
      #Set up the path to this node and the data...
      $CurrentPath = @( $Path + $FriendlyChildName ) -join "."

      #Get the children's children we care about, and their names.  Also look for signs of a hashtable like type
      $ChildrensChildren = [xgen]::ExcludeProperties($ChildValue)
      $HashKeys = if ($ChildValue.Keys -and $ChildValue.Values) {
        $ChildValue.Keys
      } else {
        $null
      }
      if ($(@($ChildrensChildren).count -ne 0 -or $HashKeys) -and $Depth -lt [xgen]::Options.MaxDepth) {
        #This handles hashtables.  But it won't recurse...
        if ($HashKeys) {
          foreach ($key in $HashKeys) {
            $Output | Add-Member -MemberType NoteProperty -Name "$CurrentPath['$key']" -Value $ChildValue["$key"]
            $Output = [xgen]::RecurseObject($ChildValue["$key"], "$CurrentPath['$key']", $Output, $depth)
          }
        } else {
          if ($IsArray) {
            foreach ($item in @($ChildValue)) {
              $Output = [xgen]::RecurseObject($item, "$CurrentPath[$count]", $Output, $depth)
              $Count++
            }
          } else {
            $Output = [xgen]::RecurseObject($ChildValue, $CurrentPath, $Output, $depth)
          }
        }
      }
    }
    return $Output
  }
  static [hashtable[]] FindHashKeyValue($PropertyName, $Ast) {
    return [xgen]::FindHashKeyValue($PropertyName, $Ast, @())
  }
  static [hashtable[]] FindHashKeyValue($PropertyName, $Ast, [string[]]$CurrentPath) {
    if ($PropertyName -eq ($CurrentPath -Join '.') -or $PropertyName -eq $CurrentPath[-1]) {
      return $Ast | Add-Member NoteProperty HashKeyPath ($CurrentPath -join '.') -PassThru -Force | Add-Member NoteProperty HashKeyName ($CurrentPath[-1]) -PassThru -Force
    }; $r = @()
    if ($Ast.PipelineElements.Expression -is [System.Management.Automation.Language.HashtableAst]) {
      $KeyValue = $Ast.PipelineElements.Expression
      ForEach ($KV in $KeyValue.KeyValuePairs) {
        $result = [xgen]::FindHashKeyValue($PropertyName, $KV.Item2, @($CurrentPath + $KV.Item1.Value))
        if ($null -ne $result) {
          $r += $result
        }
      }
    }
    return $r
  }
  static [string] EscapeSpecialCharacters([string]$str) {
    if ([string]::IsNullOrWhiteSpace($str)) {
      return $str
    } else {
      [string]$ParsedText = $str
      if ($ParsedText.ToCharArray() -icontains "'") {
        $ParsedText = $ParsedText -replace "'", "''"
      }
      return $ParsedText
    }
  }
}

# Binary-Coded Decimal (BCD) Encoding:
# This algorithm represents decimal digits with four bits, with each decimal digit encoded in its own four-bit code.
class BCD {
  BCD() {}
}

# Also known as reflected binary code, this encoding scheme assigns a unique binary code to each decimal number,
# such that only one bit changes between consecutive numbers.
class GrayCode {
}

# This algorithm assigns shorter binary codes to more frequently occurring characters in a message,
# and longer codes to less frequently occurring characters.
class Huffman {
}


# This is a coding scheme in which the transition of a signal from high to low represents a binary 1,
# and the transition from low to high represents a binary 0.
class Manchester {
}