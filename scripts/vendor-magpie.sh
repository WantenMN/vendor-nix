#!/usr/bin/env bash
# Track yetone/magpie (prebuilt GUI + static CLI binaries, nothing built).
. "$(dirname "$0")/lib.sh"

target=dist/nix/magpie.nix
upstream=yetone/magpie

tag=$(gh release view --repo "$upstream" --json tagName --jq .tagName)
[ -n "$tag" ] || die "failed to resolve latest upstream release"
version=${tag#v}
[ -n "$version" ] || die "empty version from tag $tag"
log "upstream tag: $tag"
log "version:      $version"

if is_up_to_date "$target" "$version"; then
  log "already up to date: $version"
  exit 0
fi

gui_url="https://github.com/${upstream}/releases/download/v${version}/magpie-linux-amd64"
cli_url="https://github.com/${upstream}/releases/download/v${version}/magpie-cli-linux-amd64"
tmp_gui="$RUNNER_TEMP/magpie-gui"
tmp_cli="$RUNNER_TEMP/magpie-cli"
# Release CDN occasionally answers 503; retry before giving up.
curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors -o "$tmp_gui" "$gui_url"
curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors -o "$tmp_cli" "$cli_url"
hash_gui=$(nix hash file --sri "$tmp_gui")
hash_cli=$(nix hash file --sri "$tmp_cli")
log "gui hash: $hash_gui"
log "cli hash: $hash_cli"
sed -i -E \
  -e "s|version = \".*\";|version = \"${version}\";|" \
  -e "s|magpie/releases/download/v[^/]*/magpie-linux-amd64|magpie/releases/download/v${version}/magpie-linux-amd64|" \
  -e "s|magpie/releases/download/v[^/]*/magpie-cli-linux-amd64|magpie/releases/download/v${version}/magpie-cli-linux-amd64|" \
  "$target"
# Replace the two hashes in order: srcGui block first, srcCli second.
replace_hashes "$target" "$hash_gui" "$hash_cli"
grep -nE 'version = |magpie-linux-amd64|magpie-cli-linux-amd64|hash = ' "$target"

out=$(build_package "$target")
log "built: $out"

# The GUI binary keeps the host ELF interpreter (/lib64/ld-linux-x86-64.so.2)
# while its DT_NEEDED libs are nixpkgs builds requiring a newer glibc, so
# running it directly fails on the Ubuntu runner. On NixOS the host loader is
# the nix one, so this only bites in CI. Invoke it through the closure's glibc
# loader with the wrapper's LD_LIBRARY_PATH. The binary must not be
# patchelf'd — see the comment in dist/nix/magpie.nix.
loader=$(closure_loader "$out")
libpath=$(wrapper_libpath "$out/bin/magpie")
[ -x "$loader" ] || die "glibc loader not found in closure of $out"
[ -n "$libpath" ] || die "no LD_LIBRARY_PATH entries in wrapper $out/bin/magpie"
# sed (not head) so the producer is never SIGPIPE'd under pipefail.
"$loader" --library-path "$libpath" "$out/bin/.magpie-unwrapped" --help | sed -n '1,5p'
"$out/bin/magpie-cli" --help | sed -n '1,5p'

publish_asset "$target"
log "published: $target"
