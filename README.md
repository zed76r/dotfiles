# dotfiles

Public, sanitized Zsh configuration shared between macOS and WSL.

## Ownership and synchronization

macOS is the authority for shared shell declarations:

```text
macOS: edit and validate -> syncmac -u
WSL:   syncwin -d -> zsh ~/.zsh/bin/shell-bootstrap.zsh -> exec zsh
```

WSL must not upload the Mac-authored `.zshrc`, `.zshenv`, `.zprofile`, `.zsh/zimrc`,
`.zsh/versions.lock`, or `.zsh/bin/` files. Machine-local binaries, Zimfw modules,
completion output, compdump, histories, sessions, and credentials are never synced
or committed.

The live synchronization tools are backed up as [`tools/syncmac`](./tools/syncmac)
and [`tools/syncwin`](./tools/syncwin). Repository copies must remain byte-identical
to the scripts in the OneDrive `Tools/scripts` directory.

## Install on macOS

Review the diff first, then:

```zsh
zsh scripts/apply-dotfiles.zsh
zsh ~/.zsh/bin/shell-bootstrap.zsh
exec zsh
```

The apply script backs up every overwritten file under
`${XDG_STATE_HOME:-~/.local/state}/dotfiles/backups/`.

## Install after `syncwin -d`

No Homebrew dependency is used for Zimfw, Starship, or mise:

`syncwin -d` invokes `zsh ~/.zsh/bin/shell-bootstrap.zsh` automatically after the
declarative files are downloaded. Open a new shell or run `exec zsh` afterward.

The bootstrap installs platform-specific binaries into `~/.local/bin`, Zimfw and
plugins into `${XDG_DATA_HOME:-~/.local/share}/zim`, and generated completions into
`${XDG_CACHE_HOME:-~/.cache}/zsh/completions`.

## Reproducible updates

Versions and plugin commits are pinned in `.zsh/versions.lock`. Change the lock on
macOS, run the bootstrap, perform interactive validation, and commit it. WSL then
converges to the same lock after `syncwin -d`.

`upgrade_all` updates the platform package manager and invokes
`.zsh/bin/shell-update.zsh`; the latter reconciles locked shell infrastructure,
refreshes completions, updates mise-managed tools, and invokes `codex update`.

## Secret protection

Install the repository-owned pre-commit hook once per clone:

```bash
bash scripts/install-hooks.sh
```

The hook scans only staged Git blobs, blocks known credential-bearing paths and
token/private-key patterns, and uses `gitleaks` as an additional layer when it is
installed. It reports rule names and paths, never matching values.

Credentials such as `.zsh/gitlab-token`, kubeconfig, histories, generated
completions, and `.env` files are excluded by `.gitignore` and must stay local.

## Design and benchmarks

See [zimfw-wsl-research.md](./zimfw-wsl-research.md).

Run the real-PTY first-key benchmark on macOS with:

```bash
python3 tests/pty-latency.py --samples 30
```

The Linux/WSL smoke test is designed for an ephemeral Debian container mounted
at `/repo`; [`tests/debian-smoke.sh`](./tests/debian-smoke.sh) validates both
native Linux and cross-architecture release assets.
