#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
node_bin="${CODEX_ANYWHERE_TEST_NODE:-$(command -v node)}"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/codex-anywhere-test.XXXXXX")"

cleanup() {
    rm -rf -- "$test_root"
}
trap cleanup EXIT

"$node_bin" --check "$script_dir/codex-stdio-ws-bridge.mjs"
bash -n "$script_dir/codex-vscode-shared"
bash -n "$script_dir/install.sh"
bash -n "$script_dir/diagnose.sh"

mkdir -p "$test_root/fake" "$test_root/bin" "$test_root/data"
fake_codex="$test_root/fake/codex"
printf '%s\n' '#!/usr/bin/env bash' 'echo "codex-cli test-double"' > "$fake_codex"
chmod 0755 "$fake_codex"

CODEX_ANYWHERE_NODE_BIN="$node_bin" bash "$script_dir/install.sh" \
    --bin-dir "$test_root/bin" \
    --data-dir "$test_root/data"

output="$({
    CODEX_ANYWHERE_CODEX_BIN="$fake_codex" \
    CODEX_ANYWHERE_BRIDGE="$test_root/data/codex-stdio-ws-bridge.mjs" \
    "$test_root/bin/codex-vscode-shared" --version
} 2>&1)"

if [[ "$output" != "codex-cli test-double" ]]; then
    echo "Unexpected wrapper output: $output" >&2
    exit 1
fi

if CODEX_ANYWHERE_CODEX_BIN="$fake_codex" \
    CODEX_ANYWHERE_BRIDGE="$test_root/data/codex-stdio-ws-bridge.mjs" \
    CODEX_ANYWHERE_SOCKET="$test_root/missing.sock" \
    "$test_root/bin/codex-vscode-shared" app-server 2>/dev/null; then
    echo "Wrapper unexpectedly accepted a missing socket." >&2
    exit 1
fi

echo "codex-anywhere self-test passed with $($node_bin --version)."
