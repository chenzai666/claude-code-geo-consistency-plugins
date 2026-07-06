---
description: 验证 macOS Claude Code 直连、环境代理和显式代理出口是否一致
allowed-tools:
  - Bash(bash:*)
  - Bash(sh:*)
---

Run the macOS geo consistency verifier and report whether Claude Code's terminal environment, explicit proxy route, and Anthropic endpoints agree.

Use:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/geo-verify.sh" $ARGUMENTS
```

If `${CLAUDE_PLUGIN_ROOT}` is empty in this Claude Code version, ask the user where the plugin is installed, then run `scripts/geo-verify.sh` from that plugin directory.
