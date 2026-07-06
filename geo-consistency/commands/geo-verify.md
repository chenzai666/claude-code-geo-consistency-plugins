---
description: 自动按当前系统验证 Claude Code 直连、环境代理和显式代理出口是否一致
allowed-tools:
  - Bash(powershell.exe:*)
  - Bash(pwsh:*)
  - Bash(bash:*)
  - Bash(sh:*)
---

Run the unified geo consistency verifier and report whether Claude Code's terminal environment, explicit proxy route, and Anthropic endpoints agree.

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
