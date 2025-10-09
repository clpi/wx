# APT/Debian Installation

## Installing wx via APT

APT (Advanced Package Tool) is the package manager for Debian-based systems like Ubuntu.

### Prerequisites

You need a Debian-based system:
- Debian (Bookworm, Bullseye, or newer)
- Ubuntu (22.04 LTS or newer)
- Linux Mint
- Pop!_OS
- Elementary OS
- Other Debian-based distributions

### Option 1: Install from .deb Package

Download the .deb package from the [releases page](https://github.com/clpi/wx/releases) and install:

```bash
# Download the .deb file
wget https://github.com/clpi/wx/releases/download/v0.1.0/wx_0.1.0-1_amd64.deb

# Install the package
sudo dpkg -i wx_0.1.0-1_amd64.deb

# Install any missing dependencies
sudo apt-get install -f

# Verify installation
wx --help
```

### Option 2: Install from PPA (Future)

Once a PPA is set up, you'll be able to install with:

```bash
# Add the PPA
sudo add-apt-repository ppa:clpi/wx
sudo apt-get update

# Install wx
sudo apt-get install wx

# Verify installation
wx --help
```

### Updating

If installed from PPA:

```bash
sudo apt-get update
sudo apt-get upgrade wx
```

If installed from .deb:

```bash
# Download the new .deb file
wget https://github.com/clpi/wx/releases/download/v0.2.0/wx_0.2.0-1_amd64.deb

# Install the update
sudo dpkg -i wx_0.2.0-1_amd64.deb
```

### Uninstalling

```bash
sudo apt-get remove wx

# Or remove with configuration files
sudo apt-get purge wx
```

## Supported Architectures

- amd64 (x86_64)
- arm64 (aarch64)

## Package Information

```bash
# Show package information
apt-cache show wx

# List files installed by the package
dpkg -L wx

# Check package status
dpkg -s wx
```

## Building the .deb Package Locally

If you want to build the Debian package yourself:

```bash
# Install build dependencies
sudo apt-get update
sudo apt-get install -y \
    debhelper \
    devscripts \
    build-essential \
    curl \
    xz-utils

# Install Zig
curl -L https://ziglang.org/download/0.15.1/zig-linux-x86_64-0.15.1.tar.xz -o zig.tar.xz
tar -xf zig.tar.xz
sudo mv zig-linux-x86_64-0.15.1 /usr/local/zig
export PATH="/usr/local/zig:$PATH"

# Clone the repository
git clone https://github.com/clpi/wx.git
cd wx

# Build the package
dpkg-buildpackage -us -uc -b

# Install the built package
cd ..
sudo dpkg -i wx_*.deb
```

## Troubleshooting

### Dependency issues

If you encounter dependency issues:

```bash
# Fix broken dependencies
sudo apt-get install -f

# Or use aptitude for better dependency resolution
sudo apt-get install aptitude
sudo aptitude install wx
```

### Package not found

If the package is not found after adding the PPA:

```bash
# Update package lists
sudo apt-get update

# Search for the package
apt-cache search wx
```

### Permission errors

Make sure you use `sudo` for installation commands.

## Verifying Performance

After installation, you can benchmark wx against other runtimes:

```bash
# Install comparison runtimes (optional)
curl https://get.wasmer.io -sSfL | sh
curl https://wasmtime.dev/install.sh -sSfL | bash

# Clone repository for benchmark files
git clone https://github.com/clpi/wx.git
cd wx/bench

# Run comprehensive benchmarks
python3 benchmark.py
```

See [BENCHMARKS.md](BENCHMARKS.md) for detailed performance information.

## Alternative Installation Methods

If APT installation is not suitable, you can:

1. **Build from source**:
   ```bash
   sudo apt-get install zig
   git clone https://github.com/clpi/wx.git
   cd wx
   zig build -Doptimize=ReleaseFast
   sudo cp zig-out/bin/wx /usr/local/bin/
   ```

2. **Use Snap**: `sudo snap install wx`
3. **Use Nix**: `nix profile install github:clpi/wx`

## Package Details

- **Package Name**: wx
- **Section**: utils
- **Priority**: optional
- **Description**: High-performance WebAssembly runtime written in Zig
- **Homepage**: https://github.com/clpi/wx
- **License**: MIT

---

**wx** - High-performance WebAssembly runtime, now available as a .deb! 📦
