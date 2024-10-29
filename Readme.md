# [![✖convert](/docs/img/favicons/favicon-150x150.png)](https://alainQtec.dev/clihelper-modules/xconvert)

<p><b><a href="https://powershellgallery.com/packages/cliHelper.xconvert">✖convert</a></b> - version <b>0.1.3</b></p>

An all-in-one module to convert files and object types.

<p>
Its like the builtin <a href="https://learn.microsoft.com/en-us/dotnet/fundamentals/runtime-libraries/system-convert">[system.convert]</a> but extended.
</br>
</p>

## ↯ Install

```PowerShell
Install-Module cliHelper.xconvert
```

⤷ Straight forward; gets the latest version.

## 🧑🏻‍💻 ᴜsᴀɢᴇ

<p>
Hint: <a href="./Public/Invoke-Converter.ps1">xconvert</a> is pretty much the only cmdlet
you have to remember ×͜×

</p>

⤷ **1. (xconvert). Like directly using the class.**

- To know what method to use, you just type `xconvert From` and <details>
  <summary><b>Tab</b> to see all options.</summary>

  xconvert From `Tab`

  gives this output

  [![from tab](/docs/img/from.png)](https://alainQtec.dev/clihelper-modules/xconvert)

  `or` xconvert To `Tab`

  [![to tab](/docs/img/to.png)](https://alainQtec.dev/clihelper-modules/xconvert)

</details>

Then you can do stuff like:

```PowerShell
"HelloWorld" | xconvert ToBase32String
# same as
(xconvert)::ToBase32String("HelloWorld")
```

<p>
ie: since xconvert is an alias for the public funtion <a href="./Public/Invoke-Converter.ps1">Invoke-Converter</a>.
</br>
Note: Tab argumant completion is still ᴡɪᴘ &will ship in v0.1.3
</p>

⤷ **2. Chain⫘⫘ing and piping public function(s)**

ex: do stuff like

```PowerShell
$enc_Pass = "HelloWorld" | Xconvert ToBase32String, ToObfuscated, ToSecurestring
# then reverse:
$txt_Pass = $enc_Pass | xconvert -m ToString, FromObfuscated, FromBase32String, ToInt32, Tostring
$txt_Pass | Should -Be "HelloWorld"
# Metal 🔥 ⚡︎ 🤘
```

Advanced? yeah you can get nuts with this cmdlet 🤓

<details>
  <summary><b>ғᴀᴏ̨ (‘•.•’)</b>: Why?!</summary>

⤷ **PowerShell has limited built-in Support for Some Formats**.

<p>
For me, this is like a fun and AIO solution to extend that
functionality.
</p>

- While PowerShell excels at handling common file formats(JSON, XML, CSV) and
  [data types](https://learn.microsoft.com/en-us/powershell/scripting/lang-spec/chapter-06?view=powershell-7.4),
  users may find limited built-in support for less common file types,
  necessitating additional modules.

  `Example`: Converting excel Files often result in
  [corrupted files](https://forums.powershell.org/t/converting-excel-files-in-powershell/10807).

The goal is simple, to make [xconvert] the <b>best module to convert</b> objects
in powershell.

</details>

## ʟɪᴄᴇɴsᴇ

This project is licensed under the MIT License. See the
[ʟɪᴄᴇɴsᴇ](https://alain.MIT-license.org) file for details.

## sᴘᴏɴsᴏʀ?

If this tool saves your time and you want to support me;
<a href="https://www.paypal.com/donate/?hosted_button_id=3LA3EUKRU6722">
<img src="https://img.shields.io/static/v1?logo=paypal&label=PayPal&logoColor=white&message=donate to alain&color=00457C"/>
</a>

[You can also share ideas, and provide feedback](https://github.com/alainQtec/cliHelper.xconvert/discussions/1).

Contributions are really welcome.

⤷ This is still a **ᴡɪᴘ 🚧**. Yes its usable, but alot of cool stuff are not
fully done.

For more, checkout the [progress](./docs/Readme.md)

[![Contributors](https://contrib.rocks/image?repo=alainQtec/cliHelper.xconvert)](https://github.com/alainQtec/cliHelper.xconvert/graphs/contributors)

Thank you.

![Alt](https://repobeats.axiom.co/api/embed/9cbc0ffce6f62ace082852045cd005b5ad61cebd.svg "Repobeats analytics image")
