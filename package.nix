{ lib
, stdenv
, fetchurl
, buildFHSEnv
, autoPatchelfHook
, makeDesktopItem
, copyDesktopItems
, makeWrapper
, writeShellScript
, alsa-lib
, at-spi2-atk
, at-spi2-core
, atk
, cairo
, chromium
, cups
, dbus
, expat
, glib
, gtk3
, libdrm
, libgbm
, libglvnd
, libnotify
, libsecret
, libuuid
, libxkbcommon
, mesa
, nspr
, nss
, pango
, systemd
, vulkan-loader
, libx11
, libxscrnsaver
, libxcomposite
, libxcursor
, libxdamage
, libxext
, libxfixes
, libxi
, libxrandr
, libxrender
, libxtst
, libxcb
, libxshmfence
, libxkbfile
, zlib
, useFHS ? true
, google-chrome ? null
}:

let
  pname = "google-antigravity";
  version = "1.16.5-6703236727046144";

  isAarch64 = stdenv.hostPlatform.system == "aarch64-linux";

  browserPkg =
    if isAarch64 then chromium
    else if google-chrome != null then google-chrome
    else throw ''
      google-chrome is required on ${stdenv.hostPlatform.system} builds.
      Make sure you have allowUnfree = true or pass a google-chrome package.
    '';

  browserCommand =
    if isAarch64 then "chromium" else "google-chrome-stable";

  browserProfileDir =
    if isAarch64 then "$HOME/.config/chromium" else "$HOME/.config/google-chrome";

  src = fetchurl {
    url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/${version}/linux-x64/Antigravity.tar.gz";
    sha256 = "sha256-GVPGJFLTKnLllff6gyx6ftkHLSLJz5nfOiLCSal/Xpc=";
  };

  # Create a browser wrapper that uses the user's existing profile
  chrome-wrapper = writeShellScript "${browserCommand}-with-profile" ''
    set -euo pipefail

    system_browser="/run/current-system/sw/bin/${browserCommand}"
    browser_cmd="$system_browser"

    if [ ! -x "$system_browser" ]; then
      browser_cmd=${browserPkg}/bin/${browserCommand}
    fi

    exec "$browser_cmd" \
      --user-data-dir="${browserProfileDir}" \
      --profile-directory=Default \
      "$@"
  '';

  # Shared runtime library dependencies
  runtimeLibs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libdrm
    libgbm
    libglvnd
    libnotify
    libsecret
    libuuid
    libxkbcommon
    mesa
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    systemd
    vulkan-loader
    libx11
    libxscrnsaver
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxtst
    libxcb
    libxshmfence
    libxkbfile
    zlib
  ];

  desktopItem = makeDesktopItem {
    name = "antigravity";
    desktopName = "Google Antigravity";
    comment = "Next-generation agentic IDE";
    exec = "antigravity --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform-hint=auto %U";
    icon = "antigravity";
    categories = [ "Development" "IDE" ];
    startupNotify = true;
    startupWMClass = "Antigravity";
    mimeTypes = [
      "x-scheme-handler/antigravity"
      "text/plain"
    ];
  };

  meta = with lib; {
    description = "Google Antigravity - Next-generation agentic IDE";
    homepage = "https://antigravity.google";
    license = licenses.unfree;
    platforms = platforms.linux;
    maintainers = [ ];
  };

  # ── FHS variant (default) ──────────────────────────────────

  # Extract the upstream tarball without modification
  antigravity-unwrapped = stdenv.mkDerivation {
    inherit pname version src;

    dontBuild = true;
    dontConfigure = true;
    dontPatchELF = true;
    dontStrip = true;

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/antigravity
      cp -r ./* $out/lib/antigravity/

      runHook postInstall
    '';

    inherit meta;
  };

  # FHS environment for running Antigravity
  fhs = buildFHSEnv {
    name = "antigravity-fhs";

    targetPkgs = _: runtimeLibs ++ lib.optional (browserPkg != null) browserPkg;

    runScript = writeShellScript "antigravity-wrapper" ''
      # Set Chrome paths to use our wrapper that forces user profile
      # This ensures extensions installed in user's Chrome profile are available
      export CHROME_BIN=${chrome-wrapper}
      export CHROME_PATH=${chrome-wrapper}

      exec ${antigravity-unwrapped}/lib/antigravity/bin/antigravity "$@"
    '';

    inherit meta;
  };

  fhs-package = stdenv.mkDerivation {
    inherit pname version meta;

    dontUnpack = true;
    dontBuild = true;

    nativeBuildInputs = [ copyDesktopItems ];

    desktopItems = [ desktopItem ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      ln -s ${fhs}/bin/antigravity-fhs $out/bin/antigravity

      # Install icon from the app resources
      mkdir -p $out/share/pixmaps $out/share/icons/hicolor/1024x1024/apps
      cp ${antigravity-unwrapped}/lib/antigravity/resources/app/resources/linux/code.png $out/share/pixmaps/antigravity.png
      cp ${antigravity-unwrapped}/lib/antigravity/resources/app/resources/linux/code.png $out/share/icons/hicolor/1024x1024/apps/antigravity.png

      runHook postInstall
    '';
  };

  # ── Non-FHS variant ────────────────────────────────────────
  # Uses autoPatchelfHook instead of buildFHSEnv.
  # This avoids the bubblewrap sandbox that sets the kernel
  # "no new privileges" flag, which prevents sudo from working
  # in the integrated terminal.

  no-fhs-package = stdenv.mkDerivation {
    inherit pname version src meta;

    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
      copyDesktopItems
    ];

    buildInputs = runtimeLibs;

    # Libraries loaded via dlopen at runtime (e.g. GPU drivers)
    runtimeDependencies = runtimeLibs;

    # The Microsoft Authentication extension bundles libmsalruntime.so which
    # links against webkit2gtk and libsoup. These are large optional deps
    # that the FHS variant doesn't include either — ignore them.
    autoPatchelfIgnoreMissingDeps = [
      "libwebkit2gtk-4.1.so.0"
      "libsoup-3.0.so.0"
    ];

    dontBuild = true;
    dontConfigure = true;

    desktopItems = [ desktopItem ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/antigravity
      cp -r ./* $out/lib/antigravity/

      mkdir -p $out/bin
      makeWrapper $out/lib/antigravity/bin/antigravity $out/bin/antigravity \
        --set CHROME_BIN ${chrome-wrapper} \
        --set CHROME_PATH ${chrome-wrapper} \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}"

      # Install icon from the app resources
      mkdir -p $out/share/pixmaps $out/share/icons/hicolor/1024x1024/apps
      cp $out/lib/antigravity/resources/app/resources/linux/code.png $out/share/pixmaps/antigravity.png
      cp $out/lib/antigravity/resources/app/resources/linux/code.png $out/share/icons/hicolor/1024x1024/apps/antigravity.png

      runHook postInstall
    '';
  };

in
  if useFHS then fhs-package else no-fhs-package
