#!/usr/bin/env bash

set -u

codex_home="${CODEX_HOME:-$HOME/.codex}"
socket_path="${CODEX_ANYWHERE_SOCKET:-$codex_home/app-server-control/app-server-control.sock}"

section() {
    echo
    echo "[$1]"
}

section "System"
uname -a 2>/dev/null || true

section "Codex CLI"
if command -v codex >/dev/null 2>&1; then
    command -v codex
    codex --version 2>&1 || true
    codex app-server daemon version 2>&1 || true
else
    echo "codex: not found in PATH"
fi

section "Node.js"
if command -v node >/dev/null 2>&1; then
    command -v node
    node --version 2>&1 || true
else
    echo "node: not found in PATH"
fi
if [[ -x /usr/bin/node && "$(command -v node 2>/dev/null)" != "/usr/bin/node" ]]; then
    echo "/usr/bin/node: $(/usr/bin/node --version 2>&1)"
fi

section "Proxy variables (values redacted)"
for variable in http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY; do
    if [[ -n "${!variable-}" ]]; then
        echo "$variable=set"
    else
        echo "$variable=unset"
    fi
done

section "Codex config"
echo "CODEX_HOME=$codex_home"
if [[ -f "$codex_home/config.toml" ]]; then
    if command -v rg >/dev/null 2>&1; then
        rg -n '^\[features\]|^network_proxy\s*=' "$codex_home/config.toml" || true
    else
        grep -nE '^\[features\]|^network_proxy[[:space:]]*=' "$codex_home/config.toml" || true
    fi
else
    echo "config.toml: missing"
fi

section "Managed control socket"
echo "$socket_path"
if [[ -S "$socket_path" ]]; then
    stat -c '%A %U:%G %n' "$socket_path" 2>&1 || true
else
    echo "socket: unavailable"
fi

section "Codex processes"
ps aux 2>/dev/null | grep -E 'codex|app-server' | grep -v grep || true

section "VS Code bundled Codex versions"
found=false
for binary in "$HOME"/.vscode-server/extensions/openai.chatgpt-*/bin/linux-*/codex; do
    if [[ -x "$binary" ]]; then
        found=true
        echo "$binary"
        "$binary" --version 2>&1 || true
    fi
done
if [[ "$found" == false ]]; then
    echo "No matching VS Code Codex binary found."
fi

section "Relevant logs"
for log in \
    "$codex_home/app-server-daemon/app-server.stderr.log" \
    "$codex_home/app-server-control/app-server.log" \
    "$codex_home/logs_2.sqlite"; do
    [[ -e "$log" ]] && echo "$log"
done

echo
echo "Diagnostics are read-only. Inspect the earliest fatal error in VS Code Output."
