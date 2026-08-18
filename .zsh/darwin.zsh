[[ "$OSTYPE" == darwin* ]] || return

for _mysql_bin in /opt/homebrew/opt/mysql-client*/bin(N-/) /usr/local/opt/mysql-client*/bin(N-/); do
  path=("$_mysql_bin" $path)
  break
done
unset _mysql_bin

upgrade_all() {
  local -a failures=()

  if (( $+commands[brew] )); then
    command brew update && command brew upgrade || failures+=(brew)
  fi
  zsh "$HOME/.zsh/bin/shell-update.zsh" || failures+=(shell)

  if (( ${#failures} )); then
    print -u2 -- "upgrade_all: failed: ${failures[*]}"
    return 1
  fi
  print -- 'upgrade_all: complete'
}

# Import fixed macOS proxy settings for CLI tools that honor *_PROXY.
# Keep explicit environment variables untouched; PAC/WPAD cannot be represented
# faithfully as one static proxy URL.
_darwin_import_system_proxy() {
  (( ${+HTTP_PROXY} || ${+http_proxy} || ${+HTTPS_PROXY} || ${+https_proxy} ||
      ${+ALL_PROXY} || ${+all_proxy} )) && return 0
  [[ -x /usr/sbin/scutil ]] || return 0

  local proxy_dump line value http_enable http_host http_port
  local https_enable https_host https_port socks_enable socks_host socks_port
  local pac_enable pac_discovery exceptions
  local -i in_exceptions=0 valid_port=0

  proxy_dump=$(/usr/sbin/scutil --proxy 2>/dev/null) || return 0
  [[ -n $proxy_dump ]] || return 0

  for line in ${(f)proxy_dump}; do
    case $line in
      *'HTTPEnable : '*) http_enable=${line##*HTTPEnable : } ;;
      *'HTTPProxy : '*) http_host=${line##*HTTPProxy : } ;;
      *'HTTPPort : '*) http_port=${line##*HTTPPort : } ;;
      *'HTTPSEnable : '*) https_enable=${line##*HTTPSEnable : } ;;
      *'HTTPSProxy : '*) https_host=${line##*HTTPSProxy : } ;;
      *'HTTPSPort : '*) https_port=${line##*HTTPSPort : } ;;
      *'SOCKSEnable : '*) socks_enable=${line##*SOCKSEnable : } ;;
      *'SOCKSProxy : '*) socks_host=${line##*SOCKSProxy : } ;;
      *'SOCKSPort : '*) socks_port=${line##*SOCKSPort : } ;;
      *'ProxyAutoConfigEnable : '*) pac_enable=${line##*ProxyAutoConfigEnable : } ;;
      *'ProxyAutoDiscoveryEnable : '*) pac_discovery=${line##*ProxyAutoDiscoveryEnable : } ;;
      *'ExceptionsList : <array>'*) in_exceptions=1 ;;
    esac

    if (( in_exceptions )); then
      if [[ $line == *' : '* && $line != *'ExceptionsList : '* ]]; then
        value=${line##* : }
        if [[ -n $value && $value != \<* && $value != \}* ]]; then
          [[ -n $exceptions ]] && exceptions+=','
          exceptions+=$value
        fi
      fi
      [[ $line == *\}* ]] && in_exceptions=0
    fi
  done

  # PAC/WPAD may choose different proxies per destination, so do not guess.
  [[ $pac_enable == 1 || $pac_discovery == 1 ]] && return 0

  if [[ $http_enable == 1 && -n $http_host && $http_host != *[[:space:]/]* &&
        $http_port == <-> ]]; then
    valid_port=0
    (( http_port >= 1 && http_port <= 65535 )) && valid_port=1
    if (( valid_port )); then
      [[ $http_host == *:* && $http_host != \[*\] ]] && http_host="[$http_host]"
      value="http://${http_host}:${http_port}"
      export HTTP_PROXY=$value http_proxy=$value
    fi
  fi

  if [[ $https_enable == 1 && -n $https_host && $https_host != *[[:space:]/]* &&
        $https_port == <-> ]]; then
    valid_port=0
    (( https_port >= 1 && https_port <= 65535 )) && valid_port=1
    if (( valid_port )); then
      [[ $https_host == *:* && $https_host != \[*\] ]] && https_host="[$https_host]"
      value="http://${https_host}:${https_port}"
      export HTTPS_PROXY=$value https_proxy=$value
    fi
  fi

  if [[ $socks_enable == 1 && -n $socks_host && $socks_host != *[[:space:]/]* &&
        $socks_port == <-> ]]; then
    valid_port=0
    (( socks_port >= 1 && socks_port <= 65535 )) && valid_port=1
    if (( valid_port )); then
      [[ $socks_host == *:* && $socks_host != \[*\] ]] && socks_host="[$socks_host]"
      value="socks5h://${socks_host}:${socks_port}"
      export ALL_PROXY=$value all_proxy=$value
    fi
  fi

  if [[ -n $exceptions ]] && (( ! ${+NO_PROXY} && ! ${+no_proxy} )); then
    export NO_PROXY=$exceptions no_proxy=$exceptions
  fi
}

_darwin_import_system_proxy
unfunction _darwin_import_system_proxy
