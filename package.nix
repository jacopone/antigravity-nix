{ lib
, stdenv
, fetchurl
, buildFHSEnv
, makeDesktopItem
, copyDesktopItems
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
, libnotify
, libsecret
, libuuid
, libxkbcommon
, mesa
, nspr
, nss
, pango
, systemd
, xorg
, zlib
, google-chrome ? null
}:

let
  pname = "google-antigravity";
  version = "1.11.5-5234145629700096";

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
    sha256 = "sha256-TgMVGlV0PPMPrFlauzQ8nrWjtqgNJUATbXW06tgHIRI=";
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

  # Extract and prepare the antigravity binary
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

    meta = with lib; {
      description = "Google Antigravity - Next-generation agentic IDE";
      homepage = "https://antigravity.google";
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = [ ];
    };
  };

  # FHS environment for running Antigravity
  fhs = buildFHSEnv {
    name = "antigravity-fhs";

    targetPkgs = pkgs:
      (with pkgs; [
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
        xorg.libX11
        xorg.libXScrnSaver
        xorg.libXcomposite
        xorg.libXcursor
        xorg.libXdamage
        xorg.libXext
        xorg.libXfixes
        xorg.libXi
        xorg.libXrandr
        xorg.libXrender
        xorg.libXtst
        xorg.libxcb
        xorg.libxshmfence
        zlib
      ]) ++ lib.optional (browserPkg != null) browserPkg;

    runScript = writeShellScript "antigravity-wrapper" ''
      # Set Chrome paths to use our wrapper that forces user profile
      # This ensures extensions installed in user's Chrome profile are available
      export CHROME_BIN=${chrome-wrapper}
      export CHROME_PATH=${chrome-wrapper}

      exec ${antigravity-unwrapped}/lib/antigravity/antigravity "$@"
    '';

    meta = antigravity-unwrapped.meta;
  };

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

  # Icon file
  iconFile = ./icons/antigravity.png;

in
stdenv.mkDerivation {
  inherit pname version;

  dontUnpack = true;
  dontBuild = true;

  nativeBuildInputs = [ copyDesktopItems ];

  desktopItems = [ desktopItem ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    ln -s ${fhs}/bin/antigravity-fhs $out/bin/antigravity

    # Install icon from local icons directory
    mkdir -p $out/share/pixmaps $out/share/icons/hicolor/512x512/apps
    cp ${iconFile} $out/share/pixmaps/antigravity.png
    cp ${iconFile} $out/share/icons/hicolor/512x512/apps/antigravity.png

    runHook postInstall
  '';

  meta = antigravity-unwrapped.meta;
}
