#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
syncwin="$repo_root/tools/syncwin"
test_root=$(mktemp -d "${TMPDIR:-/tmp}/sync-filter-smoke.XXXXXXXX")
cleanup() {
  [[ -n ${test_root:-} && -d "$test_root" && "${test_root##*/}" == sync-filter-smoke.* ]] &&
    rm -rf -- "$test_root"
}
trap cleanup EXIT INT TERM

base_filter="$test_root/base.filter"
upload_filter="$test_root/upload.filter"
files_list="$test_root/files.list"
upload_files_list="$test_root/upload-files.list"

awk '/cat >"\$filter_list" <<EOF/ {capture=1; next} capture && /^EOF$/ {exit} capture' \
  "$syncwin" > "$base_filter"
awk '/cat >"\$filter_upload_list" <<EOF/ {capture=1; next} capture && /^EOF$/ {exit} capture' \
  "$syncwin" > "$upload_filter"
command cat "$base_filter" >> "$upload_filter"

printf '%s\n' '.zsh/' '.zshrc' '.zshenv' '.zprofile' '.vimrc' > "$files_list"
grep -Ev '^(\.zsh/|\.zshenv|\.zshrc|\.zprofile)$' "$files_list" > "$upload_files_list"
mkdir -p "$test_root/source/.zsh" "$test_root/destination"
printf 'shared\n' > "$test_root/source/.zsh/zimrc"
printf 'secret\n' > "$test_root/source/.zsh/gitlab-token"
printf 'generated\n' > "$test_root/source/.zsh/completions-placeholder"
printf 'shell\n' > "$test_root/source/.zshrc"
printf 'env\n' > "$test_root/source/.zshenv"
printf 'profile\n' > "$test_root/source/.zprofile"
printf 'vim\n' > "$test_root/source/.vimrc"

upload_plan=$(rsync -an --out-format='%n' --files-from="$upload_files_list" \
  --filter="merge $upload_filter" "$test_root/source/" "$test_root/destination/")
[[ "$upload_plan" == *'.vimrc'* ]] || { echo 'upload filter dropped WSL-owned file' >&2; exit 1; }
[[ "$upload_plan" != *'.zsh'* ]] || { echo 'upload filter exposed Mac-owned shell files' >&2; exit 1; }

mkdir -p "$test_root/source/.zsh/completions" "$test_root/source/.zsh/codex-zdotdir"
printf 'generated\n' > "$test_root/source/.zsh/completions/_codex"
printf 'history\n' > "$test_root/source/.zsh/codex-zdotdir/.zsh_history"
download_plan=$(rsync -an --out-format='%n' --files-from="$files_list" \
  --filter="merge $base_filter" "$test_root/source/" "$test_root/destination/")
[[ "$download_plan" == *'.zsh/zimrc'* ]] || { echo 'download filter dropped shared shell declaration' >&2; exit 1; }
[[ "$download_plan" != *'gitlab-token'* ]] || { echo 'download filter included token path' >&2; exit 1; }
[[ "$download_plan" != *'_codex'* ]] || { echo 'download filter included generated completion' >&2; exit 1; }
[[ "$download_plan" != *'.zsh_history'* ]] || { echo 'download filter included history' >&2; exit 1; }

echo 'sync-filter-smoke: passed'
