# codex-anywhere

Turn a Linux server into a Codex host you can reach directly from your phone—without keeping a personal Windows or macOS computer online as a relay.

`codex-anywhere` helps an AI agent configure the server-side Codex Remote daemon, launch the official phone pairing flow, and connect Codex CLI, ChatGPT Remote/mobile, and the Codex VS Code extension to one shared app-server. The result is one synchronized workspace and conversation history across terminal, phone, and editor.

> [!WARNING]
> Codex app-server and WebSocket transports are experimental. This project is not an official OpenAI project, and compatibility may change between Codex releases.

## The idea

Traditional remote workflows often leave a personal computer in the middle: the server is reached through a laptop or desktop, and mobile access depends on that machine remaining online. `codex-anywhere` makes the Ubuntu/Linux server the Codex host instead:

```text
Phone / ChatGPT Remote <--> OpenAI Remote service <== outbound == Linux server
                                                           |
                             +-----------------------------+----------------+
                             |                             |                |
                         Codex CLI                    VS Code        repositories,
                                                     bridge         tools and jobs
                             +---------- shared app-server ---------------+
```

After setup, an AI using the bundled Skill can:

- diagnose proxy, daemon, socket, runtime, and version problems;
- start the managed Remote daemon on the server;
- invoke the official pairing command and present the real pairing instructions/code to the user;
- route VS Code into the same app-server used by CLI and mobile;
- verify that one conversation can be opened and continued across all three clients;
- provide exact rollback steps without deleting session data.

Here, "direct" means no personal PC relay; the connection still uses the official OpenAI/ChatGPT Remote service. The Skill never invents a pairing code and never bypasses OpenAI authentication. Pairing availability and account support remain controlled by Codex and ChatGPT.

## Why the shared app-server matters

A typical failure looks like this:

```text
thread-store conflict: thread ... already has an active writer
```

Mobile Remote and the CLI can share one managed daemon, while the VS Code extension normally starts a second app-server. Opening the same thread from both sides then creates competing writers and can make the VS Code webview flicker.

`codex-anywhere` routes the VS Code extension's stdio JSONL stream into the managed daemon's WebSocket-over-Unix-socket transport:

```text
Mobile Remote ──────────────┐
Codex CLI ──────────────────┼── shared managed app-server
VS Code → JSONL/WS bridge ──┘
```

## Requirements

- Linux with a working Codex CLI that supports `remote-control` and `app-server daemon`.
- Node.js 12 or newer.
- A running managed Remote daemon and its user-private Unix control socket.
- The Codex VS Code extension.
- If your network requires a proxy, working `HTTP_PROXY`/`HTTPS_PROXY` variables in the environment that starts the daemon.

## Quick start

Run diagnostics first:

```bash
bash skills/codex-anywhere/scripts/diagnose.sh
```

Start the server-side Remote daemon and request official phone pairing instructions:

```bash
codex remote-control start
codex remote-control pair
```

Complete the pairing flow shown by Codex on your phone. The server must be able to reach Codex directly; configure any required HTTP(S) proxy in the daemon's launch environment.

Preview and install the bridge:

```bash
bash skills/codex-anywhere/scripts/install.sh --dry-run
bash skills/codex-anywhere/scripts/install.sh
```

The installer prints a VS Code User setting similar to:

```json
"chatgpt.cliExecutable": "/home/you/.local/bin/codex-vscode-shared"
```

Apply it in VS Code User Settings JSON, then run `Developer: Reload Window`.

Read the canonical [setup runbook](skills/codex-anywhere/references/runbook.md) before changing a live daemon. For errors, use the [troubleshooting matrix](skills/codex-anywhere/references/troubleshooting.md).

## Install as a Codex skill

Copy or symlink the skill directory into your Codex skills directory:

```bash
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
ln -s "$(pwd)/skills/codex-anywhere" \
  "${CODEX_HOME:-$HOME/.codex}/skills/codex-anywhere"
```

Then invoke it explicitly with `$codex-anywhere`, or let Codex select it when the task matches its description.

## Development

Run the isolated smoke tests and skill validator:

```bash
bash skills/codex-anywhere/scripts/self-test.sh
python /path/to/skill-creator/scripts/quick_validate.py \
  skills/codex-anywhere
```

## Private runbooks

Machine-specific notes belong under `private/`, which is ignored by Git. Never commit usernames, home paths, hostnames, proxy endpoints, installation IDs, pairing codes, tokens, session IDs, or raw logs.

## License

Licensed under the [Apache License 2.0](LICENSE).

## References

- [OpenAI Docs: Build skills](https://learn.chatgpt.com/docs/build-skills)
- [OpenAI Docs: Codex App Server](https://learn.chatgpt.com/docs/app-server)
- [OpenAI Docs: Remote connections](https://learn.chatgpt.com/docs/remote-connections)
