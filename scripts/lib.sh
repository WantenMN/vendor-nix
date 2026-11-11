#!/usr/bin/env bash
# Shared helpers for scripts/vendor-*.sh. Every vendor script sources this.
set -euo pipefail

ROLL_TAG=${ROLL_TAG:-rolling}
NIXPKGS_TARBALL=${NIXPKGS_TARBALL:-https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst}
FORCE=${FORCE:-false}

log() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# First `version = "..."` field in a template.
current_version() { grep -oP 'version = "\K[^"]+' "$1" | head -1; }

asset_exists() {
  gh release view "$ROLL_TAG" --repo "$GITHUB_REPOSITORY" --json assets \
    --jq '.assets[].name' 2>/dev/null | grep -qx "$(basename "$1")"
}

# An asset is only skipped when the template matches AND the rolling pointer
# actually exists; a fresh repo must publish on its first run.
is_up_to_date() {
  local target=$1 version=$2
  [ "$(current_version "$target")" = "$version" ] || return 1
  [ "$FORCE" != "true" ] || return 1
  asset_exists "$target"
}

# Replace the first N `hash = "sha256-..."` assignments, in file order.
replace_hashes() {
  local target=$1
  shift
  python3 - "$target" "$@" <<'EOF'
import re, sys
path, *hashes = sys.argv[1:]
text = open(path).read()
it = iter(hashes)
text, n = re.subn(r'hash = "sha256-[^"]*";', lambda _: f'hash = "{next(it)}";', text, count=len(hashes))
assert n == len(hashes), f"expected {len(hashes)} hash fields, found {n}"
open(path, "w").write(text)
EOF
}

build_package() {
  nix build -L --impure --no-link --print-out-paths --expr \
    "let pkgs = import (builtins.fetchTarball { url = \"$NIXPKGS_TARBALL\"; }) { config.allowUnfree = true; }; in pkgs.callPackage ./$1 {}"
}

publish_asset() {
  local target=$1
  if ! gh release view "$ROLL_TAG" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
    gh release create "$ROLL_TAG" --repo "$GITHUB_REPOSITORY" \
      --title "Vendor rolling pointers" \
      --notes "Fixed-name vendored derivations (upstream builds, no fork). dotfiles consumes them via pkgs/update-fork-tarballs.sh." \
      --target main
  fi
  gh release upload "$ROLL_TAG" "$target" --repo "$GITHUB_REPOSITORY" --clobber
}

# glibc loader from the package's own closure. Nix binaries may need a newer
# glibc than the Ubuntu runner provides, so verification runs them through it.
closure_loader() {
  local out=$1 p
  for p in $(nix-store -qR "$out" | grep -E -- '-glibc-[0-9]' || true); do
    if [ -x "$p/lib/ld-linux-x86-64.so.2" ]; then
      printf '%s\n' "$p/lib/ld-linux-x86-64.so.2"
      return 0
    fi
  done
  return 1
}

# The makeWrapper-generated LD_LIBRARY_PATH entries, colon-joined.
wrapper_libpath() {
  sed -n "s/^LD_LIBRARY_PATH='\([^']*\)'\$LD_LIBRARY_PATH$/\1/p" "$1" | paste -sd:
}
