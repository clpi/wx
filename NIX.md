# Nix Installation

## Installing wx via Nix

wx is available as a Nix flake, making it easy to install and use on NixOS, Linux, and macOS systems with Nix installed.

### Prerequisites

You need Nix with flakes enabled. If you don't have flakes enabled yet:

```bash
# Add to ~/.config/nix/nix.conf or /etc/nix/nix.conf
experimental-features = nix-command flakes
```

Or install Nix with flakes enabled from the start:

```bash
# Install Nix with the installer that enables flakes by default
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

### Option 1: Run Without Installing

The easiest way to try wx:

```bash
nix run github:clpi/wx -- --help
nix run github:clpi/wx -- your-file.wasm
```

### Option 2: Install to Profile

Install wx to your user profile:

```bash
# Install wx
nix profile install github:clpi/wx

# Verify installation
wx --help
```

### Option 3: Use in a Development Shell

Enter a temporary shell with wx available:

```bash
# Start a shell with wx
nix shell github:clpi/wx

# Now wx is available
wx --help
```

### Option 4: NixOS System Configuration

For NixOS users, add wx to your system configuration:

```nix
{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    wx.url = "github:clpi/wx";
  };

  outputs = { self, nixpkgs, wx, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {
          environment.systemPackages = [
            wx.packages.x86_64-linux.default
          ];
        }
      ];
    };
  };
}
```

### Option 5: Home Manager

Add wx to your Home Manager configuration:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    home-manager.url = "github:nix-community/home-manager";
    wx.url = "github:clpi/wx";
  };

  outputs = { self, nixpkgs, home-manager, wx, ... }: {
    homeConfigurations."user@host" = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      modules = [
        {
          home.packages = [
            wx.packages.x86_64-linux.default
          ];
        }
      ];
    };
  };
}
```

## Development Shell

wx provides a development shell with Zig and other development tools:

```bash
# Enter the development shell
nix develop github:clpi/wx

# Now you have access to development tools
zig version
zig build
zig build test
```

Or use it for a one-off command:

```bash
nix develop github:clpi/wx --command zig build
```

## Building from Source

Build wx from the flake:

```bash
# Build the package
nix build github:clpi/wx

# The binary will be in ./result/bin/wx
./result/bin/wx --help
```

## Updating

To update wx to the latest version:

```bash
# Update the flake lock file
nix flake update github:clpi/wx

# Reinstall
nix profile upgrade '.*wx.*'
```

For NixOS/Home Manager users, update your flake inputs and rebuild:

```bash
nix flake update
sudo nixos-rebuild switch  # For NixOS
home-manager switch        # For Home Manager
```

## Pinning a Specific Version

You can pin to a specific commit or tag:

```bash
# Use a specific tag
nix run github:clpi/wx/v0.1.0

# Use a specific commit
nix run github:clpi/wx/abc1234
```

## Uninstalling

To remove wx from your profile:

```bash
nix profile remove '.*wx.*'
```

## Supported Platforms

The Nix flake builds wx for:
- `x86_64-linux`
- `aarch64-linux`
- `x86_64-darwin` (macOS Intel)
- `aarch64-darwin` (macOS Apple Silicon)

## Troubleshooting

### Flakes Not Enabled

If you get an error about flakes not being enabled:

```bash
# Enable flakes in your Nix configuration
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

### Build Failures

If the build fails:

1. Make sure you have enough disk space
2. Try cleaning the Nix store: `nix-collect-garbage`
3. Update nixpkgs: `nix flake update`

### Profile Issues

If profile commands fail:

```bash
# List installed packages
nix profile list

# Remove and reinstall
nix profile remove '.*wx.*'
nix profile install github:clpi/wx
```

## Additional Resources

- [Nix Manual](https://nixos.org/manual/nix/stable/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)

## Contributing

To contribute to the Nix flake:

1. Test your changes: `nix flake check`
2. Build the package: `nix build`
3. Test the binary: `./result/bin/wx --help`
4. Submit a pull request

---

**wx** - High-performance WebAssembly runtime, now with Nix support! ❄️
