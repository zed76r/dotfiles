[[ "$OSTYPE" == linux* ]] || return

upgrade_all() {
  local -a failures=()

  if (( $+commands[apt] )); then
    sudo apt update && sudo apt upgrade -y || failures+=(apt)
  fi
  zsh "$HOME/.zsh/bin/shell-update.zsh" || failures+=(shell)

  if (( ${#failures} )); then
    print -u2 -- "upgrade_all: failed: ${failures[*]}"
    return 1
  fi
  print -- 'upgrade_all: complete'
}
