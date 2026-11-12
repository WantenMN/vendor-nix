#!/usr/bin/env bash
# Track the official Orca ADE Linux AppImage (stablyai/orca GitHub Releases).
. "$(dirname "$0")/lib.sh"

target=dist/nix/orca.nix
upstream=stablyai/orca
asset=orca-linux.AppImage

tag=$(gh release view --repo "$upstream" --json tagName --jq .tagName)
[ -n "$tag" ] || die "failed to resolve latest upstream release"
version=${tag#v}
[ -n "$version" ] || die "empty version from tag $tag"
# The template builds the download URL from version as v<version>.
[ "$tag" = "v$version" ] || die "unexpected tag format: $tag"
log "upstream tag: $tag"
log "version:      $version"

if is_up_to_date "$target" "$version"; then
  log "already up to date: $version"
  exit 0
fi

appimage_url="https://github.com/${upstream}/releases/download/${tag}/${asset}"
tmp_appimage="$RUNNER_TEMP/orca.AppImage"
# Release CDN occasionally answers 5xx; retry before giving up.
curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors -o "$tmp_appimage" "$appimage_url"
hash_appimage=$(nix hash file --sri "$tmp_appimage")
log "appimage hash: $hash_appimage"
sed -i -E "s|version = \".*\";|version = \"${version}\";|" "$target"
replace_hashes "$target" "$hash_appimage"
grep -nE 'version = |orca/releases|AppImage|hash = ' "$target"

out=$(build_package "$target")
log "built: $out"

# `nix build` already proves the AppImage unpacks, autoPatchelf resolves every
# DT_NEEDED, and the wrapper/desktop entry install. Running Electron in CI adds
# no signal: the Nix binaries need the closure's glibc, and launching the
# Electron binary through that loader breaks its /proc/self/exe resources
# lookup. Check the packaged tree instead.
test -x "$out/bin/orca-ide"
test -x "$out/bin/orca-ide-cli"
test -f "$out/opt/orca/resources/app.asar"
test -f "$out/share/applications/orca-ide.desktop"
grep -q "Exec=$out/bin/orca-ide" "$out/share/applications/orca-ide.desktop"

# resources/bin/orca-wayland-clipboard dlopens libwayland-client.so.0 at
# runtime, so autoPatchelf cannot see it (not DT_NEEDED). If it stops
# resolving via the wrapper's LD_LIBRARY_PATH, every clipboard write fails
# with "Wayland clipboard write failed". Assert resolvability, not just
# closure membership.
libpath=$(wrapper_libpath "$out/bin/orca-ide")
[ -n "$libpath" ] || die "no LD_LIBRARY_PATH entries in wrapper $out/bin/orca-ide"
wayland_so=
old_ifs=$IFS; IFS=:
for d in $libpath; do
  if [ -f "$d/libwayland-client.so.0" ]; then wayland_so="$d/libwayland-client.so.0"; break; fi
done
IFS=$old_ifs
[ -n "$wayland_so" ] || die "libwayland-client.so.0 not reachable via wrapper LD_LIBRARY_PATH"
log "wayland clipboard dep: $wayland_so"

publish_asset "$target"
log "published: $target"
