#!/usr/bin/env zsh
set -euo pipefail

typeset -gr ZSH_CONFIG_DIR=${0:A:h:h}
zsh "$ZSH_CONFIG_DIR/bin/shell-bootstrap.zsh"

typeset -a failures=()
if (( $+commands[mise] )); then
  command mise up || failures+=(mise)
fi
if (( $+commands[codex] )); then
  command codex update || failures+=(codex)
fi

if (( ${#failures} )); then
  print -u2 -- "shell-update: failed: ${failures[*]}"
  exit 1
fi
print -- 'shell-update: complete'
