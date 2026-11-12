# vendor-nix

Nix packaging pointers for upstream binaries that dotfiles installs without
building. **Not upstream releases** — nothing is built here. One daily CI run
tracks all packages, and a failure in one never blocks the others.

Consumed by `pkgs/update-fork-tarballs.sh` in
[dotfiles](https://github.com/WantenMN/dotfiles); every pointer is uploaded to
the [`rolling` release](https://github.com/WantenMN/vendor-nix/releases/tag/rolling)
under its own fixed filename.

| Package | Upstream | Version source | Template |
|---|---|---|---|
| `alma.nix` | [yetone/alma-releases](https://github.com/yetone/alma-releases) | GitHub releases (semver) | [`dist/nix/alma.nix`](dist/nix/alma.nix) |
| `magpie.nix` | [yetone/magpie](https://github.com/yetone/magpie) | GitHub releases | [`dist/nix/magpie.nix`](dist/nix/magpie.nix) |
| `orca.nix` | [stablyai/orca](https://github.com/stablyai/orca) | GitHub releases (semver) | [`dist/nix/orca.nix`](dist/nix/orca.nix) |
| `todoist.nix` | [todoist.com/downloads/linux](https://www.todoist.com/downloads/linux) | download-page redirect | [`dist/nix/todoist.nix`](dist/nix/todoist.nix) |
| `vscode-insiders.nix` | Microsoft update API | redirect + `code.visualstudio.com/sha` | [`dist/nix/vscode-insiders.nix`](dist/nix/vscode-insiders.nix) |
| `platform-tools.nix` | [Google repository2-3.xml](https://dl.google.com/android/repository/repository2-3.xml) | stable channel revision | [`dist/nix/platform-tools.nix`](dist/nix/platform-tools.nix) |
| `w-flow-vscode.nix` | [WantenMN/w-flow](https://github.com/WantenMN/w-flow) | GitHub releases | [`dist/nix/w-flow-vscode.nix`](dist/nix/w-flow-vscode.nix) |

## Layout

- `.github/workflows/vendor-all.yml` — daily cron plus manual dispatch. A
  `prepare` job ensures the `rolling` release exists; one job per package then
  runs independently (`needs: prepare` only), so failures stay isolated. A
  final `summary` job reports per-package results without affecting publishing.
- `scripts/vendor-<package>.sh` — resolve, download, hash, rewrite the
  template, verify with `nix build`, upload. Shared helpers live in
  `scripts/lib.sh`.
- `dist/nix/<pointer>.nix` — templates whose `version`/`hash` (and for VSCode,
  `rev`/`url`/`name`) fields CI rewrites in place.

## Manual run

```sh
gh workflow run vendor-all.yml -R WantenMN/vendor-nix
# force regeneration even when upstream version is unchanged:
gh workflow run vendor-all.yml -R WantenMN/vendor-nix -f force=true
```

`alma`, `orca`, `todoist` and `vscode-insiders` ship proprietary binaries and are
marked `unfree`; consumers need `nixpkgs.config.allowUnfree` or an allowlist.
