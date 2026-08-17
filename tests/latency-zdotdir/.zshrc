source "$HOME/.zshrc"

_dotfiles_bench_mark() {
  print -u "${DOTFILES_BENCH_FD:-3}" -r -- "$1"
}

_dotfiles_bench_line_init() {
  _dotfiles_bench_mark LINE_INIT
}

_dotfiles_bench_pre_redraw() {
  _dotfiles_bench_mark "REDRAW:${#BUFFER}:${CURSOR}"
}

autoload -Uz add-zle-hook-widget
add-zle-hook-widget zle-line-init _dotfiles_bench_line_init
add-zle-hook-widget zle-line-pre-redraw _dotfiles_bench_pre_redraw
