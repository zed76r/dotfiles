export WSL_HOST_IP="127.0.0.1"
export WSL_IP="127.0.0.1"
export MIXED_PROXY_PORT=1080

alias pwsh='pwsh.exe'

function geoip() {
    wget -qO- "https://freeipapi.com/api/json/$@" | json_pp
}

function wttr() {
    curl -s "https://wttr.in/$@?n&2"
}

function my-ip() {
#    export WSL_HOST_IP=$(ip route | grep default | awk '{print $3}')
#    export WSL_IP=$(ip route | grep default -A 1 | sed -n '2p' | awk '{print $9}')
    (command -v clip.exe > /dev/null 2>&1) && (echo -n "$WSL_HOST_IP" | clip.exe)
    echo "WSL HostIP: $WSL_HOST_IP (copied)"
    echo "WSL IP: $WSL_IP"
#    curl -s "https://whatsmyip.com/api?key=e5b2c73127f8e58366ab07cde2989da42bf3231c" | prettyjson
#    local ip=$(curl -s http://myip.ipip.net)
    local ip=$(dig +short myip.opendns.com @resolver1.opendns.com.)
    echo "===========\n外网IP：$ip"
#    curl -s "https://ip.clang.cn/text" | sed -e 's/<br>/\n/g' -e 's/<[^>]*>//g'
}

function set-proxy() {
    export HTTP_PROXY=http://$WSL_HOST_IP:$MIXED_PROXY_PORT
    export HTTPS_PROXY=http://$WSL_HOST_IP:$MIXED_PROXY_PORT
    export ALL_PROXY=socks5://$WSL_HOST_IP:$MIXED_PROXY_PORT
}

function unset-proxy() {
    unset HTTP_PROXY
    unset HTTPS_PROXY
    unset ALL_PROXY
}

function zsh_fix_history() {
    mv $HOME/.zsh_history $HOME/.zsh_history_bad
    strings $HOME/.zsh_history_bad > $HOME/.zsh_history
    fc -R $HOME/.zsh_history
    rm $HOME/.zsh_history_bad
}

# https://github.com/sindresorhus/pure/blob/main/pure.zsh#L56
function prompt_set_title() {
	setopt localoptions noshwordsplit

	# Emacs terminal does not support settings the title.
	(( ${+EMACS} || ${+INSIDE_EMACS} )) && return

	case $TTY in
		/dev/ttyS[0-9]*) return;;
	esac

	# Show hostname if connected via SSH.
	local hostname=
	if [[ -n $prompt_pure_state[username] ]]; then
		# Expand in-place in case ignore-escape is used.
		hostname="${(%):-(%m) }"
	fi

	local -a opts
	case $1 in
		expand-prompt) opts=(-P);;
		ignore-escape) opts=(-r);;
	esac

	# Set title atomically in one print statement so that it works when XTRACE is enabled.
	print -n $opts $'\e]0;'${hostname}${2}$'\a'
}

function precmd_title() {
    prompt_set_title 'expand-prompt' '%~'
}

function sdkman-install() {
    set-proxy
    curl -s "https://get.sdkman.io?rcupdate=false" | bash
    unset-proxy
}


