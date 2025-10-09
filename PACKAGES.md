# Package Manager Distribution

This document provides an overview of all package managers where wx is available.

## 📦 Available Package Managers

### macOS/Linux

| Package Manager | Platform | Status | Documentation |
|----------------|----------|--------|---------------|
| **Homebrew** | macOS, Linux | ✅ Available | [HOMEBREW.md](HOMEBREW.md) |
| **Nix** | NixOS, Linux, macOS | ✅ Available | [NIX.md](NIX.md) |
| **Snap** | Linux (all distros) | 🔄 Pending | [SNAP.md](SNAP.md) |
| **APT** | Debian, Ubuntu | 🔄 Pending | [APT.md](APT.md) |
| **AUR** | Arch Linux | 🔄 Pending | [AUR.md](AUR.md) |

### Windows

| Package Manager | Status | Documentation |
|----------------|--------|---------------|
| **Chocolatey** | 🔄 Pending | [CHOCOLATEY.md](CHOCOLATEY.md) |
| **Scoop** | 🔄 Pending | [SCOOP.md](SCOOP.md) |

### Containers

| Registry | Status | Image |
|----------|--------|-------|
| **GitHub Container Registry** | ✅ Available | `ghcr.io/clpi/wx` |
| **Docker Hub** | 🔄 Pending credentials | `clpi/wx` |
| **Quay.io** | 🔄 Pending credentials | `quay.io/clpi/wx` |

## Quick Install Commands

### Linux

```bash
# Homebrew
brew install clpi/wx/wx

# Nix
nix profile install github:clpi/wx

# Snap
sudo snap install wx

# APT (Debian/Ubuntu)
wget https://github.com/clpi/wx/releases/latest/download/wx_*_amd64.deb
sudo dpkg -i wx_*_amd64.deb

# AUR (Arch Linux)
yay -S wx
```

### macOS

```bash
# Homebrew
brew install clpi/wx/wx

# Nix
nix profile install github:clpi/wx
```

### Windows

```powershell
# Chocolatey
choco install wx

# Scoop
scoop install https://raw.githubusercontent.com/clpi/wx/main/scoop/wx.json
```

### Docker/Container

```bash
# Run wx with Docker
docker run --rm ghcr.io/clpi/wx:latest --help
```

## Setting Up Package Distribution

### For Package Maintainers

If you want to maintain a wx package for a package manager not listed above:

1. Fork the repository
2. Add your package configuration files
3. Submit a pull request
4. We'll set up automated updates on new releases

### Required Secrets

To enable automated publishing, the following GitHub secrets need to be configured:

#### Snap
- `SNAPCRAFT_STORE_CREDENTIALS`: Snapcraft login credentials

#### AUR
- `AUR_SSH_PRIVATE_KEY`: SSH private key for AUR repository

#### Chocolatey
- `CHOCOLATEY_API_KEY`: Chocolatey API key from chocolatey.org

#### Scoop
- `SCOOP_BUCKET_TOKEN`: GitHub PAT with repo access to scoop-bucket

#### Container Registries
- `DOCKERHUB_USERNAME`: Docker Hub username
- `DOCKERHUB_TOKEN`: Docker Hub access token
- `QUAY_USERNAME`: Quay.io username
- `QUAY_TOKEN`: Quay.io token

## Automated Workflows

All package managers have automated GitHub Actions workflows that:

1. **Trigger on release**: Automatically build/update packages when a new release is published
2. **Manual trigger**: Can be manually triggered for specific tags
3. **Generate checksums**: Calculate SHA256 checksums for verification
4. **Upload artifacts**: Store built packages as GitHub artifacts
5. **Publish**: Push to package registries (when credentials are configured)

### Workflow Files

| Workflow | File | Package Manager |
|----------|------|-----------------|
| Homebrew | `.github/workflows/homebrew.yml` | Homebrew |
| Nix | `.github/workflows/nix.yml` | Nix Flakes |
| Snap | `.github/workflows/snap.yml` | Snap |
| APT | `.github/workflows/apt.yml` | Debian/Ubuntu |
| AUR | `.github/workflows/aur.yml` | Arch Linux |
| Chocolatey | `.github/workflows/chocolatey.yml` | Chocolatey |
| Scoop | `.github/workflows/scoop.yml` | Scoop |
| Docker | `.github/workflows/docker.yml` | Container registries |

## Release Process

When a new version is released:

1. **Tag is created**: `git tag v0.1.0 && git push origin v0.1.0`
2. **Release workflow**: Builds binaries for all platforms
3. **Package workflows**: Each package manager workflow is triggered
4. **Artifacts**: Packages are built and uploaded as artifacts
5. **Publishing**: Packages are published to registries (if credentials are available)
6. **Documentation**: README and package docs are updated with new version

## Verification

All packages include checksums for verification:

```bash
# Verify downloaded binaries
sha256sum wx-linux-x86_64
# Compare with checksums.txt from release

# Docker images
docker pull ghcr.io/clpi/wx:latest
docker inspect ghcr.io/clpi/wx:latest | grep -i digest
```

## Platform Support

### Architectures

| Architecture | Linux | macOS | Windows |
|--------------|-------|-------|---------|
| x86_64 (amd64) | ✅ | ✅ | ✅ |
| aarch64 (arm64) | ✅ | ✅ | ⚠️ Future |

### Minimum Versions

- **Linux**: Kernel 3.10+ (most distributions from 2015+)
- **macOS**: 10.15+ (Catalina or newer)
- **Windows**: Windows 10 or Windows Server 2016

## Contributing

To add support for a new package manager:

1. Create the package configuration files
2. Add a GitHub Actions workflow
3. Add documentation (PACKAGENAME.md)
4. Update this file with the new package manager
5. Submit a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for more details.

## Resources

- [GitHub Releases](https://github.com/clpi/wx/releases)
- [GitHub Actions](https://github.com/clpi/wx/actions)
- [Container Images](https://github.com/clpi/wx/pkgs/container/wx)
- [Issue Tracker](https://github.com/clpi/wx/issues)

---

**wx** - Available everywhere! 🌍
