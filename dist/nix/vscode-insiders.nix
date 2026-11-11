{
  buildVscode,
  fetchurl,
  imagemagick,
  lib,
  stdenv,
}:

# VSCode Insiders (Microsoft-built tarball, no fork).
# Generated + verified by CI (vendor-all.yml on branch main):
#   version/rev/name/url/hash are filled in by CI on every insider build and
#   uploaded as release asset `vscode-insiders.nix`. This file in dotfiles is
#   a copy fetched by pkgs/update-fork-tarballs.sh — do not edit hash by hand.
(buildVscode {
  pname = "vscode-insiders";
  executableName = "code-insiders";
  longName = "Visual Studio Code - Insiders";
  shortName = "Code - Insiders";
  version = "1.146.0-insider";
  rev = "142e5584a76358bbb4fb687d8a0d2f4e859a6767";
  commandLineArgs = "";
  useVSCodeRipgrep = false;
  sourceExecutableName = "code-insiders";
  src = fetchurl {
    name = "VSCode-Insiders-1.146.0-insider.tar.gz";
    url = "https://vscode.download.prss.microsoft.com/dbazure/download/insider/142e5584a76358bbb4fb687d8a0d2f4e859a6767/code-insider-x64-1794202011.tar.gz";
    hash = "sha256-pcSGiBux1OmSCYeaDqVdws2iThlozuEaLapnBu7jGGs=";
  };
  tests = { };
  sourceRoot = "";
  vscodeServer = null;
  updateScript = null;
  dontFixup = stdenv.hostPlatform.isDarwin;
  hasVsceSign = true;
  meta = {
    description = "Code editor developed by Microsoft (Insiders)";
    mainProgram = "code-insiders";
    homepage = "https://code.visualstudio.com/";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
  };
}).overrideAttrs (oldAttrs: {
  nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ imagemagick ];
  postInstall = (oldAttrs.postInstall or "") + ''
    # Upstream tarball ships a single 1024px code.png; generic installs it
    # only under hicolor/1024x1024, which hicolor-icon-theme does not list
    # (max 512x512), so theme-compliant launchers such as fuzzel find no
    # icon. Generate the standard sizes from the shipped pixmap.
    for src in "$out"/share/pixmaps/*.png; do
      [ -e "$src" ] || continue
      icon="$(basename "$src")"
      for size in 16 32 48 64 128 256 512; do
        mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
        convert "$src" -resize "''${size}x''${size}" "$out/share/icons/hicolor/''${size}x''${size}/apps/$icon"
      done
    done
  '';
})
