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
  undmg,
  appType,
  useFHS ? true,
  useSystemChromeProfile ? true,
  google-chrome ? null,
  extraBwrapArgs ? [ ],
  srcOverride ? null,
}:
let
  isIde = appType == "Antigravity IDE";

  links = builtins.fromJSON (
    builtins.readFile ../artifacts/antigravity-2-and-ide--1--scraped-links.json
  );
  hashes = builtins.fromJSON (
    builtins.readFile ../artifacts/antigravity-2-and-ide--2--prefetched-sha256.json
  );

  system = stdenv.hostPlatform.system;

  platformInfo =
    if system == "aarch64-darwin" then
      {
        url = links.${appType}.macos."apple silicon";
        hash = hashes.${appType}.macos."apple silicon";
      }
    else if system == "x86_64-darwin" then
      {
        url = links.${appType}.macos.intel;
        hash = hashes.${appType}.macos.intel;
      }
    else if system == "aarch64-linux" then
      {
        url = links.${appType}.linux.arm64;
        hash = hashes.${appType}.linux.arm64;
      }
    else if system == "x86_64-linux" then
      {
        url = links.${appType}.linux.x64;
        hash = hashes.${appType}.linux.x64;
      }
    else
      throw "Unsupported system for Antigravity ${appType}: ${system}";

  finalUrl = platformInfo.url;
  finalHash = platformInfo.hash;

  version =
    let
      match = builtins.match ".*\/([0-9]+\\.[0-9]+\\.[0-9]+-[0-9]+)\/.*" finalUrl;
    in
    if match != null then builtins.elemAt match 0 else "unknown";

  pname = if isIde then "google-antigravity-ide" else "google-antigravity2";
  desktopName = if isIde then "Google Antigravity IDE" else "Google Antigravity";
  binaryRelPath = if isIde then "bin/antigravity-ide" else "antigravity";
  desktopIcon = if isIde then "antigravity-ide" else "antigravity";
  startupWMClass = if isIde then "Antigravity IDE" else "Antigravity";

  isAarch64 = system == "aarch64-linux";

  browserPkg =
    if isAarch64 then
      chromium
    else if google-chrome != null then
      google-chrome
    else
      throw ''
        google-chrome is required on ${stdenv.hostPlatform.system} builds.
        Make sure you have allowUnfree = true or pass a google-chrome package.
      '';

  browserCommand = if isAarch64 then "chromium" else "google-chrome-stable";

  browserProfileDir = if isAarch64 then "$HOME/.config/chromium" else "$HOME/.config/google-chrome";

  finalSrc =
    if srcOverride != null then
      srcOverride
    else
      fetchurl {
        url = finalUrl;
        sha256 = finalHash;
      };

  # Create a browser wrapper
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
    name = desktopIcon;
    desktopName = desktopName;
    comment = "Next-generation agentic IDE";
    exec = "${desktopIcon} --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform-hint=auto --enable-wayland-ime=true --wayland-text-input-version=3 %U";
    icon = desktopIcon;
    categories = [
      "Development"
      "IDE"
    ];
    startupNotify = true;
    startupWMClass = startupWMClass;
    mimeTypes = [
      "x-scheme-handler/antigravity"
    ];
  };

  meta = with lib; {
    description = desktopName;
    homepage = "https://antigravity.google";
    license = licenses.unfree;
    platforms = platforms.linux ++ platforms.darwin;
    maintainers = [ ];
    mainProgram = desktopIcon;
  };

  # ── FHS variant (default for Linux) ────────────────────────

  # Extract the upstream tarball without modification
  antigravity-unwrapped = stdenv.mkDerivation {
    inherit pname version;
    src = finalSrc;

    dontBuild = true;
    dontConfigure = true;
    dontPatchELF = true;
    dontStrip = true;

    nativeBuildInputs = [ asar ];

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

    unpackPhase = ''
      tar -xzf $src
      for d in *; do
        if [ -d "$d" ]; then
          cd "$d"
          break
        fi
      done
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/${pname}
      cp -r ./* $out/lib/${pname}/

      # Provide a dummy tunnel script to avoid ENOENT errors when running 'antigravity tunnel'
      mkdir -p $out/lib/${pname}/resources/bin
      cat <<'EOF' > $out/lib/${pname}/resources/bin/antigravity-tunnel
      #!/usr/bin/env bash
      echo "Remote tunneling is not supported in the Linux package of Google Antigravity because the required proprietary binary is not bundled." >&2
      exit 1
      EOF
      chmod +x $out/lib/${pname}/resources/bin/antigravity-tunnel

      runHook postInstall
    '';

    inherit meta;
  };

  # FHS environment for running Antigravity
  fhs = buildFHSEnv {
    name = "${pname}-fhs";
    targetPkgs =
      pkgs:
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
    ]
    ++ extraBwrapArgs;

    runScript = writeShellScript "${pname}-wrapper" ''
      # Set Chrome paths to use our wrapper that forces user profile
      # This ensures extensions installed in user's Chrome profile are available
      export CHROME_BIN=${chrome-wrapper}
      export CHROME_PATH=${chrome-wrapper}

      exec ${antigravity-unwrapped}/lib/${pname}/${binaryRelPath} ${lib.optionalString isIde "--user-data-dir=$HOME/.antigravity-ide"} "$@"
    '';

    inherit meta;
  };

  fhs-package = stdenv.mkDerivation {
    inherit pname version meta;

    dontUnpack = true;
    dontBuild = true;

    nativeBuildInputs = [
      copyDesktopItems
      asar
    ];

    desktopItems = [ desktopItem ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      ln -s ${fhs}/bin/${pname}-fhs $out/bin/${desktopIcon}

      # Install icon from the app resources
      mkdir -p $out/share/pixmaps $out/share/icons/hicolor/1024x1024/apps
      if [ -f "${antigravity-unwrapped}/lib/${pname}/resources/app.asar" ]; then
        asar extract ${antigravity-unwrapped}/lib/${pname}/resources/app.asar temp_extracted
        cp temp_extracted/icon.png $out/share/pixmaps/${desktopIcon}.png
        cp temp_extracted/icon.png $out/share/icons/hicolor/1024x1024/apps/${desktopIcon}.png
        rm -rf temp_extracted
      elif [ -f "${antigravity-unwrapped}/lib/${pname}/resources/app/resources/linux/code.png" ]; then
        cp ${antigravity-unwrapped}/lib/${pname}/resources/app/resources/linux/code.png $out/share/pixmaps/${desktopIcon}.png
        cp ${antigravity-unwrapped}/lib/${pname}/resources/app/resources/linux/code.png $out/share/icons/hicolor/1024x1024/apps/${desktopIcon}.png
      fi

      runHook postInstall
    '';
  };

  # ── Non-FHS variant (Linux) ────────────────────────────────
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

    unpackPhase = ''
      tar -xzf $src
      for d in *; do
        if [ -d "$d" ]; then
          cd "$d"
          break
        fi
      done
    '';

    desktopItems = [ desktopItem ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/${pname}
      cp -r ./* $out/lib/${pname}/

      # Provide a dummy tunnel script to avoid ENOENT errors when running 'antigravity tunnel'
      mkdir -p $out/lib/${pname}/resources/bin
      cat <<'EOF' > $out/lib/${pname}/resources/bin/antigravity-tunnel
      #!/usr/bin/env bash
      echo "Remote tunneling is not supported in the Linux package of Google Antigravity because the required proprietary binary is not bundled." >&2
      exit 1
      EOF
      chmod +x $out/lib/${pname}/resources/bin/antigravity-tunnel

      mkdir -p $out/bin
      makeWrapper $out/lib/${pname}/${binaryRelPath} $out/bin/${desktopIcon} \
        --set CHROME_BIN ${chrome-wrapper} \
        --set CHROME_PATH ${chrome-wrapper} \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath dlopenLibs}" \
        --prefix XDG_DATA_DIRS : "${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}:${gtk3}/share/gsettings-schemas/${gtk3.name}" \
        ${lib.optionalString isIde "--add-flags \"--user-data-dir=$HOME/.antigravity-ide\""}

      # Install icon from the app resources
      mkdir -p $out/share/pixmaps $out/share/icons/hicolor/1024x1024/apps
      if [ -f "$out/lib/${pname}/resources/app.asar" ]; then
        asar extract $out/lib/${pname}/resources/app.asar temp_extracted
        cp temp_extracted/icon.png $out/share/pixmaps/${desktopIcon}.png
        cp temp_extracted/icon.png $out/share/icons/hicolor/1024x1024/apps/${desktopIcon}.png
        rm -rf temp_extracted
      elif [ -f "$out/lib/${pname}/resources/app/resources/linux/code.png" ]; then
        cp $out/lib/${pname}/resources/app/resources/linux/code.png $out/share/pixmaps/${desktopIcon}.png
        cp $out/lib/${pname}/resources/app/resources/linux/code.png $out/share/icons/hicolor/1024x1024/apps/${desktopIcon}.png
      fi

      runHook postInstall
    '';
  };

  # ── macOS (Darwin) Package ─────────────────────────────────

  darwin-package = stdenv.mkDerivation {
    inherit pname version meta;
    src = finalSrc;

    nativeBuildInputs = [ undmg ];

    sourceRoot = ".";

    installPhase = ''
      runHook preInstall

      mkdir -p $out/Applications
      cp -r *.app $out/Applications/

      runHook postInstall
    '';
  };
in
if stdenv.hostPlatform.isDarwin then
  darwin-package
else if useFHS then
  fhs-package
else
  no-fhs-package
