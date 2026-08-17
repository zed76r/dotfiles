#!/usr/bin/env zsh
set -euo pipefail

typeset -a required_functions=(
  jump mark unmark marks sudo-command-line history-search-multi-word
  _zsh_highlight _zsh_autosuggest_start mise precmd_title
  starship_zle-keymap-select
)
for name in "${required_functions[@]}"; do
  (( $+functions[$name] )) || { print -u2 -- "missing function: $name"; exit 1; }
done

typeset -a required_widgets=(
  history-search-multi-word sudo-command-line autosuggest-accept
  zle-keymap-select
)
for name in "${required_widgets[@]}"; do
  (( $+widgets[$name] )) || { print -u2 -- "missing widget: $name"; exit 1; }
done
[[ ${widgets[zle-keymap-select]} == *starship_zle-keymap-select* ]] || {
  print -u2 -- 'zle-keymap-select is not handled by Starship'
  exit 1
}

[[ "$(bindkey '^R')" == *history-search-multi-word* ]] || { print -u2 -- 'invalid ^R binding'; exit 1; }
[[ "$(bindkey '^G')" == *_mark_expansion* ]] || { print -u2 -- 'invalid ^G binding'; exit 1; }
[[ "$(bindkey '^[^[')" == *sudo-command-line* ]] || { print -u2 -- 'invalid Esc Esc binding'; exit 1; }

(( ${precmd_functions[(I)prompt_starship_precmd]} )) || exit 1
(( ${precmd_functions[(I)_mise_hook_precmd]} )) || exit 1
(( ${precmd_functions[(I)_zsh_autosuggest_start]} )) || exit 1
(( ${preexec_functions[(I)prompt_starship_preexec]} )) || exit 1
(( ${chpwd_functions[(I)_mise_hook_chpwd]} )) || exit 1

[[ ${_comps[mise]:-} == _mise ]] || { print -u2 -- 'mise completion not registered'; exit 1; }
[[ -s "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completions/_mise" ]] || exit 1

command starship --version
command mise --version
print -- 'candidate-smoke: functions, widgets, hooks, bindings and completion passed'
