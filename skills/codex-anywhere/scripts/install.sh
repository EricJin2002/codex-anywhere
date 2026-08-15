#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
bin_dir="${HOME}/.local/bin"
data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/codex-anywhere"
force=false
dry_run=false

usage() {
    echo "Usage: install.sh [--bin-dir DIR] [--data-dir DIR] [--force] [--dry-run]"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bin-dir) bin_dir="$2"; shift 2 ;;
        --data-dir) data_dir="$2"; shift 2 ;;
        --force) force=true; shift ;;
        --dry-run) dry_run=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
done

bridge_source="$script_dir/codex-stdio-ws-bridge.mjs"
wrapper_source="$script_dir/codex-vscode-shared"
bridge_target="$data_dir/codex-stdio-ws-bridge.mjs"
wrapper_target="$bin_dir/codex-vscode-shared"

node_bin="${CODEX_ANYWHERE_NODE_BIN:-$(command -v node || true)}"
if [[ -z "$node_bin" ]]; then
    echo "Node.js is required. Set up Node.js 12+ before installing." >&2
    exit 1
fi

major="$($node_bin -p 'Number(process.versions.node.split(".")[0])')"
if [[ "$major" -lt 12 ]]; then
    echo "Node.js 12+ is required; found $($node_bin --version)." >&2
    exit 1
fi

if [[ "$force" != true && ( -e "$bridge_target" || -e "$wrapper_target" ) ]]; then
    echo "Refusing to overwrite an existing installation." >&2
    echo "Use --force after reviewing the existing files." >&2
    exit 1
fi

echo "Node.js:        $node_bin ($($node_bin --version))"
echo "Bridge target: $bridge_target"
echo "Wrapper target: $wrapper_target"

if [[ "$dry_run" == true ]]; then
    echo "Dry run only; no files changed."
    exit 0
fi

mkdir -p "$data_dir" "$bin_dir"
install -m 0644 "$bridge_source" "$bridge_target"
install -m 0755 "$wrapper_source" "$wrapper_target"

echo
echo "Installed codex-anywhere."
echo "Add this VS Code User setting, then run 'Developer: Reload Window':"
printf '  "chatgpt.cliExecutable": "%s"\n' "$wrapper_target"
echo
echo "The installer did not start, stop, or restart Codex."
