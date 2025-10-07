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
          version = "0.1.0";
          
          src = self;
          
          nativeBuildInputs = [ pkgs.zig ];
          
          buildPhase = ''
            zig build -Doptimize=ReleaseFast
          '';
          
          installPhase = ''
            mkdir -p $out/bin
            cp zig-out/bin/wx $out/bin/
          '';
          
          meta = with pkgs.lib; {
            description = "WebAssembly runtime written in Zig with basic WASI support";
            homepage = "https://github.com/clpi/wx";
            license = licenses.mit;
            platforms = platforms.unix;
            mainProgram = "wx";
          };
        };
        
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            zig
          ];
        };
      }
    );
}
