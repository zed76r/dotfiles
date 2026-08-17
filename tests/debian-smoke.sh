#!/usr/bin/env bash
set -euo pipefail

if [[ $(id -u) -ne 0 || ! -r /etc/debian_version || ! -d /repo/.git ]]; then
  echo 'debian-smoke: run as root in Debian with the repository mounted at /repo' >&2
  exit 2
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq ca-certificates curl git zsh util-linux >/dev/null
useradd -m -s /bin/zsh tester

runuser -u tester -- env -u ZDOTDIR zsh /repo/scripts/apply-dotfiles.zsh
runuser -u tester -- env -u ZDOTDIR zsh /home/tester/.zsh/bin/shell-bootstrap.zsh
runuser -u tester -- env -u ZDOTDIR TERM=xterm-256color \
  script -qec '/bin/zsh -i /repo/tests/assert-candidate.zsh' /dev/null

echo 'debian-smoke: passed'
