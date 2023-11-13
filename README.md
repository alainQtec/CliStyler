# [**CliStyler**](https://CliStyler.com) ( /!\ ver α /!\ )
 Module for configuring and customizing their command-line environments

[![CI](https://github.com/alainQtec/CliStyler/actions/workflows/CI.yaml/badge.svg)](https://github.com/alainQtec/CliStyler/actions/workflows/CI.yaml)
[![Upload artifact from Ubuntu](https://github.com/alainQtec/CliStyler/actions/workflows/Upload_Artifact.yaml/badge.svg)](https://github.com/alainQtec/CliStyler/actions/workflows/Upload_Artifact.yaml)
[![Publish to PowerShell Gallery](https://github.com/alainQtec/CliStyler/actions/workflows/Publish.yaml/badge.svg)](https://github.com/alainQtec/CliStyler/actions/workflows/Publish.yaml)

![CliStyler Logo](images/icon.png)  <!-- need help creating new icon, this icon sucks!!! -->

This module is designed to empower developers by providing an intuitive and powerful toolkit for configuring and customizing their command-line environments. Whether you're a seasoned developer or just getting started, CliStyler offers a range of features to enhance your CLI experience.

## Features

Exported cmdlets:

| category    | Description | Cmdlets    |
| :---        |    :----   |          :--- |
| **Cli Customization:**    | Change CLI environment to your preferences with easy-to-use options. | Here's this   |
|**Cli Controls:** | Gain precise control over your terminal settings, prompt, ...   | add_cmdlet      |
|**Cli Setup:** |  Simplify the process of configuring your CLI environment with step-by-step guidance. | add_cmdlet      |
|**Cli Efficiency:** |  Access a collection of time-saving commands and shortcuts for common development tasks. | add_cmdlet      |

## Installation

You can install CliStyler using the PowerShell Gallery. Open a PowerShell terminal and run:

```powershell
Install-Module -Name CliStyler -Scope CurrentUser
```

## Usage

```powershell
Import-Module CliStyler
```

## Contributions

Contributions are welcome! If you have ideas, bug reports, or want to contribute to the project, please see our Contribution Guidelines.

## License

This project is licensed under the [MIT License](https://alainQtec.MIT-license.org).

## Todos

[x] Add oh-my-posh installer method to the main class

[] Add NerdFonts installer method

[] Add custom prompt to $profile

 <!-- **cli tools to add later in version 1+**

 Give your command-line environment a personal touch with CliStyler. Craft, control, and customize your CLI experience like never before.

- [pe](https://github.com/sdras/project-explorer)

- [tb](https://github.com/klaudiosinani/taskbook)

- [tr](https://transfer.sh/)

- [ts](https://terminalsplash.com/)

- [nv](https://github.com/denisidoro/navi)

- [bf](https://github.com/niieani/bash-oo-framework)

- [cl](https://github.com/replit/clui)

- [ht](https://github.com/htop-dev/htop/releases)

- [tz](https://www.terminalizer.com/)

- [dd](https://thedevdash.com/)

- [th](https://tenhands.app/) -->
