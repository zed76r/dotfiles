#!/usr/bin/env zsh
set -euo pipefail

typeset -gr ZSH_CONFIG_DIR=${0:A:h:h}
typeset -gr BIN_DIR="$HOME/.local/bin"
typeset -gr ZIM_CONFIG_FILE="$ZSH_CONFIG_DIR/zimrc"
typeset -gr ZIM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zim"
typeset -gi UPDATE_REQUESTED=0

case ${1:-} in
  '') ;;
  --update) UPDATE_REQUESTED=1 ;;
  -h|--help)
    print -- "Usage: ${0:t} [--update]"
    print -- 'Install missing shell tools; --update also upgrades them and Zimfw modules.'
    exit 0
    ;;
  *)
    print -u2 -- "${0:t}: unknown option: $1"
    exit 2
    ;;
esac

typeset task_tmp_dir
task_tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/shell-bootstrap.XXXXXXXX")
cleanup() {
  [[ -n ${task_tmp_dir:-} && -d "$task_tmp_dir" &&
     "${task_tmp_dir:h}" == "${TMPDIR:-/tmp}" &&
     "${task_tmp_dir:t}" == shell-bootstrap.* ]] && command rm -rf -- "$task_tmp_dir"
}
trap cleanup EXIT INT TERM

mkdir -p "$BIN_DIR" "$ZIM_HOME"
[[ ":$PATH:" == *":$BIN_DIR:"* ]] || path=("$BIN_DIR" $path)

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

latest_release_tag() {
  local repo=$1 payload tag
  if (( $+commands[curl] )); then
    payload=$(command curl -fsSL --retry 3 --connect-timeout 15 \
      -H 'Accept: application/vnd.github+json' \
      -H 'User-Agent: dotfiles-shell-update' \
      "https://api.github.com/repos/${repo}/releases/latest")
  elif (( $+commands[wget] )); then
    payload=$(command wget -qO- --header='Accept: application/vnd.github+json' \
      --header='User-Agent: dotfiles-shell-update' \
      "https://api.github.com/repos/${repo}/releases/latest")
  else
    print -u2 -- 'shell-bootstrap: curl or wget is required to resolve latest releases'
    return 1
  fi
  tag=$(print -r -- "$payload" | awk -F'"' '/"tag_name"[[:space:]]*:/ {print $4; exit}')
  [[ -n "$tag" ]] || {
    print -u2 -- "shell-bootstrap: latest release tag not found for $repo"
    return 1
  }
  print -r -- "$tag"
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
      MISE_PLATFORM=macos-arm64
      ;;
    Darwin:x86_64)
      STARSHIP_ASSET=starship-x86_64-apple-darwin.tar.gz
      MISE_PLATFORM=macos-x64
      ;;
    Linux:aarch64|Linux:arm64)
      STARSHIP_ASSET=starship-aarch64-unknown-linux-musl.tar.gz
      MISE_PLATFORM=linux-arm64
      ;;
    Linux:x86_64|Linux:amd64)
      STARSHIP_ASSET=starship-x86_64-unknown-linux-gnu.tar.gz
      MISE_PLATFORM=linux-x64
      ;;
    *)
      print -u2 -- "shell-bootstrap: unsupported platform $os/$arch"
      return 1
      ;;
  esac
}

install_zimfw() {
  local target="$ZIM_HOME/zimfw.zsh" candidate="$task_tmp_dir/zimfw.zsh"
  [[ -s "$target" ]] && command zsh -n "$target" 2>/dev/null && return 0
  download 'https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh' "$candidate"
  command zsh -n "$candidate"
  command install -m 0644 "$candidate" "$target.new"
  command mv -f "$target.new" "$target"
}

install_starship_latest() {
  local latest current archive checksum expected extracted
  latest=$(latest_release_tag starship/starship)
  latest=${latest#v}
  if [[ -x "$BIN_DIR/starship" ]]; then
    current=$("$BIN_DIR/starship" --version 2>/dev/null | awk 'NR == 1 {print $2}')
    [[ "$current" == "$latest" ]] && return 0
  fi

  archive="$task_tmp_dir/$STARSHIP_ASSET"
  checksum="$archive.sha256"
  download "https://github.com/starship/starship/releases/download/v${latest}/${STARSHIP_ASSET}" "$archive"
  download "https://github.com/starship/starship/releases/download/v${latest}/${STARSHIP_ASSET}.sha256" "$checksum"
  expected=$(awk 'NR == 1 {print $1}' "$checksum")
  [[ -n "$expected" ]] || { print -u2 -- 'shell-bootstrap: invalid Starship checksum'; return 1; }
  verify_sha256 "$archive" "$expected"
  command tar -xzf "$archive" -C "$task_tmp_dir"
  extracted="$task_tmp_dir/starship"
  [[ -x "$extracted" ]] || { print -u2 -- 'shell-bootstrap: Starship binary missing from archive'; return 1; }
  command install -m 0755 "$extracted" "$BIN_DIR/starship.new"
  command mv -f "$BIN_DIR/starship.new" "$BIN_DIR/starship"
}

install_mise_latest() {
  local latest current binary sums expected
  latest=$(latest_release_tag jdx/mise)
  latest=${latest#v}
  if [[ -x "$BIN_DIR/mise" ]]; then
    current=$("$BIN_DIR/mise" --version 2>/dev/null | awk 'NR == 1 {print $1}')
    [[ "$current" == "$latest" ]] && return 0
  fi

  binary="$task_tmp_dir/mise-v${latest}-${MISE_PLATFORM}"
  sums="$task_tmp_dir/SHASUMS256.txt"
  download "https://github.com/jdx/mise/releases/download/v${latest}/${binary:t}" "$binary"
  download "https://github.com/jdx/mise/releases/download/v${latest}/SHASUMS256.txt" "$sums"
  expected=$(awk -v name="${binary:t}" '$2 == name || $2 == "./" name || $2 == "*" name {print $1; exit}' "$sums")
  [[ -n "$expected" ]] || { print -u2 -- 'shell-bootstrap: mise checksum not found'; return 1; }
  verify_sha256 "$binary" "$expected"
  command chmod 0755 "$binary"
  "$binary" --version >/dev/null
  command install -m 0755 "$binary" "$BIN_DIR/mise.new"
  command mv -f "$BIN_DIR/mise.new" "$BIN_DIR/mise"
}

install_starship() {
  [[ -x "$BIN_DIR/starship" ]] || install_starship_latest
}

install_mise() {
  [[ -x "$BIN_DIR/mise" ]] || install_mise_latest
}

install_modules() {
  source "$ZIM_HOME/zimfw.zsh" install
}

update_zimfw_and_modules() {
  local target="$ZIM_HOME/zimfw.zsh" candidate="$task_tmp_dir/zimfw.zsh.update"
  download 'https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh' "$candidate"
  command zsh -n "$candidate"
  command install -m 0644 "$candidate" "$target.new"
  command mv -f "$target.new" "$target"
  source "$ZIM_HOME/zimfw.zsh" update -q
}

platform_assets
install_zimfw
install_modules
install_starship
install_mise
if (( UPDATE_REQUESTED )); then
  update_zimfw_and_modules
  install_starship_latest
  install_mise_latest
fi
hash -r
zsh "$ZSH_CONFIG_DIR/bin/refresh-completions.zsh"

if (( UPDATE_REQUESTED )); then
  print -- 'shell-bootstrap: latest shell tools and Zimfw modules are ready'
else
  print -- 'shell-bootstrap: shell tools and Zimfw modules are ready'
fi
