{
  stdenv,
  lib,
  fetchurl,
  makeWrapper,
  atk,
  at-spi2-atk,
  at-spi2-core,
  alsa-lib,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  gdk-pixbuf,
  glib,
  gtk3,
  libayatana-appindicator,
  libdrm,
  libgbm,
  libglvnd,
  libpulseaudio,
  librsvg,
  libsoup_3,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  mesa,
  nss,
  nspr,
  openssl,
  pango,
  udev,
  wayland,
  webkitgtk_4_1,
}:

# Magpie (vendored upstream build, no fork).
# Generated + verified by CI (vendor-all.yml on branch main):
#   version/url/hash are filled in by CI on every upstream release and
#   uploaded as release asset `magpie.nix`. This file in dotfiles is a copy
#   fetched by pkgs/update-fork-tarballs.sh — do not edit hash by hand.
#
#   CAUTION: CI replaces the FIRST TWO sha256 hash assignments in file
#   order (srcGui, srcCli). srcIcon below must stay third — do not move it
#   above srcGui/srcCli, and keep this comment free of any quoted
#   sha256 literal so the regex keeps hitting the real fields.
#
# Upstream publishes two Linux x86_64 binaries per release:
#   magpie-linux-amd64     (desktop GUI, Tauri/WebKitGTK — wrapped below)
#   magpie-cli-linux-amd64 (static terminal build — installed as-is)
stdenv.mkDerivation rec {
  pname = "magpie";
  version = "0.1.3771";

  srcGui = fetchurl {
    url = "https://github.com/yetone/magpie/releases/download/v0.1.3771/magpie-linux-amd64";
    hash = "sha256-thvbNJssM/1n4uC9Y4qQKckuz9GCBvRTllZm0YHP4yE=";
  };

  srcCli = fetchurl {
    url = "https://github.com/yetone/magpie/releases/download/v0.1.3771/magpie-cli-linux-amd64";
    hash = "sha256-AO//NqzxGa++H9PBDQcS2BW3YCi/jz3tllVlwgW1st0=";
  };

  # Static icon (upstream site asset, byte-identical to the one the app
  # self-installs to ~/.local/share/icons on first run — verified 2026-11-07).
  # Not versioned with releases; re-pin hash only if upstream changes the art.
  srcIcon = fetchurl {
    url = "https://raw.githubusercontent.com/yetone/magpie/main/site/public/img/icon-256.png";
    hash = "sha256-V0N8ZZbgWo/PxC1CiMAwqgDthraf411GTWnXAmFQxwQ=";
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  buildInputs = [
    atk
    at-spi2-atk
    at-spi2-core
    alsa-lib
    cairo
    cups
    dbus
    expat
    fontconfig
    gdk-pixbuf
    glib
    gtk3
    libayatana-appindicator
    libdrm
    libgbm
    libglvnd
    libpulseaudio
    librsvg
    libsoup_3
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    mesa
    nss
    nspr
    openssl
    pango
    udev
    wayland
    webkitgtk_4_1
  ];

  dontUnpack = true;

  # NOTE: do NOT patchelf this binary. It crashes (SIGSEGV before any
  # library load) once its headers are rewritten — likely an integrity
  # check. Its INTERP (/lib64/ld-linux-x86-64.so.2) already resolves on
  # NixOS; the wrapper's LD_LIBRARY_PATH provides everything else.
  dontAutoPatchelf = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp "$srcGui" $out/bin/.magpie-unwrapped
    cp "$srcCli" $out/bin/magpie-cli
    chmod +x $out/bin/.magpie-unwrapped $out/bin/magpie-cli

    makeWrapper $out/bin/.magpie-unwrapped $out/bin/magpie \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}" \
      --run 'if [ -n "$HOME" ]; then _magpie_dt="$HOME/.local/share/applications/magpie.desktop"; _magpie_sys="/run/current-system/sw/share/applications/magpie.desktop"; if [ ! -L "$_magpie_dt" ] || [ "$(readlink "$_magpie_dt")" != "$_magpie_sys" ]; then if [ ! -f "$_magpie_dt" ] || [ -L "$_magpie_dt" ] || grep -q "magpie-unwrapped" "$_magpie_dt" 2>/dev/null; then mkdir -p "$HOME/.local/share/applications"; rm -f "$_magpie_dt" 2>/dev/null || true; ln -s "$_magpie_sys" "$_magpie_dt" 2>/dev/null || true; fi; fi; unset _magpie_dt _magpie_sys; fi'

    # NOTE: the upstream binary unconditionally rewrites
    # ~/.local/share/applications/magpie.desktop on every GUI launch with
    # Exec=<store>/bin/.magpie-unwrapped (bypasses the LD_LIBRARY_PATH
    # wrapper above → missing libwayland-client etc., exit 127, silent
    # under Terminal=false) and a hardcoded store path that rots on every
    # upgrade. That user file shadows this system entry per XDG precedence.
    # The --run hook above pins the user path as a symlink to this (read-only
    # store) system entry: the app's rewrite then fails with EROFS, which it
    # logs ("magpie:// links: ... read-only file system") and ignores, while
    # clicks/magpie:// links resolve to the correct Exec/Icon/MimeType here.
    # /run/current-system always tracks the active generation, so the link
    # survives upgrades. If the package is ever removed, delete the symlink.
    mkdir -p $out/share/applications
    cat > $out/share/applications/magpie.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Magpie
    Comment=Every agent's model. One place.
    Exec=$out/bin/magpie %U
    Icon=magpie
    Terminal=false
    Categories=Utility;Development;
    StartupWMClass=magpie
    MimeType=x-scheme-handler/magpie;
    EOF

    # Upstream ships a single 256px icon; install it under the standard
    # hicolor sizes (copy, no imagemagick needed for a 6KB pixmap).
    for size in 16 32 48 64 128 256 512; do
      mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
      cp "$srcIcon" "$out/share/icons/hicolor/''${size}x''${size}/apps/magpie.png"
    done

    runHook postInstall
  '';

  meta = {
    description = "Every agent's model. One place (vendored upstream build)";
    homepage = "https://usemagpie.ai";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "magpie";
  };
}
