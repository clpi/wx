# Chocolatey Installation (Windows)

## Installing wx via Chocolatey

Chocolatey is a package manager for Windows.

### Prerequisites

Install Chocolatey if you don't have it:

1. Open PowerShell as Administrator
2. Run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

### Install wx

Once the package is published, install wx with:

```powershell
# Install wx
choco install wx

# Verify installation
wx --help
```

### Updating

To update to the latest version:

```powershell
choco upgrade wx
```

### Uninstalling

To remove wx:

```powershell
choco uninstall wx
```

## Installation Options

```powershell
# Install a specific version
choco install wx --version 0.1.0

# Install with confirmation prompts disabled
choco install wx -y

# Install and pin the version (prevent auto-updates)
choco install wx
choco pin add --name wx
```

## Configuration

The wx binary will be automatically added to your PATH by Chocolatey.

## Troubleshooting

### Command not found after installation

If `wx` command is not found after installation:

1. Close and reopen your PowerShell/Command Prompt window
2. Or refresh your environment variables:

```powershell
refreshenv
```

### Permission errors

Make sure you run PowerShell or Command Prompt as Administrator when installing packages.

### Antivirus false positives

Some antivirus software may flag the binary. This is a false positive. You can:
1. Add an exception for wx in your antivirus
2. Verify the package hash with `choco info wx`

## Package Information

- **Package Name**: wx
- **Description**: High-performance WebAssembly runtime written in Zig
- **Source**: https://github.com/clpi/wx
- **License**: MIT
- **Platform**: Windows x64

## Building the Package Locally

If you want to build the Chocolatey package yourself:

```powershell
# Clone the repository
git clone https://github.com/clpi/wx.git
cd wx

# Create the package
choco pack chocolatey/wx.nuspec

# Install the local package
choco install wx -s . -y
```

## Alternative Installation Methods

If Chocolatey installation is not available yet, you can:

1. Download the binary from [GitHub Releases](https://github.com/clpi/wx/releases)
2. Add it to a directory in your PATH
3. Or use Scoop: `scoop install wx`

---

**wx** - High-performance WebAssembly runtime, now on Chocolatey! 🍫
