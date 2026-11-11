{
  stdenv,
  lib,
  fetchzip,
  autoPatchelfHook,
  glibc,
  zlib,
  ncurses5,
}:

# Google 官方 platform-tools（adb/fastboot 二进制），替代 nixpkgs 的 android-tools。
# 原因：nixpkgs 的 android-tools 是 nmeum 重打包版，编译时去掉了 mDNS 支持
# （`adb mdns check` 报 "mdns is not supported by this version of adb"），
# 而无线调试的自动发现/自动连接依赖 mDNS，nmeum 版只能手动 `adb connect`。
#
# Generated + verified by CI (vendor-all.yml on branch main):
#   version/hash are filled in by CI from the stable channel of Google's
#   repository2-3.xml and uploaded as release asset `platform-tools.nix`.
#   This file in dotfiles is a copy fetched by pkgs/update-fork-tarballs.sh —
#   do not edit hash by hand.
stdenv.mkDerivation rec {
  pname = "platform-tools";
  version = "37.0.1";

  src = fetchzip {
    url = "https://dl.google.com/android/repository/platform-tools_r${version}-linux.zip";
    hash = "sha256-BXLq2h41IOtMQXO5C+n63bH1f3kaHhrE8hd2Wb6hOII=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  # 与 nixpkgs androidenv/platform-tools.nix 保持一致（同一份 Google 二进制）。
  buildInputs = [
    glibc
    (lib.getLib stdenv.cc.cc)
    zlib
    ncurses5
  ];

  # fetchzip 是否 strip 顶层目录不确定，这里两种布局都兼容。
  installPhase = ''
    runHook preInstall

    root="$src"
    if [ -d "$src/platform-tools" ]; then
      root="$src/platform-tools"
    fi

    mkdir -p $out
    cp -r "$root" $out/platform-tools
    chmod -R u+w $out/platform-tools

    mkdir -p $out/bin
    find $out/platform-tools -maxdepth 1 -type f -executable -not -name 'sqlite3*' | while read -r i; do
      ln -s "$i" $out/bin/
    done

    runHook postInstall
  '';

  preFixup = ''
    addAutoPatchelfSearchPath $out/platform-tools/lib64
  '';

  meta = {
    description = "Google Android SDK Platform-Tools (adb, fastboot)";
    homepage = "https://developer.android.com/tools/adb";
    # Google Android SDK 许可（同 androidenv 的 android-sdk-license）。
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "adb";
  };
}
