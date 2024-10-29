{
  description = "Automated LLVM IR optimisation pipelines using Nix flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            llvmPackages_16.llvm
            llvmPackages_16.clang
            llvmPackages_16.lld
            llvmPackages_16.lldb

            cmake
            gnumake
            ninja

            gdb
            valgrind
          ];

          shellHook = ''
            echo "Automated LLVM IR optimisation pipelines using Nix flakes"
            echo "LLVM Version: ${pkgs.llvmPackages_16.llvm.version}"
          '';
        };

        packages.default = pkgs.stdenv.mkDerivation {
          name = "llvm-ir-optimizer";
          src = ./.;
          
          buildInputs = with pkgs; [
            llvmPackages_16.llvm
            llvmPackages_16.clang
          ];

          buildPhase = ''
            # Build commands will be specified in run.sh
            echo "Building using run.sh..."
          '';

          installPhase = ''
            mkdir -p $out/bin
            # Copy necessary artifacts to output
          '';
        };
      });
}
