#!/usr/bin/env zsh
set -euo pipefail

typeset -gr COMPLETION_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completions"
typeset task_tmp_dir
task_tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/zsh-completions.XXXXXXXX")
cleanup() {
  [[ -n ${task_tmp_dir:-} && -d "$task_tmp_dir" &&
     "${task_tmp_dir:h}" == "${TMPDIR:-/tmp}" &&
     "${task_tmp_dir:t}" == zsh-completions.* ]] && command rm -rf -- "$task_tmp_dir"
}
trap cleanup EXIT INT TERM
mkdir -p "$COMPLETION_DIR"

generate_completion() {
  local output_name=$1 command_name=$2
  shift 2
  (( $+commands[$command_name] )) || return 0

  local candidate="$task_tmp_dir/$output_name"
  local target="$COMPLETION_DIR/$output_name"
  local metadata="$COMPLETION_DIR/.${output_name#_}.source"
  if ! command "$command_name" "$@" >| "$candidate"; then
    print -u2 -- "completion: generation failed for $command_name; keeping old file"
    return 1
  fi
  [[ -s "$candidate" ]] && zsh -n "$candidate" || {
    print -u2 -- "completion: invalid output for $command_name; keeping old file"
    return 1
  }
  command mv -f "$candidate" "$target"
  {
    print -r -- "command=${commands[$command_name]}"
    command "$command_name" --version 2>/dev/null | head -n 1 || true
  } >| "$metadata.new"
  command mv -f "$metadata.new" "$metadata"
  print -- "completion: refreshed $output_name"
}

typeset -i failures=0
generate_completion _kubectl kubectl completion zsh || (( failures++ ))
generate_completion _k3s k3s completion zsh || (( failures++ ))
generate_completion _flux flux completion zsh || (( failures++ ))
generate_completion _helm helm completion zsh || (( failures++ ))
generate_completion _mise mise completion zsh || (( failures++ ))
generate_completion _pnpm pnpm completion zsh || (( failures++ ))
generate_completion _codex codex completion zsh || (( failures++ ))
generate_completion _openspec openspec completion generate zsh || (( failures++ ))

(( failures == 0 )) || {
  print -u2 -- "completion: $failures generator(s) failed"
  exit 1
}
