---
description: 查看 macOS Claude Code 代理、工具代理和出口状态
allowed-tools:
  - Bash(bash:*)
  - Bash(sh:*)
---

Run the macOS geo consistency status script and summarize the result.

Use:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/geo-status.sh" $ARGUMENTS
```

If `${CLAUDE_PLUGIN_ROOT}` is empty in this Claude Code version, ask the user where the plugin is installed, then run `scripts/geo-status.sh` from that plugin directory.
