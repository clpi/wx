# Release Process

This document describes how to create a new release of `wx` and automatically generate package distribution files.

## Creating a Release

### Automated Release Workflow

The release workflow (`.github/workflows/release.yml`) automatically:
1. Builds binaries for multiple platforms (Linux, macOS x86_64, macOS ARM64, Windows)
2. Calculates SHA256 checksums for all binaries
3. Generates package files with correct checksums:
   - Homebrew Formula (`Formula/wx.rb`)
   - Homebrew Cask (`wx.rb`)
   - AUR PKGBUILD (`PKGBUILD`)
   - MacPorts Portfile (`Portfile`)
4. Uploads all binaries and package files to the GitHub release

### How to Trigger a Release

#### Option 1: Create a GitHub Release (Recommended)

1. Go to the repository on GitHub
2. Click "Releases" → "Draft a new release"
3. Choose or create a new tag (e.g., `v0.1.0`)
4. Fill in the release title and description
5. Click "Publish release"

The workflow will automatically run and attach all binaries and package files to the release.

#### Option 2: Manual Workflow Dispatch

1. Go to Actions → Release workflow
2. Click "Run workflow"
3. Select the branch
4. Click "Run workflow"

This will build all binaries and artifacts but won't create a release automatically.

## Version Numbering

The project uses semantic versioning (MAJOR.MINOR.PATCH):
- **MAJOR**: Breaking changes to the API or behavior
- **MINOR**: New features, backwards compatible
- **PATCH**: Bug fixes, backwards compatible

Current version is defined in:
- `build.zig` (line ~15): `pub const version: std.SemanticVersion`
- Package files: `Formula/wx.rb`, `PKGBUILD`, `Portfile`, `flake.nix`, `Brewfile`

### Before Creating a Release

1. Update the version in all package files:
   ```bash
   # Update these files with the new version number:
   - build.zig (version constant)
   - Formula/wx.rb (version field)
   - PKGBUILD (pkgver field)
   - Portfile (version field)
   - flake.nix (version in mkDerivation)
   - Brewfile (version field)
   ```

2. Test the build locally:
   ```bash
   zig build
   ./zig-out/bin/wx --version
   ```

3. Run tests:
   ```bash
   zig build test
   ```

4. Commit version changes:
   ```bash
   git add -u
   git commit -m "Bump version to vX.Y.Z"
   git push
   ```

## After Release

### Updating Package Repositories

The release workflow generates package files with checksums, but you still need to submit them to the respective repositories:

#### 1. Homebrew

**For a custom tap:**
- Create a GitHub repository named `homebrew-tap`
- Copy the generated `Formula/wx.rb` from the release
- Commit and push to your tap repository
- Users install with: `brew install yourusername/tap/wx`

**For official Homebrew:**
- Fork https://github.com/Homebrew/homebrew-core
- Add the generated `Formula/wx.rb` to the `Formula/` directory
- Submit a pull request

#### 2. AUR (Arch User Repository)

```bash
# Clone your AUR repository
git clone ssh://aur@aur.archlinux.org/wx-bin.git
cd wx-bin

# Copy the generated PKGBUILD from the release
curl -L -o PKGBUILD https://github.com/clpi/wx/releases/download/vX.Y.Z/PKGBUILD

# Generate .SRCINFO
makepkg --printsrcinfo > .SRCINFO

# Commit and push
git add PKGBUILD .SRCINFO
git commit -m "Update to vX.Y.Z"
git push
```

#### 3. MacPorts

- Follow the MacPorts contribution guide
- Submit the generated `Portfile` as a ticket at https://trac.macports.org/

#### 4. Nix/NixOS

**For personal use:**
Users can use the flake directly: `nix run github:clpi/wx`

**For nixpkgs:**
- Fork https://github.com/NixOS/nixpkgs
- Create `pkgs/by-name/wx/wx/package.nix` based on `flake.nix`
- Test: `nix-build -A wx`
- Submit a pull request

## Workflow Files

- `.github/workflows/build.yml` - CI build on every push
- `.github/workflows/release.yml` - Release build and package generation
- `.github/workflows/validate-packages.yml` - Validates package file syntax

## Troubleshooting

### Release workflow fails

1. Check the Actions tab for error messages
2. Verify Zig version compatibility in the workflow
3. Ensure all package files have correct syntax

### Missing artifacts

1. Verify the workflow completed successfully
2. Check that the release was created (not just a tag)
3. Confirm `GITHUB_TOKEN` has write permissions

### Incorrect checksums

The checksums are calculated automatically during the workflow. If they're incorrect:
1. Check that binaries were built successfully
2. Verify the `sha256sum` command worked in the workflow logs
3. Re-run the workflow

## Support

For issues with the release process, please open an issue on GitHub with:
- The release version you're trying to create
- Workflow run logs
- Any error messages
