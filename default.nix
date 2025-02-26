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
  lib,
  libparse,
  stdenv,
  python3,
  makeWrapper,
  ncurses,
  coreutils-full,
  gnugrep,
  gnused,
  gnutar,
  gzip,
  git,
  bash,
  yosys,
  opensta,
  openroad,
  klayout,
  netgen,
  magic-vlsi,
  verilog,
  verilator,
  volare,
  tclFull,
}: let
  pyenv = python3.withPackages (ps:
    with ps; [
      libparse
      click
      pyyaml
      XlsxWriter
      klayout.pymod
      volare
    ]);
  pyenv-sitepackages = "${pyenv}/${pyenv.sitePackages}";
in
  stdenv.mkDerivation (finalAttrs: {
    pname = "openlane1";
    version = "1.2.0";

    src = [
      ./flow.tcl
      ./scripts
      ./configuration
      ./dependencies
    ];

    unpackPhase = ''
      echo $src
      for file in $src; do
        BASENAME=$(python3 -c "import os; print('$file'.split('-', maxsplit=1)[1], end='$EMPTY')")
        cp -r $file $PWD/$BASENAME
      done
      ls -lah
    '';

    passthru = {
      pyenv = pyenv;
    };

    includedTools = [
      yosys
      opensta
      openroad
      klayout
      netgen
      magic-vlsi
      verilog
      verilator
      tclFull
    ];

    propagatedBuildInputs =
      finalAttrs.includedTools
      ++ [
        pyenv
        ncurses
        coreutils-full
        gnugrep
        gnused
        bash
        gnutar
        gzip
        git
      ];

    nativeBuildInputs = [makeWrapper];

    computed_PATH = lib.makeBinPath finalAttrs.propagatedBuildInputs;
    
    installPhase = ''
      mkdir -p $out/bin
      cp -r * $out/bin
      wrapProgram $out/bin/flow.tcl\
        --set PATH ${finalAttrs.computed_PATH}\
        --set PYTHONPATH ${pyenv-sitepackages}
    '';

    doCheck = true;

    meta = {
      description = "RTL-to-GDSII flow for application-specific integrated circuits (ASIC)s";
      homepage = "https://efabless.com/openlane";
      mainProgram = "flow.tcl";
      license = lib.licenses.asl20;
      platforms = lib.platforms.linux ++ lib.platforms.darwin;
    };
  })
