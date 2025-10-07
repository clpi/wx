# Package Distribution

This document describes how `wx` is distributed across various package managers and repositories.

## Supported Package Managers

### Homebrew (macOS and Linux)

#### Homebrew Formula (recommended)
```bash
brew install clpi/tap/wx
```

#### Homebrew Cask (macOS only)
```bash
brew install --cask wx
```

The Homebrew formula is located in `Formula/wx.rb` and supports both x86_64 and ARM64 architectures.

### Nix/NixOS

Using flakes:
```bash
nix run github:clpi/wx
```

Or add to your `flake.nix`:
```nix
{
  inputs.wx.url = "github:clpi/wx";
}
```

The Nix flake configuration is in `flake.nix` and provides both the package and a development shell.

### Arch Linux (AUR)

```bash
yay -S wx-bin
# or
paru -S wx-bin
```

The PKGBUILD file is located in the root directory and can be submitted to the AUR.

### MacPorts (macOS)

```bash
sudo port install wx
```

The Portfile is located in the root directory and can be submitted to MacPorts.

## Release Process

When a new release is created on GitHub:

1. The `release.yml` workflow automatically builds binaries for:
   - Linux x86_64
   - macOS x86_64 (Intel)
   - macOS aarch64 (Apple Silicon)
   - Windows x86_64

2. It generates package files with proper checksums:
   - `Formula/wx.rb` - Homebrew formula
   - `wx.rb` - Homebrew cask
   - `PKGBUILD` - Arch Linux AUR
   - `Portfile` - MacPorts

3. All binaries and package files are attached to the GitHub release.

## Manual Distribution

### Submitting to AUR

1. Create an AUR account at https://aur.archlinux.org/
2. Clone the AUR repository:
   ```bash
   git clone ssh://aur@aur.archlinux.org/wx-bin.git
   ```
3. Copy the generated `PKGBUILD` from the release
4. Test the package:
   ```bash
   makepkg -si
   ```
5. Commit and push:
   ```bash
   git add PKGBUILD .SRCINFO
   git commit -m "Update to version X.Y.Z"
   git push
   ```

### Submitting to Homebrew

For the official Homebrew tap:
1. Fork https://github.com/Homebrew/homebrew-core
2. Copy `Formula/wx.rb` to `Formula/` in your fork
3. Create a pull request

For a custom tap:
1. Create a repository named `homebrew-tap`
2. Add `Formula/wx.rb` to the repository
3. Users can install with: `brew install clpi/tap/wx`

### Submitting to MacPorts

1. Follow the MacPorts contribution guide: https://guide.macports.org/#project.contributing
2. Submit the `Portfile` as a new port or update

### Submitting to nixpkgs

1. Fork https://github.com/NixOS/nixpkgs
2. Add the package to `pkgs/by-name/wx/wx/package.nix`
3. Test locally:
   ```bash
   nix-build -A wx
   ```
4. Create a pull request

## Building from Source

See the main README.md for instructions on building from source using Zig.
