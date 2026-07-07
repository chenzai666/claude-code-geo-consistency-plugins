# Claude 出口一致性工具

这个仓库包含 Claude Code 插件和 Claude Desktop 扩展，用来检查当前运行环境的代理、出口 IP、Claude/Anthropic 访问路径是否一致。

它不是浏览器画像扩展，不会 patch `navigator`、`Intl`、`Date` 等网页 API，也不会读取网页或聊天内容。

## 目录

- `geo-consistency`：统一版 Claude Code 插件，优先推荐安装，会按当前系统自动调用 Windows 或 macOS 脚本。
- `geo-consistency-windows`：Windows 单平台入口，面向 v2rayN / Clash / sing-box，自动检测本地代理端口。
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
/geo-consistency:geo-profile
```

`geo-status` 默认只看本地配置和进程环境，不做外部出口请求；如需把出口 trace 加到 status 里，Windows 传 `-IncludeNetwork`，macOS 传 `--include-network`。`geo-verify` 才会做直连、终端默认路由、显式代理、Claude/Anthropic trace 的一致性对比，并以表格输出结论。

单平台入口可用命令：

```text
/geo-consistency-windows:geo-status
/geo-consistency-windows:geo-verify
/geo-consistency-windows:geo-profile
```

```text
/geo-consistency-macos:geo-status
/geo-consistency-macos:geo-verify
/geo-consistency-macos:geo-profile
```

`geo-fix` 已移除。Claude Code 插件运行在已经启动的 Claude Code 进程下面，不能反向修改父进程环境；继续保留“修复当前会话”的命令会误导使用。代理环境请先用 `proxy-setup` 或你自己的 shell 配置准备好，再从这个终端启动 Claude Code。

## 默认值

- 代理主机：`127.0.0.1`
- 代理端口：**自动检测**，按 v2rayN(`10808`) → Clash(`7890`/`7891`) → sing-box(`7897`) 顺序扫描，以第一个监听端口为准；均未监听时回退到 `10808`

端口不同或需要固定端口时，可在 slash command 后面传参数覆盖，例如 `--http-port 7890 --socks-port 7891`。

## 代理变量说明

`HTTP_PROXY` / `HTTPS_PROXY` 是按协议指定的代理变量，`ALL_PROXY` 是兜底变量。若当前 Claude Code 进程没有 `HTTP_PROXY` / `HTTPS_PROXY`，但有 `ALL_PROXY=socks5://127.0.0.1:10808`，curl 仍会通过 SOCKS 代理访问 HTTP/HTTPS 目标。v2rayN 的 `10808` 常见是 mixed port，因此同一个端口可以同时接受 `http://` 和 `socks5://` 代理写法。

`geo-verify` 里的 `terminalHttpProxyCovered` / `terminalHttpsProxyCovered` 会把 `ALL_PROXY` fallback 计算进去；只要它们为 `True`，就表示 HTTP/HTTPS 出口已有代理覆盖。

## 时区和语言画像一致

`geo-verify` 现在会检测显式代理出口 IP 的画像，并和当前 Claude Code 运行时画像对比：

- 出口画像：IP、国家码、城市/地区/国家、经纬度、ISP、IANA timezone。
- 本地运行时：`TZ`、Node/Intl 当前 timezone、系统 timezone、`LANG`、`LC_ALL`、`LC_MESSAGES`、`LANGUAGE`。
- 推断 bundle：`language`、`languages`、`acceptLanguage`、`posixLocale`、`timezone`。

如果出口是 `US / America/Chicago / en-US`，但 Claude Code 运行时仍是 `Asia/Shanghai / zh-CN`，`geo-verify` 会给出 WARN。

在 Claude Code 内可以运行 `geo-profile` 查询当前代理出口的地理画像：

```text
/geo-consistency:geo-profile
```

命令输出出口 IP、国家、时区、locale 以及会注入的代理环境变量，供参考用；它不启动嵌套 Claude Code。要让时区和语言真正生效，请从外部终端用 launcher 启动新的 Claude Code：

```powershell
cd D:\codex-demo\claude-code-geo-consistency-plugins
powershell -NoProfile -ExecutionPolicy Bypass -File .\geo-consistency\scripts\windows\geo-profile.ps1 -c
```

macOS：

```bash
cd /path/to/claude-code-geo-consistency-plugins
bash ./geo-consistency/scripts/macos/geo-profile.sh
```

launcher 会先按代理出口 IP 查询地理画像，再给子进程注入 `TZ`、`LANG`、`LC_ALL`、`LC_MESSAGES`、`LANGUAGE`、`ACCEPT_LANGUAGE` 以及代理变量，最后启动 `claude`。它不写入用户级环境变量，也不修改系统区域设置。

Windows 版 launcher 会把未知参数原样透传给 Claude Code，例如 `-c`、`--dangerously-skip-permissions`。如果要把 `--print-only` 或 `--claude-command` 当作 Claude Code 参数传入，请用 `--` 分隔。

注意：`TZ` 对 Node/Claude Code 的默认 timezone 通常生效；语言会按出口 IP 注入到 `LANG`、`LC_ALL`、`LANGUAGE`、`ACCEPT_LANGUAGE`。但 Windows 上 Node/Bun 的默认 `Intl` locale 往往来自系统区域设置，`LANG/LC_ALL` 不一定能把 `Intl.DateTimeFormat().resolvedOptions().locale` 从 `zh-CN` 改成 `en-US`。插件会保证子进程语言环境变量和时区一致，并在 `verify` 表格里单独显示 `languageEnvMatchesExit` 与 `nodeLocaleMatchesExit`。

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
- 外部请求只用于出口检测和出口画像匹配：`api.anthropic.com/cdn-cgi/trace`、`claude.ai/cdn-cgi/trace`、`cloudflare.com/cdn-cgi/trace`、`ipapi.co/json`、`ipinfo.io/json`、`ipwho.is`。
- Claude Code 插件只读取当前进程环境变量、系统代理摘要、本地端口状态、npm/git 代理配置和出口 trace。
