#!/usr/bin/env bash
# Track the w-flow VSCode extension (.vsix published on GitHub releases).
. "$(dirname "$0")/lib.sh"

target=dist/nix/w-flow-vscode.nix
upstream=WantenMN/w-flow

tag=$(gh release view --repo "$upstream" --json tagName --jq .tagName)
[ -n "$tag" ] || die "failed to resolve latest upstream release"
version=${tag#v}
[ -n "$version" ] || die "empty version from tag $tag"
asset="w-flow-${version}.vsix"
url="https://github.com/${upstream}/releases/download/${tag}/${asset}"
log "tag:     $tag"
log "version: $version"

if is_up_to_date "$target" "$version"; then
  log "already up to date: $version"
  exit 0
fi

tmp_vsix="$RUNNER_TEMP/${asset}"
curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors -o "$tmp_vsix" "$url"
hash=$(nix hash file --sri "$tmp_vsix")
log "hash: $hash"
sed -i -E \
  -e "s|version = \".*\";|version = \"${version}\";|" \
  -e "s|w-flow/releases/download/v[^/]*/w-flow-[^\"]*\.vsix|w-flow/releases/download/v${version}/${asset}|" \
  "$target"
replace_hashes "$target" "$hash"
grep -nE 'version = |w-flow/releases|hash = ' "$target"

out=$(build_package "$target")
log "built: $out"
test -n "$(find "$out" -name '*.vsix' -o -name 'package.json' | head -1)"

publish_asset "$target"
log "published: $target"
