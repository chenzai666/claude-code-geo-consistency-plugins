---
description: 自动按当前系统配置 Claude Code 终端代理变量和常用工具代理
allowed-tools:
  - Bash(powershell.exe:*)
  - Bash(pwsh:*)
  - Bash(bash:*)
  - Bash(sh:*)
---

Run the unified geo consistency fixer. It persists terminal proxy settings using the native mechanism for the current operating system and configures npm/git proxy settings for future Claude Code sessions.

First detect the current operating system from the Claude Code runtime:

- On Windows, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_PLUGIN_ROOT}\scripts\windows\geo-fix.ps1" $ARGUMENTS
```

After the Windows script completes, tell the user to restart Claude Code from a new terminal so the process inherits the updated user environment.

- On macOS, run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/macos/geo-fix.sh" $ARGUMENTS
```

After the macOS script completes, tell the user to restart Claude Code from a new terminal, or source the rc file before launching Claude Code.

- On Linux or any other OS, do not run the macOS script. Tell the user that the unified plugin currently supports Windows and macOS only.

If `${CLAUDE_PLUGIN_ROOT}` is empty in this Claude Code version, ask the user where the unified `geo-consistency` plugin is installed, then run the matching script from that plugin directory.
