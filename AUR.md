# Arch User Repository (AUR) Installation

## Installing wx from AUR

The wx package is available on the Arch User Repository (AUR).

### Prerequisites

You need an AUR helper or you can build packages manually. Popular AUR helpers include:
- yay
- paru
- pamac
- trizen

### Option 1: Using yay (Recommended)

```bash
# Install yay if you don't have it
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si

# Install wx
yay -S wx

# Verify installation
wx --help
```

### Option 2: Using paru

```bash
# Install paru if you don't have it
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si

# Install wx
paru -S wx

# Verify installation
wx --help
```

### Option 3: Manual Installation

```bash
# Install build dependencies
sudo pacman -S --needed git base-devel zig

# Clone the AUR package
git clone https://aur.archlinux.org/wx.git
cd wx

# Build and install
makepkg -si

# Verify installation
wx --help
```

## Updating

### With AUR helper

```bash
# Using yay
yay -Syu

# Using paru
paru -Syu
```

### Manual update

```bash
cd wx
git pull
makepkg -si
```

## Uninstalling

```bash
sudo pacman -R wx
```

## Building from Source

If you want to build from the latest source instead of using the AUR package:

```bash
# Install dependencies
sudo pacman -S zig

# Clone the repository
git clone https://github.com/clpi/wx.git
cd wx

# Build
zig build -Doptimize=ReleaseFast

# Install manually
sudo cp zig-out/bin/wx /usr/local/bin/
```

## Package Information

- **Package Name**: wx
- **Description**: High-performance WebAssembly runtime written in Zig
- **Upstream**: https://github.com/clpi/wx
- **License**: MIT
- **Architecture**: x86_64, aarch64

## Contributing to the AUR Package

The PKGBUILD is maintained at https://aur.archlinux.org/packages/wx

To contribute:
1. Make your changes to the PKGBUILD
2. Update .SRCINFO with `makepkg --printsrcinfo > .SRCINFO`
3. Commit and push to the AUR repository

## Troubleshooting

### Build fails with Zig errors

Make sure you have the correct Zig version:

```bash
# Check Zig version
zig version

# Should be 0.15.1 or later
```

### Checksum mismatch

If you get a checksum error, the package maintainer needs to update the PKGBUILD. You can:
1. Wait for the maintainer to update it
2. Comment on the AUR package page
3. Update it yourself and submit a merge request

---

**wx** - High-performance WebAssembly runtime, available on AUR! 🏔️
