# Fast environment shared by interactive and non-interactive Zsh.
export LANG=${LANG:-en_US.UTF-8}
typeset -U path PATH

if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

[[ -r "$HOME/.acme.sh/acme.sh.env" ]] && source "$HOME/.acme.sh/acme.sh.env"

path=(
  "$HOME/bin"(N-/)
  "$HOME/.local/bin"(N-/)
  "$HOME/.zsh/bin"(N-/)
  "$HOME/.local/share/mise/shims"(N-/)
  $path
)

[[ -r "$HOME/.kube/config" ]] && export KUBECONFIG="$HOME/.kube/config"

if [[ "$OSTYPE" == darwin* ]]; then
  path+=(
    "$HOME/Library/Application Support/JetBrains/Toolbox/scripts"(N-/)
    "$HOME/.cache/lm-studio/bin"(N-/)
  )
fi
