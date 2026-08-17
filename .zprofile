# Login-shell-only initialization.
if [[ "$OSTYPE" == darwin* && -r "$HOME/.orbstack/shell/init.zsh" ]]; then
  source "$HOME/.orbstack/shell/init.zsh" 2>/dev/null || :
fi
