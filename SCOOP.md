# Scoop Installation (Windows)

## Installing wx via Scoop

Scoop is a command-line installer for Windows.

### Prerequisites

Install Scoop if you don't have it:

1. Open PowerShell (no admin rights required)
2. Run:

```powershell
# Set execution policy for current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Install Scoop
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
```

### Install wx

Once the manifest is published, install wx with:

```powershell
# Add the wx bucket (if a separate bucket is created)
scoop bucket add wx https://github.com/clpi/scoop-bucket

# Or install directly from this repository
scoop install https://raw.githubusercontent.com/clpi/wx/main/scoop/wx.json

# Verify installation
wx --help
```

### Updating

To update to the latest version:

```powershell
scoop update wx
```

Or update all packages:

```powershell
scoop update *
```

### Uninstalling

To remove wx:

```powershell
scoop uninstall wx
```

## Installation Locations

Scoop installs applications to `~\scoop\apps\` by default. The wx binary will be in:
- `~\scoop\apps\wx\current\wx-windows-x86_64.exe`
- Automatically added to PATH as `wx`

## Advanced Usage

```powershell
# Show package information
scoop info wx

# Check for available updates
scoop status

# Hold a specific version (prevent updates)
scoop hold wx

# Unhold to allow updates again
scoop unhold wx
```

## Why Scoop?

Scoop advantages:
- **No admin rights required** for most installations
- **Clean uninstallation** - no leftover files or registry entries
- **Portable** - all apps in one directory
- **Fast** - parallel downloads and minimal overhead
- **Version management** - easy to switch between versions

## Scoop Buckets

Scoop organizes packages into "buckets". Common buckets:

```powershell
# Add common buckets
scoop bucket add extras
scoop bucket add main
scoop bucket add versions
```

## Troubleshooting

### Command not found after installation

Scoop automatically adds binaries to PATH. If not working:

1. Restart your PowerShell session
2. Or run: `scoop reset wx`

### Hash mismatch error

If you get a hash mismatch error:

```powershell
# Skip hash check (not recommended)
scoop install wx --skip

# Or wait for the manifest to be updated
```

### Installation fails

Make sure PowerShell execution policy allows scripts:

```powershell
Get-ExecutionPolicy -List
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Package Information

- **Package Name**: wx
- **Description**: High-performance WebAssembly runtime written in Zig
- **Source**: https://github.com/clpi/wx
- **License**: MIT
- **Platform**: Windows x64

## Building from Source

If you want to build from source instead:

```powershell
# Install Zig via Scoop
scoop install zig

# Clone the repository
git clone https://github.com/clpi/wx.git
cd wx

# Build
zig build -Doptimize=ReleaseFast

# The binary will be at zig-out\bin\wx.exe
```

## Alternative Installation Methods

If Scoop installation is not available yet, you can:

1. Download the binary from [GitHub Releases](https://github.com/clpi/wx/releases)
2. Or use Chocolatey: `choco install wx`

---

**wx** - High-performance WebAssembly runtime, now on Scoop! 🥄
