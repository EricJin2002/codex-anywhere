# codex-anywhere

[English](README.md) | 简体中文

让 Linux 服务器成为可以直接从手机访问的 Codex 主机——无需让个人 Windows 或 macOS 电脑保持在线充当中转。

`codex-anywhere` 帮助 AI agent 配置服务器端 Codex Remote daemon，启动官方手机配对流程，并让 Codex CLI、ChatGPT Remote/移动端和 Codex VS Code 扩展连接到同一个共享 app-server。最终得到的是一套可在终端、手机和编辑器之间同步工作区与会话历史的环境。

> [!WARNING]
> Codex app-server 和 WebSocket 传输目前仍属于实验性能力。本项目不是 OpenAI 官方项目，Codex 升级后兼容性可能发生变化。

## 项目理念

传统远程工作流通常需要一台个人电脑作为中间节点：服务器需要通过笔记本或台式机访问，手机能否连接也取决于这台电脑是否持续在线。`codex-anywhere` 改为直接让 Ubuntu/Linux 服务器承担 Codex 主机角色：

```text
手机 / ChatGPT Remote <--> OpenAI Remote 服务 <== 出站连接 == Linux 服务器
                                                               |
                                  +----------------------------+---------------+
                                  |                            |               |
                              Codex CLI                   VS Code        代码仓库、
                                                         bridge         工具和任务
                                  +--------- 共享 app-server ---------------+
```

完成配置后，使用项目内置 Skill 的 AI 可以：

- 诊断代理、daemon、socket、运行时和版本问题；
- 在服务器上启动 managed Remote daemon；
- 调用官方配对命令，把真实配对说明或配对码提供给用户；
- 让 VS Code 接入 CLI 和手机正在使用的同一个 app-server；
- 验证同一会话能否在三个客户端之间打开、继续和同步；
- 在不删除会话数据的前提下给出准确回滚步骤。

这里的“直连”是指不需要个人 PC 中转；连接仍然通过官方 OpenAI/ChatGPT Remote 服务。Skill 不会伪造配对码，也不会绕过 OpenAI 身份验证。配对能力和账户可用性仍由 Codex 与 ChatGPT 决定。

## 为什么需要共享 app-server

典型故障如下：

```text
thread-store conflict: thread ... already has an active writer
```

Mobile Remote 和 CLI 可以共享一个 managed daemon，但 VS Code 扩展通常会另外启动一个 app-server。当双方打开同一个 thread 时，两个独立 writer 会发生竞争，从而导致 VS Code webview 反复闪烁。

`codex-anywhere` 将 VS Code 扩展的 stdio JSONL 数据流桥接到 managed daemon 的 Unix socket WebSocket 传输：

```text
Mobile Remote ──────────────┐
Codex CLI ──────────────────┼── 共享 managed app-server
VS Code → JSONL/WS bridge ──┘
```

## 环境要求

- Linux，以及支持 `remote-control` 和 `app-server daemon` 的 Codex CLI。
- Node.js 12 或更高版本。
- 正在运行的 managed Remote daemon 及其仅当前用户可访问的 Unix control socket。
- Codex VS Code 扩展。
- 如果网络需要代理，启动 daemon 的环境必须具有可用的 `HTTP_PROXY`/`HTTPS_PROXY` 变量。

## 快速开始

首先运行只读诊断：

```bash
bash skills/codex-anywhere/scripts/diagnose.sh
```

启动服务器端 Remote daemon，并请求官方手机配对信息：

```bash
codex remote-control start
codex remote-control pair
```

按照 Codex 输出的流程在手机上完成配对。服务器本身必须能够连接 Codex；如果需要 HTTP(S) 代理，应把代理变量配置到启动 daemon 的环境中。

预览并安装桥接器：

```bash
bash skills/codex-anywhere/scripts/install.sh --dry-run
bash skills/codex-anywhere/scripts/install.sh
```

安装器会输出类似下面的 VS Code User setting：

```json
"chatgpt.cliExecutable": "/home/you/.local/bin/codex-vscode-shared"
```

将其加入 VS Code User Settings JSON，然后运行 `Developer: Reload Window`。

修改正在运行的 daemon 前，请先阅读完整的[配置手册](skills/codex-anywhere/references/runbook.md)。遇到报错时可查看[故障排查矩阵](skills/codex-anywhere/references/troubleshooting.md)。

## 安装为 Codex Skill

复制 Skill 目录，或将它软链接到 Codex skills 目录：

```bash
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
ln -s "$(pwd)/skills/codex-anywhere" \
  "${CODEX_HOME:-$HOME/.codex}/skills/codex-anywhere"
```

之后可以用 `$codex-anywhere` 显式调用，也可以在任务与 Skill 描述匹配时让 Codex 自动选择。

## 开发与验证

运行隔离的 smoke test 和 Skill 校验器：

```bash
bash skills/codex-anywhere/scripts/self-test.sh
python /path/to/skill-creator/scripts/quick_validate.py \
  skills/codex-anywhere
```

## 私人操作手册

机器专属信息应放在 `private/` 下；该目录已被 Git 忽略。不要提交用户名、主目录路径、主机名、代理地址、installation ID、配对码、token、session ID 或原始日志。

## 许可证

本项目采用 [Apache License 2.0](LICENSE)。

## 参考资料

- [OpenAI Docs：构建 Skills](https://learn.chatgpt.com/docs/build-skills)
- [OpenAI Docs：Codex App Server](https://learn.chatgpt.com/docs/app-server)
- [OpenAI Docs：Remote connections](https://learn.chatgpt.com/docs/remote-connections)
