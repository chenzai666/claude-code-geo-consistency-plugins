---
description: 自动按当前系统查看 Claude Code 本地代理、环境变量和工具代理状态
allowed-tools:
  - Bash(powershell.exe:*)
  - Bash(pwsh:*)
  - Bash(bash:*)
  - Bash(sh:*)
---

Run the unified geo consistency status command. Status is a local runtime snapshot: proxy ports, process environment, system proxy, and npm/git proxy config. It is intentionally not the same as verify.

Final response contract: paste the command stdout exactly as the answer. Do not summarize it, do not convert it to bullets, do not add an intro sentence, and do not turn it into a verification verdict.

First detect the current operating system from the Claude Code runtime:

- On Windows, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}\scripts\windows\geo-status.ps1" $ARGUMENTS
```

- On macOS, run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/macos/geo-status.sh" $ARGUMENTS
```

- On Linux or any other OS, do not run the macOS script. Tell the user that the unified plugin currently supports Windows and macOS only.

If `${CLAUDE_PLUGIN_ROOT}` is empty in this Claude Code version, ask the user where the unified `geo-consistency` plugin is installed, then run the matching script from that plugin directory.
