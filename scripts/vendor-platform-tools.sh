#!/usr/bin/env bash
# Track Google's official Android platform-tools (adb/fastboot binaries).
. "$(dirname "$0")/lib.sh"

target=dist/nix/platform-tools.nix
manifest=https://dl.google.com/android/repository/repository2-3.xml
base_url=https://dl.google.com/android/repository

# channel-0 is the stable channel; channel-2 in the same manifest is a
# preview that should not be vendored.
resolved=$(curl -fsSL "$manifest" | python3 -I -c '
import sys, xml.etree.ElementTree as ET
root = ET.fromstring(sys.stdin.read().encode())
for p in root.iter("remotePackage"):
    if p.get("path") != "platform-tools":
        continue
    ch = p.find("channelRef")
    if ch is None or ch.get("ref") != "channel-0":
        continue
    r = p.find("revision")
    parts = [r.findtext(k) for k in ("major", "minor", "micro")]
    ver = ".".join(x for x in parts if x)
    for a in p.iter("archive"):
        if a.findtext("host-os") == "linux":
            print(ver, a.findtext("complete/url"))
            raise SystemExit
raise SystemExit("platform-tools not found in stable channel")
')
[ -n "$resolved" ] || die "failed to resolve platform-tools"
version=${resolved%% *}
zip_name=${resolved#* }
url="${base_url}/${zip_name}"
log "version: $version"
log "url:     $url"
[ "$zip_name" = "platform-tools_r${version}-linux.zip" ] \
  || die "unexpected archive name $zip_name for revision $version"

if is_up_to_date "$target" "$version"; then
  log "already up to date: $version"
  exit 0
fi

# The template uses fetchzip, so the hash is of the unpacked tree, not the zip.
hash=$(nix store prefetch-file --unpack --json "$url" | sed -E 's/.*"hash":"([^"]+)".*/\1/')
[ -n "$hash" ] || die "failed to prefetch $url"
log "unpacked hash: $hash"
sed -i -E "s|version = \".*\";|version = \"${version}\";|" "$target"
replace_hashes "$target" "$hash"
grep -nE 'version = |platform-tools_r|hash = ' "$target"

out=$(build_package "$target")
log "built: $out"
test -x "$out/bin/adb"
test -x "$out/platform-tools/fastboot"

# Verify the binaries actually start. As with the other vendored binaries, run
# them through the closure's glibc loader to avoid the runner's older glibc.
loader=$(closure_loader "$out")
[ -x "$loader" ] || die "glibc loader not found in closure of $out"
"$loader" "$out/platform-tools/adb" version | sed -n '1,3p'
"$loader" "$out/platform-tools/fastboot" --version | sed -n '1,2p'

publish_asset "$target"
log "published: $target"
