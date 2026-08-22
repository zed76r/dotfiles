#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
bootstrap="$repo_root/.zsh/bin/shell-bootstrap.zsh"
shell_update="$repo_root/.zsh/bin/shell-update.zsh"

[[ ! -e "$repo_root/.zsh/versions.lock" ]] || {
  echo 'shell-update-contract: versions.lock must not be present' >&2
  exit 1
}
! grep -Eq 'versions\.lock|LOCK_FILE|lock_module|ZIMFW_VERSION|STARSHIP_VERSION|MISE_VERSION' "$bootstrap" || {
  echo 'shell-update-contract: bootstrap still has pinned-version logic' >&2
  exit 1
}
grep -Fq 'shell-bootstrap.zsh" --update' "$shell_update"
grep -Fq "download 'https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh'" "$bootstrap"
grep -Fq 'source "$ZIM_HOME/zimfw.zsh" update -q' "$bootstrap"
! grep -Fq 'source "$ZIM_HOME/zimfw.zsh" upgrade' "$bootstrap"
grep -Fq 'install_starship_latest' "$bootstrap"
grep -Fq 'install_mise_latest' "$bootstrap"

release_json='{"url":"https://api.github.com/repos/example/releases/123","tag_name":"v9.9.9","html_url":"https://github.com/example/releases/tag/v9.9.9"}'
latest_tag=$(printf '%s\n' "$release_json" | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | sed -n '1p')
[[ "$latest_tag" == v9.9.9 ]] || {
  echo 'shell-update-contract: single-line GitHub tag parsing failed' >&2
  exit 1
}

dry_run=$(zsh "$shell_update" --dry-run)
grep -Fq 'Zimfw modules' <<<"$dry_run"
grep -Fq 'Starship, and mise' <<<"$dry_run"
grep -Fq 'mise-managed tools and Codex' <<<"$dry_run"

echo 'shell-update-contract: passed'
