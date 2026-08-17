#!/usr/bin/env bash
set -euo pipefail

mode=${1:---staged}
found=0

case "$mode" in
  --staged)
    scan_label=staged
    list_paths() { git diff --cached --name-only --diff-filter=ACMR -z; }
    show_path() { git show ":$1"; }
    ;;
  --tracked)
    scan_label=tracked
    list_paths() { git ls-files -z; }
    show_path() { git show "HEAD:$1"; }
    ;;
  *)
    echo "usage: $0 [--staged|--tracked]" >&2
    exit 2
    ;;
esac

is_forbidden_path() {
  case "$1" in
    .env|*/.env|*.pem|*.key|*.p12|*.pfx|*.kdbx|*gitlab-token|*github-token|\
    .zsh_history|*/.zsh_history|.zsh_sessions/*|*/.zsh_sessions/*|\
    .kube/config|*/.kube/config|.aws/credentials|*/.aws/credentials)
      return 0
      ;;
  esac
  return 1
}

# Deliberately report only rule names and paths, never matching values.
scan_content() {
  local path=$1
  local content
  content=$(show_path "$path" 2>/dev/null) || return 0

  # Skip binary blobs.
  if ! printf '%s' "$content" | LC_ALL=C grep -Iq .; then
    return 0
  fi

  if printf '%s' "$content" | LC_ALL=C grep -Eaq -- \
    '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----'; then
    echo "secret-scan: private-key material detected in $path" >&2
    found=1
  fi

  if printf '%s' "$content" | LC_ALL=C grep -Eaq \
    '(gh[pousr]_[A-Za-z0-9_]{30,}|github_pat_[A-Za-z0-9_]{30,}|glpat-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{20,}|sk-[A-Za-z0-9_-]{32,})'; then
    echo "secret-scan: known token format detected in $path" >&2
    found=1
  fi

  if printf '%s' "$content" | LC_ALL=C grep -Eaiq \
    '(api[_-]?key|access[_-]?token|auth[_-]?token|client[_-]?secret|password|passwd)[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9_+/.=-]{16,}'; then
    echo "secret-scan: credential-like assignment detected in $path" >&2
    found=1
  fi

  if printf '%s' "$content" | LC_ALL=C grep -Eaq \
    'https?://[^/@[:space:]]+:[^/@[:space:]]+@'; then
    echo "secret-scan: credential-bearing URL detected in $path" >&2
    found=1
  fi
}

while IFS= read -r -d '' path; do
  if is_forbidden_path "$path"; then
    echo "secret-scan: forbidden sensitive path staged: $path" >&2
    found=1
    continue
  fi
  scan_content "$path"
done < <(list_paths)

if command -v gitleaks >/dev/null 2>&1; then
  if gitleaks help git >/dev/null 2>&1; then
    gitleaks git --staged --redact --no-banner || found=1
  elif gitleaks help protect >/dev/null 2>&1; then
    gitleaks protect --staged --redact --no-banner || found=1
  else
    echo 'secret-scan: installed gitleaks has no supported staged-scan command' >&2
    found=1
  fi
fi

if (( found )); then
  echo 'secret-scan: commit blocked; remove the secret or explicitly unstage the file.' >&2
  exit 1
fi

echo "secret-scan: $scan_label files passed"
