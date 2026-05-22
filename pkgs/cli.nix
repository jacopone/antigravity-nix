{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  installShellFiles,
}:
let
  pname = "google-antigravity-cli";
  system = stdenv.hostPlatform.system;

  versions = builtins.fromJSON (builtins.readFile ../artifacts/versions.json);
  manifest =
    versions."Antigravity CLI".${system} or (throw "Unsupported system for Antigravity CLI: ${system}");

  # The CLI artifact currently stores version inside the manifest, but we need to extract it from the URL or add it to JSON.
  # Actually, the update-version.sh script did not store the version string for CLI, it just stored url and hash.
  # Let's extract the version from the URL here like we do in package.nix.
  version =
    let
      match = builtins.match ".*/([0-9]+\\.[0-9]+\\.[0-9]+-[0-9]+)/.*" manifest.url;
    in
    if match != null then builtins.elemAt match 0 else "unknown";
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    inherit (manifest) url;
    sha512 = builtins.substring 7 128 manifest.hash; # Remove 'sha512-' prefix from our JSON
  };

  nativeBuildInputs =
    lib.optionals stdenv.hostPlatform.isLinux [
      autoPatchelfHook
    ]
    ++ [
      installShellFiles
    ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    # Rename to agy to avoid naming conflict and match installer behavior
    cp antigravity $out/bin/agy

    runHook postInstall
  '';

  meta = with lib; {
    description = "Google Antigravity CLI - Describe what you need, and Antigravity handles the rest";
    homepage = "https://antigravity.google";
    license = licenses.unfree;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    mainProgram = "agy";
  };
}
