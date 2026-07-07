---
description: 自动按当前系统验证 Claude Code 默认出口、显式代理出口和 Claude/Anthropic 出口是否一致
allowed-tools:
  - Bash(powershell.exe:*)
  - Bash(pwsh:*)
  - Bash(bash:*)
  - Bash(sh:*)
---

Run the unified geo consistency verifier. Verify is an external route comparison: direct route, terminal default route, explicit proxy route, and Claude/Anthropic trace route.

Preserve the Markdown tables printed by the script. Do not rewrite them as prose unless the user asks for a summary.

First detect the current operating system from the Claude Code runtime:

- On Windows, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}\scripts\windows\geo-verify.ps1" $ARGUMENTS
```

- On macOS, run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/macos/geo-verify.sh" $ARGUMENTS
```

- On Linux or any other OS, do not run the macOS script. Tell the user that the unified plugin currently supports Windows and macOS only.

If `${CLAUDE_PLUGIN_ROOT}` is empty in this Claude Code version, ask the user where the unified `geo-consistency` plugin is installed, then run the matching script from that plugin directory.
