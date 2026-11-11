#!/usr/bin/env bash
# Track the official Todoist Linux AppImage (electron-dl.todoist.net).
. "$(dirname "$0")/lib.sh"

target=dist/nix/todoist.nix
download_page=https://todoist.com/linux_app/appimage

# The download page answers with a 302 to the versioned CDN URL.
# HEAD keeps this cheap; -L is only needed to read the final URL.
appimage_url=$(curl -fsSIL -o /dev/null -w '%{url_effective}' "$download_page")
log "resolved: $appimage_url"
version=$(printf '%s' "$appimage_url" \
  | sed -nE 's|.*/Todoist-linux-([0-9]+(\.[0-9]+)+)-x86_64-latest\.AppImage$|\1|p')
[ -n "$version" ] || die "could not parse version from $appimage_url"
log "version:  $version"

if is_up_to_date "$target" "$version"; then
  log "already up to date: $version"
  exit 0
fi

tmp_appimage="$RUNNER_TEMP/todoist.AppImage"
# CDN occasionally answers 5xx; retry before giving up.
curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors -o "$tmp_appimage" "$appimage_url"
hash_appimage=$(nix hash file --sri "$tmp_appimage")
log "appimage hash: $hash_appimage"
sed -i -E "s|version = \".*\";|version = \"${version}\";|" "$target"
replace_hashes "$target" "$hash_appimage"
grep -nE 'version = |Todoist-linux|hash = ' "$target"

out=$(build_package "$target")
log "built: $out"

# `nix build` already proves the AppImage unpacks, autoPatchelf resolves every
# DT_NEEDED, and the wrapper/desktop entry install. Running Electron in CI adds
# no signal: the Nix binaries need the closure's glibc, and launching the
# Electron binary through that loader breaks its /proc/self/exe resources
# lookup. Check the packaged tree instead.
test -x "$out/bin/todoist"
test -f "$out/opt/todoist/resources/app.asar"
test -f "$out/share/applications/todoist.desktop"
test -f "$out/share/icons/hicolor/512x512/apps/todoist.png"
grep -q "Exec=$out/bin/todoist" "$out/share/applications/todoist.desktop"

publish_asset "$target"
log "published: $target"
