---
description: 配置 macOS shell 代理变量和 Claude Code 常用工具代理
allowed-tools:
  - Bash(bash:*)
  - Bash(sh:*)
---

Run the macOS geo consistency fixer. It writes terminal proxy exports to the shell rc file and configures npm/git proxy settings for future Claude Code sessions.

Use:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/geo-fix.sh" $ARGUMENTS
```

If `${CLAUDE_PLUGIN_ROOT}` is empty in this Claude Code version, ask the user where the plugin is installed, then run `scripts/geo-fix.sh` from that plugin directory.

After it completes, tell the user to restart Claude Code from a new terminal so the process inherits the new environment.
