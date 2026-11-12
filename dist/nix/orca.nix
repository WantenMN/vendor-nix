{
  stdenv,
  lib,
  fetchurl,
  appimageTools,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  atk,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  dbus-glib,
  expat,
  fontconfig,
  gdk-pixbuf,
  glib,
  gsettings-desktop-schemas,
  gtk3,
  libayatana-appindicator,
  libdbusmenu,
  libdbusmenu-gtk3,
  libdrm,
  libgbm,
  libglvnd,
  libnotify,
  libpulseaudio,
  librsvg,
  libsecret,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  mesa,
  nspr,
  nss,
  pango,
  systemd,
  xdg-utils,
}:

# Orca ADE (vendored upstream build, no fork).
# Generated + verified by CI (vendor-all.yml on branch main):
#   version/url/hash are filled in by CI on every upstream release and
#   uploaded as release asset `orca.nix`. This file in dotfiles is a copy
#   fetched by pkgs/update-fork-tarballs.sh — do not edit hash by hand.
#
# Upstream publishes Linux as AppImage / .deb / .rpm only; we consume the
# x86_64 AppImage from GitHub Releases.
#
# Upstream names the Linux CLI `orca-ide` (to avoid clashing with the GNOME
# Orca screen reader) and also uses it as the product name. The .deb ships a
# desktop entry that launches the Electron binary directly, plus a separate
# /usr/bin/orca-ide shim for the CLI. We mirror that split: `orca-ide` is the
# GUI launcher used by the desktop entry, `orca-ide-cli` exposes the CLI.
stdenv.mkDerivation rec {
  pname = "orca-ide";
  version = "1.4.257";

  src = fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
    hash = "sha256-kUGhx1dEv6dyTCU+ZmRSWUehVJNzVOqb6VkFJlJKh00=";
  };

  # Extraction only (no FUSE): the AppImage is a squashfs image holding a
  # stock Electron tree (orca-ide binary, resources/, locales/, bundled libs).
  contents = appimageTools.extract {
    inherit pname version src;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    atk
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    dbus-glib
    expat
    fontconfig
    gdk-pixbuf
    glib
    gsettings-desktop-schemas
    gtk3
    libayatana-appindicator
    libdbusmenu
    libdbusmenu-gtk3
    libdrm
    libgbm
    libglvnd
    libnotify
    libpulseaudio
    librsvg
    libsecret
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    mesa
    nspr
    nss
    pango
    systemd
  ];

  # The bundle ships prebuilt musl variants of native node addons
  # (orcad-template/targets/linux-x64-musl, koffi musl_x64) for Alpine hosts.
  # They are never loaded on glibc/NixOS, so leave their musl libc unresolved.
  autoPatchelfIgnoreMissingDeps = [ "libc.musl-x86_64.so.1" ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/orca
    cp -a ${contents}/. $out/opt/orca/
    chmod -R u+w $out/opt/orca

    # AppRun locates APPDIR from its own path, exports the bundled lib and
    # data dirs, then execs the Electron binary. Wrapping AppRun keeps the
    # AppImage layout intact while adding the host libraries Electron needs.
    #
    # AppRun probes `unshare -Ur` and appends --no-sandbox when unavailable,
    # matching upstream's own launcher behaviour.
    makeWrapper $out/opt/orca/AppRun $out/bin/orca-ide \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}" \
      --prefix XDG_DATA_DIRS : "$out/share" \
      --prefix GSETTINGS_SCHEMA_DIR : "${lib.concatMapStringsSep ":" glib.getSchemaPath [ gtk3 gsettings-desktop-schemas ]}" \
      --prefix PATH : "${lib.makeBinPath [ xdg-utils ]}"

    # CLI shim from the .deb layout (resources/bin/orca-ide); it runs the
    # Electron binary in ELECTRON_RUN_AS_NODE mode against out/cli/index.js.
    makeWrapper $out/opt/orca/resources/bin/orca-ide $out/bin/orca-ide-cli \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}" \
      --prefix PATH : "${lib.makeBinPath [ xdg-utils ]}"

    install -Dm644 $out/opt/orca/orca-ide.desktop $out/share/applications/orca-ide.desktop
    substituteInPlace $out/share/applications/orca-ide.desktop \
      --replace-fail "Exec=AppRun" "Exec=$out/bin/orca-ide"

    # AppImage ships the full hicolor icon set already.
    mkdir -p $out/share/icons
    cp -a $out/opt/orca/usr/share/icons/. $out/share/icons/

    runHook postInstall
  '';

  meta = {
    description = "Agent Development Environment for parallel coding agents (vendored upstream AppImage)";
    homepage = "https://orca.dev";
    # Upstream ships a proprietary binary; redistributed as published.
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "orca-ide";
  };
}
