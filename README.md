# WinRe:Bloat
**"Rebloat" your Windows installation with open-source software.**

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Supported Software](#supported-software)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
  - [Using PowerShell or Bat Scripts](#using-powershell-or-bat-scripts)
  - [Using the Python Script](#using-the-python-script)
  - [Using as PowerShell Library](#using-as-powershell-library)
  - [Using as Python Library](#using-as-python-library)
- [Customization](#customization)
  - [Default software](#default-software)
  - [Selectable software](#selectable-software)
  - [Configuration Formatting](#configuration-formatting)
- [License](#license)

---

## Overview

**WinRe:Bloat** helps you quickly reinstall essential open-source software and utilities on a Windows machine after de-bloating or a fresh install. It aims to restore productivity and "rebloat" your system with trustworthy, community-driven software.

This repository provides:
- Scripts to automate any type of software installation
- Modular approaches for customization

---

## Features

- **Automated installation** of any software provoded in the configuration.
- **Direct source** installation from github or custom website.
- **Customizable config**: Easily add or remove software to fit your workflow.
- **Rapid install list**: Install a predefined list of softwares rightaway.
- **Selectable software list**: Make a list of optional software that you want to choose at every install.
- **Wide installer support:** Can work with exe, msi and msixbundle installers.
---

## Supported Software

By default, WinRe:Bloat installs (examples; update as needed):
- Default:
  - Integrations: LocalSend, Sefirah.
  - Utilities: 7NanaZip.
  - Office: LibreOffice.
- Selectable:
  - Browsers: Firefox, Brave.

You can fully customize what gets installed (see [Customization](#customization)).

---

## Requirements

- Windows 10 or 11
- Administrator privileges (for installing software)
### Optional:
- [Python 3.x](https://www.python.org/downloads/) (if using Python scripts)
- [PSToml library for PowerShell](https://github.com/jborean93/PSToml) (for oprional toml config support)
- [toml library for Python](https://pypi.org/project/toml/) (for oprional toml config support)

---

## Installation

1. **Clone the repository:**

   ```sh
   git clone https://github.com/Blu-Tiger/win-rebloat.git
   cd win-rebloat
   ```

2. **Review scripts in [Usage](#usage)** and decide which to use (`.py`, `.ps1`, or `.bat`).

---

## Usage
### Using PowerShell or Bat Scripts

1. **Open PowerShell as Administrator**
2. **Run the main script:**
   ```powershell
   Set-ExecutionPolicy Bypass -Scope Process -Force
   .\win-rebloat.ps1
   ```
   OR
   ```powershell
   .\win-rebloat.bat
   ```
   The `.bat` file it will automatically ask for Admin Privileges
#### Optional arguments:
- **-ConfigPath [string]**  
  Path to the configuration file (default: `.\config.toml`).  
  Specifies where to find the TOML or JSON config describing which software to install.

- **-GetInfo [switch]**  
  Show a list of available apps in the configuration, grouped by category, in a human-readable format.

- **-GetObjectConfig [switch]**  
  Print the loaded configuration as a PowerShell object for inspection or further processing.

- **-GetJsonConfig [switch]**  
  Print the loaded configuration as a JSON string.

- **-Config [string/object]**  
  Pass the raw configuration content directly (as a string or object), instead of loading from a file.

- **-OptionalSelect [string]**  
  Select specific apps to be installed from the selectable categories, using a string format like:  
  `browser:firefox:chrome,utility:7zip`  
  (where categories and app names are separated by colons and different groups by commas).

### Using the Python Script
1. **Install toml dependencies (if using toml config):**
     ```sh
     pip install toml
     ```

2. **Run the script as Administrator:**
   ```sh
   python win-rebloat.py
   ```
#### Optional arguments:
- **--config-path [str]**  
  Path to the configuration file (default: `./config.toml`).

- **--get-info**  
  Show a list of available apps in the configuration, grouped by category, in a human-readable format.

- **--get-object-config**  
  Print the loaded configuration as a Python object.

- **--get-json-config**  
  Print the loaded configuration as a JSON string.

- **--config [str]**  
  Raw configuration string. If provided, this is used instead of loading from a file.

- **--optional-select [str]**  
  Select specific apps to be installed from the selectable categories, using a string format like:  
  `browser:firefox:chrome,utility:7zip`  
  (where categories and app names are separated by colons and different groups by commas).

### Using as PowerShell Library
When using win-rebloat.ps1 as a library (e.g., calling its functions from another PowerShell script), the primary function is `Win-Rebloat`. Its parameters are:

- **[string] $ConfigPath**  
  Path to the configuration file (TOML or JSON). Defaults to `.\config.toml`.

- **[switch] $GetInfo**  
  If set, shows a human-readable list of available apps, grouped by category.

- **[switch] $GetObjectConfig**  
  If set, outputs the loaded configuration as a PowerShell object.

- **[switch] $GetJsonConfig**  
  If set, outputs the loaded configuration as a JSON string.

- **$Config**  
  The raw configuration content (string or object). If provided, this overrides loading from the file specified by ConfigPath.

- **$OptionalSelect**  
  A string specifying which optional apps to select for installation. Format:  
  `category:app1:app2,category2:app3`  
  (Categories and apps are colon-separated; groups are comma-separated.)
*Usage example:*
```powershell
Win-Rebloat -ConfigPath "custom.toml" -OptionalSelect "browser:firefox"
```

### Using as Python Library
When using win-rebloat.py as a library (i.e., importing and calling its main function from another Python script), the core function is `win_rebloat`. Its parameters are:

- **config_path (str)**  
  Path to the configuration file (TOML or JSON). Default is `./config.toml`.

- **get_info (bool)**  
  If True, prints a human-readable list of available apps, grouped by category.

- **get_object_config (bool)**  
  If True, outputs the loaded configuration as a Python object.

- **get_json_config (bool)**  
  If True, outputs the loaded configuration as a JSON string.

- **config (str or None)**  
  The raw configuration content as a string. If provided, this overrides loading from the file at config_path.

- **optional_select (str or None)**  
  A string specifying which optional apps to select for installation. Format:  
  `category:app1:app2,category2:app3`  
  (Categories and apps are colon-separated; groups are comma-separated.)

*Usage example:*
```python
from win_rebloat import win_rebloat

win_rebloat(
    config_path="custom.toml",
    get_info=True,
    optional_select="browser:firefox"
)
```
---


## Customization
- **Edit the software lists** in the confog file.
- **To add a new program:**  
  Add the package name and the needed config options.
- **To exclude a program:**  
  Remove it from the list or comment it out.

### Default software
*Example (Toml):*
```toml
[[apps.utilities]]
file_pattern = ".*\\.msixbundle$"
name = "NanaZip"
repo = "M2Team/NanaZip"
type = "github"
```

*Example (JSON):*
```json
{
  "apps": {
    "utilities": [
      {
        "file_pattern": ".*\\.msixbundle$",
        "name": "NanaZip",
        "repo": "M2Team/NanaZip",
        "type": "github"
      }
    ],
  }
}
```

### Selectable software
*Example (Toml):*
```toml
[[selectable_apps.browsers]]
file_pattern = "zen\\.installer\\.exe"
install_args = "/S"
name = "Zen"
repo = "zen-browser/desktop"
selected = true
type = "github"

[[selectable_apps.browsers]]
file_pattern = "BraveBrowserStandaloneSilentSetup.exe"
name = "Brave"
repo = "brave/brave-browser"
type = "github"
```

*Example (JSON):*
```json
{
  "selectable_apps": {
    "browsers": [
      {
        "file_pattern": "zen\\.installer\\.exe",
        "install_args": "/S",
        "name": "Zen",
        "repo": "zen-browser/desktop",
        "selected": true,
        "type": "github"
      },
      {
        "file_pattern": "BraveBrowserStandaloneSilentSetup.exe",
        "name": "Brave",
        "repo": "brave/brave-browser",
        "type": "github"
      }
    ]
  }
}
```

### Configuration Formatting
- Required:
  - `name` (string)
  - `type` (github,website)
- Required for type "github":
    - `repo` (github repo)
    - `file_pattern` (regex to select the desired installer)
- Rquired for type "website":
  - `get_url_function` (Powershell function to extract download url)
    
    *Example:*
    ```
    function Get-Url {
        $LibreOfficeUri = [uri]::new( 'https://libreoffice.org/download/download/?type=win-x86_64' );
        $LibreOfficeHTML = Invoke-WebRequest -Uri $LibreOfficeUri -UseBasicParsing
        $LibreOfficeVerPattern = '(?s)class="dl_outer_green_box".*?<span class="dl_version_number">(.*?)</span>'
        $LibreOfficeVer = [regex]::Match($LibreOfficeHTML.Content, $LibreOfficeVerPattern).Groups[1].Value
        $LibreOfficeDlUri = [uri]::new( "https://download.documentfoundation.org/libreoffice/stable/$($LibreOfficeVer)/win/x86_64/LibreOffice_$($LibreOfficeVer)_Win_x86-64.msi" );
        return $LibreOfficeDlUri
    }
    ```
- Oprional for ".EXE" installers:
  - `install_args` (can be used to add arguments to the intaller and make it install silently)
- Optional for selectable software:
  - `selected` (if set to true will flag the software as default, multiple can be selected)
---

## License

This project is licensed under the [MIT License](LICENSE).

---

**Happy rebloating!**

Let me know if you want this tailored with actual script usage examples or more details on a specific section!
