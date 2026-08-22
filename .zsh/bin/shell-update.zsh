#!/usr/bin/env zsh
set -euo pipefail

typeset -gr ZSH_CONFIG_DIR=${0:A:h:h}

case ${1:-} in
  '') ;;
  --dry-run)
    print -- 'shell-update: would upgrade Zimfw, Zimfw modules, Starship, and mise'
    print -- 'shell-update: would update mise-managed tools and Codex'
    exit 0
    ;;
  -h|--help)
    print -- "Usage: ${0:t} [--dry-run]"
    print -- 'Upgrade shell tools explicitly; bootstrap remains install-only unless --update is passed.'
    exit 0
    ;;
  *)
    print -u2 -- "${0:t}: unknown option: $1"
    exit 2
    ;;
esac

zsh "$ZSH_CONFIG_DIR/bin/shell-bootstrap.zsh" --update
hash -r

typeset -a failures=()
if (( $+commands[mise] )); then
  command mise up || failures+=(mise)
elif [[ -x "$HOME/.local/bin/mise" ]]; then
  command "$HOME/.local/bin/mise" up || failures+=(mise)
fi
if (( $+commands[codex] )); then
  command codex update || failures+=(codex)
fi

if (( ${#failures} )); then
  print -u2 -- "shell-update: failed: ${failures[*]}"
  exit 1
fi
print -- 'shell-update: complete'
