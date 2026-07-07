---
description: 验证 Windows Claude Code 默认出口、显式代理出口和 Claude/Anthropic 出口是否一致
allowed-tools:
  - Bash(powershell.exe:*)
  - Bash(pwsh:*)
---

Run the Windows geo consistency verifier. Verify is an external route comparison: direct route, terminal default route, explicit proxy route, and Claude/Anthropic trace route.

Preserve the Markdown tables printed by the script. Do not rewrite them as prose unless the user asks for a summary.

Use:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}\scripts\geo-verify.ps1" $ARGUMENTS
```

If `${CLAUDE_PLUGIN_ROOT}` is empty in this Claude Code version, ask the user where the plugin is installed, then run `scripts\geo-verify.ps1` from that plugin directory.
