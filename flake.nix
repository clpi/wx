{
  description = "wx WASM runtime";
  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixos-24.05";
    };
    flakeutils = {
      url = "github:numtide/flake-utils";
    };
  };

  outputs = { self, nixpkgs, flakeutils }:
    flakeutils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "wx";
          version = "0.0.0-alpha";

          src = ./.;

          nativeBuildInputs = [ pkgs.zig_0_15 ];

          buildPhase = ''
            export HOME=$TMPDIR
            zig build
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp zig-out/bin/wx $out/bin/
          '';

          meta = with pkgs.lib; {
            description = "High-performance WebAssembly runtime written in Zig";
            homepage = "https://github.com/clpi/wx";
            license = licenses.mit;
            maintainers = [ ];
            platforms = platforms.unix;
          };
        };

        apps.default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/wx";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            zig_0_15
          ];

          shellHook = ''
            echo "wx development environment"
            echo "Zig version: $(zig version)"
          '';
        };
      }
    );
}
