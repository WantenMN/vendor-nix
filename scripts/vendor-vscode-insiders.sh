#!/usr/bin/env bash
# Track Microsoft's VSCode Insiders Linux x64 tarball (no building).
. "$(dirname "$0")/lib.sh"

target=dist/nix/vscode-insiders.nix

latest_url=$(curl -sIL -A "vscode-update-check" "https://update.code.visualstudio.com/latest/linux-x64/insider" \
  | grep -i '^location: ' | tail -1 | tr -d '\r' | awk '{print $2}')
[ -n "$latest_url" ] || die "failed to resolve latest insider URL"

rev=$(printf '%s' "$latest_url" | sed -E 's|.*/insider/([0-9a-f]+)/.*|\1|')
version=$(curl -fsSL -A "vscode-update-check" "https://code.visualstudio.com/sha" \
  | grep -o '"productVersion":"[^"]*-insider"' | head -1 | cut -d'"' -f4)
[ -n "$version" ] && [ -n "$rev" ] || die "failed to parse update info"
log "version: $version"
log "rev:     $rev"
log "url:     $latest_url"

# Insider builds change per commit; compare by rev, not by version string.
current_rev=$(grep -oP 'rev = "\K[0-9a-f]+' "$target" 2>/dev/null || true)
if [ "$current_rev" = "$rev" ] && [ "$FORCE" != "true" ] && asset_exists "$target"; then
  log "already up to date: $version ($rev)"
  exit 0
fi

tmp_tar="$RUNNER_TEMP/vscode-insiders.tar.gz"
curl -fsSL -A "vscode-update-check" -o "$tmp_tar" "$latest_url"
hash=$(nix hash file --sri "$tmp_tar")
log "hash: $hash"
sed -i -E \
  -e "s|version = \".*\";|version = \"${version}\";|" \
  -e "s|rev = \".*\";|rev = \"${rev}\";|" \
  -e "s|name = \"VSCode-Insiders-.*\";|name = \"VSCode-Insiders-${version}.tar.gz\";|" \
  -e "s|url = \"https://vscode.download.*\";|url = \"${latest_url}\";|" \
  "$target"
replace_hashes "$target" "$hash"
grep -nE 'version = |rev = |name = |url = |hash = ' "$target"

out=$(build_package "$target")
log "built: $out"
"$out/bin/code-insiders" --version | sed -n '1,3p'

publish_asset "$target"
log "published: $target"
