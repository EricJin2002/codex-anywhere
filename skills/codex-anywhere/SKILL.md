---
name: codex-anywhere
description: Turn a Linux or Ubuntu server into a phone-accessible Codex host without a Windows or macOS relay, then share its Codex app-server and conversations across Codex CLI, ChatGPT Remote/mobile, and VS Code. Use when a user wants to control server-side Codex from a phone anywhere, start Remote and obtain official pairing instructions or a pairing code, synchronize one thread across terminal/mobile/editor, or diagnose proxy timeouts, daemon errors, active-writer conflicts, flickering, Broken pipe, Node compatibility, and app-server version mismatches.
---

# Codex Anywhere

Make the Linux server the Codex host: connect it directly to ChatGPT Remote/mobile, obtain pairing instructions from the official Codex CLI, and configure one managed app-server as the shared owner for CLI, phone, and VS Code. No personal Windows or macOS relay should be required after pairing. Treat the Unix-socket bridge as an experimental compatibility layer and verify it after every Codex upgrade.

## Safety rules

- Begin with read-only diagnostics. Do not change configuration until the failure mode is identified.
- Never run `pkill codex`, delete `~/.codex/sessions`, or delete the thread store.
- Do not stop or restart a healthy daemon while it has an active turn unless the user explicitly accepts the interruption.
- Never print proxy credentials, auth tokens, or full environment dumps.
- A pairing code may be shown only to the requesting user in the active session. Never store it in files, logs, commits, or summaries.
- Never fabricate pairing codes or claim pairing succeeded without command evidence.
- Keep the Unix control socket user-private. Never expose an unauthenticated non-loopback WebSocket listener.
- Preserve existing user settings and unrelated `config.toml` keys.

## Workflow

1. Read [references/runbook.md](references/runbook.md) completely for setup, phone pairing, or architecture work.
2. For a reported error, also read [references/troubleshooting.md](references/troubleshooting.md).
3. Run the read-only diagnostic script:

   ```bash
   bash scripts/diagnose.sh
   ```

4. Classify the goal or failure before acting:
   - new phone-to-server Remote setup and pairing;
   - network/proxy inheritance;
   - unmanaged or missing daemon;
   - two app-servers writing one thread;
   - JSONL versus WebSocket transport mismatch;
   - Node runtime incompatibility;
   - Codex app-server schema/version incompatibility.
5. Explain the evidence and planned mutation to the user.
6. For phone access, confirm the daemon launch environment has working network/proxy access, then run:

   ```bash
   codex remote-control start
   codex remote-control pair
   ```

   Relay the official CLI's current pairing instructions/code to the user. Do not invent, persist, or reuse a code. If pairing times out, inspect daemon state before retrying once.
7. Install the portable bridge and VS Code wrapper when shared-daemon routing is appropriate:

   ```bash
   bash scripts/install.sh --dry-run
   bash scripts/install.sh
   ```

8. Tell the user to set the VS Code User setting printed by the installer and run `Developer: Reload Window`.
9. Verify daemon status, phone connectivity, socket permissions, bridge syntax with the oldest relevant Node runtime, and the earliest VS Code fatal log.
10. Test the same thread from CLI, mobile Remote, and VS Code. Success means messages synchronize, VS Code does not flicker, and no `already has an active writer` error appears.

## Script routing

- Use `scripts/diagnose.sh` for read-only environment and process inspection.
- Use `scripts/install.sh` to install the generic wrapper and bridge without changing VS Code settings or starting/stopping the daemon.
- Use `scripts/self-test.sh` after modifying project scripts.
- Use `scripts/codex-vscode-shared` as the portable VS Code executable wrapper.
- Use `scripts/codex-stdio-ws-bridge.mjs` for stdio JSONL ↔ Unix-socket WebSocket framing.

## Required handoff

Report:

- the first causal error, not downstream `stdin is destroyed` messages;
- Codex CLI, daemon, VS Code-bundled Codex, and Node versions;
- whether proxy variables are present without revealing values;
- daemon/socket state and whether the official pairing flow was produced;
- files changed and exact rollback steps;
- that app-server/WebSocket behavior is experimental and version-sensitive.
