{
  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-21.11;
    utils.url = github:numtide/flake-utils;
    nix-filter.url = github:numtide/nix-filter;
    zig-overlay.url = github:roarkanize/zig-overlay;
    zgl = {
      url = github:ziglibs/zgl;
      flake = false;
    };
    stb = {
      url = github:nothings/stb;
      flake = false;
    };
  };
  outputs = {self, nixpkgs, utils, nix-filter, zig-overlay, zgl, stb}:
    with utils.lib; eachSystem allSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        zig = zig-overlay.packages.${system}."0.9.1";
        buildLib = {libepoxy, gl, freetype}: pkgs.stdenvNoCC.mkDerivation rec {
          pname = "zargo";
          version = "0.1.0";
          src = with nix-filter.lib; filter {
            root = ./.;
            include = [ (inDirectory "src") (inDirectory "include") ];
          };
          buildInputs = [ libepoxy gl freetype stb ];
          phases = [ "unpackPhase" "buildPhase" "installPhase" ];
          CPPFLAGS = builtins.map (lib: "-I${if builtins.hasAttr "dev" lib then "${lib.dev}/include" else lib}") buildInputs;
          buildPhase = ''
            export ZIG_LOCAL_CACHE_DIR=$(pwd)/zig-cache
            export ZIG_GLOBAL_CACHE_DIR=$ZIG_LOCAL_CACHE_DIR
            ${zig}/bin/zig build-lib -static --name zargo --pkg-begin zgl ${zgl}/zgl.zig --pkg-end src/libzargo.zig src/stb_image.c $CPPFLAGS
          '';
          installPhase = ''
            mkdir -p $out/{lib,include}
            mv libzargo.a $out/lib
            cp -r include/zargo $out/include
          '';
        };
      in {
        packages = rec {
          clib = buildLib {
            inherit (pkgs) libepoxy freetype;
            gl = pkgs.libGL;
          };
          ctest = pkgs.stdenvNoCC.mkDerivation rec {
            pname = "zargo-ctest";
            version = "0.1.0";
            buildInputs = [ clib pkgs.glfw ];
            src = ./tests;
            buildPhases = [ "unpackPhase" "buildPhase" "installPhase" ];
            CPPFLAGS = builtins.map (lib: "-I${if builtins.hasAttr "dev" lib then lib.dev else lib}/include") buildInputs;
            LDFLAGS = builtins.map (lib: "-L${lib}/lib -l${lib.pname}") (buildInputs ++ [ pkgs.freetype ]);
            buildPhase = ''
              export ZIG_LOCAL_CACHE_DIR=$(pwd)/zig-cache
              export ZIG_GLOBAL_CACHE_DIR=$ZIG_LOCAL_CACHE_DIR
              echo CPPFLAGS=$CPPFLAGS
              echo LDFLAGS=$LDFLAGS
              ${zig}/bin/zig cc test.c -o zargo-ctest $CPPFLAGS $LDFLAGS -L${pkgs.libepoxy}/lib -lepoxy -target aarch64-macos-gnu
            '';
            installPhase = ''
              mkdir -p $out/bin
              mv zargo-ctest $out/bin
            '';
          };
        };
      }
  );
}