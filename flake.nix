# Copyright 2024 Efabless Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
{
  nixConfig = {
    extra-substituters = [
      "https://openlane.cachix.org"
    ];
    extra-trusted-public-keys = [
      "openlane.cachix.org-1:qqdwh+QMNGmZAuyeQJTH9ErW57OWSvdtuwfBKdS254E="
    ];
  };

  inputs = {
    openlane.url = github:efabless/openlane2;
  };

  outputs = {
    self,
    openlane,
    ...
  }: let
    nix-eda = openlane.inputs.nix-eda;
    nixpkgs = nix-eda.inputs.nixpkgs;
    lib = nixpkgs.lib;
  in {
    # Common
    overlays = {
      default = pkgs': pkgs: let
        callPackage = lib.callPackageWith pkgs';
        callPythonPackage = lib.callPackageWith (pkgs' // pkgs'.python3.pkgs);
      in (
        {
          # Versions from 1.0.0 (superstable)
          yosys-abc = pkgs'.stdenv.mkDerivation {
            name = "yosys-abc";
            src = pkgs'.fetchFromGitHub {
              owner = "YosysHQ";
              repo = "abc";
              rev = "bb64142b07794ee685494564471e67365a093710";
              sha256 = "sha256-nqemGBrP/Zv1YaRPSz1gCdVs7exI9eHCLZ+GU13Yw4c=";
            };

            nativeBuildInputs = [pkgs'.cmake];
            buildInputs = [pkgs'.readline];

            installPhase = "mkdir -p $out/bin && mv abc $out/bin";
          };
          yosys = (pkgs.yosys.override {
            version = "14d50a176d59a5eac95a57a01f9e933297251d5b";
            sha256 = "sha256-ZdtQ3tUEImJGYzN2j4f3fuxYUzTmSx6Vz8U7mLjgZXY=";
          }).overrideAttrs(self: super: {
            patches = [];
            makeFlags = super.makeFlags ++ [
              "CXX=clang++"
              "ABC_EXTERNAL=${pkgs'.yosys-abc}/bin/abc"
              "PREFIX=${placeholder "out"}"
            ];
            buildInputs = super.buildInputs ++ [pkgs.readline];
            meta.license = lib.licenses.gpl3; # readline linked
          });
          openroad-abc = pkgs.openroad-abc.override {
            rev = "95b3543e928640dfa25f9e882e72a090a8883a9c";
            sha256 = "sha256-U1E9wvEK5G4zo5Pepvsb5q885qSYyixIViweLacO5+U=";
          };
          opensta = pkgs.opensta.override {
            rev = "2609cc89eeb02a06ceca1890624d4fa1932d930b";
            sha256 = "sha256-7aAFd5ZVBjFKY0ek06jo7T2LNbqXd4kZ9+6z4IldKDE=";
          };
          openroad = (pkgs.openroad.override {
            rev = "41a51eaf4ca2171c92ff38afb91eb37bbd3f36da";
            sha256 = "sha256-F5Ak1Iim6JjGCh7zmji6vC4Hqv1ZFJ3Om6qXsktwkYA=";
          }).overrideAttrs(self: super: {
            patches = [];
          });
          
          # Versions for CI2504
          magic = pkgs.magic.override {
            rev = "8.3.519";
            sha256 = "sha256-dggVBuxvQlWx5BxU1k04Xz1GUGBgd3SefRnz6Qpu1mM=";
          };
          netgen = pkgs.netgen.override {
            rev = "1.5.292";
            sha256 = "sha256-IGlgrKVHWxWjqrNeYlyUvf+9bjxraPItd0ktPG8ZejY=";
          };
          klayout = pkgs.klayout.override {
            version = "0.29.11";
            sha256 = "sha256-lWVvuRPqQzlvRprXgz1X9ReSEQt0osLbZNBeV4IcXWY=";
          };
          
          # OpenLane
          openlane1 = callPythonPackage ./default.nix {};
          default = self.openlane1;
        }
        // (lib.optionalAttrs (pkgs.stdenv.isLinux) {
          openlane1-docker = callPackage ./docker/docker.nix {
            createDockerImage = nix-eda.createDockerImage;
          };
        })
      );
    };

    # Helper functions
    createOpenLaneShell = import ./nix/create-shell.nix;

    # Packages
    legacyPackages = nix-eda.forAllSystems (
      system:
        import nix-eda.inputs.nixpkgs {
          inherit system;
          overlays = [nix-eda.overlays.default openlane.overlays.default self.overlays.default];
        }
    );

    packages = nix-eda.forAllSystems (
      system: let
        pkgs = self.legacyPackages."${system}";
      in
        {
          inherit (pkgs) openlane1;
          default = pkgs.openlane1;
        }
        // lib.optionalAttrs pkgs.stdenv.isLinux {
          inherit (pkgs) openlane1-docker;
        }
    );
  };
}
