adb-connect() {
  local gateway target
  gateway=$(netstat -rn | awk '/^default.*en0/ {print $2; exit}')
  target=${ADB_DEVICE_HOST:-$gateway}
  [[ -n "$target" ]] || { print -u2 -- 'adb-connect: no target; set ADB_DEVICE_HOST'; return 1; }

  adb kill-server
  adb start-server
  adb connect "${target}:${ADB_DEVICE_PORT:-5555}"
}
