# Troubleshooting matrix

## Contents

1. MCP startup timeout
2. Remote-control errors
3. Active writer conflict and flicker
4. Broken pipe
5. Node syntax errors
6. Protocol/version errors
7. Downstream noise

## 1. MCP startup timeout

### Symptom

```text
MCP client for codex_apps timed out after 30 seconds
MCP startup incomplete
```

### Likely cause

The background app-server or MCP child did not inherit required proxy variables. Increasing `startup_timeout_sec` does not fix unreachable networking.

### Check

- Proxy variables are set in the environment that starts the daemon.
- Non-interactive shell startup does not return before proxy setup.
- Local proxy is listening.
- `network_proxy = true` remains enabled when required.

## 2. Remote-control errors

### Pairing requires Remote to be enabled

Run `codex remote-control start` first.

### App-server is not managed by the daemon

An unrelated app-server already exists. Inspect full process command lines and identify ownership before stopping anything.

### Pairing request times out

Initial enrollment may take longer than the pairing call. If the daemon becomes connected, retry pairing once.

## 3. Active writer conflict and flicker

### Symptom

```text
thread-store conflict: thread ... already has an active writer
Failed to resume conversation
```

### Cause

Two independent app-server processes are attempting to load the same persisted thread as writer. Mobile and CLI may coordinate through one managed daemon, while VS Code starts another.

### Fix

Route VS Code to the existing daemon through the installed stdio/WebSocket bridge. Do not delete thread data or increase retry intervals.

## 4. Broken pipe

### Symptom

```text
failed to relay data between stdio and socket
failed to copy data from stdin to socket
Broken pipe (os error 32)
```

### Cause

`codex app-server proxy` copied VS Code JSONL bytes directly to a socket that expects an HTTP WebSocket Upgrade followed by framed messages.

### Fix

Use `codex-stdio-ws-bridge.mjs`, not raw `app-server proxy`.

## 5. Node syntax errors

### Symptom

```text
SyntaxError: Unexpected token '?'
```

### Cause

The VS Code extension host resolved an older system Node than the interactive shell. A test performed only with NVM's current Node missed the incompatibility.

### Fix

Run `--check` with the oldest Node that VS Code can resolve. The bundled bridge targets Node 12+ and avoids optional chaining and nullish coalescing.

## 6. Protocol/version errors

Warnings about unknown feature keys may be harmless. Errors about unknown methods, invalid params, or missing response fields can indicate a real mismatch between the VS Code frontend and shared daemon.

Record both Codex versions and diff generated app-server schemas. Do not assume an alpha VS Code client is compatible with an older stable daemon.

## 7. Downstream noise

Messages such as:

```text
Attempted to send app-server message but stdin is destroyed
Codex process is not available
```

usually occur after the bridge or app-server has already exited. Scroll upward and diagnose the first fatal error.
