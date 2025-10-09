# Homebrew Installation

## Installing wx via Homebrew

### Option 1: Install from this repository (Recommended)

You can install wx directly from this repository:

```bash
brew install clpi/wx/wx
```

Or tap the repository first:

```bash
brew tap clpi/wx
brew install wx
```

### Option 2: Install from local formula

If you have cloned this repository, you can install from the local formula:

```bash
brew install --build-from-source ./Formula/wx.rb
```

Or from the Brewfile:

```bash
brew install --build-from-source ./Brewfile
```

## Updating

To update to the latest version:

```bash
brew update
brew upgrade wx
```

## Uninstalling

To uninstall wx:

```bash
brew uninstall wx
```

## Requirements

- Zig compiler (automatically installed as a dependency)

## Troubleshooting

If you encounter issues:

1. Update Homebrew: `brew update`
2. Check for conflicts: `brew doctor`
3. Try reinstalling: `brew reinstall wx`

## Using the head version

To install the latest development version from the main branch:

```bash
brew install --HEAD clpi/wx/wx
```

## Creating a Homebrew Tap

To use this formula from a tap, you can create a Homebrew tap repository:

1. Create a new repository named `homebrew-wx` (the `homebrew-` prefix is required)
2. Copy the `Formula/wx.rb` file to the root of that repository
3. Users can then install with: `brew tap clpi/wx && brew install wx`

The formula is automatically updated when new releases are published via the Homebrew workflow.

## Formula Details

The wx Homebrew formula:
- Installs the wx WebAssembly runtime
- Automatically manages the Zig dependency
- Builds from source for optimal performance
- Includes a simple test to verify installation

Current formula location: `Formula/wx.rb`
