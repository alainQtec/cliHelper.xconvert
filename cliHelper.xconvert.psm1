using namespace System.IO
using namespace System.Text
using namespace System.Reflection
using namespace System.Collections
using namespace System.Management.Automation
using namespace System.Runtime.Serialization
using namespace System.Runtime.InteropServices

#region    Classes

enum EncodingName {
  Base85
  Base58
  Base36
  Base32
  Base16
}

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

# To make sure I use the same encoding everywhere
class EncodingBase {
  static [Encoding]$Encoding = [System.Text.UTF8Encoding]::UTF8
  EncodingBase() {
    [EncodingBase]::Encoding | Get-Member -MemberType Properties |
      Select-Object -ExpandProperty Name | ForEach-Object {
        $this.PsObject.Properties.Add([psscriptproperty]::new($_, [scriptblock]::Create("return `$this::Encoding.$_ ")))
      }
  }
  static [byte[]] GetBytes([string] $s) {
    return [EncodingBase]::Encoding.GetBytes($s)
  }
  static [byte[]] GetBytes([char[]] $chars) {
    return [EncodingBase]::Encoding.GetBytes($chars)
  }
  static [byte[]] GetBytes([char[]] $chars, [int] $index, [int] $count) {
    return [EncodingBase]::Encoding.GetBytes($chars, $index, $count)
  }
  static [byte[]] GetBytes([string] $s, [int] $index, [int] $count) {
    return [EncodingBase]::Encoding.GetBytes($s, $index, $count)
  }
  static [string] GetString([byte[]]$bytes) {
    return [EncodingBase]::Encoding.GetString($bytes)
  }
  static [string] GetString([byte[]]$bytes, [int]$index, [int]$count) {
    return [EncodingBase]::Encoding.GetString($bytes, $index, $count)
  }
  static [char[]] GetChars([byte[]]$bytes) {
    return [EncodingBase]::Encoding.GetChars($bytes)
  }
  [int] GetByteCount([string] $chars) {
    return [EncodingBase]::Encoding.GetByteCount($chars)
  }
  [int] GetByteCount([char[]] $chars) {
    return [EncodingBase]::Encoding.GetByteCount($chars)
  }
  [int] GetByteCount([string] $s, [int] $index, [int] $count) {
    return [EncodingBase]::Encoding.GetByteCount($s, $index, $count)
  }
  [int] GetByteCount([char[]] $chars, [int] $index, [int] $count) {
    return [EncodingBase]::Encoding.GetByteCount($chars, $index, $count)
  }
  [Encoder] GetEncoder() {
    return [EncodingBase]::Encoding.GetEncoder()
  }
  [Decoder] GetDecoder() {
    return [EncodingBase]::Encoding.GetDecoder()
  }
}

#region    Base85
# .SYNOPSIS
#   Base85 encoding
# .DESCRIPTION
#   A binary-to-text encoding scheme that uses 85 printable ASCII characters to represent binary data
# .EXAMPLE
#   $b = [Base85]::GetBytes("Hello world")
#   $e = [base85]::Encode($b)
#   [Base85]::GetString([base85]::Decode($e)) | Should -Be "Hello world"
# .EXAMPLE
#   [Base85]::GetString([Base85]::Decode([Base85]::Encode('Hello world!'))) | Should -Be "Hello world!"
class Base85 : EncodingBase {
  static [String] $NON_A85_Pattern = "[^\x21-\x75]"

  Base85() {}
  static [string] Encode([string]$text) {
    return [Base85]::Encode([Base85]::GetBytes($text), $false)
  }
  static [string] Encode([byte[]]$Bytes) {
    return [Base85]::Encode($Bytes, $false)
  }
  static [string] Encode([byte[]]$Bytes, [bool]$Format) {
    # Using Format means we'll add "<~" Prefix and "~>" Suffix marks to output text
    [System.IO.Stream]$InputStream = New-Object -TypeName System.IO.MemoryStream(, $Bytes)
    # [System.Object]$Timer = [System.Diagnostics.Stopwatch]::StartNew()
    [System.Object]$BinaryReader = New-Object -TypeName System.IO.BinaryReader($InputStream)
    [System.Object]$Ascii85Output = New-Object -TypeName System.Text.StringBuilder
    if ($Format) {
      [void]$Ascii85Output.Append("<~")
      [System.UInt16]$LineLen = 2
    }
    $EncodedString = [string]::Empty
    Try {
      # Write-Debug "[base85] Encoding started at $([Datetime]::Now.Add($timer.Elapsed).ToString()) ..."
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
      # $Timer.Stop()
      # Write-Debug "[base85] Encoding completed in $($Timer.Elapsed.Hours) hours, $($Timer.Elapsed.Minutes) minutes, $($Timer.Elapsed.Seconds) seconds, $($Timer.Elapsed.Milliseconds) milliseconds"
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
    [System.Object]$InputStream = New-Object -TypeName System.IO.MemoryStream([Base85]::GetBytes($text), 0, $text.Length)
    [System.Object]$BinaryReader = New-Object -TypeName System.IO.BinaryReader($InputStream)
    [System.Object]$OutputStream = New-Object -TypeName System.IO.MemoryStream
    [System.Object]$BinaryWriter = New-Object -TypeName System.IO.BinaryWriter($OutputStream)
    # [System.Object]$Timer = [System.Diagnostics.Stopwatch]::StartNew()
    Try {
      # Write-Verbose "[base85] Decoding started at $([Datetime]::Now.Add($timer.Elapsed).ToString()) ..."
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
      # $Timer.Stop()
      # Write-Verbose "[base85] Decoding completed after $($Timer.Elapsed.Hours) hours, $($Timer.Elapsed.Minutes) minutes, $($Timer.Elapsed.Seconds) seconds, $($Timer.Elapsed.Milliseconds) milliseconds"
    }
    return $decoded
  }
}
#endregion Base85

#region    base16
class Base16 : EncodingBase {
  static [string] Encode([string]$text) {
    return [Base16]::Encode([Base16]::GetBytes($text))
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
    return [Base32]::Encode([Base32]::GetBytes($String), $Formatt)
  }
  static [string] Encode([Stream]$Stream, [bool]$Formatt) {
    # .EXAMPLE
    # $b32 = [Base32]::Encode("hello world!")
    # $text = [String]::Join([string]::Empty, [Base32]::ToString([int[]][Base32]::Decode($b32)))
    $BinaryReader = [BinaryReader]::new($Stream); $B32CHARSET = [Base32]::charset
    $Base32Output = [StringBuilder]::new(); $result = [string]::Empty
    # Write-Debug "[Base32] Encoding started at $([Datetime]::Now.Add($timer.Elapsed).ToString()) ..."
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
    # Write-Debug "[Base32] Encoding completed in $($Timer.Elapsed.Hours) hours, $($Timer.Elapsed.Minutes) minutes, $($Timer.Elapsed.Seconds) seconds, $($Timer.Elapsed.Milliseconds) milliseconds"
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
    return [Base36]::Encode([Base36]::GetBytes($text))
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
#   Base 58
# .EXAMPLE
#   $e = [Base58]::Encode("Hello world!!")
#   $d = [Base58]::GetString([Base58]::Decode($e))
#   ($d -eq "Hello world!!") -should be $true
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
class UnixtoUnix : EncodingBase {
  static [string] Encode([string]$text) {
    return [UnixtoUnix]::Encode([UnixtoUnix]::GetBytes($text))
  }
  static [string] Encode([byte[]]$ba) {
    $encoded = $null; # $Timer = [System.Diagnostics.Stopwatch]::StartNew();
    # Write-Debug "[UnixtoUnix] Encoding started at $([Datetime]::Now.Add($timer.Elapsed).ToString()) ..."
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

    # Write-Verbose "[UnixtoUnix] Encoding completed in $($Timer.Elapsed.Hours) hours, $($Timer.Elapsed.Minutes) minutes, $($Timer.Elapsed.Seconds) seconds, $($Timer.Elapsed.Milliseconds) milliseconds"
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

class Morse {
  # .SYNOPSIS
  #   Morse code encoding/decoding
  # .LINK
  #   https://en.wikipedia.org/wiki/Morse_code
  static $Map = @{
    'A' = '.-'; 'B' = '-...'; 'C' = '-.-.'; 'D' = '-..'; 'E' = '.';
    'F' = '..-.'; 'G' = '--.'; 'H' = '....'; 'I' = '..'; 'J' = '.---';
    'K' = '-.-'; 'L' = '.-..'; 'M' = '--'; 'N' = '-.'; 'O' = '---';
    'P' = '.--.'; 'Q' = '--.-'; 'R' = '.-.'; 'S' = '...'; 'T' = '-';
    'U' = '..-'; 'V' = '...-'; 'W' = '.--'; 'X' = '-..-'; 'Y' = '-.--';
    'Z' = '--..'; '1' = '.----'; '2' = '..---'; '3' = '...--'; '4' = '....-';
    '5' = '.....'; '6' = '-....'; '7' = '--...'; '8' = '---..'; '9' = '----.';
    '0' = '-----'
  }
  static [string] Encode([string]$text) {
    if ([string]::IsNullOrEmpty($text)) { return '' }
    # Clean up input - replace underscore with dash for consistency
    $text = $text.Replace('_', '-')

    # Split into words (multiple spaces between words)
    $words = $text -split " " | Where-Object { ![String]::IsNullOrEmpty($_.Trim()) }

    # Process each word
    $result = foreach ($word in $words) {
      # Split word into individual characters (single space between letters)
      $letters = $word -split '' | Where-Object { ![String]::IsNullOrEmpty($_.Trim()) }
      $($letters | ForEach-Object {
          if ($morseMap.ContainsKey($_)) {
            [Morse]::Map[$_]
          } else { '' }
        }
      ) -join ''
    }
    return ($result -join ' ')
  }
  static [string] Decode([string]$text) {
    if ([string]::IsNullOrEmpty($text)) { return '' }
    return ''
  }
}

class ROT13 {
  # .SYNOPSIS
  #   rotate by 13 places
  # .LINK
  #   https://en.wikipedia.org/wiki/ROT13
  static [string] Encode([string]$text) {
    $result = ''; $text.ToCharArray() | ForEach-Object {
      if ((([int] $_ -ge 97) -and ([int] $_ -le 109)) -or (([int] $_ -ge 65) -and ([int] $_ -le 77))) {
        $result += [char] ([int] $_ + 13);
      } elseif ((([int] $_ -ge 110) -and ([int] $_ -le 122)) -or (([int] $_ -ge 78) -and ([int] $_ -le 90))) {
        $result += [char] ([int] $_ - 13);
      } else {
        $result += $_
      }
    }
    return $result
  }
  static [string] Decode([string]$text) {
    return [ROT13]::Encode($text)
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
        'Base36' {}
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
    return [EncodingBase]::Encoding.GetBytes($text)
  }
  static [string] GetString([byte[]]$bytes) {
    return [EncodingBase]::Encoding.GetString($bytes)
  }
}

class xObOptions {
  [bool]$SkipDefaults = $true
  [string[]]$PropstoExclude
  [string[]]$PropstoInclude
  hidden [string[]]$Values
  [int]$MaxDepth = 10
}

class xget {
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
    return [xget]::ListProperties($Obj, '')
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
        $Properties += [xget]::ListProperties($PropertyValue, $FullPropertyName)
      }
    }
    return $Properties
  }
  static [Object[]] ExcludeProperties($Object) {
    return [xget]::ExcludeProperties($Object, [xget]::Options.PropstoExclude)
  }
  static [Object[]] ExcludeProperties($Object, [string[]]$PropstoExclude) {
    $DefaultTypeProps = @()
    if ([xget]::Options.SkipDefaults) {
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
    return [xget]::RecurseObject($Object, '$Object', $Output, 0)
  }
  static [PSObject] RecurseObject($Object, [string[]]$Path, [PSObject]$Output, [int]$Depth) {
    $Depth++
    #Get the children we care about, and their names
    $Children = [xget]::ExcludeProperties($Object);
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
      $IsInInclude = ![xget]::Options.PropstoInclude -or @([xget]::Options.PropstoInclude).Where({ $ChildName -like $_ })
      $IsInValue = ![xget]::Options.Value -or (@([xget]::Options.Value).Where({ $ChildValue -like $_ }).Count -gt 0)
      if ($IsInInclude -and $IsInValue -and $Depth -le [xget]::Options.MaxDepth) {
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
      $ChildrensChildren = [xget]::ExcludeProperties($ChildValue)
      $HashKeys = if ($ChildValue.Keys -and $ChildValue.Values) {
        $ChildValue.Keys
      } else {
        $null
      }
      if ($(@($ChildrensChildren).count -ne 0 -or $HashKeys) -and $Depth -lt [xget]::Options.MaxDepth) {
        #This handles hashtables.  But it won't recurse...
        if ($HashKeys) {
          foreach ($key in $HashKeys) {
            $Output | Add-Member -MemberType NoteProperty -Name "$CurrentPath['$key']" -Value $ChildValue["$key"]
            $Output = [xget]::RecurseObject($ChildValue["$key"], "$CurrentPath['$key']", $Output, $depth)
          }
        } else {
          if ($IsArray) {
            foreach ($item in @($ChildValue)) {
              $Output = [xget]::RecurseObject($item, "$CurrentPath[$count]", $Output, $depth)
              $Count++
            }
          } else {
            $Output = [xget]::RecurseObject($ChildValue, $CurrentPath, $Output, $depth)
          }
        }
      }
    }
    return $Output
  }
  static [hashtable[]] FindHashKeyValue($PropertyName, $Ast) {
    return [xget]::FindHashKeyValue($PropertyName, $Ast, @())
  }
  static [hashtable[]] FindHashKeyValue($PropertyName, $Ast, [string[]]$CurrentPath) {
    if ($PropertyName -eq ($CurrentPath -Join '.') -or $PropertyName -eq $CurrentPath[-1]) {
      return $Ast | Add-Member NoteProperty HashKeyPath ($CurrentPath -join '.') -PassThru -Force | Add-Member NoteProperty HashKeyName ($CurrentPath[-1]) -PassThru -Force
    }; $r = @()
    if ($Ast.PipelineElements.Expression -is [System.Management.Automation.Language.HashtableAst]) {
      $KeyValue = $Ast.PipelineElements.Expression
      ForEach ($KV in $KeyValue.KeyValuePairs) {
        $result = [xget]::FindHashKeyValue($PropertyName, $KV.Item2, @($CurrentPath + $KV.Item1.Value))
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
  static [Hashtable] RegexMatch([regex]$Regex, [RegularExpressions.Match]$Match) {
    if (!$Match.Groups[0].Success) {
      throw New-Object System.ArgumentException('Match does not contain any captures.', 'Match')
    }
    $h = @{}
    foreach ($name in $Regex.GetGroupNames()) {
      if ($name -eq 0) {
        continue
      }
      $h.$name = $Match.Groups[$name].Value
    }
    return $h
  }
  static [string] RegexEscape([string]$LiteralText) {
    if ([string]::IsNullOrEmpty($LiteralText)) { $LiteralText = [string]::Empty }
    return [regex]::Escape($LiteralText);
  }
  static [bool] IsValidHex([string]$Text) {
    return [regex]::IsMatch($Text, '^#?([a-f0-9]{6}|[a-f0-9]{3})$')
  }
  static [bool] IsValidHex([byte[]]$bytes) {
    # .Example
    # $bytes = [byte[]](0x00, 0x1F, 0x2A, 0xFF)
    # $isValid = [MyConverter]::IsValidHex($bytes)
    # Write-Host "Is valid hex: $isValid"
    foreach ($byte in $bytes) {
      if ($byte -lt 0x00 -or $byte -gt 0xFF) {
        return $false
      }
    } return $true
  }
  static [bool] IsValidBase64([string]$string) {
    return $(
      [regex]::IsMatch([string]$string, '^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$') -and
      ![string]::IsNullOrWhiteSpace([string]$string) -and !$string.Length % 4 -eq 0 -and !$string.Contains(" ") -and
      !$string.Contains(" ") -and !$string.Contains("`t") -and !$string.Contains("`n")
    )
  }
  static [void] ValidatePolybius([string]$Text, [string]$Key, [string]$Action) {
    if ($Text -notmatch "^[a-z ]*$" -and ($Action -ne 'Decrypt')) {
      throw('Text must only have alphabetical characters');
    }
    if ($Key.Length -ne 25) {
      throw('Key must be 25 characters in length');
    }
    if ($Key -notmatch "^[a-z]*$") {
      throw('Key must only have alphabetical characters');
    }
    for ($i = 0; $i -lt 25; $i++) {
      for ($j = 0; $j -lt 25; $j++) {
        if (($Key[$i] -eq $Key[$j]) -and ($i -ne $j)) {
          throw('Key must have no repeating letters');
        }
      }
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

# .SYNOPSIS
#   Convert data from one format to another
# .DESCRIPTION
#   Extended version of built in [convert] class
class xconvert : System.ComponentModel.TypeConverter {
  static hidden [MethodInfo[]] $Methods = (Get-Methods)
  static hidden [Type[]] $ReturnTypes = (Get-ReturnTypes)
  xconvert() {}
  static [string] Tostring($Object) {
    if ($null -eq $Object) { return [string]::Empty };
    $s = ('BitArray', 'byte[]', 'char[]', 'int[]', 'SecureString', 'guid', 'k3y', 'Hashtable', 'OrderedDictionary', 'AXNodeConfiguration', 'PSBoundParametersDictionary')
    if (!$Object.GetType().IsPrimitive -and $Object.GetType().Name -notin $s) {
      throw [System.InvalidOperationException]::new("Object type not upported")
    }
    $r = switch ($Object.GetType().Name) {
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
  static hidden [string] ToString([int[]]$CharCodes, [string]$separator) {
    return [string]::Join($separator, [xconvert]::ToString($CharCodes));
  }
  static hidden [string] ToString([int]$value, [int]$toBase) {
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
  static hidden [string] ToString([Int]$value, [char[]]$baseChars) {
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
  static hidden [psobject] ToCaesar([string]$Text, [int]$Key) {
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
  static hidden [string] FromCaesar([string]$Cipher, [int]$Key) {
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
  static hidden [psobject] ToPolybius([string]$Text, [string]$Key) {
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
  static hidden [string] FromPolybius([string]$Cipher, [string]$Key) {
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
  static [string] ToROT13([string]$Text) {
    return [ROT13]::Encode($Text)
  }
  static [string] FromROT13([string]$Text) {
    return [ROT13]::Decode($Text)
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
  static hidden [string] ToCsv([System.Object]$Obj, [int]$depth) {
    return [xconvert]::ToCsv($Obj, @('pstypenames', 'BaseType'), $depth, 0)
  }
  static hidden [string] ToCsv([System.Object]$Obj, [string[]]$excludedProps, [int]$depth, [int]$currentDepth = 0) {
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
  static hidden [object] FromPSObject([PSCustomObject]$PSObject, [string]$typeName) {
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
  static [PSCustomObject] ToPSCustomObject($Obj) {
    $OutputObject = [PSCustomObject]::new()
    $Obj.PSObject.Properties | ForEach-Object {
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
  static [byte[]] FromBase32([byte[]]$bytes) {
    return [Base32]::Decode([xconvert]::ToUTF8str($bytes))
  }
  static [byte[]] FromBase58([string]$text) {
    return [Base58]::Decode($text)
  }
  static [byte[]] FromBase58([byte[]]$bytes) {
    return [Base58]::Decode([xconvert]::ToUTF8str($bytes))
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
  static hidden [string] ToBase32([byte[]]$bytes, [bool]$Formatt) {
    return [Base32]::Encode($bytes, $Formatt)
  }
  static hidden [string] ToBase32([string]$s, [bool]$Formatt) {
    return [Base32]::Encode($s, $Formatt)
  }
  static hidden [string] ToBase32([Stream]$Stream, [bool]$Formatt) {
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
  static hidden [string] ToProtected([string]$string, [ProtectionScope]$Scope) {
    $Entropy = [Encoding]::UTF8.GetBytes([xget]::UniqueMachineId())[0..15];
    return [xconvert]::Tostring([xconvert]::ToProtected([xconvert]::ToBytes($string), $Entropy, $Scope))
  }
  static hidden [string] ToProtected([string]$string, [byte[]]$Entropy, [ProtectionScope]$Scope) {
    return [xconvert]::Tostring([xconvert]::ToProtected([xconvert]::ToBytes($string), $Entropy, $Scope))
  }
  static [byte[]] ToProtected([byte[]]$Bytes) {
    $Scope = [ProtectionScope]::CurrentUser
    $Entropy = [Encoding]::UTF8.GetBytes([xget]::UniqueMachineId())[0..15];
    return [xconvert]::ToProtected($bytes, $Entropy, $Scope)
  }
  static hidden [byte[]] ToProtected([byte[]]$Bytes, [ProtectionScope]$Scope) {
    $Entropy = [Encoding]::UTF8.GetBytes([xget]::UniqueMachineId())[0..15];
    return [xconvert]::ToProtected($bytes, $Entropy, $Scope)
  }
  static hidden [byte[]] ToProtected([byte[]]$Bytes, [byte[]]$Entropy, [ProtectionScope]$Scope) {
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
  static hidden [string] FromProtected([string]$string, [ProtectionScope]$Scope) {
    $Entropy = [Encoding]::UTF8.GetBytes([xget]::UniqueMachineId())[0..15];
    return [xconvert]::FromBytes([xconvert]::FromProtected([xconvert]::ToBytes($string), $Entropy, $Scope))
  }
  static hidden [string] FromProtected([string]$string, [byte[]]$Entropy, [ProtectionScope]$Scope) {
    return [xconvert]::FromBytes([xconvert]::FromProtected([xconvert]::ToBytes($string), $Entropy, $Scope))
  }
  static hidden [byte[]] FromProtected([byte[]]$Bytes, [byte[]]$Entropy, [ProtectionScope]$Scope) {
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
  static hidden [string] ToCompressed([string]$Plaintext) {
    return [convert]::ToBase64String([xconvert]::ToCompressed([Encoding]::UTF8.GetBytes($Plaintext)));
  }
  static hidden [byte[]] ToCompressed([byte[]]$Bytes, [string]$Compression) {
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
  static hidden [byte[]] FromCompressed([byte[]]$Bytes, [string]$Compression) {
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
  static [PSObject[]] ToFlatObject([PSObject[]]$obj) {
    $op = [xget]::Options
    return [xconvert]::ToFlatObject($obj, $op.PropstoExclude, $op.SkipDefaults, $op.PropstoInclude, $op.Values, $op.MaxDepth)
  }
  static hidden [PSObject[]] ToFlatObject([PSObject[]]$obj, [string[]]$PropstoExclude, [bool]$SkipDefaults, [string[]]$PropstoInclude, [string[]]$Values, [int]$MaxDepth) {
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
    foreach ($i in $obj) {
      $result += [xget]::RecurseObject($i, [PSObject]::new())
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
  static hidden [Hashtable] ToHashTable([PSPropertyInfo[]]$properties, [int]$depth) {
    return [xconvert]::ToHashTable($properties, $depth, 100)
  }
  static hidden [Hashtable] ToHashTable([PSPropertyInfo[]]$properties, [int]$depth, [int]$maxDepth) {
    if ($depth -ge $maxDepth) { Write-Error -Message "Converting to Hashtable reached Depth Threshold of $maxDepth on $($properties.Name -join ',')" -ErrorAction Stop }
    $depth++; $ht = [hashtable]::new()
    foreach ($prop in $properties) {
      # Skip properties with no values unless explicitly null
      if ($null -eq $prop.Value) { $ht[$prop.Name] = $null; continue }
      switch ($true) {
        # DateTime types converted to ISO 8601 string format
        ($prop.TypeNameOfValue -match 'System\.DateTime') {
          $ht[$prop.Name] = $prop.Value.ToString("o") # "o" for ISO 8601
          break
        }
        # Nested PSCustomObjects
        ($prop.Value -is [PSCustomObject]) {
          $ht[$prop.Name] = [xconvert]::ToHashTable($prop.Value.PSObject.Properties, $depth)
          break
        }
        # Fallback for Unknown typesand Primitive types: $prop.TypeNameOfValue -match 'System\.(String|Boolean|Int32|Int64|Double|Float|Char)'
        default {
          $ht[$prop.Name] = $prop.Value
        }
      }
    }
    return $ht
  }
  static [string] ToHexString([byte[]]$Bytes) {
    return [string][System.BitConverter]::ToString($bytes).replace('-', [string]::Empty).Tolower();
  }
  static hidden [string] ToHexString([uint64[]]$Numbers, [int]$MinWidth, [string]$Prefix) {
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
  static hidden [byte[]] ToBytes([object]$obj, [bool]$protect) {
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
  static hidden [byte[]] ToSerialized($Obj, [bool]$Force) {
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
  static hidden [Object[]] FromBytes([byte[]]$data, [bool]$Unprotect) {
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
  static hidden [string] ToBitArrayString([byte[]]$Bytes, [bool]$Tidy) {
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
  static hidden [string] ToBitArrayString([BitArray]$binary, [bool]$Tidy) {
    [string]$binStr = [xconvert]::ToBitArrayString($binary)
    if ($Tidy) { $binStr = [string]::Join('', $binStr.Split()) }
    return $binStr
  }
  static [string] ToBitArrayString([string]$string) {
    return [xconvert]::ToBitArrayString($string, $false)
  }
  static hidden [string] ToBitArrayString([string]$string, [bool]$Tidy) {
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
  static hidden [object] ToObject([IO.FileInfo]$File, [string]$Type) {
    return [xconvert]::ToObject($File.FullName, $Type, $false);
  }
  static hidden [object] ToObject([IO.FileInfo]$File, [bool]$Decrypt) {
    $FilePath = [xget]::ResolvedPath($File.FullName); $Object = $null
    try {
      if ($Decrypt) { $(Get-Item $FilePath).Decrypt() }
      $Object = Import-Clixml -Path $FilePath
    } catch {
      Write-Error $_
    }
    return $Object
  }
  static hidden [object] ToObject([IO.FileInfo]$File, [string]$Type, [bool]$Decrypt) {
    $FilePath = [xget]::ResolvedPath($File.FullName); $Object = $null
    try {
      if ($Decrypt) { $(Get-Item $FilePath).Decrypt() }
      $Object = (Import-Clixml -Path $FilePath) -as "$Type"
    } catch {
      Write-Error $_
    }
    return $Object
  }
  static hidden [IO.FileInfo] FromObject($Object, [string]$OutFile) {
    return [xconvert]::FromObject($Object, $OutFile, $false);
  }
  static hidden [IO.FileInfo] FromObject($Object, [string]$OutFile, [bool]$encrypt) {
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
  static hidden [datetime[]] ToDateTime([String[]]$DateString, [bool]$UTC) {
    return [xconvert]::ToDateTime($DateString, [dateFormat]::UNKNOWN, $UTC)
  }
  static hidden [datetime[]] ToDateTime([String[]]$DateString, [dateFormat]$Format, [bool]$UTC) {
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

# Types that will be available to users when they import the module.
$typestoExport = @(
  [ProtectionScope],
  [EncodingBase],
  [EncodKit],
  [xconvert],
  [Base85],
  [Base58],
  [Base36],
  [Base32],
  [Base16],
  [xget]
)
$TypeAcceleratorsClass = [PsObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')
foreach ($Type in $typestoExport) {
  if ($Type.FullName -in $TypeAcceleratorsClass::Get.Keys) {
    $Message = @(
      "Unable to register type accelerator '$($Type.FullName)'"
      'Accelerator already exists.'
    ) -join ' - '

    [System.Management.Automation.ErrorRecord]::new(
      [System.InvalidOperationException]::new($Message),
      'TypeAcceleratorAlreadyExists',
      [System.Management.Automation.ErrorCategory]::InvalidOperation,
      $Type.FullName
    ) | Write-Warning
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

$scripts = @(); $Public = Get-ChildItem "$PSScriptRoot/Public/" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
$scripts += Get-ChildItem "$PSScriptRoot/Private/" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
$scripts += $Public

foreach ($file in $scripts) {
  Try {
    if ([string]::IsNullOrWhiteSpace($file.fullname)) { continue }
    . "$($file.fullname)"
  } Catch {
    Write-Warning "Failed to import function $($file.BaseName): $_"
    $host.UI.WriteErrorLine($_)
  }
}

$Param = @{
  Function = $Public.BaseName
  Cmdlet   = '*'
  Alias    = '*'
  Verbose  = $false
}
Export-ModuleMember @Param