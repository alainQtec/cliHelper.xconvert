# [![xconver icon](/docs/img/favicons/favicon-150x150.png)](https://alainQtec.dev/clihelper-modules/xconvert)

<p><b><a href="https://powershellgallery.com/packages/cliHelper.xconvert">xconvert</a></b> - version <b>0.1.0 α</b></p>

An all-in-one module to convert files and object types.

<p>
<a href="cliHelper.xconvert.psm1">[xconvert]</a> is like the builtin <a href="https://learn.microsoft.com/en-us/dotnet/fundamentals/runtime-libraries/system-convert">[system.convert]</a> but extended.
</p>

**⬇️ Install:**

```PowerShell
Install-Module cliHelper.xconvert
```

---

**🚧 WIP:** This is still version alpha, so alot of stuff is'nt done yet.

Here's the progress list:

- [x] Added main class (90%)
- [x] Added Private /utility classes
- [x] Add Public function(s)

  `Note`: [This module intentionally uses 1 huge main class](). _Creating all
  functions for each method in [xconvert] might get tedious overtime_, so _only
  functions for **Common format conversions** will be created_. **i.e**:

  - [ ] functions to convert between file formats (CSV, JSON, XML ...)
  - [ ] functions convert data type to another (string, integer, datetime ...)
  - [ ] functions to convert encodings (ASCII, UTF-8, base32 ...)
  - [ ] functions to convert between visualization formats

---

#### (‘•.•’)? FAQs

<details>
  <summary>Why build this?</summary>

⤷ **PowerShell has limited built-in Support for Some Formats**.

- While PowerShell excels at handling common file formats(JSON, XML, CSV) and
  [data types](https://learn.microsoft.com/en-us/powershell/scripting/lang-spec/chapter-06?view=powershell-7.4),
  users may find limited built-in support for less common file types,
  necessitating additional modules.

  `Example`: Converting excel Files often result in
  [corrupted files](https://forums.powershell.org/t/converting-excel-files-in-powershell/10807).

This is like an AIO custom solution to extend the built-in functionality.

</details>

<details>
  <summary>How to use this?</summary>

⤷ **Use Public functions or directly use the [xconvert] class.**

- The functions give more options & output pipeline.
- If you can't find what method to use, you just `[xconvert]::From` and press
  `Tab` to see all options.

[xconvert]::From + `Tab`

gives this output

[![from tab](/docs/img/from.png)](https://alainQtec.dev/clihelper-modules/xconvert)

`or` [xconvert]::To + `Tab`

[![to tab](/docs/img/to.png)](https://alainQtec.dev/clihelper-modules/xconvert)

</details>

## License

This project is licensed under the MIT License. See the
[License](https://alainQtec.MIT-license.org) file for details.
