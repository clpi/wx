# Releasing wx

This document describes how to create a new release of wx.

## Release Process

The release process is automated through GitHub Actions. When you push a version tag, the workflow will:

1. Build binaries for multiple platforms (Linux, macOS Intel, macOS ARM, Windows)
2. Create a GitHub release with the binaries attached
3. Generate release notes automatically

## Creating a Release

### 1. Update Version

First, update the version in `build.zig`:

```zig
pub const version: std.SemanticVersion = .{
    .build = "0",
    .major = 0,
    .patch = 1,  // Increment this or other version fields
    .minor = 0,
    .pre = null,  // Remove "alpha" for stable releases
};
```

Also update `.build.zig.zon` if needed:

```zig
.version = "0.0.1",
```

### 2. Commit Changes

```bash
git add build.zig .build.zig.zon
git commit -m "Bump version to v0.0.1"
```

### 3. Create and Push Tag

```bash
git tag v0.0.1
git push origin v0.0.1
```

### 4. Monitor Workflow

The release workflow will automatically start. You can monitor it at:
https://github.com/clpi/wx/actions/workflows/release.yml

### 5. Verify Release

Once the workflow completes, verify the release at:
https://github.com/clpi/wx/releases

The release should include binaries for:
- `wx-linux-x86_64`
- `wx-macos-x86_64`
- `wx-macos-aarch64`
- `wx-windows-x86_64.exe`

## Version Numbering

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR** version for incompatible API changes
- **MINOR** version for new functionality in a backward compatible manner
- **PATCH** version for backward compatible bug fixes

### Pre-releases

For pre-release versions, use tags like:
- `v0.1.0-alpha.1`
- `v0.1.0-beta.1`
- `v0.1.0-rc.1`

These will be marked as pre-releases on GitHub automatically.

## Manual Release Trigger

You can also trigger a release manually without pushing a tag:

1. Go to https://github.com/clpi/wx/actions/workflows/release.yml
2. Click "Run workflow"
3. Select the branch
4. Click "Run workflow"

Note: Manual runs without a tag will create a release with the commit SHA.

## Troubleshooting

### Build Fails for a Platform

If the build fails for a specific platform:

1. Check the workflow logs
2. Test locally with: `zig build -Dtarget=<target> -Doptimize=ReleaseFast`
3. Fix any platform-specific issues
4. Delete the failed tag: `git tag -d v0.0.1 && git push origin :refs/tags/v0.0.1`
5. Create a new tag after fixing

### Release Already Exists

If you need to re-create a release:

1. Delete the release on GitHub
2. Delete the tag locally and remotely
3. Create and push the tag again
