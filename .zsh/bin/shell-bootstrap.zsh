#!/usr/bin/env zsh
set -euo pipefail

typeset -gr ZSH_CONFIG_DIR=${0:A:h:h}
typeset -gr LOCK_FILE="$ZSH_CONFIG_DIR/versions.lock"
typeset -gr BIN_DIR="$HOME/.local/bin"
typeset -gr ZIM_CONFIG_FILE="$ZSH_CONFIG_DIR/zimrc"
typeset -gr ZIM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zim"

[[ -r "$LOCK_FILE" ]] || { print -u2 -- "missing lock file: $LOCK_FILE"; exit 1; }
source "$LOCK_FILE"

typeset task_tmp_dir
task_tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/shell-bootstrap.XXXXXXXX")
cleanup() {
  [[ -n ${task_tmp_dir:-} && -d "$task_tmp_dir" &&
     "${task_tmp_dir:h}" == "${TMPDIR:-/tmp}" &&
     "${task_tmp_dir:t}" == shell-bootstrap.* ]] && command rm -rf -- "$task_tmp_dir"
}
trap cleanup EXIT INT TERM

mkdir -p "$BIN_DIR" "$ZIM_HOME"

download() {
  local url=$1 output=$2
  if (( $+commands[curl] )); then
    command curl -fsSL --retry 3 --connect-timeout 15 -o "$output" "$url"
  elif (( $+commands[wget] )); then
    command wget -O "$output" "$url"
  else
    print -u2 -- 'shell-bootstrap: curl or wget is required'
    return 1
  fi
}

sha256() {
  if (( $+commands[sha256sum] )); then
    command sha256sum "$1" | awk '{print $1}'
  else
    command shasum -a 256 "$1" | awk '{print $1}'
  fi
}

verify_sha256() {
  local file=$1 expected=$2 actual
  actual=$(sha256 "$file")
  [[ "$actual" == "$expected" ]] || {
    print -u2 -- "shell-bootstrap: checksum mismatch for ${file:t}"
    return 1
  }
}

platform_assets() {
  local os arch
  os=$(uname -s)
  arch=$(uname -m)
  case "$os:$arch" in
    Darwin:arm64)
      STARSHIP_ASSET=starship-aarch64-apple-darwin.tar.gz
      MISE_ASSET="mise-v${MISE_VERSION}-macos-arm64"
      ;;
    Darwin:x86_64)
      STARSHIP_ASSET=starship-x86_64-apple-darwin.tar.gz
      MISE_ASSET="mise-v${MISE_VERSION}-macos-x64"
      ;;
    Linux:aarch64|Linux:arm64)
      STARSHIP_ASSET=starship-aarch64-unknown-linux-musl.tar.gz
      MISE_ASSET="mise-v${MISE_VERSION}-linux-arm64"
      ;;
    Linux:x86_64|Linux:amd64)
      STARSHIP_ASSET=starship-x86_64-unknown-linux-gnu.tar.gz
      MISE_ASSET="mise-v${MISE_VERSION}-linux-x64"
      ;;
    *)
      print -u2 -- "shell-bootstrap: unsupported platform $os/$arch"
      return 1
      ;;
  esac
}

install_zimfw() {
  local target="$ZIM_HOME/zimfw.zsh" candidate="$task_tmp_dir/zimfw.zsh"
  if [[ -s "$target" ]] && verify_sha256 "$target" "$ZIMFW_SHA256" 2>/dev/null; then
    return 0
  fi
  download "https://github.com/zimfw/zimfw/releases/download/v${ZIMFW_VERSION}/zimfw.zsh" "$candidate"
  verify_sha256 "$candidate" "$ZIMFW_SHA256"
  command install -m 0644 "$candidate" "$target.new"
  command mv -f "$target.new" "$target"
}

install_starship() {
  local current= archive checksum expected extracted
  if [[ -x "$BIN_DIR/starship" ]]; then
    current=$("$BIN_DIR/starship" --version 2>/dev/null | awk 'NR == 1 {print $2}')
  fi
  [[ "$current" == "$STARSHIP_VERSION" ]] && return 0

  archive="$task_tmp_dir/$STARSHIP_ASSET"
  checksum="$archive.sha256"
  download "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/${STARSHIP_ASSET}" "$archive"
  download "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/${STARSHIP_ASSET}.sha256" "$checksum"
  expected=$(awk 'NR == 1 {print $1}' "$checksum")
  [[ -n "$expected" ]] || { print -u2 -- 'shell-bootstrap: invalid Starship checksum'; return 1; }
  verify_sha256 "$archive" "$expected"
  command tar -xzf "$archive" -C "$task_tmp_dir"
  extracted="$task_tmp_dir/starship"
  [[ -x "$extracted" ]] || { print -u2 -- 'shell-bootstrap: Starship binary missing from archive'; return 1; }
  command install -m 0755 "$extracted" "$BIN_DIR/starship.new"
  command mv -f "$BIN_DIR/starship.new" "$BIN_DIR/starship"
}

install_mise() {
  local current= binary sums expected
  if [[ -x "$BIN_DIR/mise" ]]; then
    current=$("$BIN_DIR/mise" --version 2>/dev/null | awk 'NR == 1 {print $1}')
  fi
  [[ "$current" == "$MISE_VERSION" ]] && return 0

  binary="$task_tmp_dir/$MISE_ASSET"
  sums="$task_tmp_dir/SHASUMS256.txt"
  download "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/${MISE_ASSET}" "$binary"
  download "https://github.com/jdx/mise/releases/download/v${MISE_VERSION}/SHASUMS256.txt" "$sums"
  expected=$(awk -v name="$MISE_ASSET" '$2 == name || $2 == "./" name || $2 == "*" name {print $1; exit}' "$sums")
  [[ -n "$expected" ]] || { print -u2 -- 'shell-bootstrap: mise checksum not found'; return 1; }
  verify_sha256 "$binary" "$expected"
  command chmod 0755 "$binary"
  "$binary" --version >/dev/null
  command install -m 0755 "$binary" "$BIN_DIR/mise.new"
  command mv -f "$BIN_DIR/mise.new" "$BIN_DIR/mise"
}

module_path() {
  local name=$1
  if [[ -d "$ZIM_HOME/modules/$name/.git" ]]; then
    print -r -- "$ZIM_HOME/modules/$name"
  else
    print -r -- "$ZIM_HOME/$name"
  fi
}

lock_module() {
  local name=$1 revision=$2 directory
  directory=$(module_path "$name")
  [[ -d "$directory/.git" ]] || {
    print -u2 -- "shell-bootstrap: module not installed: $name"
    return 1
  }
  if ! command git -C "$directory" cat-file -e "${revision}^{commit}" 2>/dev/null; then
    command git -C "$directory" fetch --depth 1 origin "$revision"
  fi
  command git -C "$directory" checkout --quiet --detach "$revision"
}

install_modules() {
  source "$ZIM_HOME/zimfw.zsh" install
  lock_module zsh-completions "$ZSH_COMPLETIONS_REV"
  lock_module ohmyzsh "$OHMYZSH_REV"
  lock_module history-search-multi-word "$HISTORY_SEARCH_MULTI_WORD_REV"
  lock_module zsh-autosuggestions "$ZSH_AUTOSUGGESTIONS_REV"
  lock_module fast-syntax-highlighting "$FAST_SYNTAX_HIGHLIGHTING_REV"
  source "$ZIM_HOME/zimfw.zsh" build
  # A synced zimrc can have a newer timestamp even when init.zsh content is
  # already correct. Mark the successful locked build as converged.
  command touch "$ZIM_HOME/init.zsh"
}

platform_assets
install_zimfw
install_starship
install_mise
hash -r
install_modules
zsh "$ZSH_CONFIG_DIR/bin/refresh-completions.zsh"

print -- "shell-bootstrap: ready (zimfw $ZIMFW_VERSION, starship $STARSHIP_VERSION, mise $MISE_VERSION)"
