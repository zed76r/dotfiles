[[ -n ${ZPROF:-} ]] && zmodload zsh/zprof

for _zsh_file in "$HOME"/.zsh/*.zsh(N); do
  source "$_zsh_file"
done
unset _zsh_file

if command ls --color=auto -d . >/dev/null 2>&1; then
  alias ls='ls --color=auto'
  (( $+commands[dir] )) && alias dir='dir --color=auto'
  (( $+commands[vdir] )) && alias vdir='vdir --color=auto'
else
  alias ls='ls -G'
fi
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'

HISTFILE=${HISTFILE:-$HOME/.zsh_history}
HISTSIZE=50000
SAVEHIST=$HISTSIZE
setopt extended_history hist_expire_dups_first hist_ignore_all_dups hist_ignore_space

export STARSHIP_CONFIG="$HOME/.zsh/starship.toml"
if (( $+commands[starship] )); then
  (( $+functions[precmd_title] )) && precmd_functions+=(precmd_title)
  eval "$(starship init zsh)"
fi

export ZIM_CONFIG_FILE="$HOME/.zsh/zimrc"
export ZIM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zim"
if [[ -r "$ZIM_HOME/init.zsh" ]]; then
  source "$ZIM_HOME/init.zsh"
  [[ "$ZIM_HOME/init.zsh" -nt "$ZIM_CONFIG_FILE" ]] ||
    print -u2 -- 'zimfw: configuration changed; run zsh ~/.zsh/bin/shell-bootstrap.zsh'
else
  print -u2 -- 'zimfw: not installed; run zsh ~/.zsh/bin/shell-bootstrap.zsh'
fi

if (( $+commands[mise] )); then
  eval "$(mise activate zsh)"
fi

typeset -g ZSH_COMPLETION_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completions"
[[ -d "$ZSH_COMPLETION_CACHE" ]] && fpath=("$ZSH_COMPLETION_CACHE" $fpath)

autoload -Uz compinit
typeset -g ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${ZSH_VERSION}"
mkdir -p "${ZSH_COMPDUMP:h}"
if [[ -s "$ZSH_COMPDUMP" && "$ZSH_COMPDUMP" -nt "$ZIM_CONFIG_FILE" &&
      ( ! -e "$ZIM_HOME/init.zsh" || "$ZSH_COMPDUMP" -nt "$ZIM_HOME/init.zsh" ) ]]; then
  compinit -C -d "$ZSH_COMPDUMP"
else
  compinit -d "$ZSH_COMPDUMP"
fi

(( $+functions[_codex_with_effort] && $+functions[_codex] )) &&
  compdef _codex_with_effort codex

zstyle ':completion:*' menu select=2
zstyle ':history-search-multi-word' page-size 10
zstyle ':history-search-multi-word' highlight-color 'fg=red,bold'
zstyle ':plugin:history-search-multi-word' reset-prompt-protect 1
(( $+widgets[history-search-multi-word] )) && bindkey '^R' history-search-multi-word

if (( $+commands[dircolors] )); then
  eval "$(dircolors -b)"
elif (( $+commands[gdircolors] )); then
  eval "$(gdircolors -b)"
fi
[[ -n ${LS_COLORS:-} ]] && zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

if [[ "$TERM_PROGRAM" == vscode ]] && (( $+commands[code] )); then
  _vscode_shell_integration=$(code --locate-shell-integration-path zsh 2>/dev/null)
  [[ -r "$_vscode_shell_integration" ]] && source "$_vscode_shell_integration"
  unset _vscode_shell_integration
fi

[[ -n ${ZPROF:-} ]] && zprof
