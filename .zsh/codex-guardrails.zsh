#!/usr/bin/env zsh

# Load guardrails only inside Codex-managed shell sessions.
if [[ -z "${CODEX_CI:-}" && -z "${CODEX_THREAD_ID:-}" && -z "${CODEX_GUARDRAILS:-}" ]]; then
    return 0
fi

function __codex_has_arg() {
    local needle="$1"
    shift
    local arg
    for arg in "$@"; do
        [[ "$arg" == "$needle" ]] && return 0
    done
    return 1
}

function __codex_block_npm() {
    print -u2 -- "npm/npx is not allowed here. Use pnpm/pnpx instead: npm install -> pnpm install, npm install <pkg> -> pnpm add <pkg>, npm run <script> -> pnpm <script>, npx <cmd> -> pnpm dlx <cmd>"
    return 2
}

function __codex_block_pip_break_system() {
    print -u2 -- "--break-system-packages is not allowed here. Use uv instead: pip install <pkg> -> uv pip install <pkg>, pip install -r requirements.txt -> uv pip install -r requirements.txt"
    return 2
}

function npm() {
    __codex_block_npm
}

function npx() {
    __codex_block_npm
}

function pip() {
    if __codex_has_arg "--break-system-packages" "$@"; then
        __codex_block_pip_break_system
        return $?
    fi
    command pip "$@"
}

function pip3() {
    if __codex_has_arg "--break-system-packages" "$@"; then
        __codex_block_pip_break_system
        return $?
    fi
    command pip3 "$@"
}

function python() {
    if [[ "${1:-}" == "-m" && "${2:-}" == "pip" ]] && __codex_has_arg "--break-system-packages" "$@"; then
        __codex_block_pip_break_system
        return $?
    fi
    command python "$@"
}

function python3() {
    if [[ "${1:-}" == "-m" && "${2:-}" == "pip" ]] && __codex_has_arg "--break-system-packages" "$@"; then
        __codex_block_pip_break_system
        return $?
    fi
    command python3 "$@"
}
