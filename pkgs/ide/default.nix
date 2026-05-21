{
  lib,
  stdenv,
  fetchurl,
  buildFHSEnv,
  autoPatchelfHook,
  makeDesktopItem,
  copyDesktopItems,
  makeWrapper,
  writeShellScript,
  asar,
  bash,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  chromium,
  cups,
  dbus,
  expat,
  glib,
  gsettings-desktop-schemas,
  gtk3,
  mesa,
  libdrm,
  libgbm,
  libglvnd,
  libnotify,
  libsecret,
  libuuid,
  libxkbcommon,
  nspr,
  nss,
  pango,
  systemdLibs,
  vulkan-loader,
  libx11,
  libxscrnsaver,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxtst,
  libxcb,
  libxshmfence,
  libxkbfile,
  zlib,
  useFHS ? true,
  useSystemChromeProfile ? true,
  google-chrome ? null,
  extraBwrapArgs ? [],
  srcOverride ? null,
}: let
  pname = "google-antigravity-ide";
  version = "2.0.1-4861014005645312";

  isAarch64 = stdenv.hostPlatform.system == "aarch64-linux";

  browserPkg =
    if isAarch64
    then chromium
    else if google-chrome != null
    then google-chrome
    else
      throw ''
        google-chrome is required on ${stdenv.hostPlatform.system} builds.
        Make sure you have allowUnfree = true or pass a google-chrome package.
      '';

  browserCommand =
    if isAarch64
    then "chromium"
    else "google-chrome-stable";

  browserProfileDir =
    if isAarch64
    then "$HOME/.config/chromium"
    else "$HOME/.config/google-chrome";

  finalSrc =
    if srcOverride != null
    then srcOverride
    else
      fetchurl {
        name = "Antigravity_IDE.tar.gz";
        url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/${version}/linux-x64/Antigravity%20IDE.tar.gz";
        sha256 = "sha256-dHFjqjqK+6SzFvl8QLSnXKRzall2ikFs0eiB5z7DHvk=";
      };

  # Create a browser wrapper
  # When useSystemChromeProfile is true (default), forces use of the user's
  # existing Chrome profile so extensions are available to Antigravity.
  # When false, omits profile flags so Chrome runs with its own default
  # behavior, isolating Antigravity from the user's main profile.
  chrome-wrapper = writeShellScript "${browserCommand}-with-profile" ''
    set -euo pipefail

    system_browser="/run/current-system/sw/bin/${browserCommand}"
    browser_cmd="$system_browser"

    if [ ! -x "$system_browser" ]; then
      browser_cmd=${browserPkg}/bin/${browserCommand}
    fi

    exec "$browser_cmd" \
      ${lib.optionalString useSystemChromeProfile ''--user-data-dir="${browserProfileDir}" --profile-directory=Default''} \
      "$@"
  '';

  # Libraries loaded via dlopen() at runtime
  dlopenLibs = [
    libglvnd
    mesa
    vulkan-loader
    systemdLibs
    libnotify
    libsecret
  ];

  # Libraries linked normally (resolved by autoPatchelf via rpath)
  linkedLibs = [
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
    libuuid
    libxkbcommon
    nspr
    nss
    pango
    stdenv.cc.cc.lib
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

  runtimeLibs = linkedLibs ++ dlopenLibs;

  desktopItem = makeDesktopItem {
    name = "antigravity-ide";
    desktopName = "Google Antigravity IDE";
    comment = "Next-generation agentic IDE";
    exec = "antigravity-ide --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform-hint=auto --enable-wayland-ime=true --wayland-text-input-version=3 %U";
    icon = "antigravity-ide";
    categories = ["Development" "IDE"];
    startupNotify = true;
    startupWMClass = "Antigravity IDE";
    mimeTypes = [
      "x-scheme-handler/antigravity"
    ];
  };

  meta = with lib; {
    description = "Google Antigravity - Next-generation agentic IDE";
    homepage = "https://antigravity.google";
    license = licenses.unfree;
    platforms = platforms.linux;
    maintainers = [];
    mainProgram = "antigravity-ide";
  };

  # ── FHS variant (default) ──────────────────────────────────

  # Extract the upstream tarball without modification
  antigravity-unwrapped = stdenv.mkDerivation {
    inherit pname version;
    src = finalSrc;

    dontBuild = true;
    dontConfigure = true;
    dontPatchELF = true;
    dontStrip = true;

    nativeBuildInputs = [asar];

    postPatch = ''
      packed="resources/app/node_modules.asar"
      unpacked="resources/app/node_modules"
      if [ -f "$packed" ]; then
        asar extract "$packed" "$unpacked"
        if [ -f "$unpacked/@vscode/sudo-prompt/index.js" ]; then
          substituteInPlace $unpacked/@vscode/sudo-prompt/index.js \
            --replace-fail "/usr/bin/pkexec" "/run/wrappers/bin/pkexec" \
            --replace-fail "/bin/bash" "${bash}/bin/bash"
        fi
        rm -rf "$packed"
        ln -rs "$unpacked" "$packed"
      elif [ -d "$unpacked" ]; then
        if [ -f "$unpacked/@vscode/sudo-prompt/index.js" ]; then
          substituteInPlace $unpacked/@vscode/sudo-prompt/index.js \
            --replace-fail "/usr/bin/pkexec" "/run/wrappers/bin/pkexec" \
            --replace-fail "/bin/bash" "${bash}/bin/bash"
        fi
      fi
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/antigravity-ide
      cp -r ./* $out/lib/antigravity-ide/

      # Provide a dummy tunnel script to avoid ENOENT errors when running 'antigravity-ide tunnel'
      mkdir -p $out/lib/antigravity-ide/bin
      cat <<'EOF' > $out/lib/antigravity-ide/bin/antigravity-tunnel
      #!/usr/bin/env bash
      echo "Remote tunneling is not supported in the Linux package of Google Antigravity IDE because the required proprietary binary is not bundled." >&2
      exit 1
      EOF
      chmod +x $out/lib/antigravity-ide/bin/antigravity-tunnel

      runHook postInstall
    '';

    inherit meta;
  };

  # FHS environment for running Antigravity
  fhs = buildFHSEnv {
    name = "antigravity-fhs";
    targetPkgs = pkgs:
      runtimeLibs
      ++ [
        pkgs.udev
        pkgs.libudev0-shim
      ]
      ++ lib.optional (browserPkg != null) browserPkg;

    extraBwrapArgs = [
      "--bind-try /etc/nixos/ /etc/nixos/"
      "--ro-bind-try /etc/xdg/ /etc/xdg/"
      "--ro-bind-try /etc/nixpkgs/ /etc/nixpkgs/"
    ] ++ extraBwrapArgs;

    runScript = writeShellScript "antigravity-wrapper" ''
      export XDG_DATA_DIRS=${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}:${gtk3}/share/gsettings-schemas/${gtk3.name}:''${XDG_DATA_DIRS:-/usr/share}

      # Set Chrome paths to use our wrapper that forces user profile
      # This ensures extensions installed in user's Chrome profile are available
      export CHROME_BIN=${chrome-wrapper}
      export CHROME_PATH=${chrome-wrapper}

      if [[ "$NIXOS_OZONE_WL" == "1" ]]; then
        exec ${antigravity-unwrapped}/lib/antigravity-ide/bin/antigravity-ide --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform-hint=auto --enable-wayland-ime=true --wayland-text-input-version=3 "$@"
      else
        exec ${antigravity-unwrapped}/lib/antigravity-ide/bin/antigravity-ide "$@"
      fi
    '';

    inherit meta;
  };

  fhs-package = stdenv.mkDerivation {
    inherit pname version meta;

    dontUnpack = true;
    dontBuild = true;

    nativeBuildInputs = [copyDesktopItems];

    desktopItems = [desktopItem];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      ln -s ${fhs}/bin/antigravity-fhs $out/bin/antigravity-ide

      # Install icon from the app resources
      mkdir -p $out/share/pixmaps $out/share/icons/hicolor/1024x1024/apps
      if [ -f "${antigravity-unwrapped}/lib/antigravity-ide/resources/app/resources/linux/code.png" ]; then
        cp "${antigravity-unwrapped}/lib/antigravity-ide/resources/app/resources/linux/code.png" $out/share/pixmaps/antigravity-ide.png
        cp "${antigravity-unwrapped}/lib/antigravity-ide/resources/app/resources/linux/code.png" $out/share/icons/hicolor/1024x1024/apps/antigravity-ide.png
      fi

      runHook postInstall
    '';
  };

  # ── Non-FHS variant ────────────────────────────────────────
  # Uses autoPatchelfHook instead of buildFHSEnv.
  # This avoids the bubblewrap sandbox that sets the kernel
  # "no new privileges" flag, which prevents sudo from working
  # in the integrated terminal.

  no-fhs-package = stdenv.mkDerivation {
    inherit pname version meta;
    src = finalSrc;

    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
      copyDesktopItems
      asar
    ];

    buildInputs = runtimeLibs;

    runtimeDependencies = dlopenLibs;

    # Optional deps from the bundled Microsoft Authentication extension
    autoPatchelfIgnoreMissingDeps = [
      "libwebkit2gtk-4.1.so.0"
      "libsoup-3.0.so.0"
      "libcurl.so.4"
      "libcrypto.so.3"
    ];

    dontBuild = true;
    dontConfigure = true;

    postPatch = ''
      packed="resources/app/node_modules.asar"
      unpacked="resources/app/node_modules"
      if [ -f "$packed" ]; then
        asar extract "$packed" "$unpacked"
        if [ -f "$unpacked/@vscode/sudo-prompt/index.js" ]; then
          substituteInPlace $unpacked/@vscode/sudo-prompt/index.js \
            --replace-fail "/usr/bin/pkexec" "/run/wrappers/bin/pkexec" \
            --replace-fail "/bin/bash" "${bash}/bin/bash"
        fi
        rm -rf "$packed"
        ln -rs "$unpacked" "$packed"
      elif [ -d "$unpacked" ]; then
        if [ -f "$unpacked/@vscode/sudo-prompt/index.js" ]; then
          substituteInPlace $unpacked/@vscode/sudo-prompt/index.js \
            --replace-fail "/usr/bin/pkexec" "/run/wrappers/bin/pkexec" \
            --replace-fail "/bin/bash" "${bash}/bin/bash"
        fi
      fi
    '';

    desktopItems = [desktopItem];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/antigravity-ide
      cp -r ./* $out/lib/antigravity-ide/

      # Provide a dummy tunnel script to avoid ENOENT errors when running 'antigravity-ide tunnel'
      mkdir -p $out/lib/antigravity-ide/bin
      cat <<'EOF' > $out/lib/antigravity-ide/bin/antigravity-tunnel
      #!/usr/bin/env bash
      echo "Remote tunneling is not supported in the Linux package of Google Antigravity IDE because the required proprietary binary is not bundled." >&2
      exit 1
      EOF
      chmod +x $out/lib/antigravity-ide/bin/antigravity-tunnel

      mkdir -p $out/bin
      makeWrapper $out/lib/antigravity-ide/bin/antigravity-ide $out/bin/antigravity-ide \
        --set CHROME_BIN ${chrome-wrapper} \
        --set CHROME_PATH ${chrome-wrapper} \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath dlopenLibs}" \
        --prefix XDG_DATA_DIRS : "${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}:${gtk3}/share/gsettings-schemas/${gtk3.name}" \
        --add-flags "\''${NIXOS_OZONE_WL:+--enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform-hint=auto --enable-wayland-ime=true --wayland-text-input-version=3}"

      # Install icon from the app resources
      mkdir -p $out/share/pixmaps $out/share/icons/hicolor/1024x1024/apps
      if [ -f "$out/lib/antigravity-ide/resources/app/resources/linux/code.png" ]; then
        cp "$out/lib/antigravity-ide/resources/app/resources/linux/code.png" $out/share/pixmaps/antigravity-ide.png
        cp "$out/lib/antigravity-ide/resources/app/resources/linux/code.png" $out/share/icons/hicolor/1024x1024/apps/antigravity-ide.png
      fi

      runHook postInstall
    '';
  };
in
  if useFHS
  then fhs-package
  else no-fhs-package
