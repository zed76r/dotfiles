function claude() {
    local proxy_url="http://${PROXY_HOST:-localhost}:${PROXY_PORT:-1080}"
    HTTP_PROXY="$proxy_url" \
    HTTPS_PROXY="$proxy_url" \
    NO_PROXY="${NO_PROXY:-localhost,127.*,172.*,10.*}" \
    command claude --allow-dangerously-skip-permissions "$@"
}

function codex() {
    local effort escaped_effort fast_mode=0
    local proxy_url="http://${PROXY_HOST:-localhost}:${PROXY_PORT:-1080}"
    local -a codex_args effort_args fast_args

    # `-e high` is shorthand for
    # `-c 'model_reasoning_effort="high"'`.  Keep explicit `-c` arguments
    # later in the command line so callers can still override this shortcut.
    while (( $# > 0 )); do
        case "$1" in
            -e|--effort)
                if (( $# < 2 )) || [[ -z "$2" ]]; then
                    print -u2 -- "codex: $1 requires an effort value"
                    return 2
                fi
                effort="$2"
                shift 2
                ;;
            --effort=*)
                effort="${1#--effort=}"
                if [[ -z "$effort" ]]; then
                    print -u2 -- "codex: --effort requires an effort value"
                    return 2
                fi
                shift
                ;;
            --fast)
                fast_mode=1
                shift
                ;;
            --)
                codex_args+=("$@")
                break
                ;;
            *)
                codex_args+=("$1")
                shift
                ;;
        esac
    done

    if [[ -n "$effort" ]]; then
        # Preserve TOML string syntax even if a future effort value contains
        # a backslash or quote.
        escaped_effort="${effort//\\\\/\\\\\\\\}"
        escaped_effort="${escaped_effort//\"/\\\"}"
        effort_args=(-c "model_reasoning_effort=\"$escaped_effort\"")
    fi
    if (( fast_mode )); then
        # Enable Fast mode for this invocation without changing config.toml.
        fast_args=(-c 'service_tier="fast"' -c 'features.fast_mode=true')
    fi
    HTTP_PROXY="$proxy_url" \
    HTTPS_PROXY="$proxy_url" \
    NO_PROXY="${NO_PROXY:-localhost,127.*,172.*,10.*}" \
    ZDOTDIR="$HOME/.zsh/codex-zdotdir" \
    CODEX_GUARDRAILS="1" \
    command codex "${effort_args[@]}" "${fast_args[@]}" "${codex_args[@]}"
}

# Extend Codex CLI completion for the local codex() wrapper's options.
_codex_completion_wrapper_options=(-e --effort --fast)
_codex_completion_wrapper_descriptions=(
    'Set model reasoning effort'
    'Set model reasoning effort'
    'Enable Fast mode for this invocation'
)
_codex_completion_effort_values=(low medium high xhigh ultra max)
_codex_completion_effort_descriptions=(
    'Low reasoning effort'
    'Medium reasoning effort'
    'High reasoning effort'
    'Extra-high reasoning effort'
    'Ultra reasoning effort'
    'Maximum reasoning effort'
)
_codex_with_effort() {
    local -a original_words filtered_words
    local -i original_current i filtered_current=0
    local effort_prefix ret

    original_words=("${words[@]}")
    original_current=$CURRENT

    if [[ ${words[CURRENT]} == (-e|--effort|--fast) ]]; then
        compadd -d _codex_completion_wrapper_descriptions -- \
            "${_codex_completion_wrapper_options[@]}"
        return 0
    fi
    if (( CURRENT > 1 )) && [[ ${words[CURRENT-1]} == (-e|--effort) ]]; then
        compadd -d _codex_completion_effort_descriptions -- \
            "${_codex_completion_effort_values[@]}"
        return 0
    fi
    if [[ ${words[CURRENT]} == --effort=* ]]; then
        effort_prefix="${words[CURRENT]%%=*}="
        compadd -P "$effort_prefix" -d _codex_completion_effort_descriptions -- \
            "${_codex_completion_effort_values[@]}"
        return 0
    fi

    filtered_words=()
    for (( i = 1; i <= ${#original_words}; i++ )); do
        case ${original_words[i]} in
            -e|--effort)
                (( i++ ))
                ;;
            --effort=*)
                ;;
            --fast)
                ;;
            *)
                filtered_words+=("${original_words[i]}")
                if (( i == original_current )); then
                    filtered_current=${#filtered_words}
                elif (( i < original_current )); then
                    (( filtered_current++ ))
                fi
                ;;
        esac
    done
    (( filtered_current == 0 )) && filtered_current=${#filtered_words}

    words=("${filtered_words[@]}")
    CURRENT=$filtered_current
    _codex "$@"
    ret=$?
    if (( original_current == 2 )) || [[ ${original_words[original_current]} == -* ]]; then
        compadd -d _codex_completion_wrapper_descriptions -- \
            "${_codex_completion_wrapper_options[@]}"
    fi
    words=("${original_words[@]}")
    CURRENT=$original_current
    return $ret
}
