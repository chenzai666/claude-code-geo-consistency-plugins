# Claude 出口一致性工具

这个仓库包含 Claude Code 插件和 Claude Desktop 扩展，用来检查当前运行环境的代理、出口 IP、Claude/Anthropic 访问路径是否一致。

它不是浏览器画像扩展，不会 patch `navigator`、`Intl`、`Date` 等网页 API，也不会读取网页或聊天内容。

## 目录

- `geo-consistency`：统一版 Claude Code 插件，优先推荐安装，会按当前系统自动调用 Windows 或 macOS 脚本。
- `geo-consistency-windows`：Windows 单平台入口，默认面向 v2rayN / PowerShell / `127.0.0.1:10808`。
- `geo-consistency-macos`：macOS 单平台入口，面向 zsh/bash 和本地代理端口检测。
- `claude-desktop-geo-consistency`：Claude Desktop Desktop Extension/MCPB 版本。

## Claude Code 安装

先在 Claude Code 里添加 marketplace：

```text
/plugin marketplace add chenzai666/claude-code-geo-consistency-plugins
```

推荐安装统一版：

```text
/plugin install geo-consistency@geo-consistency
```

也可以只安装单平台入口：

```text
/plugin install geo-consistency-windows@geo-consistency
```

```text
/plugin install geo-consistency-macos@geo-consistency
```

安装后执行：

```text
/reload-plugins
```

统一版可用命令：

```text
/geo-consistency:geo-status
/geo-consistency:geo-verify
```

单平台入口可用命令：

```text
/geo-consistency-windows:geo-status
/geo-consistency-windows:geo-verify
```

```text
/geo-consistency-macos:geo-status
/geo-consistency-macos:geo-verify
```

`geo-fix` 已移除。Claude Code 插件运行在已经启动的 Claude Code 进程下面，不能反向修改父进程环境；继续保留“修复当前会话”的命令会误导使用。代理环境请先用 `proxy-setup` 或你自己的 shell 配置准备好，再从这个终端启动 Claude Code。

## 默认值

- 代理主机：`127.0.0.1`
- HTTP 代理端口：`10808`
- SOCKS 代理端口：`10808`

这匹配 v2rayN 常见的 mixed/http 端口配置。端口不同可以在 slash command 后面传参数覆盖。

## Claude Code 卸载

在 Claude Code 中按你安装的入口执行：

```text
/plugin uninstall geo-consistency@geo-consistency
```

```text
/plugin uninstall geo-consistency-windows@geo-consistency
```

```text
/plugin uninstall geo-consistency-macos@geo-consistency
```

卸载后执行：

```text
/reload-plugins
```

如需移除 marketplace，可以在 `/plugin` 的 marketplace 管理界面删除 `geo-consistency`，或在终端执行：

```powershell
claude plugin marketplace remove geo-consistency --scope user
```

手动清理缓存时只删除本插件相关目录，不要清空整个 Claude Code 配置目录：

```powershell
Remove-Item -Recurse -Force "$env:USERPROFILE\.claude\plugins\cache\geo-consistency" -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force "$env:USERPROFILE\.claude\plugins\marketplaces\geo-consistency" -ErrorAction SilentlyContinue
```

macOS/Linux：

```bash
rm -rf "$HOME/.claude/plugins/cache/geo-consistency"
rm -rf "$HOME/.claude/plugins/marketplaces/geo-consistency"
```

## Claude Desktop 安装

安装仓库中的 Desktop Extension：

```text
claude-desktop-geo-consistency/dist/claude-desktop-geo-consistency.mcpb
```

在 Claude Desktop 中打开该 `.mcpb` 文件并确认安装。安装后可用 MCP 工具：

- `geo_status`
- `geo_verify`
- `geo_fix_terminal_proxy`

`geo_fix_terminal_proxy` 默认是 dry-run，不会直接修改环境；只有传 `apply=true` 才会写入用户级终端代理变量和 npm/git 代理配置。若你不想使用用户级环境变量，可以只使用 `geo_status` 和 `geo_verify`。

如果 Windows AppX 版 Claude Desktop 双击 `.mcpb` 弹出“Windows 无法访问指定设备、路径或文件”，在仓库根目录运行：

```powershell
cd .\claude-desktop-geo-consistency
powershell -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1
```

## Claude Desktop 卸载

优先在 Claude Desktop 中打开 `Settings > Extensions`，找到 `Claude Desktop Geo Consistency`，点击禁用或卸载，然后完全退出并重启 Claude Desktop。

如果需要清理本地构建产物，可以删除：

```powershell
Remove-Item -Recurse -Force ".\claude-desktop-geo-consistency\dist" -ErrorAction SilentlyContinue
```

这只删除仓库里的打包文件，不会删除 Claude Desktop 的账号、聊天记录或其他扩展。

## 隐私模型

- 无 telemetry。
- 无 analytics。
- 无账号系统。
- 不读取网页内容。
- 不读取 Claude 聊天内容。
- 外部请求只用于出口检测：`api.anthropic.com/cdn-cgi/trace`、`claude.ai/cdn-cgi/trace`、`cloudflare.com/cdn-cgi/trace`。
- Claude Code 插件只读取当前进程环境变量、系统代理摘要、本地端口状态、npm/git 代理配置和出口 trace。
