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
  expat,
  fontconfig,
  gdk-pixbuf,
  glib,
  gsettings-desktop-schemas,
  gtk3,
  libayatana-appindicator,
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
}:

# Todoist desktop (vendored upstream build, no fork).
# Generated + verified by CI (vendor-all.yml on branch main):
#   version/url/hash are filled in by CI on every upstream release and
#   uploaded as release asset `todoist.nix`. This file in dotfiles is a copy
#   fetched by pkgs/update-fork-tarballs.sh — do not edit hash by hand.
#
# Upstream only offers Linux as Snap or a raw AppImage; we consume the
# x86_64 AppImage from electron-dl.todoist.net. The version is resolved
# through https://todoist.com/linux_app/appimage (302 redirect).
stdenv.mkDerivation rec {
  pname = "todoist";
  version = "9.36.2";

  src = fetchurl {
    url = "https://electron-dl.todoist.net/linux/Todoist-linux-${version}-x86_64-latest.AppImage";
    hash = "sha256-KI6b0nX/b/Nuo7iv81hcjjBpFVDCc6K/BW3AKbCKTHs=";
  };

  # Extraction only (no FUSE): the AppImage is a squashfs image holding a
  # stock Electron tree (todoist binary, resources/, locales/, bundled libs).
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
    expat
    fontconfig
    gdk-pixbuf
    glib
    gsettings-desktop-schemas
    gtk3
    libayatana-appindicator
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

  # The AppImage bundles stale appindicator/gconf helpers that link against
  # GTK2 and libdbusmenu-gtk2. nixpkgs no longer ships libdbusmenu-gtk2, and
  # Electron never dlopen()s these legacy fallbacks, so leave them unpatched.
  autoPatchelfIgnoreMissingDeps = [
    "libdbusmenu-gtk.so.4"
    "libgtk-x11-2.0.so.0"
    "libdbus-glib-1.so.2"
  ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/todoist
    cp -a ${contents}/. $out/opt/todoist/
    chmod -R u+w $out/opt/todoist

    # AppRun locates APPDIR from its own path, exports the bundled lib and
    # data dirs, then execs the Electron binary. Wrapping AppRun keeps the
    # AppImage layout intact while adding the host libraries Electron needs.
    #
    # AppRun self-detects whether `unshare -Ur` works and appends
    # --no-sandbox when it does not; the desktop entry also passes it
    # explicitly, matching upstream's own AppImage launcher.
    makeWrapper $out/opt/todoist/AppRun $out/bin/todoist \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}" \
      --prefix XDG_DATA_DIRS : "$out/share" \
      --prefix GSETTINGS_SCHEMA_DIR : "${lib.concatMapStringsSep ":" glib.getSchemaPath [ gtk3 gsettings-desktop-schemas ]}"

    install -Dm644 $out/opt/todoist/todoist.desktop $out/share/applications/todoist.desktop
    substituteInPlace $out/share/applications/todoist.desktop \
      --replace-fail "Exec=AppRun" "Exec=$out/bin/todoist" \
      --replace-fail "Exec=todoist" "Exec=$out/bin/todoist"

    mkdir -p $out/share/icons
    cp -a $out/opt/todoist/usr/share/icons/. $out/share/icons/

    runHook postInstall
  '';

  meta = {
    description = "Todoist task manager desktop app (vendored upstream AppImage)";
    homepage = "https://www.todoist.com";
    # Upstream ships a proprietary binary; redistributed as published.
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "todoist";
  };
}
