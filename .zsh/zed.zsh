alias pwsh='pwsh.exe'
alias frpcw="$HOME/.config/frp/frpc.sh"

if [[ "$OSTYPE" == darwin* ]]; then
  alias rst-launchpad='trash /private$(getconf DARWIN_USER_DIR)com.apple.dock.launchpad; killall Dock'
fi

geoip() {
  wget -qO- "https://freeipapi.com/api/json/$@" | json_pp
}

wttr() {
  curl -s "https://wttr.in/$@?n&2"
}

my-ip() {
  local internal_ip ipv4 ipv6
  if [[ "$OSTYPE" == darwin* ]]; then
    internal_ip=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || print 'N/A')
    print -rn -- "$internal_ip" | pbcopy
  else
    internal_ip=$(hostname -I | awk '{print $1}')
    (( $+commands[clip.exe] )) && print -rn -- "$internal_ip" | clip.exe
  fi
  print -- "Internal IP: $internal_ip (copied)"
  ipv4=$(curl -s 4.ipw.cn)
  ipv6=$(curl -s 6.ipw.cn)
  print -- "External IPv4: $ipv4\nExternal IPv6: $ipv6"
}

set-proxy() {
  local proxy_host=${PROXY_HOST:-localhost}
  local proxy_port=${PROXY_PORT:-1080}
  export HTTP_PROXY="http://${proxy_host}:${proxy_port}"
  export http_proxy=$HTTP_PROXY
  export HTTPS_PROXY=$HTTP_PROXY
  export https_proxy=$HTTPS_PROXY
  export ALL_PROXY="socks5://${proxy_host}:${proxy_port}"
  export all_proxy=$ALL_PROXY
  export NO_PROXY=${NO_PROXY:-'localhost,127.*,172.*,10.*'}
  export no_proxy=$NO_PROXY
}

unset-proxy() {
  unset HTTP_PROXY http_proxy HTTPS_PROXY https_proxy ALL_PROXY all_proxy NO_PROXY no_proxy
}

zsh_fix_history() {
  local bad_history="$HOME/.zsh_history_bad"
  command mv "$HOME/.zsh_history" "$bad_history"
  command strings "$bad_history" >| "$HOME/.zsh_history"
  fc -R "$HOME/.zsh_history"
  command rm "$bad_history"
}

precmd_title() {
  local hostname=
  [[ -n ${SSH_CONNECTION:-} ]] && hostname="${(%):-%m} "
  print -n $'\e]0;'${hostname}${(%):-%~}$'\a'
}

sdkman-install() {
  set-proxy
  curl -s 'https://get.sdkman.io?rcupdate=false' | bash
  unset-proxy
}

then-notify() {
  local status=$?
  (( $+commands[osascript] )) || return $status
  if (( status == 0 )); then
    osascript -e 'display notification "The command finished" with title "Success"'
  else
    osascript -e 'display notification "The command failed" with title "Failed"'
  fi
  return $status
}
