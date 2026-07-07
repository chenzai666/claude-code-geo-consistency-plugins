---
description: 查询当前代理出口 IP 的地理画像（TZ、locale、代理环境变量），不启动新的 Claude Code 会话
allowed-tools:
  - Bash(powershell.exe:*)
  - Bash(pwsh:*)
  - Bash(bash:*)
  - Bash(sh:*)
---

Generate the launch profile for Windows Claude Code geo consistency. This command must not start a nested Claude Code session from inside the current Claude Code process. It should run the launcher in print-only mode and paste stdout exactly.

Final response contract: paste the command stdout exactly as the answer. Do not summarize it, do not convert it to bullets, and do not add an intro sentence.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}\scripts\geo-profile.ps1" -PrintOnly $ARGUMENTS
```

If `${CLAUDE_PLUGIN_ROOT}` is empty in this Claude Code version, ask the user where the `geo-consistency-windows` plugin is installed, then run the script from that plugin directory.
