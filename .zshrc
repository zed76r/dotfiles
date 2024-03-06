#!/usr/bin/env zsh
[ -z "$ZPROF" ] || zmodload zsh/zprof
. $HOME/.zsh/*.zsh

# Zinit init
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
    mkdir -p "$(dirname $ZINIT_HOME)"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME" -o origin
fi

source "${ZINIT_HOME}/zinit.zsh"


# some more ls aliases
alias ls='ls --color=auto'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'


#set history
[ -z "$HISTFILE" ] && HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=$HISTSIZE
setopt extended_history       # record timestamp of command in HISTFILE
setopt hist_expire_dups_first # delete duplicates first when HISTFILE size exceeds HISTSIZE
setopt hist_ignore_all_dups   # ignore duplicated commands history list
setopt hist_ignore_space      # ignore commands that start with space


#  as"completion" https://github.com/docker/cli/blob/master/contrib/completion/zsh/_docker \

#   as"completion" has"kubectl" id-as"kubectl--completion" \
#   atpull'%atclone' atclone"kubectl completion zsh > _kubectl; zinit creinstall -q kubectl--completion" \
#   run-atpull nocompile zdharma-continuum/null \

#   as"completion" has"k3d" id-as"k3d--completion" \
#   atpull'%atclone' atclone"k3d completion zsh > _k3d; zinit creinstall -q k3d--completion" \
#   run-atpull nocompile zdharma-continuum/null \

# completion

zinit wait lucid for \
    atload"zicompinit; zicdreplay" \
    blockf \
    lucid \
    wait \
  zsh-users/zsh-completions \
  as"completion" has"kubectl" id-as"kubectl--completion" \
  atpull'%atclone' atclone"kubectl completion zsh > _kubectl; zinit creinstall -q kubectl--completion" \
  run-atpull nocompile zdharma-continuum/null \
  as"completion" has"k3s" id-as"k3s--completion" \
  atpull'%atclone' atclone"k3s completion zsh > _k3s; zinit creinstall -q k3s--completion" \
  run-atpull nocompile zdharma-continuum/null \
  as"completion" has"flux" id-as"flux--completion" \
  atpull'%atclone' atclone"flux completion zsh > _flux; zinit creinstall -q flux--completion" \
  run-atpull nocompile zdharma-continuum/null 

# Load starship theme
export STARSHIP_CONFIG="$HOME/.zsh/starship.toml"
zinit ice from"gh-r" as"command" atload'precmd_functions+=(precmd_title); eval "$(starship init zsh)"'
zinit light starship/starship

# plugins
ZSH_CACHE_DIR=~/.cache

zinit wait lucid for \
    atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
    blockf \
    zsh-users/zsh-completions \
    atload"!_zsh_autosuggest_start" \
    zsh-users/zsh-autosuggestions

zinit wait lucid light-mode for \
    OMZP::jump \
    OMZP::sudo \
    zdharma-continuum/fast-syntax-highlighting \
    atload"!_zsh_autosuggest_start" \
    atinit"
        zstyle ':completion:*' completer _expand _complete _ignored _approximate
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
        zstyle ':completion:*' menu select=2
        zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'
        zstyle ':completion:*:descriptions' format '-- %d --'
        zstyle ':completion:*:processes' command 'ps -au$USER'
        zstyle ':completion:complete:*:options' sort false
        zstyle ':completion:*:*:*:*:processes' command 'ps -u $USER -o pid,user,comm,cmd -w -w'
        zstyle ':completion:*:*:docker:*' option-stacking yes
        zstyle ':completion:*:*:docker-*:*' option-stacking yes
    " \
    zsh-users/zsh-autosuggestions \
    bindmap"^R -> ^H" atinit"
        zstyle :history-search-multi-word page-size 10
        zstyle :history-search-multi-word highlight-color fg=red,bold
        zstyle :plugin:history-search-multi-word reset-prompt-protect 1
    " \
    zdharma-continuum/history-search-multi-word \
    reset \
    atclone"dircolors -b LS_COLORS > clrs.zsh" atpull'%atclone' pick"clrs.zsh" nocompile'!' \
    atload'zstyle ":completion:*" list-colors “${(s.:.)LS_COLORS}”' \
    trapd00r/LS_COLORS

# programs

# 'n' program need load immediately
 
zinit light-mode for \
    as'command' atinit'export N_PREFIX="$HOME/.n"; export N_USE_XZ=true; export N_NODE_MIRROR=https://npmmirror.com/mirrors/node; [[ :$PATH: == *":$N_PREFIX/bin:"* ]] || PATH+=":$N_PREFIX/bin"' pick"bin/n" \
    tj/n


[ -z "$ZPROF" ] || zprof
