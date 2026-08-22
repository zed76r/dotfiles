#!/usr/bin/env zsh
set -euo pipefail

typeset -gr REPO_ROOT=${0:A:h:h}
typeset -gr BACKUP_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backups/$(date +%Y%m%d-%H%M%S)"
typeset -a sources=(
  .zshrc
  .zshenv
  .zprofile
  .zsh/adb.zsh
  .zsh/ai.zsh
  .zsh/android.zsh
  .zsh/codex-guardrails.zsh
  .zsh/codex-zdotdir/.zshenv
  .zsh/darwin.zsh
  .zsh/linux.zsh
  .zsh/starship.toml
  .zsh/zimrc
  .zsh/zed.zsh
  .zsh/zsh.zsh
  .zsh/bin/pnpx
  .zsh/bin/refresh-completions.zsh
  .zsh/bin/shell-bootstrap.zsh
  .zsh/bin/shell-update.zsh
  .zsh/bin/tail-url
)

mkdir -p "$BACKUP_ROOT"
for relative in "${sources[@]}"; do
  source_file="$REPO_ROOT/$relative"
  target_file="$HOME/$relative"
  target_mode=0644
  [[ "$relative" == .zsh/bin/* ]] && target_mode=0755
  [[ -r "$source_file" ]] || { print -u2 -- "missing repository file: $relative"; exit 1; }
  mkdir -p "${target_file:h}" "$BACKUP_ROOT/${relative:h}"
  [[ -e "$target_file" ]] && command cp -p "$target_file" "$BACKUP_ROOT/$relative"
  command install -m "$target_mode" "$source_file" "$target_file.new"
  command mv -f "$target_file.new" "$target_file"
done

# Remove the retired pinned-version file after preserving a rollback copy.
legacy_lock="$HOME/.zsh/versions.lock"
if [[ -e "$legacy_lock" ]]; then
  command cp -p "$legacy_lock" "$BACKUP_ROOT/.zsh/versions.lock"
  command rm -f -- "$legacy_lock"
fi

mkdir -p "$HOME/.local/bin"
ln -fs "$HOME/.zsh/bin/pnpx" "$HOME/.local/bin/pnpx"
ln -fs "$HOME/.zsh/bin/tail-url" "$HOME/.local/bin/turl"

print -- "dotfiles applied; previous files saved under $BACKUP_ROOT"
print -- 'next: zsh ~/.zsh/bin/shell-bootstrap.zsh'
