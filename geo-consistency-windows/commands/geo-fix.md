---
description: 配置 Windows 用户级终端代理变量和 Claude Code 常用工具代理
allowed-tools:
  - Bash(powershell.exe:*)
  - Bash(pwsh:*)
---

Run the Windows geo consistency fixer. It persists user-level terminal proxy variables and configures npm/git proxy settings for future Claude Code sessions.

Use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}\scripts\geo-fix.ps1" $ARGUMENTS
```

If `${CLAUDE_PLUGIN_ROOT}` is empty in this Claude Code version, ask the user where the plugin is installed, then run `scripts\geo-fix.ps1` from that plugin directory.

After it completes, tell the user to restart Claude Code from a new terminal so the process inherits the new environment.
