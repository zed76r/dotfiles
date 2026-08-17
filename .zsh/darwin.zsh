[[ "$OSTYPE" == darwin* ]] || return

for _mysql_bin in /opt/homebrew/opt/mysql-client*/bin(N-/) /usr/local/opt/mysql-client*/bin(N-/); do
  path=("$_mysql_bin" $path)
  break
done
unset _mysql_bin

upgrade_all() {
  local -a failures=()

  if (( $+commands[brew] )); then
    command brew update && command brew upgrade || failures+=(brew)
  fi
  zsh "$HOME/.zsh/bin/shell-update.zsh" || failures+=(shell)

  if (( ${#failures} )); then
    print -u2 -- "upgrade_all: failed: ${failures[*]}"
    return 1
  fi
  print -- 'upgrade_all: complete'
}
