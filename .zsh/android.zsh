[[ "$OSTYPE" == darwin* ]] || return

typeset -g ANDROID_HOME=${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}
export ANDROID_HOME
export ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT:-$ANDROID_HOME}
path=(
  "$ANDROID_HOME/cmdline-tools/latest/bin"(N-/)
  "$ANDROID_HOME/platform-tools"(N-/)
  "$ANDROID_HOME/emulator"(N-/)
  $path
)
