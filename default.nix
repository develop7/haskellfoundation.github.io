{ compiler ? "ghc865"
, system ? builtins.currentSystem
, pkgs ? import (import ./dep/nixpkgs.nix) { inherit system; }
}:

let
  inherit (pkgs.lib.trivial) flip pipe;
  inherit (pkgs.haskell.lib) appendPatch appendConfigureFlags overrideCabal;
  nodePkgs = (pkgs.callPackage ./dep/node { inherit pkgs; nodejs = pkgs.nodejs-12_x; }).shell.nodeDependencies;

  haskellPackages = pkgs.haskell.packages.${compiler}.override {
    overrides = hpNew: hpOld: {
      hakyll =
        pipe
           hpOld.hakyll
           [ (flip appendConfigureFlags [ "-f" "watchServer" "-f" "previewServer" ])
           ];

      haskell-foundation = hpNew.callCabal2nix "haskell-foundation" (pkgs.stdenv.lib.cleanSource ./haskell) { };
    };
  };

  project = haskellPackages.haskell-foundation;
in
{
  inherit project nodePkgs;

  site = pkgs.runCommand "haskell-foundation" {
    nativeBuildInputs = [ nodePkgs project ];
  } ''
    cp --no-preserve=mode -r ${./site} site
    cd site
    site build
  '';

  shell = haskellPackages.shellFor {
    packages = p: with p; [
      haskell-foundation
    ];
    nativeBuildInputs = with haskellPackages.buildHaskellPackages; [
      ghcid
      hlint
      nodePkgs
      cabal-install
    ];
    NODE_PATH = "${nodePkgs}/lib/node_modules";
    withHoogle = true;
  };
}
