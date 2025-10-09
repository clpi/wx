# Snap Installation

## Installing wx via Snap

Snap is a universal Linux package manager that works across different distributions.

### Prerequisites

Install snapd if you don't have it:

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install snapd

# Fedora
sudo dnf install snapd

# Arch Linux
sudo pacman -S snapd
sudo systemctl enable --now snapd.socket
```

### Install wx

Once the snap is published, you can install wx with:

```bash
# Install from the stable channel
sudo snap install wx

# Or install from the edge channel (pre-releases)
sudo snap install wx --edge

# Verify installation
wx --help
```

### Permissions

The wx snap requires the following permissions (automatically granted):
- `home`: Access to files in your home directory
- `network`: Network access for WASI networking syscalls
- `network-bind`: Ability to bind to network ports

### Updating

Snaps are automatically updated, but you can manually update with:

```bash
sudo snap refresh wx
```

### Uninstalling

To remove wx:

```bash
sudo snap remove wx
```

## Building the Snap Locally

If you want to build the snap package yourself:

```bash
# Install snapcraft
sudo snap install snapcraft --classic

# Build the snap
snapcraft

# Install the local snap
sudo snap install ./wx_*.snap --dangerous
```

## Channels

- **stable**: Stable releases (e.g., v1.0.0)
- **candidate**: Release candidates (e.g., v1.0.0-rc.1)
- **beta**: Beta releases (e.g., v1.0.0-beta.1)
- **edge**: Alpha releases and development builds (e.g., v1.0.0-alpha.1)

## Troubleshooting

### Snap not found

If the snap command is not found after installation:

```bash
# Add snap bin to PATH
export PATH="$PATH:/snap/bin"

# Or for permanent setup, add to ~/.bashrc or ~/.zshrc
echo 'export PATH="$PATH:/snap/bin"' >> ~/.bashrc
```

### Permission denied

If you get permission errors when running WASM files:

```bash
# Ensure the file is readable
chmod +r your-file.wasm

# Or copy it to your home directory where snap has access
```

---

**wx** - High-performance WebAssembly runtime, now available as a snap! 📦
