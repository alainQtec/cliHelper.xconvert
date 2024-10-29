# [![✖convert](/docs/img/favicons/favicon-150x150.png)](https://alainQtec.dev/clihelper-modules/xconvert)

<p><b><a href="https://powershellgallery.com/packages/cliHelper.xconvert">✖convert</a></b> - version <b>0.1.2</b></p>

An all-in-one module to convert files and object types.

<p>
Its like the builtin <a href="https://learn.microsoft.com/en-us/dotnet/fundamentals/runtime-libraries/system-convert">[system.convert]</a> but extended.
</br>
</p>

## ⬇️ Install

```PowerShell
Install-Module cliHelper.xconvert
```

⤷ Straight forward; gets the latest version.

## 🧑🏻‍💻 Usage

<p>
Hint: <a href="./Public/Invoke-Converter.ps1">xconvert</a> is pretty much the only cmdlet
you have to remember ×͜×

</p>

**1. The simplest way?**

⤷ **Use Public function(s) or directly use the [xconvert] class.**

- The functions give more options & output pipeline.
- To know what method to use, you just `[xconvert]::From` and press `Tab` to see
  all options.

  (Tab argumant completion is still wip &will ship in v0.1.3)

[xconvert]::From + `Tab`

gives this output

[![from tab](/docs/img/from.png)](https://alainQtec.dev/clihelper-modules/xconvert)

`or` [xconvert]::To + `Tab`

[![to tab](/docs/img/to.png)](https://alainQtec.dev/clihelper-modules/xconvert)

Then you can do stuff like:

```PowerShell
(Xconvert)::ToBase32String("HelloWorld")
```

ie: since `xconvert` is an alias for the public funtion `Invoke-Converter`.
</br>

**2. Metal ⚡︎ 🤘**

⤷ **Chaining and Pipeline**

You can do stuff like:

```PowerShell
$der_Pass = "HelloWorld" | Xconvert ToBase32String, ToObfuscated, ToSecurestring
```

Advanced? yeah you can get nuts with this cmdlet 🤓

<details>
  <summary><b>FAQ (‘•.•’)</b>: Why?!</summary>

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

## License

This project is licensed under the MIT License. See the
[License](https://alain.MIT-license.org) file for details.

## Sponsor?

If this tool saves your time and you want to support me;
<a href="https://www.paypal.com/donate/?hosted_button_id=3LA3EUKRU6722">
<img src="https://img.shields.io/static/v1?logo=paypal&label=PayPal&logoColor=white&message=donate to alain&color=00457C"/>
</a>

[You can also share ideas, and provide feedback](https://github.com/alainQtec/cliHelper.xconvert/discussions/1).

Contributions are really welcome.

⤷ This is still a **WIP 🚧**. Yes its usable, but alot of cool stuff are not
fully done.

For more, checkout the [progress](./docs/Readme.md)

[![Contributors](https://contrib.rocks/image?repo=alainQtec/cliHelper.xconvert)](https://github.com/alainQtec/cliHelper.xconvert/graphs/contributors)

Thank you.

![Alt](https://repobeats.axiom.co/api/embed/9cbc0ffce6f62ace082852045cd005b5ad61cebd.svg "Repobeats analytics image")
