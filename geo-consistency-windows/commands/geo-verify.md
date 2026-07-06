---
description: 验证 Windows Claude Code 直连、环境代理和显式代理出口是否一致
allowed-tools:
  - Bash(powershell.exe:*)
  - Bash(pwsh:*)
---

Run the Windows geo consistency verifier and report whether Claude Code's terminal environment, explicit proxy route, and Anthropic endpoints agree.

Use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}\scripts\geo-verify.ps1" $ARGUMENTS
```

If `${CLAUDE_PLUGIN_ROOT}` is empty in this Claude Code version, ask the user where the plugin is installed, then run `scripts\geo-verify.ps1` from that plugin directory.
