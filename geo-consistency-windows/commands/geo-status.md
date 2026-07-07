---
description: 查看 Windows Claude Code 本地代理、环境变量和工具代理状态
allowed-tools:
  - Bash(powershell.exe:*)
  - Bash(pwsh:*)
---

Run the Windows geo consistency status script. Status is a local runtime snapshot: proxy ports, process environment, Windows system proxy, and npm/git proxy config.

Preserve the script output. Do not turn it into a verification verdict.

Use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}\scripts\geo-status.ps1" $ARGUMENTS
```

If `${CLAUDE_PLUGIN_ROOT}` is empty in this Claude Code version, ask the user where the plugin is installed, then run `scripts\geo-status.ps1` from that plugin directory.
