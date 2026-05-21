{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  zlib,
}: let
  pname = "google-antigravity-cli";
  version = "1.0.0-5288553236791296";

  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/${version}/linux-x64/cli_linux_x64.tar.gz";
    sha256 = "sha256-cAljQFdPr8SgbE08gFcxTiLUdc4cgg0K1R/wf7fpnrY=";
  };
in
  stdenv.mkDerivation {
    inherit pname version src;

    nativeBuildInputs = [autoPatchelfHook];
    buildInputs = [
      zlib
      stdenv.cc.cc.lib
    ];

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      cp antigravity $out/bin/antigravity-cli
      chmod +x $out/bin/antigravity-cli

      runHook postInstall
    '';

    meta = with lib; {
      description = "Google Antigravity CLI";
      homepage = "https://antigravity.google";
      license = licenses.unfree;
      platforms = platforms.linux;
      mainProgram = "antigravity-cli";
    };
  }
