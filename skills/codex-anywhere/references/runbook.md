# Shared app-server runbook

## Contents

1. Goal and architecture
2. Preconditions
3. Read-only diagnosis
4. Proxy inheritance
5. Managed Remote daemon and phone pairing
6. Bridge installation
7. VS Code configuration
8. Verification
9. Upgrades
10. Rollback and safety

## 1. Goal and architecture

Use this runbook to make a Linux server directly accessible from ChatGPT Remote/mobile without keeping a personal Windows or macOS computer online as a relay. The same managed app-server should serve phone, Codex CLI, and VS Code so a conversation can continue across clients.

The target topology is:

```text
ChatGPT Remote/mobile ─────────┐
Codex CLI remote client ───────┼── managed Codex app-server daemon
VS Code → stdio/WS bridge ─────┘   Unix socket + outbound Remote connection
```

The server initiates the Remote connection, so it does not require a publicly exposed inbound WebSocket port. One app-server owns each loaded thread, while multiple clients can attach to it.

OpenAI documents that app-server powers rich clients such as the VS Code extension. Its default stdio transport uses JSONL, while its Unix socket transport uses WebSocket over a standard HTTP Upgrade. The bridge converts between those transports. See <https://learn.chatgpt.com/docs/app-server>.

The current bridge defaults to WebSocket path `/rpc`. This path was observed from the official Codex CLI and is not currently documented as a stable public contract. Override it with `CODEX_ANYWHERE_WS_PATH` if a future version changes it.

## 2. Preconditions

Require:

- a Codex CLI with `remote-control` and `app-server daemon` commands;
- Node.js 12 or newer;
- the Codex VS Code extension running on the same Linux account as the daemon;
- a working network path to Codex, including any required proxy;
- a user-private app-server Unix socket.

Record versions before modifying anything:

```bash
codex --version
codex app-server daemon version
node --version
```

Locate the VS Code-bundled Codex and record its version. Extension directories change across upgrades.

## 3. Read-only diagnosis

From the skill directory, run:

```bash
bash scripts/diagnose.sh
```

Also collect the Codex VS Code Output beginning at `Spawning codex app-server`. Find the first fatal error; later `stdin is destroyed` messages are usually consequences.

Do not print a complete environment or authentication files. Proxy values and tokens may be sensitive.

## 4. Proxy inheritance

Interactive shell helpers such as `proxy_on` do not guarantee that non-interactive SSH sessions, VS Code extension hosts, daemon managers, or MCP children inherit proxy variables. Shell startup files may return early for non-interactive shells.

Set `HTTP_PROXY`, `HTTPS_PROXY`, lowercase equivalents when required, and `NO_PROXY` for localhost before starting the managed daemon. Use a small wrapper when a persistent background launch must always receive these variables. Parameterize the endpoints; never hard-code a user's proxy into the public project.

If the Codex configuration uses the network proxy feature, preserve it:

```toml
[features]
network_proxy = true
```

An MCP startup timeout is often a network-inheritance failure, not a reason to increase the timeout.

## 5. Managed Remote daemon and phone pairing

Start the daemon only after network access works:

```bash
codex remote-control start
codex app-server daemon version
```

The version result should report `running` and a socket path. Confirm the socket is owned by the current user and is not group/world accessible.

Pair the phone only after the Remote connection is ready:

```bash
codex remote-control pair
```

This command starts the official pairing flow. Present its current instructions or code directly to the requesting user, who completes the flow in ChatGPT on the phone. Never generate a substitute code, store a real code in a file, or assume an old code can be reused.

After pairing, verify from the phone that the server is visible and can open or create a Codex conversation. A personal desktop or laptop should not be required to remain online; the Linux server and its outbound network path must remain available.

First-time enrollment may finish after the pairing command's deadline. If logs show that Remote connected, retry pairing once rather than repeatedly restarting the daemon.

If startup reports that an app-server is running but is not managed by the daemon, inspect exact process command lines. Distinguish a VS Code-bundled app-server from the intended standalone managed daemon. Never kill all Codex processes broadly.

## 6. Bridge installation

From the repository root:

```bash
bash skills/codex-anywhere/scripts/install.sh --dry-run
bash skills/codex-anywhere/scripts/install.sh
```

The installer only copies:

- `codex-stdio-ws-bridge.mjs` into the user's data directory;
- `codex-vscode-shared` into the user's local bin directory.

It does not edit Codex configuration, edit VS Code settings, or control the daemon.

Environment overrides supported by the installed wrapper:

```text
CODEX_HOME
CODEX_ANYWHERE_CODEX_BIN
CODEX_ANYWHERE_NODE_BIN
CODEX_ANYWHERE_SOCKET
CODEX_ANYWHERE_BRIDGE
CODEX_ANYWHERE_WS_PATH
XDG_DATA_HOME
```

The wrapper intercepts only invocations containing the exact `app-server` argument. Version probes and other Codex commands go to the real CLI.

## 7. VS Code configuration

Add the path printed by the installer to VS Code User Settings JSON:

```json
"chatgpt.cliExecutable": "/absolute/path/to/codex-vscode-shared"
```

Use User scope for Remote SSH setups unless a narrower scope is intentional. Then run:

```text
Developer: Reload Window
```

Do not point VS Code directly at `codex app-server proxy`: that command relays raw bytes and does not convert stdio JSONL to WebSocket frames.

## 8. Verification

Verify:

```bash
codex app-server daemon version
stat "$CODEX_HOME/app-server-control/app-server-control.sock"
/path/to/oldest/relevant/node --check /path/to/codex-stdio-ws-bridge.mjs
ps aux | grep -E 'codex|app-server' | grep -v grep
```

Expected process shape:

- one managed `codex app-server --remote-control --listen unix://`;
- its daemon manager;
- a CLI client when open;
- one bridge process per connected VS Code extension host.

An extra bridge is fine. An extra independent VS Code app-server is not the target topology.

Open one thread from mobile, CLI, and VS Code. Send a harmless test message from each client and confirm updates appear on the others. VS Code must not flicker or emit active-writer errors.

## 9. Upgrades

App-server schemas are version-specific. After upgrading the standalone CLI or VS Code extension:

1. record both versions;
2. run the project self-test with the oldest Node runtime the extension may use;
3. reload VS Code and test `initialize`, `config/read`, and `thread/list`;
4. generate and diff schemas if request or response validation fails:

   ```bash
   codex app-server generate-json-schema --out /tmp/schema-standalone
   /path/to/vscode/codex app-server generate-json-schema --out /tmp/schema-vscode
   diff -ru /tmp/schema-standalone /tmp/schema-vscode
   ```

5. re-observe the official CLI's local Unix-socket handshake if `/rpc` stops working.

## 10. Rollback and safety

To roll back only VS Code routing:

1. remove `chatgpt.cliExecutable` from VS Code User Settings;
2. run `Developer: Reload Window`.

This leaves the daemon and mobile Remote untouched. The original active-writer conflict may return if VS Code opens a thread still loaded by the managed daemon.

To disable Remote entirely, use `codex remote-control stop` only after confirming that no active task depends on it.

Never delete session rollouts or the SQLite store to resolve writer ownership. Never expose a plain unauthenticated WebSocket on a non-loopback interface.
