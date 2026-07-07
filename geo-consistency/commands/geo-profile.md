---
description: 查询当前代理出口 IP 的地理画像（TZ、locale、代理环境变量），不启动新的 Claude Code 会话
allowed-tools:
  - Bash(powershell.exe:*)
  - Bash(pwsh:*)
  - Bash(bash:*)
  - Bash(sh:*)
---

Query the geo profile for the current proxy exit IP — the TZ, locale, and proxy env vars that would be injected if Claude Code were launched with this proxy. This command must not start a nested Claude Code session inside the current process. It runs the launcher in print-only mode and pastes stdout exactly.

Final response contract: paste the command stdout exactly as the answer. Do not summarize it, do not convert it to bullets, and do not add an intro sentence.

First detect the current operating system from the Claude Code runtime:

- On Windows, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}\scripts\windows\geo-profile.ps1" -PrintOnly $ARGUMENTS
```

- On macOS, run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/macos/geo-profile.sh" --print-only $ARGUMENTS
```

- On Linux or any other OS, do not run the macOS script. Tell the user that the unified plugin currently supports Windows and macOS only.

If `${CLAUDE_PLUGIN_ROOT}` is empty in this Claude Code version, ask the user where the unified `geo-consistency` plugin is installed, then run the matching script from that plugin directory.
