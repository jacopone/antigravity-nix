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

  manifestFile =
    if system == "x86_64-linux" then
      ../artifacts/antigravity-cli--manifests/linux_amd64.json
    else if system == "aarch64-linux" then
      ../artifacts/antigravity-cli--manifests/linux_arm64.json
    else if system == "x86_64-darwin" then
      ../artifacts/antigravity-cli--manifests/darwin_amd64.json
    else if system == "aarch64-darwin" then
      ../artifacts/antigravity-cli--manifests/darwin_arm64.json
    else
      throw "Unsupported system for Antigravity CLI: ${system}";

  manifest = builtins.fromJSON (builtins.readFile manifestFile);

  version = manifest.version;
in
stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = manifest.url;
    sha512 = manifest.sha512;
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
