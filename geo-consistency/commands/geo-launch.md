---
description: 生成与当前代理出口 IP 一致的 Claude Code 启动画像，包括 TZ、locale 和代理环境变量
allowed-tools:
  - Bash(powershell.exe:*)
  - Bash(pwsh:*)
  - Bash(bash:*)
  - Bash(sh:*)
---

Generate the launch profile for Claude Code geo consistency. This command must not start a nested Claude Code session from inside the current Claude Code process. It should run the launcher in print-only mode and paste stdout exactly.

Final response contract: paste the command stdout exactly as the answer. Do not summarize it, do not convert it to bullets, and do not add an intro sentence.

First detect the current operating system from the Claude Code runtime:

- On Windows, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}\scripts\windows\geo-launch.ps1" -PrintOnly $ARGUMENTS
```

- On macOS, run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/macos/geo-launch.sh" --print-only $ARGUMENTS
```

- On Linux or any other OS, do not run the macOS script. Tell the user that the unified plugin currently supports Windows and macOS only.

If `${CLAUDE_PLUGIN_ROOT}` is empty in this Claude Code version, ask the user where the unified `geo-consistency` plugin is installed, then run the matching script from that plugin directory.
