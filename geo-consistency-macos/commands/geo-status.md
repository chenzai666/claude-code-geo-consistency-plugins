---
description: 查看 macOS Claude Code 本地代理、环境变量和工具代理状态
allowed-tools:
  - Bash(bash:*)
  - Bash(sh:*)
---

Run the macOS geo consistency status script. Status is a local runtime snapshot: proxy ports, process environment, macOS system proxy, and npm/git proxy config.

Final response contract: paste the command stdout exactly as the answer. Do not summarize it, do not convert it to bullets, do not add an intro sentence, and do not turn it into a verification verdict.

Use:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/geo-status.sh" $ARGUMENTS
```

If `${CLAUDE_PLUGIN_ROOT}` is empty in this Claude Code version, ask the user where the plugin is installed, then run `scripts/geo-status.sh` from that plugin directory.
