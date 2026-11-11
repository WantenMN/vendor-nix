#!/usr/bin/env bash
# Track yetone/alma-releases (prebuilt closed-source AppImage, nothing built).
. "$(dirname "$0")/lib.sh"

target=dist/nix/alma.nix
upstream=yetone/alma-releases

# Ignore the android-* / non-semver tags published in the same repo.
tag=$(gh release list --repo "$upstream" --limit 50 \
  --json tagName,isDraft,isPrerelease \
  --jq '[.[] | select(.isDraft == false and .isPrerelease == false)
             | select(.tagName | test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))][0].tagName')
[ -n "$tag" ] || die "failed to resolve latest upstream release"
version=${tag#v}
[ -n "$version" ] || die "empty version from tag $tag"
log "upstream tag: $tag"
log "version:      $version"

if is_up_to_date "$target" "$version"; then
  log "already up to date: $version"
  exit 0
fi

appimage_url="https://github.com/${upstream}/releases/download/v${version}/alma-${version}-linux-x86_64.AppImage"
tmp_appimage="$RUNNER_TEMP/alma.AppImage"
# Release CDN occasionally answers 503; retry before giving up.
curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors -o "$tmp_appimage" "$appimage_url"
hash_appimage=$(nix hash file --sri "$tmp_appimage")
log "appimage hash: $hash_appimage"
sed -i -E "s|version = \".*\";|version = \"${version}\";|" "$target"
replace_hashes "$target" "$hash_appimage"
grep -nE 'version = |alma-releases|AppImage|hash = ' "$target"

out=$(build_package "$target")
log "built: $out"

# The launcher ignores --help/--version and opens the GUI, and its
# os.Executable()-based backend discovery breaks when started through the
# loader (/proc/self/exe becomes the loader). So verify the part packaging
# can break: the GUI starts under Xvfb and every dlopen()ed GTK/WebKitGTK
# library resolves. The binary must not be patchelf'd, so run it via the
# closure's glibc loader with the wrapper's LD_LIBRARY_PATH.
loader=$(closure_loader "$out")
libpath=$(wrapper_libpath "$out/bin/alma")
[ -x "$loader" ] || die "glibc loader not found in closure of $out"
[ -n "$libpath" ] || die "no LD_LIBRARY_PATH entries in wrapper $out/bin/alma"
if ! command -v xvfb-run >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq xvfb
fi
log_file="$RUNNER_TEMP/alma-verify.log"
set +e
APPDIR="$out/opt/alma" timeout 25 xvfb-run -a \
  "$loader" --library-path "$libpath" "$out/opt/alma/alma" >"$log_file" 2>&1
rc=$?
set -e
log "alma startup exit: $rc (124 = still running when timeout hit)"
sed -n '1,20p' "$log_file"
if grep -qE 'cannot open shared object file|cannot load lib|error while loading shared libraries' "$log_file"; then
  die "alma failed to load a shared library"
fi
"$out/opt/alma/alma-server/runtime/node" --version

publish_asset "$target"
log "published: $target"
