{
  stdenv,
  lib,
  fetchurl,
  makeWrapper,
  appimageTools,
  alsa-lib,
  atk,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  ffmpeg,
  fontconfig,
  gdk-pixbuf,
  glib,
  gsettings-desktop-schemas,
  gtk3,
  gtk-layer-shell,
  harfbuzz,
  libayatana-appindicator,
  libdrm,
  libepoxy,
  libgbm,
  libglvnd,
  libpulseaudio,
  librsvg,
  libsecret,
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
  nspr,
  nss,
  openssl,
  pango,
  udev,
  wayland,
  webkitgtk_4_1,
}:

# Alma (vendored upstream build, no fork).
# Generated + verified by CI (vendor-all.yml on branch main):
#   version/url/hash are filled in by CI on every upstream release and
#   uploaded as release asset `alma.nix`. This file in dotfiles is a copy
#   fetched by pkgs/update-fork-tarballs.sh — do not edit hash by hand.
#
# Upstream publishes electron-builder style artifacts in a releases-only
# repo (yetone/alma-releases). We consume the Linux x86_64 AppImage: it is
# the only artifact that ships the complete app tree (native launcher,
# bundled Node `alma-server` runtime, renderer assets, icons, desktop file).
let
  # GTK3 ships its own GSettings schemas (e.g. org.gtk.Settings.FileChooser)
  # in $gtk3/share/gsettings-schemas/gtk+3-<ver>, separate from
  # gsettings-desktop-schemas. wrapGAppsHook normally exports these through
  # XDG_DATA_DIRS; Alma's launcher dlopen()s GTK directly and is not wrapped
  # by that hook, so without this GTK aborts on the first file dialog with
  # "Settings schema 'org.gtk.Settings.FileChooser' is not installed".
  gsettingsDataDirs = lib.concatMapStringsSep ":" glib.getSchemaDataDirPath [
    gtk3
    gsettings-desktop-schemas
  ];
  gsettingsSchemaDirs = lib.concatMapStringsSep ":" glib.getSchemaPath [
    gtk3
    gsettings-desktop-schemas
  ];
in
stdenv.mkDerivation rec {
  pname = "alma";
  version = "0.4.570";

  srcAppImage = fetchurl {
    url = "https://github.com/yetone/alma-releases/releases/download/v${version}/alma-${version}-linux-x86_64.AppImage";
    hash = "sha256-JZR3kZitIWzI3IDiaOdWpdtQRh/DHtVvFh8OaXNqpD8=";
  };

  # Extraction only (no FUSE): the AppImage is a squashfs image. The app tree
  # is installed as-is under $out/opt/alma; resources are located via APPDIR.
  contents = appimageTools.extract {
    pname = "alma";
    inherit version;
    src = srcAppImage;
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  # The launcher is a Go binary that dlopen()s GTK/WebKitGTK at runtime; the
  # bundled Node runtime and alma-server are prebuilt. All of them keep their
  # upstream ELF interpreter (/lib64/ld-linux-x86-64.so.2), so do not patchelf
  # them: patchelf (even 0.19.2) rewrites this Go binary in a way that makes it
  # segfault on startup.
  buildInputs = [
    alsa-lib
    atk
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    ffmpeg
    fontconfig
    gdk-pixbuf
    glib
    gtk3
    gtk-layer-shell
    harfbuzz
    libayatana-appindicator
    libdrm
    libepoxy
    libgbm
    libglvnd
    libpulseaudio
    librsvg
    libsecret
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
    nspr
    nss
    openssl
    pango
    udev
    wayland
    webkitgtk_4_1
  ];

  dontUnpack = true;
  dontAutoPatchelf = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/alma
    cp -a ${contents}/. $out/opt/alma/

    # The launcher dlopen()s GTK/WebKitGTK, so it needs this search path. Every
    # process Alma spawns (herdr-core, terminal panes, agent CLIs) inherits it
    # too, and LD_LIBRARY_PATH outranks each binary's own RUNPATH. OpenSSL is
    # therefore filtered out: nothing in the launcher links libcrypto, and a
    # leaked libcrypto path makes children load the wrong ABI — codex is built
    # against aws-lc and aborts on its aws-lc-only `EC_group_p384` symbol.
    almaLibPath="${lib.makeLibraryPath (builtins.filter (p: p != openssl) buildInputs)}"

    makeWrapper $out/opt/alma/alma $out/bin/alma \
      --prefix LD_LIBRARY_PATH : "$almaLibPath" \
      --prefix XDG_DATA_DIRS : "${gsettingsDataDirs}" \
      --prefix GSETTINGS_SCHEMA_DIR : "${gsettingsSchemaDirs}" \
      --set APPDIR "$out/opt/alma" \
      --run 'if [ -n "$HOME" ]; then _alma_cli="$HOME/.local/bin/alma"; _alma_sys="'"$out"'/bin/alma-cli"; if [ ! -L "$_alma_cli" ] || [ "$(readlink "$_alma_cli")" != "$_alma_sys" ]; then if [ ! -e "$_alma_cli" ] || [ -L "$_alma_cli" ] || grep -q "alma-server/resources/cli/alma" "$_alma_cli" 2>/dev/null; then mkdir -p "$HOME/.local/bin"; rm -f "$_alma_cli" 2>/dev/null || true; ln -s "$_alma_sys" "$_alma_cli" 2>/dev/null || true; fi; fi; unset _alma_cli _alma_sys; fi'

    # Upstream's launcher self-installs ~/.local/bin/alma as a shell script
    # with a hardcoded store path, which breaks after a GC or upgrade. Provide
    # a stable CLI wrapper; the --run hook above pins the user path to it as a
    # read-only symlink, so the launcher's rewrite fails with EROFS (it logs
    # and ignores that, like magpie's desktop entry).
    #
    # The CLI keeps LD_LIBRARY_PATH: bun needs it, and alma-cli never spawns
    # herdr/agents, so it cannot leak into their environment.
    makeWrapper $out/opt/alma/alma-server/resources/bun/bun $out/bin/alma-cli \
      --add-flags "$out/opt/alma/alma-server/resources/cli/alma" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}"

    mkdir -p $out/share/applications
    install -Dm644 $out/opt/alma/alma.desktop $out/share/applications/alma.desktop
    substituteInPlace $out/share/applications/alma.desktop \
      --replace-fail "Exec=alma" "Exec=$out/bin/alma"

    install -Dm644 $out/opt/alma/alma-256x256.png $out/share/icons/hicolor/256x256/apps/alma.png
    install -Dm644 $out/opt/alma/alma.png $out/share/icons/hicolor/512x512/apps/alma.png

    runHook postInstall
  '';

  meta = {
    description = "Alma desktop app (vendored upstream build)";
    homepage = "https://alma.now";
    # Upstream ships a proprietary binary; the desktop app is redistributed
    # as published by yetone/alma-releases.
    license = lib.licenses.unfreeRedistributable;
    platforms = [ "x86_64-linux" ];
    mainProgram = "alma";
  };
}
