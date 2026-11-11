{ lib, vscode-utils, fetchurl }:

# w-flow VSCode extension (traditional .vsix from GitHub Release).
# Generated + verified by CI (vendor-all.yml on branch main):
#   version/url/hash are filled in by CI on every upstream release and
#   uploaded as release asset `w-flow-vscode.nix`. This file in dotfiles is
#   a copy fetched by pkgs/update-fork-tarballs.sh — do not edit hash by hand.
vscode-utils.buildVscodeExtension {
  pname = "w-flow";
  version = "0.0.1";

  src = fetchurl {
    url = "https://github.com/WantenMN/w-flow/releases/download/v0.0.1/w-flow-0.0.1.vsix";
    hash = "sha256-U4fDdtQlRnMuKRv6K6R0LYd+kFmNxMFRCXlqoHmdmMk=";
  };

  vscodeExtPublisher = "Wanten";
  vscodeExtName = "w-flow";
  vscodeExtUniqueId = "Wanten.w-flow";

  meta = {
    description = "Personal workflow automation";
    homepage = "https://github.com/WantenMN/w-flow";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
}
